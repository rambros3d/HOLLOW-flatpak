import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/rust/api/network.dart' as network_api;
import 'package:hollow/src/rust/api/storage.dart' as storage_api;

/// A friend entry from the local DB.
class FriendInfo {
  final String peerId;
  final String status; // 'pending', 'accepted'
  final String direction; // 'outgoing', 'incoming', '' (accepted)
  final int requestedAt;
  final int updatedAt;

  const FriendInfo({
    required this.peerId,
    required this.status,
    required this.direction,
    required this.requestedAt,
    required this.updatedAt,
  });
}

/// Manages the friends list. Loaded from local DB.
class FriendsNotifier extends Notifier<Map<String, FriendInfo>> {
  @override
  Map<String, FriendInfo> build() => {};

  /// Load all friends from DB.
  Future<void> loadAll() async {
    try {
      final rows = await storage_api.loadFriends();
      final map = <String, FriendInfo>{};
      for (final f in rows) {
        map[f.peerId] = FriendInfo(
          peerId: f.peerId,
          status: f.status,
          direction: f.direction,
          requestedAt: f.requestedAt,
          updatedAt: f.updatedAt,
        );
      }
      state = map;
    } catch (e) {
      debugPrint('[HOLLOW] Failed to load friends: $e');
    }
  }

  /// Send a friend request.
  Future<void> sendRequest(String peerId) async {
    try {
      await network_api.sendFriendRequest(peerId: peerId);
      await loadAll();
    } catch (e) {
      debugPrint('[HOLLOW] Failed to send friend request: $e');
    }
  }

  /// Accept an incoming friend request.
  Future<void> acceptRequest(String peerId) async {
    try {
      await network_api.acceptFriendRequest(peerId: peerId);
      await loadAll();
    } catch (e) {
      debugPrint('[HOLLOW] Failed to accept friend request: $e');
    }
  }

  /// Reject an incoming friend request.
  Future<void> rejectRequest(String peerId) async {
    try {
      await network_api.rejectFriendRequest(peerId: peerId);
      await loadAll();
    } catch (e) {
      debugPrint('[HOLLOW] Failed to reject friend request: $e');
    }
  }

  /// Remove a friend.
  Future<void> removeFriend(String peerId) async {
    try {
      await network_api.removeFriend(peerId: peerId);
      await loadAll();
    } catch (e) {
      debugPrint('[HOLLOW] Failed to remove friend: $e');
    }
  }
}

final friendsProvider =
    NotifierProvider<FriendsNotifier, Map<String, FriendInfo>>(
        FriendsNotifier.new);
