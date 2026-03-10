import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/models/chat_message.dart';
import 'package:haven/src/core/providers/identity_provider.dart';
import 'package:haven/src/core/providers/profile_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_avatar.dart';

/// Deterministic name color from peer ID (same hue as avatar, lighter for readability).
Color nameColorFromId(String id) {
  final hash = id.hashCode;
  final hue = (hash % 360).abs().toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.6, 0.65).toColor();
}

/// Flat message row for DMs — no bubbles.
///
/// [showHeader] controls whether avatar + name + timestamp are shown
/// (first message in a group) or just indented text (continuation).
class MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final String peerId;
  final bool showHeader;

  const MessageBubble({
    super.key,
    required this.message,
    required this.peerId,
    required this.showHeader,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haven = HavenTheme.of(context);
    final isMe = message.isMe;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    final profiles = ref.watch(profileProvider);
    final localPeerId = ref.watch(identityProvider).peerId ?? '';
    final senderId = isMe ? localPeerId : peerId;
    final senderName = displayNameFor(profiles, senderId);

    const avatarSize = 32.0;
    const avatarGap = HavenSpacing.sm + 2; // 10px
    const indent = avatarSize + avatarGap;

    final meDecoration = BoxDecoration(
      border: Border(
        right: BorderSide(color: haven.accent, width: 2),
      ),
    );

    if (showHeader) {
      // Group spacing is outside the border container.
      return Padding(
        padding: const EdgeInsets.only(top: HavenSpacing.sm + 2),
        child: Container(
          padding: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: HavenSpacing.md,
            right: isMe ? 0 : HavenSpacing.md,
          ),
          decoration: isMe ? meDecoration : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HavenAvatar(peerId: senderId, size: avatarSize),
              const SizedBox(width: avatarGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          senderName,
                          style: HavenTypography.body.copyWith(
                            color: isMe
                                ? haven.accent
                                : nameColorFromId(senderId),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: HavenSpacing.sm),
                        Text(
                          time,
                          style: HavenTypography.caption.copyWith(
                            color:
                                haven.textSecondary.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.text,
                      style: HavenTypography.body.copyWith(
                        color: haven.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Continuation message — indented, no avatar/name.
    return Container(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: HavenSpacing.md + indent,
        right: isMe ? 0 : HavenSpacing.md,
      ),
      decoration: isMe ? meDecoration : null,
      child: Text(
        message.text,
        style: HavenTypography.body.copyWith(
          color: haven.textPrimary,
        ),
      ),
    );
  }
}
