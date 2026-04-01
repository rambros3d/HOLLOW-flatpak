import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/providers/call_provider.dart';
import 'package:hollow/src/core/providers/profile_provider.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/animations/hollow_curves.dart';
import 'package:hollow/src/ui/components/hollow_avatar.dart';
import 'package:hollow/src/ui/components/hollow_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Overlay that shows an incoming call card in the top-center of the screen.
/// Watches [callProvider] and renders only when status is ringing + incoming.
class IncomingCallOverlay extends ConsumerStatefulWidget {
  const IncomingCallOverlay({super.key});

  @override
  ConsumerState<IncomingCallOverlay> createState() =>
      _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: HollowDurations.normal,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: HollowCurves.enter,
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: HollowCurves.enter,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    final isVisible = call.status == CallStatus.ringing &&
        call.direction == CallDirection.incoming;

    if (isVisible && !_wasVisible) {
      _controller.forward(from: 0);
    } else if (!isVisible && _wasVisible) {
      _controller.reverse();
    }
    _wasVisible = isVisible;

    if (!isVisible && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    final hollow = HollowTheme.of(context);
    final peerId = call.peerId ?? '';
    final profiles = ref.watch(profileProvider);
    final displayName =
        displayNameFor(profiles, peerId);
    final avatarBytes = profiles[peerId]?.avatarBytes;

    return Positioned(
      top: HollowSpacing.xl + 32, // below title bar
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(HollowSpacing.lg),
              decoration: BoxDecoration(
                color: hollow.elevated,
                borderRadius: BorderRadius.circular(hollow.radiusLg),
                border: Border.all(color: hollow.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HollowAvatar(
                    peerId: peerId,
                    size: 56,
                    imageBytes: avatarBytes,
                  ),
                  const SizedBox(height: HollowSpacing.sm),
                  Text(
                    displayName,
                    style: HollowTypography.body.copyWith(
                      color: hollow.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: HollowSpacing.xs),
                  Text(
                    call.isVideoCall
                        ? 'Incoming video call...'
                        : 'Incoming voice call...',
                    style: HollowTypography.caption.copyWith(
                      color: hollow.textSecondary,
                    ),
                  ),
                  const SizedBox(height: HollowSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HollowButton.danger(
                        onPressed: () {
                          ref.read(callProvider.notifier).rejectCall();
                        },
                        icon: Icon(LucideIcons.phoneOff, size: 16),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: HollowSpacing.md),
                      HollowButton.filled(
                        onPressed: () {
                          ref.read(callProvider.notifier).acceptCall();
                        },
                        icon: Icon(
                          call.isVideoCall ? LucideIcons.video : LucideIcons.phone,
                          size: 16,
                        ),
                        child: const Text('Accept'),
                      ),
                    ],
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
