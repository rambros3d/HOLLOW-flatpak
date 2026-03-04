/// A single channel chat message.
class ChannelChatMessage {
  final String senderId;
  final String text;
  final bool isMe;
  final DateTime timestamp;

  ChannelChatMessage({
    required this.senderId,
    required this.text,
    required this.isMe,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
