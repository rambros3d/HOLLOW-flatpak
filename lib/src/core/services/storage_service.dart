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
}
