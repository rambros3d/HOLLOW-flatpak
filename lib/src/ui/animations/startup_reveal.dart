import 'package:flutter/material.dart';

/// Shares the master startup animation controller with the entire
/// widget subtree via [InheritedWidget].
///
/// Child widgets call [StartupRevealScope.of] to get the controller
/// (returns `null` after the animation completes — skip all wrapping).
/// [StartupRevealScope.interval] creates a [CurvedAnimation] sub-interval
/// for staggering child elements.
class StartupRevealScope extends InheritedWidget {
  final AnimationController controller;
  final bool isComplete;

  const StartupRevealScope({
    super.key,
    required this.controller,
    required this.isComplete,
    required super.child,
  });

  /// Returns the startup animation controller, or `null` if the reveal
  /// is already complete (widgets should render fully, no animation).
  static AnimationController? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<StartupRevealScope>();
    if (scope == null || scope.isComplete) return null;
    return scope.controller;
  }

  /// Create a [CurvedAnimation] for a sub-interval of the master timeline.
  ///
  /// Returns `null` when the reveal is complete — callers should render
  /// their child fully when null.
  static Animation<double>? interval(
    BuildContext context,
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) {
    final controller = of(context);
    if (controller == null) return null;
    return CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  bool updateShouldNotify(StartupRevealScope oldWidget) =>
      isComplete != oldWidget.isComplete;
}
