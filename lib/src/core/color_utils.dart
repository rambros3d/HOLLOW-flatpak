import 'dart:ui' show Color;
import 'package:flutter/painting.dart' show HSLColor;

final _avatarColorCache = <String, Color>{};
final _nameColorCache = <String, Color>{};

Color colorFromId(String id) {
  return _avatarColorCache[id] ??= _compute(id, 0.5, 0.45);
}

Color nameColorFromId(String id) {
  return _nameColorCache[id] ??= _compute(id, 0.6, 0.65);
}

Color _compute(String id, double saturation, double lightness) {
  final hue = (id.hashCode % 360).abs().toDouble();
  return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
}
