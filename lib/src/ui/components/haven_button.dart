import 'package:flutter/material.dart';

/// Button variant selector for Haven-branded buttons.
enum HavenButtonVariant { filled, outlined, text }

/// Haven-branded button that delegates to the appropriate Material button
/// (which is already themed via HavenThemeData).
class HavenButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final HavenButtonVariant variant;

  const HavenButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = HavenButtonVariant.filled,
  });

  const HavenButton.filled({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  }) : variant = HavenButtonVariant.filled;

  const HavenButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  }) : variant = HavenButtonVariant.outlined;

  const HavenButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  }) : variant = HavenButtonVariant.text;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      HavenButtonVariant.filled => icon != null
          ? FilledButton.icon(
              onPressed: onPressed, icon: icon!, label: child)
          : FilledButton(onPressed: onPressed, child: child),
      HavenButtonVariant.outlined => icon != null
          ? OutlinedButton.icon(
              onPressed: onPressed, icon: icon!, label: child)
          : OutlinedButton(onPressed: onPressed, child: child),
      HavenButtonVariant.text => icon != null
          ? TextButton.icon(
              onPressed: onPressed, icon: icon!, label: child)
          : TextButton(onPressed: onPressed, child: child),
    };
  }
}
