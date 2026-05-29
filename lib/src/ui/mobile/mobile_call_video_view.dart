import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hollow/src/core/providers/call_provider.dart';
import 'package:hollow/src/core/providers/identity_provider.dart';
import 'package:hollow/src/core/providers/profile_provider.dart';
import 'package:hollow/src/theme/hollow_spacing.dart';
import 'package:hollow/src/theme/hollow_theme.dart';
import 'package:hollow/src/theme/hollow_typography.dart';
import 'package:hollow/src/ui/components/hollow_avatar.dart';
import 'package:hollow/src/ui/components/hollow_pressable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full-screen call overlay that slides up from the bottom inside a DM chat.
/// Handles all call states: ringing, connecting, active (audio + video).
/// Reusable for voice channels later (pass participant list).
class MobileCallScreen extends ConsumerStatefulWidget {
  final String peerId;
  const MobileCallScreen({super.key, required this.peerId});

  @override
  ConsumerState<MobileCallScreen> createState() => _MobileCallScreenState();
}

class _MobileCallScreenState extends ConsumerState<MobileCallScreen> {
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  Offset _pipOffset = const Offset(12, 12);

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime startedAt) {
    _durationTimer?.cancel();
    _duration = DateTime.now().difference(startedAt);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _duration = DateTime.now().difference(startedAt);
      });
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _statusText(CallState call) {
    switch (call.status) {
      case CallStatus.ringing:
        return call.direction == CallDirection.outgoing
            ? 'Calling...'
            : 'Incoming...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.active:
        return _formatDuration(_duration);
      case CallStatus.idle:
        return 'Ended';
    }
  }

  /// Whether to show the video area. Must have an active call with explicit
  /// video enabled AND a real renderer with a source — otherwise the
  /// onRemoteVideoTrack safety net can trigger a black rectangle over the
  /// avatars even when no camera is actually sending.
  bool _hasRealVideo(CallState call) {
    if (call.status != CallStatus.active) return false;
    final vs = ref.read(callProvider.notifier).voiceService;

    final remoteHasVideo = call.remoteVideoEnabled &&
        vs?.remoteRenderer != null &&
        vs!.remoteRenderer!.srcObject != null;
    final localHasVideo = call.isVideoEnabled &&
        vs?.localRenderer != null &&
        vs!.localRenderer!.srcObject != null;

    return remoteHasVideo || localHasVideo;
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    final hollow = HollowTheme.of(context);
    final localPeerId = ref.read(identityProvider).peerId ?? '';

    // Auto-pop when call ends.
    ref.listen<CallState>(callProvider, (prev, next) {
      if (next.status == CallStatus.idle &&
          prev?.status != CallStatus.idle) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    if (call.status == CallStatus.active && call.startedAt != null) {
      if (_durationTimer == null) _startTimer(call.startedAt!);
    } else if (call.status != CallStatus.active) {
      _durationTimer?.cancel();
      _durationTimer = null;
    }

    final showVideo = _hasRealVideo(call);

    return Scaffold(
      backgroundColor: hollow.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(hollow, call),
            Expanded(
              child: showVideo
                  ? _buildVideoView(hollow, call)
                  : _buildAudioView(hollow, call, localPeerId),
            ),
            _buildControls(hollow, call),
            const SizedBox(height: HollowSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(HollowTheme hollow, CallState call) {
    final profiles = ref.watch(profileProvider);
    final displayName = displayNameFor(profiles, widget.peerId);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HollowSpacing.md,
        vertical: HollowSpacing.sm,
      ),
      child: Row(
        children: [
          HollowPressable(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(hollow.radiusSm),
            padding: const EdgeInsets.all(HollowSpacing.sm),
            child: Icon(LucideIcons.chevronDown,
                size: 24, color: hollow.textPrimary),
          ),
          const SizedBox(width: HollowSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: HollowTypography.body.copyWith(
                    color: hollow.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _statusText(call),
                  style: HollowTypography.caption.copyWith(
                    color: call.status == CallStatus.active
                        ? hollow.textSecondary
                        : hollow.accent,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioView(
      HollowTheme hollow, CallState call, String localPeerId) {
    return Center(
      child: _ClusteredAvatars(
        participants: [localPeerId, widget.peerId],
        speakingSet: {
          if (call.isLocalSpeaking) localPeerId,
          if (call.isRemoteSpeaking) widget.peerId,
        },
        mutedSet: {
          if (call.isMuted) localPeerId,
        },
      ),
    );
  }

  Widget _buildVideoView(HollowTheme hollow, CallState call) {
    final voiceService = ref.read(callProvider.notifier).voiceService;
    final remoteRenderer = voiceService?.remoteRenderer;
    final localRenderer = voiceService?.localRenderer;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final showRemoteFull = call.remoteVideoEnabled &&
        remoteRenderer != null &&
        remoteRenderer.srcObject != null;
    final showLocalFull = !showRemoteFull &&
        call.isVideoEnabled &&
        localRenderer != null &&
        localRenderer.srcObject != null;
    final showLocalPip = showRemoteFull &&
        call.isVideoEnabled &&
        localRenderer != null &&
        localRenderer.srcObject != null;

    return Stack(
      children: [
        if (showRemoteFull)
          Positioned.fill(
            child: RepaintBoundary(
              child: RTCVideoView(
                remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),
          )
        else if (showLocalFull)
          Positioned.fill(
            child: RepaintBoundary(
              child: RTCVideoView(
                localRenderer,
                mirror: true,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(
              color: hollow.elevated,
              child: Center(
                child: HollowAvatar(peerId: widget.peerId, size: 80),
              ),
            ),
          ),
        // Local PiP — portrait proportioned (3:4)
        if (showLocalPip)
          Positioned(
            right: _pipOffset.dx,
            bottom: _pipOffset.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _pipOffset = Offset(
                    (_pipOffset.dx - details.delta.dx)
                        .clamp(0.0, screenWidth - 110.0),
                    (_pipOffset.dy - details.delta.dy).clamp(0.0, 400.0),
                  );
                });
              },
              child: Container(
                width: 90,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hollow.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: RepaintBoundary(
                    child: RTCVideoView(
                      localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit
                          .RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls(HollowTheme hollow, CallState call) {
    const iconSize = 26.0;
    const buttonSize = 56.0;
    final canControl = call.status == CallStatus.active ||
        call.status == CallStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HollowSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: call.isMuted ? LucideIcons.micOff : LucideIcons.mic,
            iconSize: iconSize,
            size: buttonSize,
            color: call.isMuted ? hollow.error : hollow.textPrimary,
            backgroundColor: call.isMuted
                ? hollow.error.withValues(alpha: 0.15)
                : hollow.elevated,
            onTap: canControl
                ? () => ref.read(callProvider.notifier).toggleMute()
                : null,
          ),
          _ControlButton(
            icon: call.isVideoEnabled
                ? LucideIcons.video
                : LucideIcons.videoOff,
            iconSize: iconSize,
            size: buttonSize,
            color:
                call.isVideoEnabled ? hollow.accent : hollow.textPrimary,
            backgroundColor: call.isVideoEnabled
                ? hollow.accent.withValues(alpha: 0.15)
                : hollow.elevated,
            onTap: call.status == CallStatus.active
                ? () => ref.read(callProvider.notifier).toggleVideo()
                : null,
          ),
          _ControlButton(
            icon: LucideIcons.phoneOff,
            iconSize: iconSize,
            size: buttonSize,
            color: Colors.white,
            backgroundColor: hollow.error,
            onTap: () => ref.read(callProvider.notifier).endCall(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Clustered avatar layout with speaking indicators
// ─────────────────────────────────────────────────

class _ClusteredAvatars extends StatelessWidget {
  final List<String> participants;
  final Set<String> speakingSet;
  final Set<String> mutedSet;

  const _ClusteredAvatars({
    required this.participants,
    required this.speakingSet,
    this.mutedSet = const {},
  });

  @override
  Widget build(BuildContext context) {
    final count = participants.length;
    final avatarSize = count <= 2 ? 96.0 : count <= 4 ? 80.0 : 64.0;
    final gap = avatarSize * 0.25;

    final List<List<String>> rows;
    switch (count) {
      case 1:
        rows = [
          [participants[0]]
        ];
      case 2:
        rows = [participants];
      case 3:
        rows = [
          participants.sublist(0, 2),
          [participants[2]],
        ];
      case 4:
        rows = [
          participants.sublist(0, 2),
          participants.sublist(2, 4),
        ];
      case 5:
        rows = [
          participants.sublist(0, 2),
          [participants[2]],
          participants.sublist(3, 5),
        ];
      default:
        rows = [];
        for (var i = 0; i < count; i += 3) {
          rows.add(participants.sublist(i, (i + 3).clamp(0, count)));
        }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                if (c > 0) SizedBox(width: gap),
                _SpeakingAvatar(
                  peerId: rows[r][c],
                  size: avatarSize,
                  isSpeaking: speakingSet.contains(rows[r][c]),
                  isMuted: mutedSet.contains(rows[r][c]),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// Single avatar with animated teal speaking glow (rounded square)
// ─────────────────────────────────────────────────

class _SpeakingAvatar extends ConsumerStatefulWidget {
  final String peerId;
  final double size;
  final bool isSpeaking;
  final bool isMuted;

  const _SpeakingAvatar({
    required this.peerId,
    required this.size,
    required this.isSpeaking,
    this.isMuted = false,
  });

  @override
  ConsumerState<_SpeakingAvatar> createState() => _SpeakingAvatarState();
}

class _SpeakingAvatarState extends ConsumerState<_SpeakingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowAnim = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOut,
    );
    if (widget.isSpeaking) _glowController.forward();
  }

  @override
  void didUpdateWidget(_SpeakingAvatar old) {
    super.didUpdateWidget(old);
    if (widget.isSpeaking && !old.isSpeaking) {
      _glowController.forward();
    } else if (!widget.isSpeaking && old.isSpeaking) {
      _glowController.reverse();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final profiles = ref.watch(profileProvider);
    final displayName = displayNameFor(profiles, widget.peerId);
    final localPeerId = ref.read(identityProvider).peerId ?? '';
    final isMe = widget.peerId == localPeerId;
    final radius = hollow.radiusMd;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 4),
                border: Border.all(
                  color: hollow.accent
                      .withValues(alpha: _glowAnim.value * 0.9),
                  width: 3 * _glowAnim.value,
                ),
                boxShadow: _glowAnim.value > 0.01
                    ? [
                        BoxShadow(
                          color: hollow.accent
                              .withValues(alpha: _glowAnim.value * 0.3),
                          blurRadius: 16 * _glowAnim.value,
                          spreadRadius: 2 * _glowAnim.value,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              HollowAvatar(peerId: widget.peerId, size: widget.size),
              if (widget.isMuted)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: hollow.error,
                      borderRadius: BorderRadius.circular(radius * 0.6),
                      border:
                          Border.all(color: hollow.background, width: 2),
                    ),
                    child: Icon(LucideIcons.micOff,
                        size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: HollowSpacing.sm),
        Text(
          isMe ? 'You' : displayName,
          style: HollowTypography.caption.copyWith(
            color: hollow.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// Circular control button
// ─────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final double size;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.iconSize,
    required this.size,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Thin call status strip (shown in chat when call screen is dismissed)
// ─────────────────────────────────────────────────

class MobileCallStatusStrip extends ConsumerWidget {
  final String peerId;
  const MobileCallStatusStrip({super.key, required this.peerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    final isCallWithThisPeer =
        call.peerId == peerId && call.status != CallStatus.idle;

    // Don't show strip for incoming ringing — the IncomingCallOverlay handles that.
    if (!isCallWithThisPeer) return const SizedBox.shrink();
    if (call.status == CallStatus.ringing &&
        call.direction == CallDirection.incoming) {
      return const SizedBox.shrink();
    }

    final hollow = HollowTheme.of(context);
    final profiles = ref.watch(profileProvider);
    final displayName = displayNameFor(profiles, peerId);

    String label;
    switch (call.status) {
      case CallStatus.ringing:
        label = call.direction == CallDirection.outgoing
            ? 'Calling $displayName...'
            : 'Incoming call...';
      case CallStatus.connecting:
        label = 'Connecting...';
      case CallStatus.active:
        label = 'In call with $displayName';
      case CallStatus.idle:
        label = '';
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                MobileCallScreen(peerId: peerId),
            transitionsBuilder: (_, anim, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOut,
                )),
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HollowSpacing.md,
          vertical: HollowSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: hollow.success.withValues(alpha: 0.1),
          border: Border(
            bottom:
                BorderSide(color: hollow.success.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hollow.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: HollowSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: HollowTypography.caption.copyWith(
                  color: hollow.success,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Tap to return',
              style: HollowTypography.caption.copyWith(
                color: hollow.success.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: HollowSpacing.xs),
            Icon(LucideIcons.chevronUp,
                size: 14, color: hollow.success.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
