/// File attachment metadata for messages.
class FileAttachment {
  final String fileId;
  final String fileName;
  final String fileExt;
  final String mimeType;
  final int sizeBytes;
  final bool isImage;
  final int? width;
  final int? height;
  final int totalChunks;
  final int chunksReceived;
  final bool isComplete;
  final String? diskPath;

  const FileAttachment({
    required this.fileId,
    required this.fileName,
    required this.fileExt,
    required this.mimeType,
    required this.sizeBytes,
    required this.isImage,
    this.width,
    this.height,
    required this.totalChunks,
    this.chunksReceived = 0,
    this.isComplete = false,
    this.diskPath,
  });

  double get progress =>
      totalChunks > 0 ? chunksReceived / totalChunks : 0;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  FileAttachment copyWith({
    int? chunksReceived,
    bool? isComplete,
    String? diskPath,
  }) {
    return FileAttachment(
      fileId: fileId,
      fileName: fileName,
      fileExt: fileExt,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      isImage: isImage,
      width: width,
      height: height,
      totalChunks: totalChunks,
      chunksReceived: chunksReceived ?? this.chunksReceived,
      isComplete: isComplete ?? this.isComplete,
      diskPath: diskPath ?? this.diskPath,
    );
  }
}
