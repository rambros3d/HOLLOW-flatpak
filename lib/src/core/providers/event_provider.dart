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
import 'package:haven/src/core/providers/sync_progress_provider.dart';
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
        if (ref.read(selectedPeerProvider) == peerId) {
          ref.read(selectedPeerProvider.notifier).state = null;
        }

      case NetworkEvent_PeerDisconnected(:final peerId):
        debugPrint('[HAVEN] Peer disconnected: $peerId');
        ref.read(peersProvider.notifier).removePeer(peerId);
        if (ref.read(selectedPeerProvider) == peerId) {
          ref.read(selectedPeerProvider.notifier).state = null;
        }

      case NetworkEvent_RoomCleared():
        debugPrint('[HAVEN] Room cleared');
        ref.read(peersProvider.notifier).clearAll();
        ref.read(selectedPeerProvider.notifier).state = null;

      case NetworkEvent_Listening(:final address):
        debugPrint('[HAVEN] Listening: $address');

      case NetworkEvent_MessageReceived(:final fromPeer, :final text, :final timestamp):
        ref.read(chatProvider.notifier).receiveMessage(fromPeer, text, timestamp);

      case NetworkEvent_ChannelMessageReceived(
            :final serverId, :final channelId, :final fromPeer, :final text, :final timestamp):
        ref
            .read(channelChatProvider.notifier)
            .receiveMessage(serverId, channelId, fromPeer, text, timestamp);

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
        if (newMessageCount > 0) {
          // Clear in-memory cache so loadHistory re-reads from DB.
          ref
              .read(channelChatProvider.notifier)
              .clearServerCache(serverId);
          // Reload the active channel if the user is viewing this server.
          final selectedServer = ref.read(selectedServerProvider);
          final selectedChannel = ref.read(selectedChannelProvider);
          if (selectedServer == serverId && selectedChannel != null) {
            ref
                .read(channelChatProvider.notifier)
                .loadHistory(serverId, selectedChannel);
          }
        }

      case NetworkEvent_MessageSyncFailed(:final serverId, :final error):
        debugPrint('[HAVEN] Message sync failed for $serverId: $error');
        ref.read(syncingPeersProvider.notifier).clearServer(serverId);
        ref.read(syncProgressProvider.notifier).clearServer(serverId);
        ref.read(syncStatusProvider.notifier).setStatus(
            serverId, ServerSyncStatus.failed);

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
    }
  }

  /// When a session is (re-)established with a peer, clear any "Sync failed"
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
