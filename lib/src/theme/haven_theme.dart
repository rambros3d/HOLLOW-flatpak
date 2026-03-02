import 'package:flutter/material.dart';
import 'haven_colors.dart';
import 'haven_spacing.dart';

/// Haven's custom theme extension — travels with ThemeData.
///
/// Access via: `Theme.of(context).extension<HavenTheme>()!`
/// or the convenience: `HavenTheme.of(context)`
class HavenTheme extends ThemeExtension<HavenTheme> {
  final Color background;
  final Color surface;
  final Color elevated;
  final Color accent;
  final Color accentHover;
  final Color accentMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnAccent;
  final Color border;
  final Color error;
  final Color success;
  final Color warning;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;

  const HavenTheme({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.accent,
    required this.accentHover,
    required this.accentMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.border,
    required this.error,
    required this.success,
    required this.warning,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
  });

  /// Default dark theme.
  factory HavenTheme.dark() => const HavenTheme(
        background: HavenColors.background,
        surface: HavenColors.surface,
        elevated: HavenColors.elevated,
        accent: HavenColors.accent,
        accentHover: HavenColors.accentHover,
        accentMuted: HavenColors.accentMuted,
        textPrimary: HavenColors.textPrimary,
        textSecondary: HavenColors.textSecondary,
        textOnAccent: HavenColors.textOnAccent,
        border: HavenColors.border,
        error: HavenColors.error,
        success: HavenColors.success,
        warning: HavenColors.warning,
        radiusSm: HavenRadius.sm,
        radiusMd: HavenRadius.md,
        radiusLg: HavenRadius.lg,
        radiusXl: HavenRadius.xl,
      );

  /// Light theme.
  factory HavenTheme.light() => const HavenTheme(
        background: HavenColors.backgroundLight,
        surface: HavenColors.surfaceLight,
        elevated: HavenColors.elevatedLight,
        accent: HavenColors.accent,
        accentHover: HavenColors.accentHover,
        accentMuted: HavenColors.accentMutedLight,
        textPrimary: HavenColors.textPrimaryLight,
        textSecondary: HavenColors.textSecondaryLight,
        textOnAccent: HavenColors.textOnAccentLight,
        border: HavenColors.borderLight,
        error: HavenColors.error,
        success: HavenColors.success,
        warning: HavenColors.warning,
        radiusSm: HavenRadius.sm,
        radiusMd: HavenRadius.md,
        radiusLg: HavenRadius.lg,
        radiusXl: HavenRadius.xl,
      );

  /// Convenience accessor.
  static HavenTheme of(BuildContext context) =>
      Theme.of(context).extension<HavenTheme>()!;

  @override
  HavenTheme copyWith({
    Color? background,
    Color? surface,
    Color? elevated,
    Color? accent,
    Color? accentHover,
    Color? accentMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnAccent,
    Color? border,
    Color? error,
    Color? success,
    Color? warning,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
  }) {
    return HavenTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentMuted: accentMuted ?? this.accentMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      border: border ?? this.border,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
    );
  }

  @override
  HavenTheme lerp(covariant HavenTheme? other, double t) {
    if (other == null) return this;
    return HavenTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      radiusSm: radiusSm + (other.radiusSm - radiusSm) * t,
      radiusMd: radiusMd + (other.radiusMd - radiusMd) * t,
      radiusLg: radiusLg + (other.radiusLg - radiusLg) * t,
      radiusXl: radiusXl + (other.radiusXl - radiusXl) * t,
    );
  }
}
