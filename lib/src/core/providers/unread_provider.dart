import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/rust/api/storage.dart' as storage_api;

/// Tracks unread message state per channel and per DM.
///
/// "Seen" = the channel/DM was selected while the app was focused.
/// Stored in app_settings as:
/// - `seen:ch:{serverId}:{channelId}` → last seen message ID
/// - `seen:dm:{peerId}` → last seen message ID
///
/// Unread count is computed by comparing the stored last-seen ID
/// against the latest message ID from in-memory state.
class UnreadNotifier extends Notifier<UnreadState> {
  @override
  UnreadState build() => const UnreadState();

  /// Load last-seen state from DB on startup.
  Future<void> loadAll(
      Map<String, List<String>> serverChannels,
      List<String> dmPeerIds) async {
    final channelSeen = <String, String>{};
    final dmSeen = <String, String>{};

    for (final entry in serverChannels.entries) {
      for (final cid in entry.value) {
        final key = 'seen:ch:${entry.key}:$cid';
        final val = await storage_api.loadSetting(key: key);
        if (val != null) {
          channelSeen['${entry.key}:$cid'] = val;
        }
      }
    }

    for (final peerId in dmPeerIds) {
      final val = await storage_api.loadSetting(key: 'seen:dm:$peerId');
      if (val != null) {
        dmSeen[peerId] = val;
      }
    }

    state = UnreadState(
      channelLastSeen: channelSeen,
      dmLastSeen: dmSeen,
    );
  }

  /// Mark a channel as seen (user is viewing it).
  Future<void> markChannelSeen(
      String serverId, String channelId, String? latestMessageId) async {
    if (latestMessageId == null) return;
    final key = '$serverId:$channelId';

    // Update in-memory.
    final updatedSeen =
        Map<String, String>.from(state.channelLastSeen);
    updatedSeen[key] = latestMessageId;

    // Clear unread count.
    final updatedCounts =
        Map<String, int>.from(state.channelUnreadCounts);
    updatedCounts.remove(key);

    state = state.copyWith(
      channelLastSeen: updatedSeen,
      channelUnreadCounts: updatedCounts,
    );

    // Persist.
    await storage_api.saveSetting(
      key: 'seen:ch:$serverId:$channelId',
      value: latestMessageId,
    );
  }

  /// Mark a DM as seen.
  Future<void> markDmSeen(String peerId, String? latestMessageId) async {
    if (latestMessageId == null) return;

    final updatedSeen = Map<String, String>.from(state.dmLastSeen);
    updatedSeen[peerId] = latestMessageId;

    final updatedCounts = Map<String, int>.from(state.dmUnreadCounts);
    updatedCounts.remove(peerId);

    state = state.copyWith(
      dmLastSeen: updatedSeen,
      dmUnreadCounts: updatedCounts,
    );

    await storage_api.saveSetting(
      key: 'seen:dm:$peerId',
      value: latestMessageId,
    );
  }

  /// Called when a new live channel message arrives.
  /// Increments unread count if the channel is not currently viewed.
  void onChannelMessage(String serverId, String channelId,
      String messageId, bool isCurrentlyViewing) {
    if (isCurrentlyViewing) {
      // User is looking at this channel — mark as seen immediately.
      markChannelSeen(serverId, channelId, messageId);
      return;
    }

    final key = '$serverId:$channelId';
    final updatedCounts =
        Map<String, int>.from(state.channelUnreadCounts);
    updatedCounts[key] = (updatedCounts[key] ?? 0) + 1;

    // Also track the latest message ID.
    final updatedLatest =
        Map<String, String>.from(state.channelLatestId);
    updatedLatest[key] = messageId;

    state = state.copyWith(
      channelUnreadCounts: updatedCounts,
      channelLatestId: updatedLatest,
    );
  }

  /// Called when a new live DM arrives.
  void onDmMessage(
      String peerId, String messageId, bool isCurrentlyViewing) {
    if (isCurrentlyViewing) {
      markDmSeen(peerId, messageId);
      return;
    }

    final updatedCounts = Map<String, int>.from(state.dmUnreadCounts);
    updatedCounts[peerId] = (updatedCounts[peerId] ?? 0) + 1;

    final updatedLatest = Map<String, String>.from(state.dmLatestId);
    updatedLatest[peerId] = messageId;

    state = state.copyWith(
      dmUnreadCounts: updatedCounts,
      dmLatestId: updatedLatest,
    );
  }

  /// Get unread count for a channel.
  int channelUnreadCount(String serverId, String channelId) {
    return state.channelUnreadCounts['$serverId:$channelId'] ?? 0;
  }

  /// Get total unread count for a server (sum of all channels).
  int serverUnreadCount(String serverId) {
    int total = 0;
    for (final entry in state.channelUnreadCounts.entries) {
      if (entry.key.startsWith('$serverId:')) {
        total += entry.value;
      }
    }
    return total;
  }

  /// Whether a channel has unread messages.
  bool isChannelUnread(String serverId, String channelId) {
    return channelUnreadCount(serverId, channelId) > 0;
  }

  /// Whether any channel in a server has unread messages.
  bool isServerUnread(String serverId) {
    return serverUnreadCount(serverId) > 0;
  }

  /// Get unread count for a DM.
  int dmUnreadCount(String peerId) {
    return state.dmUnreadCounts[peerId] ?? 0;
  }

  /// Whether a DM has unread messages.
  bool isDmUnread(String peerId) {
    return dmUnreadCount(peerId) > 0;
  }

  /// Whether any DM has unread messages.
  bool hasAnyDmUnread() {
    return state.dmUnreadCounts.values.any((c) => c > 0);
  }
}

/// Immutable unread state.
class UnreadState {
  /// Last seen message ID per channel (key: "serverId:channelId").
  final Map<String, String> channelLastSeen;

  /// Last seen message ID per DM (key: peerId).
  final Map<String, String> dmLastSeen;

  /// Current unread counts per channel (key: "serverId:channelId").
  final Map<String, int> channelUnreadCounts;

  /// Current unread counts per DM (key: peerId).
  final Map<String, int> dmUnreadCounts;

  /// Latest message ID per channel (for marking seen).
  final Map<String, String> channelLatestId;

  /// Latest message ID per DM.
  final Map<String, String> dmLatestId;

  const UnreadState({
    this.channelLastSeen = const {},
    this.dmLastSeen = const {},
    this.channelUnreadCounts = const {},
    this.dmUnreadCounts = const {},
    this.channelLatestId = const {},
    this.dmLatestId = const {},
  });

  UnreadState copyWith({
    Map<String, String>? channelLastSeen,
    Map<String, String>? dmLastSeen,
    Map<String, int>? channelUnreadCounts,
    Map<String, int>? dmUnreadCounts,
    Map<String, String>? channelLatestId,
    Map<String, String>? dmLatestId,
  }) {
    return UnreadState(
      channelLastSeen: channelLastSeen ?? this.channelLastSeen,
      dmLastSeen: dmLastSeen ?? this.dmLastSeen,
      channelUnreadCounts: channelUnreadCounts ?? this.channelUnreadCounts,
      dmUnreadCounts: dmUnreadCounts ?? this.dmUnreadCounts,
      channelLatestId: channelLatestId ?? this.channelLatestId,
      dmLatestId: dmLatestId ?? this.dmLatestId,
    );
  }
}

final unreadProvider =
    NotifierProvider<UnreadNotifier, UnreadState>(UnreadNotifier.new);
