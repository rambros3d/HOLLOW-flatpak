import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rust/api/network.dart' as network_api;
import 'relay_domain_provider.dart';

/// Log to hollow_debug.log (visible in release builds + debug file).
void _iceLog(String msg) {
  network_api.logFromDart(message: msg);
}

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
    return _stunOnlyConfig();
  }

  String get _domain => ref.read(relayDomainProvider);

  Map<String, dynamic> _stunOnlyConfig() => {
    'iceServers': [
      {'urls': 'stun:$_domain:3478'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  Future<void> _fetchTurnCredentials() async {
    final signalingUrl = 'https://$_domain';
    _iceLog('[HOLLOW-ICE] Fetching TURN credentials from $signalingUrl/turn-credentials');
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request =
          await client.getUrl(Uri.parse('$signalingUrl/turn-credentials'));
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

      // IMPORTANT: Each TURN URI must be a SEPARATE iceServer entry.
      final turnServers = uris
          .map((uri) => <String, dynamic>{
                'urls': uri,
                'username': username,
                'credential': password,
              })
          .toList();

      state = {
        'iceServers': [
          {'urls': 'stun:$_domain:3478'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
          {'urls': 'stun:stun.l.google.com:19302'},
          ...turnServers,
        ],
      };

      _iceLog('[HOLLOW-ICE] TURN credentials OK: ${uris.length} URIs, username=${username.split(':').first}...');

      _refreshTimer?.cancel();
      _refreshTimer = Timer(_kRefreshInterval, _fetchTurnCredentials);
    } catch (e) {
      _iceLog('[HOLLOW-ICE] TURN credentials fetch EXCEPTION: $e');
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
  final domain = ref.watch(relayDomainProvider);
  return {
    'iceServers': [
      {'urls': 'stun:$domain:3478'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };
});

/// ICE config for hidden Share connections (video streaming, large files).
/// STUN-only — large file transfers through TURN would saturate relay bandwidth.
final streamIceConfigProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(shareIceConfigProvider);
});
