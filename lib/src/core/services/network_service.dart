import 'package:hollow/src/rust/api/network.dart' as ffi;

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
    required String messageId,
    String? replyToMid,
  }) => ffi.sendMessage(
    peerId: peerId,
    text: text,
    messageId: messageId,
    replyToMid: replyToMid,
  );

  Future<void> sendChannelMessage({
    required String serverId,
    required String channelId,
    required String text,
    required String messageId,
    String? replyToMid,
  }) => ffi.sendChannelMessage(
    serverId: serverId,
    channelId: channelId,
    text: text,
    messageId: messageId,
    replyToMid: replyToMid,
  );

  Future<void> joinRoom({required String roomCode}) =>
      ffi.joinRoom(roomCode: roomCode);

  Future<void> stopNode() => ffi.stopNode();
}
