import 'package:flutter/material.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/animations/haven_transitions.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final isMe = message.isMe;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return FadeSlideTransition(
      beginOffset: Offset(isMe ? 0.05 : -0.05, 0.0),
      duration: const Duration(milliseconds: 200),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: HavenSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: HavenSpacing.md + 2,
            vertical: HavenSpacing.sm + 2,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.5,
          ),
          decoration: BoxDecoration(
            color: isMe ? haven.accent : haven.elevated,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(haven.radiusLg),
              topRight: Radius.circular(haven.radiusLg),
              bottomLeft: Radius.circular(isMe ? haven.radiusLg : haven.radiusSm),
              bottomRight: Radius.circular(isMe ? haven.radiusSm : haven.radiusLg),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: HavenTypography.body.copyWith(
                  color: isMe ? haven.textOnAccent : haven.textPrimary,
                ),
              ),
              const SizedBox(height: HavenSpacing.xs),
              Text(
                time,
                style: HavenTypography.caption.copyWith(
                  color: isMe
                      ? haven.textOnAccent.withValues(alpha: 0.7)
                      : haven.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
