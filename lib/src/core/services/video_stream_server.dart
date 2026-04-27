import 'dart:io';

import 'package:flutter/foundation.dart';

class VideoStreamServer {
  HttpServer? _server;
  RandomAccessFile? _raf;
  int _availableBytes = 0;
  int _totalSize = 0;
  String _mimeType = 'video/mp4';

  Uri? get uri => _server == null
      ? null
      : Uri.parse('http://127.0.0.1:${_server!.port}/video');

  Future<Uri> start(String filePath, int totalSize, String mimeType) async {
    await stop();
    _totalSize = totalSize;
    _mimeType = mimeType;
    _raf = await File(filePath).open(mode: FileMode.read);

    final fileLength = await File(filePath).length();
    _availableBytes = fileLength;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);

    final serverUri = Uri.parse('http://127.0.0.1:${_server!.port}/video');
    debugPrint('[HOLLOW-STREAM] Video server started at $serverUri (available: $_availableBytes / $_totalSize)');
    return serverUri;
  }

  void updateAvailableBytes(int bytes) {
    _availableBytes = bytes;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _raf?.closeSync();
    _raf = null;
    _availableBytes = 0;
    _totalSize = 0;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final raf = _raf;
    if (raf == null) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..close();
      return;
    }

    final rangeHeader = request.headers.value('range');

    if (rangeHeader == null) {
      if (_availableBytes >= _totalSize) {
        await _serveRange(request, raf, 0, _totalSize - 1, _totalSize);
      } else if (_availableBytes > 0) {
        await _serveRange(request, raf, 0, _availableBytes - 1, _totalSize);
      } else {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.set('Retry-After', '1')
          ..close();
      }
      return;
    }

    final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
    if (match == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final start = int.parse(match.group(1)!);
    final endStr = match.group(2);
    var end = (endStr != null && endStr.isNotEmpty)
        ? int.parse(endStr)
        : _totalSize - 1;

    if (start >= _availableBytes) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.set('Retry-After', '1')
        ..close();
      return;
    }

    if (end >= _availableBytes) {
      end = _availableBytes - 1;
    }

    await _serveRange(request, raf, start, end, _totalSize);
  }

  Future<void> _serveRange(
    HttpRequest request,
    RandomAccessFile raf,
    int start,
    int end,
    int totalSize,
  ) async {
    final length = end - start + 1;
    request.response
      ..statusCode = HttpStatus.partialContent
      ..headers.contentType = ContentType.parse(_mimeType)
      ..headers.contentLength = length
      ..headers.set('Accept-Ranges', 'bytes')
      ..headers.set('Content-Range', 'bytes $start-$end/$totalSize');

    try {
      await raf.setPosition(start);
      const chunkSize = 65536;
      var remaining = length;
      while (remaining > 0) {
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final bytes = await raf.read(toRead);
        if (bytes.isEmpty) break;
        request.response.add(bytes);
        remaining -= bytes.length;
      }
      await request.response.close();
    } catch (e) {
      debugPrint('[HOLLOW-STREAM] Error serving range: $e');
      try { await request.response.close(); } catch (_) {}
    }
  }
}
