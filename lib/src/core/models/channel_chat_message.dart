/// A single channel chat message.
class ChannelChatMessage {
  final String senderId;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? signature;
  final String? publicKey;
  final String? messageId;
  final DateTime? editedAt;

  ChannelChatMessage({
    required this.senderId,
    required this.text,
    required this.isMe,
    DateTime? timestamp,
    this.signature,
    this.publicKey,
    this.messageId,
    this.editedAt,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with updated fields (for editing).
  ChannelChatMessage copyWith({String? text, DateTime? editedAt}) {
    return ChannelChatMessage(
      senderId: senderId,
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
