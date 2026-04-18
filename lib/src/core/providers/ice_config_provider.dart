import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rust/api/network.dart' as network_api;

/// Log to hollow_debug.log (visible in release builds + debug file).
void _iceLog(String msg) {
  network_api.logFromDart(message: msg);
}

const _kSignalingUrl = 'http://141.227.186.209:8080';
const _kRefreshInterval = Duration(minutes: 50); // credentials last 1 hour

/// ICE server configuration with STUN and TURN servers.
///
/// Fetches time-limited TURN credentials from the relay server on startup
/// and refreshes them before they expire. Falls back to STUN-only if
/// TURN credentials are unavailable.
class IceConfigNotifier extends Notifier<Map<String, dynamic>> {
  Timer? _refreshTimer;

  @override
  Map<String, dynamic> build() {
    // Start with STUN-only, fetch TURN credentials async.
    _fetchTurnCredentials();
    ref.onDispose(() => _refreshTimer?.cancel());
    return _stunOnlyConfig;
  }

  /// STUN-only fallback config (works for 85-90% of peers).
  static final _stunOnlyConfig = {
    'iceServers': [
      {'urls': 'stun:relay.anonlisten.com:3478'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  Future<void> _fetchTurnCredentials() async {
    _iceLog('[HOLLOW-ICE] Fetching TURN credentials from $_kSignalingUrl/turn-credentials');
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request =
          await client.getUrl(Uri.parse('$_kSignalingUrl/turn-credentials'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        _iceLog('[HOLLOW-ICE] TURN credentials fetch FAILED: HTTP ${response.statusCode} — $body');
        return;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final username = json['username'] as String;
      final password = json['password'] as String;
      final uris = (json['uris'] as List).cast<String>();

      // Build full ICE config with STUN + TURN.
      // IMPORTANT: Each TURN URI must be a SEPARATE iceServer entry.
      // flutter_webrtc's native C++ layer (FlutterWebRTCBase::CreateIceServers)
      // has a single `uri` field per IceServer struct — a list of URLs gets
      // overwritten to only the last one. Splitting ensures all transports
      // (UDP, TCP, TLS) are tried with proper credentials.
      final turnServers = uris
          .map((uri) => <String, dynamic>{
                'urls': uri,
                'username': username,
                'credential': password,
              })
          .toList();

      state = {
        'iceServers': [
          // Own STUN (coturn doubles as STUN)
          {'urls': 'stun:relay.anonlisten.com:3478'},
          // Fallback STUN servers
          {'urls': 'stun:stun.cloudflare.com:3478'},
          {'urls': 'stun:stun.l.google.com:19302'},
          // TURN servers — one entry per transport (UDP, TCP, TLS)
          ...turnServers,
        ],
      };

      _iceLog('[HOLLOW-ICE] TURN credentials OK: ${uris.length} URIs, username=${username.split(':').first}...');

      // Schedule refresh before expiry.
      _refreshTimer?.cancel();
      _refreshTimer = Timer(_kRefreshInterval, _fetchTurnCredentials);
    } catch (e) {
      _iceLog('[HOLLOW-ICE] TURN credentials fetch EXCEPTION: $e');
      // Retry in 30 seconds on failure.
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 30), _fetchTurnCredentials);
    }
  }
}

final iceConfigProvider =
    NotifierProvider<IceConfigNotifier, Map<String, dynamic>>(
        IceConfigNotifier.new);

/// STUN-only ICE config used by Hollow Share data channels (Phase 7A).
///
/// Per HOLLOW_PLAN.md §7A: share traffic must NOT consume relay (TURN)
/// bandwidth — that capacity is reserved for messaging and voice. About
/// 85% of peers connect via STUN; the rest can't participate in a given
/// share but can still join other shares.
///
/// Pass this map to `RTCPeerConnection` factory calls whose room ID begins
/// with `share:`. Mirrors `IceConfigNotifier._stunOnlyConfig`.
final shareIceConfigProvider = Provider<Map<String, dynamic>>((ref) {
  return const {
    'iceServers': [
      {'urls': 'stun:relay.anonlisten.com:3478'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };
});
