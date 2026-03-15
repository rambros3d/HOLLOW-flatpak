import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haven/src/core/providers/channel_provider.dart';
import 'package:haven/src/core/providers/selected_peer_provider.dart';
import 'package:haven/src/core/providers/server_provider.dart';
import 'package:haven/src/core/providers/system_notification_provider.dart';
import 'package:haven/src/theme/haven_spacing.dart';
import 'package:haven/src/theme/haven_theme.dart';
import 'package:haven/src/theme/haven_typography.dart';
import 'package:haven/src/ui/components/haven_avatar.dart';
import 'package:haven/src/ui/components/haven_pressable.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Overlay that shows notification cards in the bottom-right corner.
///
/// Up to 3 cards stacked vertically. Each card shows a header
/// (avatar + source name) and up to 5 accumulated messages.
/// Cards auto-dismiss after 5 seconds, hover pauses the timer.
/// Click navigates to the source conversation.
class NotificationOverlay extends ConsumerWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(systemNotificationProvider);

    if (cards.isEmpty) return const SizedBox.shrink();

    // Stack cards from bottom, each card ~100px tall + 4px gap.
    // Newest at bottom, oldest at top.
    const cardHeight = 100.0;
    const gap = HavenSpacing.xxs;

    return Stack(
      children: [
        for (int i = 0; i < cards.length; i++)
          AnimatedPositioned(
            key: ValueKey(cards[i].sourceKey),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            right: HavenSpacing.lg,
            bottom: HavenSpacing.lg +
                (cards.length - 1 - i) * (cardHeight + gap),
            child: _NotificationCardWidget(
              key: ValueKey('card-${cards[i].sourceKey}'),
              card: cards[i],
            ),
          ),
      ],
    );
  }
}

/// A single notification card with auto-dismiss.
class _NotificationCardWidget extends ConsumerStatefulWidget {
  final NotificationCard card;

  const _NotificationCardWidget({
    super.key,
    required this.card,
  });

  @override
  ConsumerState<_NotificationCardWidget> createState() =>
      _NotificationCardWidgetState();
}

class _NotificationCardWidgetState
    extends ConsumerState<_NotificationCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;
  bool _hovering = false;

  static const _autoDismissDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
    _startDismissTimer();
  }

  @override
  void didUpdateWidget(_NotificationCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset timer when new messages arrive in this card.
    if (widget.card.messages.length != oldWidget.card.messages.length) {
      _restartDismissTimer();
    }
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_autoDismissDuration, _dismiss);
  }

  void _restartDismissTimer() {
    if (!_hovering) _startDismissTimer();
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        ref
            .read(systemNotificationProvider.notifier)
            .dismissCard(widget.card.sourceKey);
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    // Navigate to the source conversation.
    if (widget.card.isDm && widget.card.peerId != null) {
      ref.read(selectedServerProvider.notifier).state = null;
      ref.read(selectedPeerProvider.notifier).state = widget.card.peerId;
    } else if (widget.card.serverId != null &&
        widget.card.channelId != null) {
      ref.read(selectedServerProvider.notifier).state =
          widget.card.serverId;
      ref.read(selectedChannelProvider.notifier).state =
          widget.card.channelId;
      ref.read(selectedPeerProvider.notifier).state = null;
    }
    // Dismiss this card.
    ref
        .read(systemNotificationProvider.notifier)
        .dismissCard(widget.card.sourceKey);
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    final card = widget.card;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: MouseRegion(
          onEnter: (_) {
            _hovering = true;
            _dismissTimer?.cancel();
          },
          onExit: (_) {
            _hovering = false;
            _startDismissTimer();
          },
          child: GestureDetector(
            onTap: _onTap,
            child: Container(
              width: 320,
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: haven.elevated.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(haven.radiusMd),
                border: Border.all(
                  color: haven.accent.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HavenSpacing.md,
                      HavenSpacing.sm + 2,
                      HavenSpacing.sm,
                      HavenSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        HavenAvatar(
                          peerId: card.avatarId,
                          size: 24,
                        ),
                        const SizedBox(width: HavenSpacing.sm),
                        Expanded(
                          child: Text(
                            card.title,
                            style: HavenTypography.body.copyWith(
                              color: haven.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Close button
                        HavenPressable(
                          onTap: _dismiss,
                          borderRadius:
                              BorderRadius.circular(haven.radiusSm),
                          padding:
                              const EdgeInsets.all(HavenSpacing.xxs),
                          child: Icon(
                            LucideIcons.x,
                            size: 14,
                            color: haven.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    color: haven.border.withValues(alpha: 0.5),
                  ),

                  // Messages
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HavenSpacing.md,
                        vertical: HavenSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0;
                              i < card.messages.length;
                              i++) ...[
                            if (i > 0)
                              const SizedBox(height: HavenSpacing.xxs),
                            _MessageRow(
                              message: card.messages[i],
                              isDm: card.isDm,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single message row in a notification card.
class _MessageRow extends StatelessWidget {
  final NotificationMessage message;
  final bool isDm;

  const _MessageRow({
    required this.message,
    required this.isDm,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    // For DMs, don't repeat the sender name (it's in the header).
    // For channels, show sender name since multiple people can send.
    if (isDm) {
      return Text(
        message.text,
        style: HavenTypography.body.copyWith(
          color: haven.textSecondary,
          fontSize: 12,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${message.senderName}: ',
          style: HavenTypography.body.copyWith(
            color: haven.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            message.text,
            style: HavenTypography.body.copyWith(
              color: haven.textSecondary,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
