import 'package:flutter/material.dart';
import 'package:hollow/src/core/shared_tickers.dart';

/// A subtle shimmer overlay for selected list items.
///
/// A transparent-to-highlight-to-transparent gradient sweeps across
/// the widget over 4s, repeating infinitely via [SharedTickers].
/// Very subtle — just enough to catch the eye.
///
/// Set [vertical] to true for a top-to-bottom sweep (voice channels).
class SelectionShimmer extends StatelessWidget {
  final Widget child;
  final Color highlightColor;
  final BorderRadius? borderRadius;
  final bool vertical;

  const SelectionShimmer({
    super.key,
    required this.child,
    required this.highlightColor,
    this.borderRadius,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: SharedTickers.instance.shimmer,
      builder: (context, value, child) {
        final pos = value * 4.0 - 1.5;
        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: borderRadius ?? BorderRadius.zero,
                  child: CustomPaint(
                    painter: _ShimmerPainter(
                      position: pos,
                      highlightColor: highlightColor,
                      vertical: vertical,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double position;
  final Color highlightColor;
  final bool vertical;

  final Paint _paint = Paint();

  _ShimmerPainter({
    required this.position,
    required this.highlightColor,
    required this.vertical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Alignment begin;
    final Alignment end;
    if (vertical) {
      begin = Alignment(0, position - 0.5);
      end = Alignment(0, position + 0.5);
    } else {
      begin = Alignment(position - 0.5, 0);
      end = Alignment(position + 0.5, 0);
    }
    _paint.shader = LinearGradient(
      begin: begin,
      end: end,
      colors: [Colors.transparent, highlightColor, Colors.transparent],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.position != position;
}
