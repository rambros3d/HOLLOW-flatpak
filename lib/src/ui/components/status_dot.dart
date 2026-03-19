import 'package:flutter/material.dart';
import 'package:hollow/src/theme/hollow_theme.dart';

/// A small colored circle indicating connection/encryption status.
///
/// Set [pulse] to true for a breathing glow animation — a soft ring
/// that fades in/out over 3 seconds. Used on online presence dots.
class StatusDot extends StatefulWidget {
  final Color? color;
  final double size;
  final bool pulse;

  const StatusDot({
    super.key,
    this.color,
    this.size = 8,
    this.pulse = false,
  });

  /// Online status (green) with optional pulse.
  const StatusDot.online({super.key, this.size = 8, this.pulse = false})
      : color = null; // uses success from theme

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _initPulse();
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && _controller == null) {
      _initPulse();
    } else if (!widget.pulse && _controller != null) {
      _controller!.dispose();
      _controller = null;
      _pulseAnimation = null;
    }
  }

  void _initPulse() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
    );
    _controller!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final dotColor = widget.color ?? hollow.success;

    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    if (_pulseAnimation == null) return dot;

    // Keep glow tight — just a soft shadow, no size increase.
    return AnimatedBuilder(
      animation: _pulseAnimation!,
      builder: (context, child) {
        final value = _pulseAnimation!.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.4 * value),
                blurRadius: 3 * value,
                spreadRadius: 1.5 * value,
              ),
            ],
          ),
        );
      },
      child: dot,
    );
  }
}
