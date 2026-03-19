import 'package:flutter/animation.dart';

/// Standard animation curves for Hollow UI.
abstract final class HollowCurves {
  /// Default enter curve — snappy with a small overshoot.
  static const enter = Curves.easeOutCubic;

  /// Default exit curve — smooth deceleration.
  static const exit = Curves.easeInCubic;

  /// Spring curve for interactive elements (buttons, cards).
  static const spring = Curves.elasticOut;

  /// Subtle ease for hover/focus transitions.
  static const subtle = Curves.easeInOut;
}

/// Standard animation durations for Hollow UI.
abstract final class HollowDurations {
  /// Quick transitions (hover, focus, status changes).
  static const fast = Duration(milliseconds: 150);

  /// Standard transitions (panels, dialogs).
  static const normal = Duration(milliseconds: 250);

  /// Longer transitions (page changes, layout shifts).
  static const slow = Duration(milliseconds: 400);
}
