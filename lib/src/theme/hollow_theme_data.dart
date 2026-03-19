import 'package:flutter/material.dart';
import 'hollow_colors.dart';
import 'hollow_spacing.dart';
import 'hollow_theme.dart';
import 'hollow_typography.dart';

/// Factory for creating Flutter ThemeData with Hollow's design system.
abstract final class HollowThemeData {
  /// Hollow's primary dark theme.
  static ThemeData dark() {
    final hollow = HollowTheme.dark();

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: hollow.background,
      canvasColor: hollow.surface,

      // ── Color Scheme ──
      colorScheme: ColorScheme.dark(
        primary: hollow.accent,
        onPrimary: hollow.textOnAccent,
        secondary: hollow.accent,
        onSecondary: hollow.textOnAccent,
        surface: hollow.surface,
        onSurface: hollow.textPrimary,
        error: hollow.error,
        onError: HollowColors.textPrimary,
      ),

      // ── Typography ──
      textTheme: TextTheme(
        displayLarge: HollowTypography.display,
        headlineMedium: HollowTypography.heading,
        titleMedium: HollowTypography.subheading,
        bodyLarge: HollowTypography.body,
        bodyMedium: HollowTypography.body,
        bodySmall: HollowTypography.bodySmall,
        labelLarge: HollowTypography.label,
        labelSmall: HollowTypography.caption,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: hollow.border,
        thickness: 1,
        space: 1,
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: hollow.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HollowSpacing.md,
          vertical: HollowSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
          borderSide: BorderSide(color: hollow.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
          borderSide: BorderSide(color: hollow.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
          borderSide: BorderSide(color: hollow.accent, width: 1.5),
        ),
        hintStyle: HollowTypography.body.copyWith(
          color: hollow.textSecondary,
        ),
        labelStyle: HollowTypography.body.copyWith(
          color: hollow.textSecondary,
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(hollow.accent),
          foregroundColor: WidgetStatePropertyAll(hollow.textOnAccent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HollowRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HollowTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HollowSpacing.lg,
              vertical: HollowSpacing.sm,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(hollow.accent),
          side: WidgetStatePropertyAll(
            BorderSide(color: hollow.accent.withValues(alpha: 0.5)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HollowRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HollowTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HollowSpacing.lg,
              vertical: HollowSpacing.sm,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(hollow.accent),
          textStyle: WidgetStatePropertyAll(HollowTypography.label),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(hollow.textSecondary),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: hollow.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HollowRadius.lg),
        ),
        titleTextStyle: HollowTypography.heading,
        contentTextStyle: HollowTypography.body,
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: hollow.elevated,
        contentTextStyle: HollowTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: hollow.elevated,
          borderRadius: BorderRadius.circular(HollowRadius.sm),
          border: Border.all(color: hollow.border),
        ),
        textStyle: HollowTypography.bodySmall.copyWith(
          color: hollow.textPrimary,
        ),
      ),

      // ── Scrollbar ──
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          hollow.textSecondary.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(HollowRadius.sm),
        thickness: const WidgetStatePropertyAll(6),
      ),

      // ── Hollow extension ──
      extensions: [hollow],
    );
  }

  /// Hollow's secondary light theme.
  static ThemeData light() {
    final hollow = HollowTheme.light();

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: hollow.background,
      canvasColor: hollow.surface,

      // ── Color Scheme ──
      colorScheme: ColorScheme.light(
        primary: hollow.accent,
        onPrimary: hollow.textOnAccent,
        secondary: hollow.accent,
        onSecondary: hollow.textOnAccent,
        surface: hollow.surface,
        onSurface: hollow.textPrimary,
        error: hollow.error,
        onError: HollowColors.textPrimaryLight,
      ),

      // ── Typography (override hardcoded dark colors) ──
      textTheme: TextTheme(
        displayLarge:
            HollowTypography.display.copyWith(color: hollow.textPrimary),
        headlineMedium:
            HollowTypography.heading.copyWith(color: hollow.textPrimary),
        titleMedium:
            HollowTypography.subheading.copyWith(color: hollow.textPrimary),
        bodyLarge: HollowTypography.body.copyWith(color: hollow.textPrimary),
        bodyMedium: HollowTypography.body.copyWith(color: hollow.textPrimary),
        bodySmall:
            HollowTypography.bodySmall.copyWith(color: hollow.textSecondary),
        labelLarge: HollowTypography.label.copyWith(color: hollow.textPrimary),
        labelSmall:
            HollowTypography.caption.copyWith(color: hollow.textSecondary),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: hollow.border,
        thickness: 1,
        space: 1,
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: hollow.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HollowSpacing.md,
          vertical: HollowSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
          borderSide: BorderSide(color: hollow.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
          borderSide: BorderSide(color: hollow.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
          borderSide: BorderSide(color: hollow.accent, width: 1.5),
        ),
        hintStyle: HollowTypography.body.copyWith(
          color: hollow.textSecondary,
        ),
        labelStyle: HollowTypography.body.copyWith(
          color: hollow.textSecondary,
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(hollow.accent),
          foregroundColor: WidgetStatePropertyAll(hollow.textOnAccent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HollowRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HollowTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HollowSpacing.lg,
              vertical: HollowSpacing.sm,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(hollow.accent),
          side: WidgetStatePropertyAll(
            BorderSide(color: hollow.accent.withValues(alpha: 0.5)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HollowRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HollowTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HollowSpacing.lg,
              vertical: HollowSpacing.sm,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(hollow.accent),
          textStyle: WidgetStatePropertyAll(HollowTypography.label),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(hollow.textSecondary),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: hollow.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HollowRadius.lg),
        ),
        titleTextStyle:
            HollowTypography.heading.copyWith(color: hollow.textPrimary),
        contentTextStyle:
            HollowTypography.body.copyWith(color: hollow.textPrimary),
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: hollow.elevated,
        contentTextStyle:
            HollowTypography.body.copyWith(color: hollow.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HollowRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: hollow.elevated,
          borderRadius: BorderRadius.circular(HollowRadius.sm),
          border: Border.all(color: hollow.border),
        ),
        textStyle: HollowTypography.bodySmall.copyWith(
          color: hollow.textPrimary,
        ),
      ),

      // ── Scrollbar ──
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          hollow.textSecondary.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(HollowRadius.sm),
        thickness: const WidgetStatePropertyAll(6),
      ),

      // ── Hollow extension ──
      extensions: [hollow],
    );
  }
}
