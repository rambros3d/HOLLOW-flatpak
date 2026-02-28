import 'package:flutter/material.dart';
import 'package:haven/src/theme/haven_theme.dart';

/// A small colored circle indicating connection/encryption status.
class StatusDot extends StatelessWidget {
  final Color? color;
  final double size;

  const StatusDot({
    super.key,
    this.color,
    this.size = 8,
  });

  /// Online status (green).
  const StatusDot.online({super.key, this.size = 8})
      : color = null; // uses success from theme

  @override
  Widget build(BuildContext context) {
    final haven = HavenTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? haven.success,
        shape: BoxShape.circle,
      ),
    );
  }
}
