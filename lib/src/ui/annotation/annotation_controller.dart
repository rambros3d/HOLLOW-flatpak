import 'package:flutter/material.dart';

import 'annotation_models.dart';

/// Singleton-ish state container for the annotation overlay. Holds the
/// committed strokes, the undo/redo stack pointer, and the current drawing
/// settings (tool, color, width, line style).
///
/// One instance lives in [AnnotationOverlay] for the duration of an
/// annotation session; closing the overlay disposes it.
class AnnotationController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  // Pointer into [_strokes]: strokes at indexes < _historyIndex are visible.
  // Undo decrements; redo increments (if there are strokes ahead).
  int _historyIndex = 0;

  AnnotationTool _tool = AnnotationTool.freehand;
  Color _color = Colors.red;
  double _width = 4.0;
  LineStyle _style = LineStyle.solid;

  // ── Public read-only accessors ───────────────────────────────────────────

  List<Stroke> get visibleStrokes =>
      List.unmodifiable(_strokes.sublist(0, _historyIndex));

  AnnotationTool get tool => _tool;
  Color get color => _color;
  double get width => _width;
  LineStyle get style => _style;

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _strokes.length;
  bool get hasContent => _historyIndex > 0;

  // ── Mutations ────────────────────────────────────────────────────────────

  void setTool(AnnotationTool t) {
    if (_tool == t) return;
    _tool = t;
    notifyListeners();
  }

  void setColor(Color c) {
    if (_color == c) return;
    _color = c;
    notifyListeners();
  }

  void setWidth(double w) {
    if (_width == w) return;
    _width = w;
    notifyListeners();
  }

  void setStyle(LineStyle s) {
    if (_style == s) return;
    _style = s;
    notifyListeners();
  }

  /// Add a new finished stroke. Truncates any redo tail.
  void commitStroke(Stroke s) {
    if (_historyIndex < _strokes.length) {
      _strokes.removeRange(_historyIndex, _strokes.length);
    }
    _strokes.add(s);
    _historyIndex = _strokes.length;
    notifyListeners();
  }

  /// Remove every visible stroke that has a point within [radius] of [hit].
  /// Cleans the stroke list so undo doesn't bring back erased strokes
  /// (eraser is a destructive op, modelled as one undoable event per call).
  bool eraseAt(Offset hit, double radius) {
    if (_historyIndex == 0) return false;
    var changed = false;
    for (var i = _historyIndex - 1; i >= 0; i--) {
      final s = _strokes[i];
      if (s.tool == AnnotationTool.eraser) continue;
      if (_strokeIntersects(s, hit, radius)) {
        _strokes.removeAt(i);
        _historyIndex--;
        changed = true;
      }
    }
    if (changed) notifyListeners();
    return changed;
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    _historyIndex = 0;
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  bool _strokeIntersects(Stroke s, Offset hit, double radius) {
    final r2 = radius * radius;
    for (final p in s.points) {
      final dx = p.dx - hit.dx;
      final dy = p.dy - hit.dy;
      if (dx * dx + dy * dy <= r2) return true;
    }
    // For straight lines/arrows the on-screen segment is between the first
    // and last point — check perpendicular distance.
    if (s.points.length == 2) {
      final a = s.points.first;
      final b = s.points.last;
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (len2 == 0) return false;
      final t = ((hit - a).dx * ab.dx + (hit - a).dy * ab.dy) / len2;
      final clamped = t.clamp(0.0, 1.0);
      final proj = a + Offset(ab.dx * clamped, ab.dy * clamped);
      final dx = hit.dx - proj.dx;
      final dy = hit.dy - proj.dy;
      return dx * dx + dy * dy <= r2;
    }
    return false;
  }
}
