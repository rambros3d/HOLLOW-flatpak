import 'package:haven/src/rust/api/network.dart' as ffi;

/// Thin wrapper around the FFI network layer for testability.
class NetworkService {
  Future<String> startNode() => ffi.startNode();

  Future<ffi.NetworkEvent?> pollNetworkEvent() => ffi.pollNetworkEvent();

  Stream<ffi.NetworkEvent> watchNetworkEvents() => ffi.watchNetworkEvents();

  Future<String?> getLocalPeerId() => ffi.getLocalPeerId();

  Future<String?> getOlmFingerprint() => ffi.getOlmFingerprint();

  Future<void> sendMessage({
    required String peerId,
    required String text,
  }) => ffi.sendMessage(peerId: peerId, text: text);

  Future<void> joinRoom({required String roomCode}) =>
      ffi.joinRoom(roomCode: roomCode);

  Future<void> stopNode() => ffi.stopNode();
}
