/// A single chat message.
class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? signature;
  final String? publicKey;
  final String? messageId;
  final DateTime? editedAt;

  ChatMessage({
    required this.text,
    required this.isMe,
    DateTime? timestamp,
    this.signature,
    this.publicKey,
    this.messageId,
    this.editedAt,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with updated fields (for editing).
  ChatMessage copyWith({String? text, DateTime? editedAt}) {
    return ChatMessage(
      text: text ?? this.text,
      isMe: isMe,
      timestamp: timestamp,
      signature: signature,
      publicKey: publicKey,
      messageId: messageId,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}
