import 'dart:async';
import 'dart:io';

import '../../rust/api/network.dart' as network_api;
import 'video_thumbnail_service.dart';

void _log(String msg) {
  network_api.logFromDart(message: msg);
}

/// Extracts duration metadata from audio files using the bundled ffmpeg binary.
///
/// Reuses [VideoThumbnailService.findFfmpegBinary] to locate the binary and
/// the same `Duration: HH:MM:SS.cs` stderr parsing pattern.
///
/// Results are cached in-memory so repeated widget rebuilds don't re-probe.
class AudioProbeService {
  static final Map<String, int> _cache = {};

  /// Returns the duration in milliseconds for the audio file at [audioPath],
  /// or null if probing fails (missing ffmpeg, corrupt file, timeout).
  ///
  /// Results are cached by path — subsequent calls for the same path return
  /// instantly.
  static Future<int?> probeDurationMs(String audioPath) async {
    final cached = _cache[audioPath];
    if (cached != null) return cached;

    final ffmpeg = VideoThumbnailService.findFfmpegBinary();
    if (ffmpeg == null) return null;

    if (!File(audioPath).existsSync()) return null;

    try {
      // Run ffmpeg with no output — we only need the stderr probe info.
      // -i <path>    input file (triggers format detection + probe)
      // -f null -    discard output (we just want the probe metadata)
      final result = await Process.run(
        ffmpeg,
        ['-i', audioPath, '-f', 'null', '-'],
        stdoutEncoding: null,
        stderrEncoding: null,
      ).timeout(const Duration(seconds: 5));

      final stderrStr = _bytesToString(result.stderr);
      final durationMs = _parseDuration(stderrStr);
      if (durationMs != null && durationMs > 0) {
        _cache[audioPath] = durationMs;
        return durationMs;
      }
      return null;
    } on TimeoutException {
      _log('[AudioProbe] ffmpeg timed out on: $audioPath');
      return null;
    } catch (e) {
      _log('[AudioProbe] probe failed: $e');
      return null;
    }
  }

  /// Parse `Duration: HH:MM:SS.cs` from ffmpeg stderr.
  /// Same regex pattern as [VideoThumbnailService._parseFfmpegStderr].
  static int? _parseDuration(String stderr) {
    final match =
        RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(stderr);
    if (match == null) return null;

    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    final csStr = match.group(4) ?? '0';
    final cs = int.tryParse(csStr) ?? 0;
    final ms = csStr.length == 2
        ? cs * 10
        : (csStr.length == 3 ? cs : (cs * 1000 ~/ _pow10(csStr.length)));
    return ((h * 3600 + m * 60 + s) * 1000) + ms;
  }

  static String _bytesToString(dynamic bytes) {
    if (bytes is List<int>) {
      try {
        return String.fromCharCodes(bytes);
      } catch (_) {
        return '';
      }
    }
    if (bytes is String) return bytes;
    return bytes?.toString() ?? '';
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}
