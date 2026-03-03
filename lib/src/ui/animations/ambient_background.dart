import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Very slow-drifting ambient background for the chat area.
///
/// Two soft radial gradient blobs (teal + purple/blue) at low opacity
/// drift in a slow figure-8 pattern over ~45 seconds.
/// Rule: if you notice the animation while chatting, it's too much.
class AmbientBackground extends StatefulWidget {
  final Color color1;
  final Color color2;
  final double opacity;
  final Widget child;

  const AmbientBackground({
    super.key,
    required this.color1,
    required this.color2,
    this.opacity = 0.04,
    required this.child,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;

        // Figure-8 (lemniscate) path for blob 1.
        final x1 = 0.5 + 0.25 * math.sin(t);
        final y1 = 0.5 + 0.15 * math.sin(t * 2);

        // Opposite phase for blob 2.
        final x2 = 0.5 - 0.2 * math.sin(t + math.pi * 0.7);
        final y2 = 0.5 - 0.2 * math.sin(t * 2 + math.pi);

        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AmbientPainter(
                    color1: widget.color1.withValues(alpha: widget.opacity),
                    color2: widget.color2.withValues(alpha: widget.opacity),
                    center1: Offset(x1, y1),
                    center2: Offset(x2, y2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final Offset center1;
  final Offset center2;

  _AmbientPainter({
    required this.color1,
    required this.color2,
    required this.center1,
    required this.center2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Blob 1 — teal (wide soft fill)
    final c1 = Offset(center1.dx * size.width, center1.dy * size.height);
    final r1 = size.width * 0.55;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [color1, color1, color1.withValues(alpha: 0)],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));
    canvas.drawCircle(c1, r1, paint1);

    // Blob 2 — purple/blue (wide soft fill)
    final c2 = Offset(center2.dx * size.width, center2.dy * size.height);
    final r2 = size.width * 0.5;
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [color2, color2, color2.withValues(alpha: 0)],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));
    canvas.drawCircle(c2, r2, paint2);
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) {
    return center1 != oldDelegate.center1 || center2 != oldDelegate.center2;
  }
}
