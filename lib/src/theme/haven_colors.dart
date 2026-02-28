import 'dart:ui';

/// Haven color palette — Deep Dark + Teal Accent.
///
/// Teal evokes calm/shelter (aligns with "Haven" name).
/// Distinct from Discord (purple), Signal (blue), WhatsApp (green).
abstract final class HavenColors {
  // ── Backgrounds ──
  static const background = Color(0xFF0D0F14);
  static const surface = Color(0xFF14161C);
  static const elevated = Color(0xFF1A1D25);

  // ── Accent ──
  static const accent = Color(0xFF00BFA6);
  static const accentHover = Color(0xFF00D9BB);
  static const accentMuted = Color(0x3300BFA6);

  // ── Text ──
  static const textPrimary = Color(0xFFF1F3F5);
  static const textSecondary = Color(0xFF8B919A);
  static const textOnAccent = Color(0xFF0D0F14);

  // ── Borders ──
  static const border = Color(0x14FFFFFF); // ~8% white

  // ── Semantic ──
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}
