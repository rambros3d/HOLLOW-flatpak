import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;

/// Tracks pinned message IDs per channel.
/// State: Map of "serverId:channelId" to List of message IDs.
class PinnedNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() => {};

  /// Load pinned messages for a channel from DB.
  Future<void> loadPins(String serverId, String channelId) async {
    final key = '$serverId:$channelId';
    try {
      final pins = await crdt_api.getPinnedMessages(
        serverId: serverId,
        channelId: channelId,
      );
      state = {...state, key: pins};
    } catch (e) {
      debugPrint('[HAVEN] Failed to load pins: $e');
    }
  }

  /// Called when a message is pinned (from event).
  void applyPin(String serverId, String channelId, String messageId) {
    final key = '$serverId:$channelId';
    final current = state[key] ?? [];
    if (!current.contains(messageId)) {
      state = {...state, key: [...current, messageId]};
    }
  }

  /// Called when a message is unpinned (from event).
  void applyUnpin(String serverId, String channelId, String messageId) {
    final key = '$serverId:$channelId';
    final current = state[key];
    if (current != null) {
      final updated = current.where((id) => id != messageId).toList();
      if (updated.isEmpty) {
        state = Map.from(state)..remove(key);
      } else {
        state = {...state, key: updated};
      }
    }
  }
}

final pinnedProvider =
    NotifierProvider<PinnedNotifier, Map<String, List<String>>>(
        PinnedNotifier.new);
