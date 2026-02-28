import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/core/providers/service_providers.dart';

class RoomNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Join a room from a room code or haven:// invite link.
  Future<void> join(String input) async {
    final roomCode = _extractRoomCode(input);
    if (roomCode.isEmpty) return;

    final nodeState = ref.read(nodeProvider);
    if (nodeState.status != NodeStatus.connected) return;

    try {
      // Clear peers when switching rooms.
      if (state != null && state != roomCode) {
        ref.read(peersProvider.notifier).clearAll();
        ref.read(selectedPeerProvider.notifier).state = null;
      }

      await ref.read(networkServiceProvider).joinRoom(roomCode: roomCode);
      state = roomCode;
    } catch (e) {
      debugPrint('[HAVEN] Join room error: $e');
      ref.read(nodeProvider.notifier).state =
          ref.read(nodeProvider).copyWith(error: e.toString());
    }
  }

  /// Create a new room and return the invite link.
  Future<String?> createInvite() async {
    final nodeState = ref.read(nodeProvider);
    if (nodeState.status != NodeStatus.connected) return null;

    final roomCode = _generateRoomCode();
    await join(roomCode);
    return 'haven://join?room=$roomCode';
  }

  static String _generateRoomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String _extractRoomCode(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'haven' && uri.host == 'join') {
      final room = uri.queryParameters['room'];
      if (room != null && room.isNotEmpty) return room;
    }
    return trimmed;
  }
}

final roomProvider =
    NotifierProvider<RoomNotifier, String?>(RoomNotifier.new);
