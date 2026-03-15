import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/rust/api/network.dart' as network_api;

/// State for a single file transfer (sending or receiving).
class FileTransferState {
  final String fileId;
  final String fileName;
  final int sizeBytes;
  final int totalChunks;
  final int chunksReceived;
  final bool isComplete;
  final bool isSending;
  final String? error;
  final String? diskPath;
  final bool isImage;
  final int? width;
  final int? height;

  const FileTransferState({
    required this.fileId,
    required this.fileName,
    required this.sizeBytes,
    required this.totalChunks,
    this.chunksReceived = 0,
    this.isComplete = false,
    this.isSending = false,
    this.error,
    this.diskPath,
    this.isImage = false,
    this.width,
    this.height,
  });

  double get progress =>
      totalChunks > 0 ? chunksReceived / totalChunks : 0;

  FileTransferState copyWith({
    int? chunksReceived,
    bool? isComplete,
    String? error,
    String? diskPath,
  }) {
    return FileTransferState(
      fileId: fileId,
      fileName: fileName,
      sizeBytes: sizeBytes,
      totalChunks: totalChunks,
      chunksReceived: chunksReceived ?? this.chunksReceived,
      isComplete: isComplete ?? this.isComplete,
      isSending: isSending,
      error: error ?? this.error,
      diskPath: diskPath ?? this.diskPath,
      isImage: isImage,
      width: width,
      height: height,
    );
  }
}

/// Tracks active file transfers.
class FileTransferNotifier
    extends Notifier<Map<String, FileTransferState>> {
  @override
  Map<String, FileTransferState> build() => {};

  /// Initiate a file send.
  Future<void> sendFile({
    String? peerId,
    String? serverId,
    String? channelId,
    required String filePath,
    required String messageId,
    String messageText = '',
  }) async {
    // Extract filename for display.
    final parts = filePath.replaceAll('\\', '/').split('/');
    final fileName = parts.isNotEmpty ? parts.last : 'file';

    // Add optimistic transfer state.
    final updated = Map<String, FileTransferState>.from(state);
    updated[messageId] = FileTransferState(
      fileId: messageId,
      fileName: fileName,
      sizeBytes: 0,
      totalChunks: 0,
      isSending: true,
    );
    state = updated;

    // Call Rust FFI.
    try {
      await network_api.sendFile(
        peerId: peerId,
        serverId: serverId,
        channelId: channelId,
        filePath: filePath,
        messageId: messageId,
        messageText: messageText,
      );
    } catch (e) {
      final err = Map<String, FileTransferState>.from(state);
      err[messageId] = FileTransferState(
        fileId: messageId,
        fileName: fileName,
        sizeBytes: 0,
        totalChunks: 0,
        isSending: true,
        error: e.toString(),
      );
      state = err;
    }
  }

  /// Handle FileHeaderReceived event.
  void onFileHeaderReceived({
    required String fileId,
    required String fileName,
    required int sizeBytes,
    required bool isImage,
    int? width,
    int? height,
  }) {
    final updated = Map<String, FileTransferState>.from(state);
    updated[fileId] = FileTransferState(
      fileId: fileId,
      fileName: fileName,
      sizeBytes: sizeBytes,
      totalChunks: 0, // Will be updated by progress events.
      isImage: isImage,
      width: width,
      height: height,
    );
    state = updated;
  }

  /// Handle FileProgress event.
  void onFileProgress(String fileId, int chunksReceived, int totalChunks) {
    final current = state[fileId];
    if (current == null) return;
    final updated = Map<String, FileTransferState>.from(state);
    updated[fileId] = current.copyWith(chunksReceived: chunksReceived);
    // Update totalChunks if we have it now.
    if (current.totalChunks == 0 && totalChunks > 0) {
      updated[fileId] = FileTransferState(
        fileId: current.fileId,
        fileName: current.fileName,
        sizeBytes: current.sizeBytes,
        totalChunks: totalChunks,
        chunksReceived: chunksReceived,
        isSending: current.isSending,
        isImage: current.isImage,
        width: current.width,
        height: current.height,
      );
    }
    state = updated;
  }

  /// Handle FileCompleted event.
  void onFileCompleted(String fileId, String diskPath) {
    final current = state[fileId];
    if (current == null) return;
    final updated = Map<String, FileTransferState>.from(state);
    updated[fileId] = current.copyWith(
      isComplete: true,
      diskPath: diskPath,
      chunksReceived: current.totalChunks,
    );
    state = updated;
  }

  /// Handle FileFailed event.
  void onFileFailed(String fileId, String error) {
    final current = state[fileId];
    final updated = Map<String, FileTransferState>.from(state);
    updated[fileId] = FileTransferState(
      fileId: fileId,
      fileName: current?.fileName ?? 'file',
      sizeBytes: current?.sizeBytes ?? 0,
      totalChunks: current?.totalChunks ?? 0,
      chunksReceived: current?.chunksReceived ?? 0,
      isSending: current?.isSending ?? false,
      error: error,
    );
    state = updated;
  }
}

final fileTransferProvider = NotifierProvider<FileTransferNotifier,
    Map<String, FileTransferState>>(FileTransferNotifier.new);
