import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/rust/api/crdt.dart' as crdt_api;

/// Cache of server avatar bytes keyed by server_id.
class ServerAvatarNotifier extends Notifier<Map<String, Uint8List>> {
  @override
  Map<String, Uint8List> build() => {};

  /// Load a server avatar from DB and cache it.
  Future<void> loadAvatar(String serverId) async {
    try {
      final bytes = await crdt_api.getServerAvatar(serverId: serverId);
      if (bytes != null && bytes.isNotEmpty) {
        state = {...state, serverId: bytes};
      } else {
        if (state.containsKey(serverId)) {
          final next = Map<String, Uint8List>.from(state);
          next.remove(serverId);
          state = next;
        }
      }
    } catch (e) {
      debugPrint('[HOLLOW] Failed to load server avatar for $serverId: $e');
    }
  }

  /// Load avatars for all servers.
  Future<void> loadAll(List<String> serverIds) async {
    for (final id in serverIds) {
      await loadAvatar(id);
    }
  }
}

final serverAvatarProvider =
    NotifierProvider<ServerAvatarNotifier, Map<String, Uint8List>>(
  ServerAvatarNotifier.new,
);
