import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/chat_provider.dart';
import 'package:haven/src/core/providers/node_provider.dart';
import 'package:haven/src/core/providers/peers_provider.dart';
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/core/providers/service_providers.dart';
import 'package:haven/src/rust/api/network.dart';

/// Wraps the 500ms FFI polling behind a stream and dispatches events
/// to the appropriate providers.
class EventPollerNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() => false; // running?

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _poll(),
    );
    state = true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = false;
  }

  Future<void> _poll() async {
    final networkService = ref.read(networkServiceProvider);
    while (true) {
      final event = await networkService.pollNetworkEvent();
      if (event == null) break;
      _dispatch(event);
    }
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

      case NetworkEvent_MessageReceived(:final fromPeer, :final text):
        ref.read(chatProvider.notifier).receiveMessage(fromPeer, text);

      case NetworkEvent_SessionEstablished(:final peerId):
        ref.read(peersProvider.notifier).markEncrypted(peerId);

      case NetworkEvent_MessageSent():
        break;

      case NetworkEvent_MessageSendFailed(:final toPeer, :final error):
        ref.read(chatProvider.notifier).addSendFailure(toPeer, error);

      case NetworkEvent_Error(:final message):
        debugPrint('[HAVEN] $message');
        ref.read(nodeProvider.notifier).state =
            ref.read(nodeProvider).copyWith(error: message);
    }
  }
}

final eventPollerProvider =
    NotifierProvider<EventPollerNotifier, bool>(EventPollerNotifier.new);
