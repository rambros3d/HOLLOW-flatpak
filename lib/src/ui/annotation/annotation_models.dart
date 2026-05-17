import 'package:flutter/material.dart';

/// Drawing tool currently selected in the annotation overlay.
enum AnnotationTool {
  freehand, // Continuous brush stroke that follows the cursor.
  line,     // Straight line between pointer-down and pointer-up.
  arrow,    // Straight line with a triangular head at the release point.
  eraser,   // Removes any stroke whose path is touched by the cursor.
}

/// Visual style of the stroke contour.
enum LineStyle {
  solid,
  dotted,  // Dense dots (~1px on, 3px off).
  dashed,  // Long dashes (~10px on, 6px off).
}

/// One committed stroke owned by the annotation controller. Strokes are
/// immutable once committed — undo/redo just moves the visible range in the
/// controller's stack.
class Stroke {
  final AnnotationTool tool;
  final List<Offset> points;
  final Color color;
  final double width;
  final LineStyle style;

  const Stroke({
    required this.tool,
    required this.points,
    required this.color,
    required this.width,
    required this.style,
  });
}
