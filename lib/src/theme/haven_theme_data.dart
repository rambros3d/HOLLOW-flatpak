import 'package:flutter/material.dart';
import 'haven_colors.dart';
import 'haven_spacing.dart';
import 'haven_theme.dart';
import 'haven_typography.dart';

/// Factory for creating Flutter ThemeData with Haven's design system.
abstract final class HavenThemeData {
  /// Haven's primary dark theme.
  static ThemeData dark() {
    final haven = HavenTheme.dark();

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: haven.background,
      canvasColor: haven.surface,

      // ── Color Scheme ──
      colorScheme: ColorScheme.dark(
        primary: haven.accent,
        onPrimary: haven.textOnAccent,
        secondary: haven.accent,
        onSecondary: haven.textOnAccent,
        surface: haven.surface,
        onSurface: haven.textPrimary,
        error: haven.error,
        onError: HavenColors.textPrimary,
      ),

      // ── Typography ──
      textTheme: TextTheme(
        displayLarge: HavenTypography.display,
        headlineMedium: HavenTypography.heading,
        titleMedium: HavenTypography.subheading,
        bodyLarge: HavenTypography.body,
        bodyMedium: HavenTypography.body,
        bodySmall: HavenTypography.bodySmall,
        labelLarge: HavenTypography.label,
        labelSmall: HavenTypography.caption,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: haven.border,
        thickness: 1,
        space: 1,
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: haven.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HavenSpacing.md,
          vertical: HavenSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
          borderSide: BorderSide(color: haven.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
          borderSide: BorderSide(color: haven.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
          borderSide: BorderSide(color: haven.accent, width: 1.5),
        ),
        hintStyle: HavenTypography.body.copyWith(
          color: haven.textSecondary,
        ),
        labelStyle: HavenTypography.body.copyWith(
          color: haven.textSecondary,
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(haven.accent),
          foregroundColor: WidgetStatePropertyAll(haven.textOnAccent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HavenRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HavenTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HavenSpacing.lg,
              vertical: HavenSpacing.sm,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(haven.accent),
          side: WidgetStatePropertyAll(
            BorderSide(color: haven.accent.withValues(alpha: 0.5)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HavenRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HavenTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HavenSpacing.lg,
              vertical: HavenSpacing.sm,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(haven.accent),
          textStyle: WidgetStatePropertyAll(HavenTypography.label),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(haven.textSecondary),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: haven.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HavenRadius.lg),
        ),
        titleTextStyle: HavenTypography.heading,
        contentTextStyle: HavenTypography.body,
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: haven.elevated,
        contentTextStyle: HavenTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: haven.elevated,
          borderRadius: BorderRadius.circular(HavenRadius.sm),
          border: Border.all(color: haven.border),
        ),
        textStyle: HavenTypography.bodySmall.copyWith(
          color: haven.textPrimary,
        ),
      ),

      // ── Scrollbar ──
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          haven.textSecondary.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(HavenRadius.sm),
        thickness: const WidgetStatePropertyAll(6),
      ),

      // ── Haven extension ──
      extensions: [haven],
    );
  }

  /// Haven's secondary light theme.
  static ThemeData light() {
    final haven = HavenTheme.light();

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: haven.background,
      canvasColor: haven.surface,

      // ── Color Scheme ──
      colorScheme: ColorScheme.light(
        primary: haven.accent,
        onPrimary: haven.textOnAccent,
        secondary: haven.accent,
        onSecondary: haven.textOnAccent,
        surface: haven.surface,
        onSurface: haven.textPrimary,
        error: haven.error,
        onError: HavenColors.textPrimaryLight,
      ),

      // ── Typography (override hardcoded dark colors) ──
      textTheme: TextTheme(
        displayLarge:
            HavenTypography.display.copyWith(color: haven.textPrimary),
        headlineMedium:
            HavenTypography.heading.copyWith(color: haven.textPrimary),
        titleMedium:
            HavenTypography.subheading.copyWith(color: haven.textPrimary),
        bodyLarge: HavenTypography.body.copyWith(color: haven.textPrimary),
        bodyMedium: HavenTypography.body.copyWith(color: haven.textPrimary),
        bodySmall:
            HavenTypography.bodySmall.copyWith(color: haven.textSecondary),
        labelLarge: HavenTypography.label.copyWith(color: haven.textPrimary),
        labelSmall:
            HavenTypography.caption.copyWith(color: haven.textSecondary),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: haven.border,
        thickness: 1,
        space: 1,
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: haven.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HavenSpacing.md,
          vertical: HavenSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
          borderSide: BorderSide(color: haven.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
          borderSide: BorderSide(color: haven.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
          borderSide: BorderSide(color: haven.accent, width: 1.5),
        ),
        hintStyle: HavenTypography.body.copyWith(
          color: haven.textSecondary,
        ),
        labelStyle: HavenTypography.body.copyWith(
          color: haven.textSecondary,
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(haven.accent),
          foregroundColor: WidgetStatePropertyAll(haven.textOnAccent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HavenRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HavenTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HavenSpacing.lg,
              vertical: HavenSpacing.sm,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(haven.accent),
          side: WidgetStatePropertyAll(
            BorderSide(color: haven.accent.withValues(alpha: 0.5)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HavenRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(HavenTypography.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: HavenSpacing.lg,
              vertical: HavenSpacing.sm,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(haven.accent),
          textStyle: WidgetStatePropertyAll(HavenTypography.label),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(haven.textSecondary),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: haven.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HavenRadius.lg),
        ),
        titleTextStyle:
            HavenTypography.heading.copyWith(color: haven.textPrimary),
        contentTextStyle:
            HavenTypography.body.copyWith(color: haven.textPrimary),
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: haven.elevated,
        contentTextStyle:
            HavenTypography.body.copyWith(color: haven.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HavenRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: haven.elevated,
          borderRadius: BorderRadius.circular(HavenRadius.sm),
          border: Border.all(color: haven.border),
        ),
        textStyle: HavenTypography.bodySmall.copyWith(
          color: haven.textPrimary,
        ),
      ),

      // ── Scrollbar ──
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          haven.textSecondary.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(HavenRadius.sm),
        thickness: const WidgetStatePropertyAll(6),
      ),

      // ── Haven extension ──
      extensions: [haven],
    );
  }
}
