import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request =
          await client.getUrl(Uri.parse('$_kSignalingUrl/turn-credentials'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        debugPrint('[HOLLOW-ICE] TURN credentials fetch failed: $body');
        return;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final username = json['username'] as String;
      final password = json['password'] as String;
      final uris = (json['uris'] as List).cast<String>();

      // Build full ICE config with STUN + TURN.
      state = {
        'iceServers': [
          // Own STUN (coturn doubles as STUN)
          {'urls': 'stun:relay.anonlisten.com:3478'},
          // Fallback STUN servers
          {'urls': 'stun:stun.cloudflare.com:3478'},
          {'urls': 'stun:stun.l.google.com:19302'},
          // TURN servers (for symmetric NAT)
          {
            'urls': uris,
            'username': username,
            'credential': password,
          },
        ],
      };

      debugPrint('[HOLLOW-ICE] TURN credentials fetched, ${uris.length} URIs');

      // Schedule refresh before expiry.
      _refreshTimer?.cancel();
      _refreshTimer = Timer(_kRefreshInterval, _fetchTurnCredentials);
    } catch (e) {
      debugPrint('[HOLLOW-ICE] Failed to fetch TURN credentials: $e');
      // Retry in 30 seconds on failure.
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 30), _fetchTurnCredentials);
    }
  }
}

final iceConfigProvider =
    NotifierProvider<IceConfigNotifier, Map<String, dynamic>>(
        IceConfigNotifier.new);
