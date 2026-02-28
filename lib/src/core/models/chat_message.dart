/// A single chat message.
class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isMe, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}
