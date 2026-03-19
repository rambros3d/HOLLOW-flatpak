import 'package:flutter/material.dart';
import 'package:hollow/src/theme/hollow_theme.dart';

/// Deterministic avatar generated from a peer ID hash.
class HollowAvatar extends StatelessWidget {
  final String peerId;
  final double size;

  const HollowAvatar({
    super.key,
    required this.peerId,
    this.size = 36,
  });

  /// Deterministic color from peer ID.
  Color _colorFromId(String id) {
    final hash = id.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.45).toColor();
  }

  String _initialsFromId(String id) {
    if (id.length < 2) return '??';
    return id.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);
    final bgColor = _colorFromId(peerId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(hollow.radiusMd),
      ),
      alignment: Alignment.center,
      child: Text(
        _initialsFromId(peerId),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
