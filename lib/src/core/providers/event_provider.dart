import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/channel_chat_provider.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/core/providers/chat_provider.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:haven/src/core/providers/service_providers.dart';
import 'package:haven/src/core/providers/profile_provider.dart';
import 'package:haven/src/core/providers/sync_progress_provider.dart';
import 'package:haven/src/core/providers/typing_provider.dart';
import 'package:haven/src/core/providers/pinned_provider.dart';
import 'package:haven/src/core/providers/friends_provider.dart';
import 'package:haven/src/core/providers/unread_provider.dart';
import 'package:haven/src/core/providers/notification_provider.dart';
import 'package:haven/src/core/providers/system_notification_provider.dart';
import 'package:haven/src/rust/api/crdt.dart' as crdt_api;
import 'package:haven/src/rust/api/network.dart';

/// Listens to the Rust event stream and dispatches events
/// to the appropriate providers.
class EventStreamNotifier extends Notifier<bool> {
  StreamSubscription<NetworkEvent>? _subscription;

  @override
  bool build() => false; // streaming?

  void start() {
    if (_subscription != null) return;
    final networkService = ref.read(networkServiceProvider);
    _subscription = networkService.watchNetworkEvents().listen(
      _dispatch,
      onError: (error) {
        debugPrint('[HAVEN] Event stream error: $error');
      },
      onDone: () {
        debugPrint('[HAVEN] Event stream closed');
        _subscription = null;
        state = false;
      },
    );
    state = true;
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    state = false;
  }

  void _dispatch(NetworkEvent event) {
    switch (event) {
      case NetworkEvent_PeerDiscovered(:final peer):
        debugPrint(
            '[HAVEN] Peer discovered: ${peer.peerId} at ${peer.addresses}');
        ref.read(peersProvider.notifier).addPeer(peer.peerId, peer.addresses);

      case NetworkEvent_PeerExpired(:final peerId):
        ref.read(peersProvider.notifier).removePeer(peerId);
        // Don't deselect — friends stay visible when offline.

      case NetworkEvent_PeerDisconnected(:final peerId):
        debugPrint('[HAVEN] Peer disconnected: $peerId');
        ref.read(peersProvider.notifier).removePeer(peerId);
        // Don't deselect — friends stay visible when offline.

      case NetworkEvent_RoomCleared():
        debugPrint('[HAVEN] Room cleared');
        ref.read(peersProvider.notifier).clearAll();
        ref.read(selectedPeerProvider.notifier).state = null;

      case NetworkEvent_Listening(:final address):
        debugPrint('[HAVEN] Listening: $address');

      case NetworkEvent_MessageReceived(:final fromPeer, :final text, :final timestamp, :final messageId, :final replyToMid):
        ref.read(chatProvider.notifier).receiveMessage(fromPeer, text, timestamp, messageId, replyToMid);
        ref.read(typingProvider.notifier).clearTyping(fromPeer, fromPeer);
        // Track unread DM — only if not muted.
        final isViewingDm = ref.read(selectedPeerProvider) == fromPeer &&
            ref.read(selectedServerProvider) == null;
        final isDmMuted = !ref
            .read(notificationSettingsProvider.notifier)
            .isDmEnabled(fromPeer);
        if (!isDmMuted) {
          ref.read(unreadProvider.notifier).onDmMessage(
              fromPeer, messageId, isViewingDm);
        }
        // System notification for DM.
        if (!isViewingDm && !isDmMuted) {
          ref.read(systemNotificationProvider.notifier).notifyDm(
                fromPeerId: fromPeer,
                text: text,
                replyToMid: replyToMid,
              );
        }

      case NetworkEvent_ChannelMessageReceived(
            :final serverId, :final channelId, :final fromPeer, :final text, :final timestamp, :final messageId, :final replyToMid):
        ref
            .read(channelChatProvider.notifier)
            .receiveMessage(serverId, channelId, fromPeer, text, timestamp, messageId, replyToMid);
        ref.read(typingProvider.notifier).clearTyping('$serverId:$channelId', fromPeer);
        // Track unread channel message — only if not muted.
        final isViewingChannel =
            ref.read(selectedServerProvider) == serverId &&
                ref.read(selectedChannelProvider) == channelId;
        final channelNotifLevel = ref
            .read(notificationSettingsProvider.notifier)
            .effectiveChannelLevel(serverId, channelId);
        final isChannelMuted =
            channelNotifLevel == NotificationLevel.nothing;
        if (!isChannelMuted) {
          ref.read(unreadProvider.notifier).onChannelMessage(
              serverId, channelId, messageId, isViewingChannel);
        }
        // System notification for channel message.
        if (!isViewingChannel && !isChannelMuted) {
          // Resolve channel name and notify (async, fire-and-forget).
          _notifyChannelWithName(
              serverId, channelId, fromPeer, text, replyToMid);
        }

      case NetworkEvent_SessionEstablished(:final peerId):
        ref.read(peersProvider.notifier).markEncrypted(peerId);
        // After re-key, clear any "Sync failed" status for servers where this
        // peer is a member, so the UI recovers automatically.
        _clearFailedSyncForPeer(peerId);

      case NetworkEvent_MessageSent():
        break;

      case NetworkEvent_MessageSendFailed(:final toPeer, :final error):
        ref.read(chatProvider.notifier).addSendFailure(toPeer, error);

      case NetworkEvent_Error(:final message):
        debugPrint('[HAVEN] $message');
        ref.read(nodeProvider.notifier).state =
            ref.read(nodeProvider).copyWith(error: message);

      // -- CRDT events (Phase 3) --
      case NetworkEvent_ServerCreated(:final serverId, :final name):
        debugPrint('[HAVEN] Server created: $name ($serverId)');
        ref.read(serverListProvider.notifier).onServerCreated(serverId, name);

      case NetworkEvent_ServerUpdated(:final serverId):
        debugPrint('[HAVEN] Server updated: $serverId');
        ref.read(serverListProvider.notifier).onServerUpdated(serverId);
        // Reload channels and layout in case they changed.
        if (ref.read(selectedServerProvider) == serverId) {
          ref.read(channelListProvider.notifier).loadForServer(serverId);
          ref.read(channelLayoutProvider.notifier).loadForServer(serverId);
        }

      case NetworkEvent_ChannelAdded(
            :final serverId, :final channelId, :final name):
        debugPrint('[HAVEN] Channel added: $name ($channelId) in $serverId');
        ref
            .read(channelListProvider.notifier)
            .onChannelAdded(serverId, channelId, name);

      case NetworkEvent_ChannelRemoved(:final serverId, :final channelId):
        debugPrint('[HAVEN] Channel removed: $channelId in $serverId');
        ref
            .read(channelListProvider.notifier)
            .onChannelRemoved(serverId, channelId);

      case NetworkEvent_ChannelRenamed(
            :final serverId, :final channelId, :final newName):
        debugPrint(
            '[HAVEN] Channel renamed: $channelId to $newName in $serverId');
        ref
            .read(channelListProvider.notifier)
            .onChannelRenamed(serverId, channelId, newName);

      case NetworkEvent_ServerDeleted(:final serverId):
        debugPrint('[HAVEN] Server deleted: $serverId');
        ref.read(serverListProvider.notifier).onServerDeleted(serverId);
        // Deselect if this was the active server.
        if (ref.read(selectedServerProvider) == serverId) {
          ref.read(selectedServerProvider.notifier).state = null;
          ref.read(selectedChannelProvider.notifier).state = null;
          ref.read(serverSettingsOpenProvider.notifier).state = false;
        }

      case NetworkEvent_MemberJoined(:final serverId, :final peerId):
        debugPrint('[HAVEN] Member joined: $peerId in $serverId');
        ref.read(serverListProvider.notifier).onServerUpdated(serverId);
        ref.invalidate(serverMembersProvider(serverId));

      case NetworkEvent_MemberLeft(:final serverId, :final peerId):
        debugPrint('[HAVEN] Member left: $peerId in $serverId');
        ref.read(serverListProvider.notifier).onServerUpdated(serverId);
        ref.invalidate(serverMembersProvider(serverId));

      case NetworkEvent_SyncCompleted(:final serverId, :final opsApplied):
        debugPrint('[HAVEN] Sync completed: $serverId ($opsApplied ops)');
        ref.read(serverListProvider.notifier).onServerUpdated(serverId);
        ref.invalidate(serverMembersProvider(serverId));

      case NetworkEvent_ServerJoined(:final serverId, :final name):
        debugPrint('[HAVEN] Server joined: $name ($serverId)');
        ref.read(serverListProvider.notifier).onServerCreated(serverId, name);
        // Auto-select the newly joined server and load its channels
        ref.read(selectedServerProvider.notifier).state = serverId;
        ref
            .read(channelListProvider.notifier)
            .loadForServer(serverId);
        ref.read(selectedChannelProvider.notifier).state = null;
        ref.read(serverSettingsOpenProvider.notifier).state = false;

      case NetworkEvent_MessageSyncStarted(:final serverId, :final peerId):
        debugPrint('[HAVEN] Message sync started for $serverId with $peerId');
        ref.read(syncingPeersProvider.notifier).addPeer(serverId, peerId);
        final current = ref.read(serverSyncStatusProvider(serverId));
        ref.read(syncStatusProvider.notifier).setStatus(
          serverId,
          current == ServerSyncStatus.failed
              ? ServerSyncStatus.retrying
              : ServerSyncStatus.syncing,
        );

      case NetworkEvent_MessageSyncCompleted(
            :final serverId, :final newMessageCount):
        debugPrint(
            '[HAVEN] Message sync: $newMessageCount new messages for $serverId');
        ref.read(syncingPeersProvider.notifier).clearServer(serverId);
        ref.read(syncProgressProvider.notifier).clearServer(serverId);
        ref.read(syncStatusProvider.notifier).setStatus(
            serverId, ServerSyncStatus.synced);
        final selectedServer = ref.read(selectedServerProvider);
        final selectedChannel = ref.read(selectedChannelProvider);
        if (newMessageCount > 0) {
          // New messages arrived — clear cache and reload (includes reactions).
          ref
              .read(channelChatProvider.notifier)
              .clearServerCache(serverId);
          if (selectedServer == serverId && selectedChannel != null) {
            ref
                .read(channelChatProvider.notifier)
                .loadHistory(serverId, selectedChannel);
          }
        } else if (selectedServer == serverId && selectedChannel != null) {
          // No new messages but reactions may have synced — just refresh
          // reactions on existing in-memory messages (no sync trigger).
          ref
              .read(channelChatProvider.notifier)
              .reloadReactions(serverId, selectedChannel);
        }
        // Always refresh pins (lightweight, no sync loop risk).
        if (selectedServer == serverId && selectedChannel != null) {
          ref
              .read(pinnedProvider.notifier)
              .loadPins(serverId, selectedChannel);
        }

      case NetworkEvent_MessageSyncFailed(:final serverId, :final error):
        debugPrint('[HAVEN] Message sync failed for $serverId: $error');
        ref.read(syncingPeersProvider.notifier).clearServer(serverId);
        ref.read(syncProgressProvider.notifier).clearServer(serverId);
        // Transient decrypt failures during re-key → show "Retrying"
        // instead of stuck "Failed" state.
        final isReKeying = error.contains('re-keying') ||
            error.contains('re-key');
        ref.read(syncStatusProvider.notifier).setStatus(
            serverId,
            isReKeying
                ? ServerSyncStatus.retrying
                : ServerSyncStatus.failed);

      case NetworkEvent_MessageSyncProgress(
            :final serverId, :final channelId, :final receivedCount, :final totalCount):
        debugPrint(
            '[HAVEN] Sync progress: $receivedCount/$totalCount for $channelId in $serverId');
        ref.read(syncProgressProvider.notifier).updateProgress(
            serverId, receivedCount, totalCount);

      case NetworkEvent_RoleChanged(:final serverId, :final peerId, :final newRole):
        debugPrint('[HAVEN] Role changed: $peerId is now $newRole in $serverId');
        ref.read(serverListProvider.notifier).onServerUpdated(serverId);
        ref.invalidate(serverMembersProvider(serverId));
        ref.invalidate(myRoleProvider(serverId));
        ref.invalidate(myPermissionsProvider(serverId));

      case NetworkEvent_DmSyncCompleted(:final peerId, :final newMessageCount):
        debugPrint('[HAVEN] DM sync: $newMessageCount new messages from $peerId');
        // Always reload DM history from DB after sync completes — even if
        // newMessageCount == 0. Dart may have cleared its in-memory cache on
        // disconnect, and the messages are all in DB already (duplicates).
        final chatNotifier = ref.read(chatProvider.notifier);
        chatNotifier.clearPeerCache(peerId);
        final selectedPeer = ref.read(selectedPeerProvider);
        if (selectedPeer == peerId) {
          chatNotifier.loadHistory(peerId);
        }

      case NetworkEvent_ProfileUpdated(:final peerId):
        debugPrint('[HAVEN] Profile updated: $peerId');
        ref.read(profileProvider.notifier).reloadProfile(peerId);

      case NetworkEvent_ChannelMessageEdited(
            :final serverId, :final channelId, :final messageId, :final newText, :final editedAt):
        debugPrint('[HAVEN] Channel message edited: $messageId in $serverId/$channelId');
        ref.read(channelChatProvider.notifier).applyEdit(
            serverId, channelId, messageId, newText, editedAt);

      case NetworkEvent_DmMessageEdited(
            :final peerId, :final messageId, :final newText, :final editedAt):
        debugPrint('[HAVEN] DM message edited: $messageId from $peerId');
        ref.read(chatProvider.notifier).applyEdit(
            peerId, messageId, newText, editedAt);

      case NetworkEvent_ChannelMessageDeleted(
            :final serverId, :final channelId, :final messageId, :final deletedAt):
        debugPrint('[HAVEN] Channel message deleted: $messageId in $serverId/$channelId');
        ref.read(channelChatProvider.notifier).applyDelete(
            serverId, channelId, messageId, deletedAt);

      case NetworkEvent_DmMessageDeleted(
            :final peerId, :final messageId, :final deletedAt):
        debugPrint('[HAVEN] DM message deleted: $messageId from $peerId');
        ref.read(chatProvider.notifier).applyDelete(
            peerId, messageId, deletedAt);

      // -- Emoji reaction events (Phase 3.5) --
      case NetworkEvent_ChannelReactionAdded(
            :final serverId, :final channelId, :final messageId, :final emoji, :final reactor):
        debugPrint('[HAVEN] Reaction $emoji on $messageId by $reactor in $serverId/$channelId');
        ref.read(channelChatProvider.notifier).applyAddReaction(
            serverId, channelId, messageId, emoji, reactor);

      case NetworkEvent_DmReactionAdded(
            :final peerId, :final messageId, :final emoji, :final reactor):
        debugPrint('[HAVEN] DM reaction $emoji on $messageId by $reactor for $peerId');
        ref.read(chatProvider.notifier).applyAddReaction(
            peerId, messageId, emoji, reactor);

      case NetworkEvent_ChannelReactionRemoved(
            :final serverId, :final channelId, :final messageId, :final emoji, :final reactor):
        debugPrint('[HAVEN] Reaction $emoji removed on $messageId by $reactor in $serverId/$channelId');
        ref.read(channelChatProvider.notifier).applyRemoveReaction(
            serverId, channelId, messageId, emoji, reactor);

      case NetworkEvent_DmReactionRemoved(
            :final peerId, :final messageId, :final emoji, :final reactor):
        debugPrint('[HAVEN] DM reaction $emoji removed on $messageId by $reactor for $peerId');
        ref.read(chatProvider.notifier).applyRemoveReaction(
            peerId, messageId, emoji, reactor);

      // -- Friend events (Phase 3.5) --
      case NetworkEvent_FriendRequestReceived(:final peerId):
        debugPrint('[HAVEN] Friend request received from $peerId');
        ref.read(friendsProvider.notifier).loadAll();

      case NetworkEvent_FriendRequestAccepted(:final peerId):
        debugPrint('[HAVEN] Friend accepted by $peerId');
        ref.read(friendsProvider.notifier).loadAll();

      case NetworkEvent_FriendRequestRejected(:final peerId):
        debugPrint('[HAVEN] Friend rejected by $peerId');
        ref.read(friendsProvider.notifier).loadAll();

      case NetworkEvent_FriendRemoved(:final peerId):
        debugPrint('[HAVEN] Friend removed: $peerId');
        ref.read(friendsProvider.notifier).loadAll();

      // -- Typing indicator events (Phase 3.5) --
      case NetworkEvent_TypingStarted(
            :final peerId, :final serverId, :final channelId):
        final key = serverId.isEmpty ? peerId : '$serverId:$channelId';
        ref.read(typingProvider.notifier).setTyping(key, peerId);

      // -- Pinned message events (Phase 3.5) --
      case NetworkEvent_MessagePinned(
            :final serverId, :final channelId, :final messageId):
        debugPrint('[HAVEN] Message pinned: $messageId in $serverId/$channelId');
        ref.read(pinnedProvider.notifier).applyPin(serverId, channelId, messageId);

      case NetworkEvent_MessageUnpinned(
            :final serverId, :final channelId, :final messageId):
        debugPrint('[HAVEN] Message unpinned: $messageId in $serverId/$channelId');
        ref.read(pinnedProvider.notifier).applyUnpin(serverId, channelId, messageId);
    }
  }

  /// When a session is (re-)established with a peer, clear any "Sync failed"
  /// Resolve channel name and show notification (async helper).
  Future<void> _notifyChannelWithName(String serverId, String channelId,
      String fromPeer, String text, String? replyToMid) async {
    String? chName = ref.read(channelListProvider)[channelId]?.name;
    if (chName == null) {
      try {
        final channels =
            await crdt_api.getServerChannels(serverId: serverId);
        chName = channels
            .where((c) => c.channelId == channelId)
            .firstOrNull
            ?.name;
      } catch (_) {}
    }
    ref.read(systemNotificationProvider.notifier).notifyChannel(
          serverId: serverId,
          channelId: channelId,
          fromPeerId: fromPeer,
          text: text,
          replyToMid: replyToMid,
          channelName: chName,
        );
  }

  /// status for servers where that peer is a member, and re-trigger sync for
  /// the active channel so the UI recovers automatically after re-key.
  void _clearFailedSyncForPeer(String peerId) {
    final syncStatuses = ref.read(syncStatusProvider);
    final servers = ref.read(serverListProvider);

    for (final serverId in servers.keys) {
      final status = syncStatuses[serverId];
      if (status != ServerSyncStatus.failed) continue;

      // Check if this peer is a member of this server.
      final membersAsync = ref.read(serverMembersProvider(serverId));
      final isMember = membersAsync.whenOrNull(
        data: (members) => members.any((m) => m.peerId == peerId),
      ) ?? false;

      if (isMember) {
        // Clear the failed status — effective status will derive from peer count.
        ref.read(syncStatusProvider.notifier).setStatus(
            serverId, ServerSyncStatus.idle);

        // Re-trigger sync for the currently viewed channel.
        final selectedServer = ref.read(selectedServerProvider);
        final selectedChannel = ref.read(selectedChannelProvider);
        if (selectedServer == serverId && selectedChannel != null) {
          try {
            requestChannelSync(
              serverId: serverId,
              channelId: selectedChannel,
            );
          } catch (_) {}
        }
      }
    }
  }
}

final eventStreamProvider =
    NotifierProvider<EventStreamNotifier, bool>(EventStreamNotifier.new);
