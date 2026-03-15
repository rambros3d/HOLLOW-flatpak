import 'package:haven/src/core/models/file_attachment.dart';

/// A single chat message.
class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? signature;
  final String? publicKey;
  final String? messageId;
  final DateTime? editedAt;
  final DateTime? hiddenAt;
  final String? replyToMid;
  /// Emoji reactions: emoji → list of peer IDs who reacted.
  final Map<String, List<String>> reactions;
  /// File attachment (null if text-only message).
  final FileAttachment? fileAttachment;

  ChatMessage({
    required this.text,
    required this.isMe,
    DateTime? timestamp,
    this.signature,
    this.publicKey,
    this.messageId,
    this.editedAt,
    this.hiddenAt,
    this.replyToMid,
    Map<String, List<String>>? reactions,
    this.fileAttachment,
  })  : timestamp = timestamp ?? DateTime.now(),
        reactions = reactions ?? const {};

  /// Create a copy with updated fields (for editing/deletion/reactions).
  ChatMessage copyWith({
    String? text,
    DateTime? editedAt,
    DateTime? hiddenAt,
    Map<String, List<String>>? reactions,
    FileAttachment? fileAttachment,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isMe: isMe,
      timestamp: timestamp,
      signature: signature,
      publicKey: publicKey,
      messageId: messageId,
      editedAt: editedAt ?? this.editedAt,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      replyToMid: replyToMid,
      reactions: reactions ?? this.reactions,
      fileAttachment: fileAttachment ?? this.fileAttachment,
    );
  }
}
