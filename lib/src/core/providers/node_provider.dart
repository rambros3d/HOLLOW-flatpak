import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/node_status.dart';
import 'package:haven/src/core/providers/event_provider.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/service_providers.dart';

/// Node state: status + last error.
class NodeState {
  final NodeStatus status;
  final String? error;

  const NodeState({this.status = NodeStatus.loading, this.error});

  NodeState copyWith({NodeStatus? status, String? error}) {
    return NodeState(
      status: status ?? this.status,
      error: error,
    );
  }
}

class NodeNotifier extends Notifier<NodeState> {
  @override
  NodeState build() => const NodeState();

  /// Start the libp2p node and begin event polling.
  Future<void> start() async {
    state = state.copyWith(status: NodeStatus.starting, error: null);
    try {
      final networkService = ref.read(networkServiceProvider);
      final peerId = await networkService.startNode();

      // Update identity with the peer ID from the node.
      final identity = ref.read(identityProvider.notifier);
      identity.state = identity.state.copyWith(peerId: peerId);

      state = state.copyWith(status: NodeStatus.connected);

      // Start polling for network events.
      ref.read(eventPollerProvider.notifier).start();
    } catch (e) {
      debugPrint('[HAVEN] Node start error: $e');
      state = state.copyWith(status: NodeStatus.error, error: e.toString());
    }
  }

  /// Stop the node and event polling.
  Future<void> stop() async {
    ref.read(eventPollerProvider.notifier).stop();
    try {
      await ref.read(networkServiceProvider).stopNode();
    } catch (e) {
      debugPrint('[HAVEN] Node stop error: $e');
    }
    state = state.copyWith(status: NodeStatus.loading);
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final nodeProvider =
    NotifierProvider<NodeNotifier, NodeState>(NodeNotifier.new);
