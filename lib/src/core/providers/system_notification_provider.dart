import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/core/providers/notification_provider.dart';
import 'package:haven/src/core/providers/profile_provider.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:window_manager/window_manager.dart';

/// A single message within a notification card.
class NotificationMessage {
  final String senderPeerId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  const NotificationMessage({
    required this.senderPeerId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });
}

/// A notification card — groups messages from the same source.
/// Source key: peerId for DMs, "serverId:channelId" for channels.
class NotificationCard {
  final String sourceKey;

  /// For DMs: peer's display name. For channels: "Server > #channel".
  final String title;

  /// For DMs: the peer ID (used for avatar). For channels: server ID.
  final String avatarId;

  /// Whether this is a DM or channel notification.
  final bool isDm;

  /// For channels: server and channel IDs for navigation.
  final String? serverId;
  final String? channelId;

  /// For DMs: peer ID for navigation.
  final String? peerId;

  /// Messages accumulated in this card (max 5).
  final List<NotificationMessage> messages;

  /// When this card was first created.
  final DateTime createdAt;

  NotificationCard({
    required this.sourceKey,
    required this.title,
    required this.avatarId,
    required this.isDm,
    this.serverId,
    this.channelId,
    this.peerId,
    List<NotificationMessage>? messages,
    DateTime? createdAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// Add a message, keeping max 5.
  NotificationCard withMessage(NotificationMessage msg) {
    final updated = List<NotificationMessage>.from(messages)..add(msg);
    if (updated.length > 5) {
      updated.removeRange(0, updated.length - 5);
    }
    return NotificationCard(
      sourceKey: sourceKey,
      title: title,
      avatarId: avatarId,
      isDm: isDm,
      serverId: serverId,
      channelId: channelId,
      peerId: peerId,
      messages: updated,
      createdAt: createdAt,
    );
  }
}

/// Manages in-app notification overlay state.
///
/// Up to 3 cards from different sources. Each card accumulates
/// up to 5 messages. Cards auto-dismiss after 5 seconds (handled by UI).
class SystemNotificationNotifier
    extends Notifier<List<NotificationCard>> {
  @override
  List<NotificationCard> build() => [];

  /// Show a notification for a new DM message.
  Future<void> notifyDm({
    required String fromPeerId,
    required String text,
    required String? replyToMid,
  }) async {
    // Check if DM is muted.
    final notifSettings = ref.read(notificationSettingsProvider.notifier);
    if (!notifSettings.isDmEnabled(fromPeerId)) return;

    // Check if window is focused — don't notify if user is looking at the app.
    if (await _isWindowFocused()) return;

    // Resolve sender name.
    final profiles = ref.read(profileProvider);
    final senderName = displayNameFor(profiles, fromPeerId);

    _addMessage(
      sourceKey: fromPeerId,
      title: senderName,
      avatarId: fromPeerId,
      isDm: true,
      peerId: fromPeerId,
      message: NotificationMessage(
        senderPeerId: fromPeerId,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Show a notification for a new channel message.
  Future<void> notifyChannel({
    required String serverId,
    required String channelId,
    required String fromPeerId,
    required String text,
    required String? replyToMid,
    String? channelName,
  }) async {
    final notifSettings = ref.read(notificationSettingsProvider.notifier);
    final level =
        notifSettings.effectiveChannelLevel(serverId, channelId);

    if (level == NotificationLevel.nothing) return;

    // "Mentions only" — only notify on replies.
    if (level == NotificationLevel.mentions) {
      if (replyToMid == null) return;
    }

    if (await _isWindowFocused()) return;

    // Resolve names.
    final profiles = ref.read(profileProvider);
    final senderName = displayNameFor(profiles, fromPeerId);
    final servers = ref.read(serverListProvider);
    final serverName = servers[serverId]?.name ?? 'Server';

    final resolvedChannelName =
        channelName ?? _channelName(serverId, channelId);

    _addMessage(
      sourceKey: '$serverId:$channelId',
      title: '$serverName > #$resolvedChannelName',
      avatarId: serverId,
      isDm: false,
      serverId: serverId,
      channelId: channelId,
      message: NotificationMessage(
        senderPeerId: fromPeerId,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Dismiss a specific card by source key.
  void dismissCard(String sourceKey) {
    state = state.where((c) => c.sourceKey != sourceKey).toList();
  }

  /// Dismiss all cards.
  void dismissAll() {
    state = [];
  }

  void _addMessage({
    required String sourceKey,
    required String title,
    required String avatarId,
    required bool isDm,
    String? serverId,
    String? channelId,
    String? peerId,
    required NotificationMessage message,
  }) {
    final cards = List<NotificationCard>.from(state);

    // Check if a card for this source already exists.
    final existingIndex =
        cards.indexWhere((c) => c.sourceKey == sourceKey);

    if (existingIndex >= 0) {
      // Add message to existing card.
      cards[existingIndex] = cards[existingIndex].withMessage(message);
    } else {
      // Create new card — max 3 cards.
      if (cards.length >= 3) {
        // Don't show a 4th card.
        return;
      }
      cards.add(NotificationCard(
        sourceKey: sourceKey,
        title: title,
        avatarId: avatarId,
        isDm: isDm,
        serverId: serverId,
        channelId: channelId,
        peerId: peerId,
        messages: [message],
      ));
    }

    state = cards;
  }

  String _channelName(String serverId, String channelId) {
    final channels = ref.read(channelListProvider);
    return channels[channelId]?.name ?? 'channel';
  }

  Future<bool> _isWindowFocused() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return true;
    }
    try {
      return await windowManager.isFocused();
    } catch (_) {
      return true; // Assume focused if we can't check.
    }
  }
}

final systemNotificationProvider = NotifierProvider<
    SystemNotificationNotifier,
    List<NotificationCard>>(SystemNotificationNotifier.new);
