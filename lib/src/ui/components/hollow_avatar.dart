import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hollow/src/theme/hollow_theme.dart';

/// Avatar widget — shows a real image when available, falls back to
/// deterministic color + initials from peer ID.
class HollowAvatar extends StatelessWidget {
  final String peerId;
  final double size;
  final Uint8List? imageBytes;

  const HollowAvatar({
    super.key,
    required this.peerId,
    this.size = 36,
    this.imageBytes,
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

  Widget _buildFallback(HollowTheme hollow) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFromId(peerId),
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

  @override
  Widget build(BuildContext context) {
    final hollow = HollowTheme.of(context);

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(hollow.radiusMd),
        child: Image.memory(
          imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(hollow),
        ),
      );
    }

    return _buildFallback(hollow);
  }
}
