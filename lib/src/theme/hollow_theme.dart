import 'package:flutter/material.dart';
import 'hollow_colors.dart';
import 'hollow_spacing.dart';

/// Hollow's custom theme extension — travels with ThemeData.
///
/// Access via: `Theme.of(context).extension<HollowTheme>()!`
/// or the convenience: `HollowTheme.of(context)`
class HollowTheme extends ThemeExtension<HollowTheme> {
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

  const HollowTheme({
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
  factory HollowTheme.dark() => const HollowTheme(
        background: HollowColors.background,
        surface: HollowColors.surface,
        elevated: HollowColors.elevated,
        accent: HollowColors.accent,
        accentHover: HollowColors.accentHover,
        accentMuted: HollowColors.accentMuted,
        textPrimary: HollowColors.textPrimary,
        textSecondary: HollowColors.textSecondary,
        textOnAccent: HollowColors.textOnAccent,
        border: HollowColors.border,
        error: HollowColors.error,
        success: HollowColors.success,
        warning: HollowColors.warning,
        radiusSm: HollowRadius.sm,
        radiusMd: HollowRadius.md,
        radiusLg: HollowRadius.lg,
        radiusXl: HollowRadius.xl,
      );

  /// Light theme.
  factory HollowTheme.light() => const HollowTheme(
        background: HollowColors.backgroundLight,
        surface: HollowColors.surfaceLight,
        elevated: HollowColors.elevatedLight,
        accent: HollowColors.accent,
        accentHover: HollowColors.accentHover,
        accentMuted: HollowColors.accentMutedLight,
        textPrimary: HollowColors.textPrimaryLight,
        textSecondary: HollowColors.textSecondaryLight,
        textOnAccent: HollowColors.textOnAccentLight,
        border: HollowColors.borderLight,
        error: HollowColors.error,
        success: HollowColors.success,
        warning: HollowColors.warning,
        radiusSm: HollowRadius.sm,
        radiusMd: HollowRadius.md,
        radiusLg: HollowRadius.lg,
        radiusXl: HollowRadius.xl,
      );

  /// Convenience accessor.
  static HollowTheme of(BuildContext context) =>
      Theme.of(context).extension<HollowTheme>()!;

  @override
  HollowTheme copyWith({
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
    return HollowTheme(
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
  HollowTheme lerp(covariant HollowTheme? other, double t) {
    if (other == null) return this;
    return HollowTheme(
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
