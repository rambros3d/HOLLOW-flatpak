import 'package:flutter/material.dart';
import 'haven_colors.dart';

/// Haven typography scale.
///
/// Uses the system font stack for native feel on each platform.
/// All styles default to textPrimary color — override via copyWith where needed.
abstract final class HavenTypography {
  static const _base = TextStyle(
    fontFamily: null, // System default (Segoe UI on Windows, SF Pro on macOS, etc.)
    color: HavenColors.textPrimary,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Display — large headings (server name, onboarding titles)
  static final display = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Heading — section headers
  static final heading = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Subheading — panel titles, dialog headers
  static final subheading = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Body — default text
  static final body = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Body small — secondary text, timestamps
  static final bodySmall = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HavenColors.textSecondary,
  );

  /// Label — buttons, badges, chips
  static final label = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Caption — tiny text, metadata
  static final caption = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: HavenColors.textSecondary,
  );

  /// Mono — peer IDs, code, technical strings
  static final mono = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'Consolas', // Falls back to monospace on other platforms
    letterSpacing: 0.5,
  );
}
