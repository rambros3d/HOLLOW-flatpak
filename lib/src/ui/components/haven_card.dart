import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_theme.dart';

/// An elevated surface container using Haven's design system.
class HavenCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const HavenCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? haven.elevated,
        borderRadius: BorderRadius.circular(haven.radiusMd),
        border: Border.all(color: haven.border),
      ),
      child: child,
    );
  }
}
