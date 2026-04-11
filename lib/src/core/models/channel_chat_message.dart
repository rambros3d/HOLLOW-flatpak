import 'package:hollow/src/core/models/file_attachment.dart';
import 'package:hollow/src/rust/api/network.dart' as network_api;

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
  final DateTime? hiddenAt;
  final String? replyToMid;
  /// Emoji reactions: emoji → list of peer IDs who reacted.
  final Map<String, List<String>> reactions;
  /// File attachment (null if text-only message).
  final FileAttachment? fileAttachment;
  /// OG link preview for the first URL in the message (Phase 6.75).
  /// Null when the message has no URL, when the OG fetch failed, or when
  /// the message was sent before link previews existed.
  final network_api.LinkPreviewRef? linkPreview;

  ChannelChatMessage({
    required this.senderId,
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
    this.linkPreview,
  })  : timestamp = timestamp ?? DateTime.now(),
        reactions = reactions ?? const {};

  /// Create a copy with updated fields (for editing/deletion/reactions).
  ChannelChatMessage copyWith({
    String? text,
    DateTime? timestamp,
    DateTime? editedAt,
    DateTime? hiddenAt,
    Map<String, List<String>>? reactions,
    FileAttachment? fileAttachment,
    network_api.LinkPreviewRef? linkPreview,
    String? signature,
    String? publicKey,
  }) {
    return ChannelChatMessage(
      senderId: senderId,
      text: text ?? this.text,
      isMe: isMe,
      timestamp: timestamp ?? this.timestamp,
      signature: signature ?? this.signature,
      publicKey: publicKey ?? this.publicKey,
      messageId: messageId,
      editedAt: editedAt ?? this.editedAt,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      replyToMid: replyToMid,
      reactions: reactions ?? this.reactions,
      fileAttachment: fileAttachment ?? this.fileAttachment,
      linkPreview: linkPreview ?? this.linkPreview,
    );
  }
}
