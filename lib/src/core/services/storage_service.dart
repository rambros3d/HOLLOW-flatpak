import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:haven/src/rust/api/storage.dart' as ffi;

/// Thin wrapper around the FFI storage layer for testability.
class StorageService {
  Future<void> openMessageStore() => ffi.openMessageStore();

  Future<PlatformInt64> saveMessage({
    required String peerId,
    required String text,
    required bool isMine,
    required PlatformInt64 timestamp,
  }) => ffi.saveMessage(
    peerId: peerId,
    text: text,
    isMine: isMine,
    timestamp: timestamp,
  );

  Future<List<ffi.StoredMessage>> loadMessages({
    required String peerId,
    required int limit,
  }) => ffi.loadMessages(peerId: peerId, limit: limit);

  Future<PlatformInt64> saveChannelMessage({
    required String serverId,
    required String channelId,
    required String senderId,
    required String text,
    required bool isMine,
    required PlatformInt64 timestamp,
  }) => ffi.saveChannelMessage(
    serverId: serverId,
    channelId: channelId,
    senderId: senderId,
    text: text,
    isMine: isMine,
    timestamp: timestamp,
  );

  Future<List<ffi.StoredChannelMessage>> loadChannelMessages({
    required String serverId,
    required String channelId,
    required int limit,
  }) => ffi.loadChannelMessages(
    serverId: serverId,
    channelId: channelId,
    limit: limit,
  );
}
