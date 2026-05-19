import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Legacy palette ─────────────────────────────────────────
  // Still used by the auth screens (splash / login / register),
  // which keep the original dark video-background look.
  static const Color primary = Color(0xFFFF6B35);
  static const Color accent = Color(0xFFFFD23F);
  static const Color dark = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color cardBg = Color(0x99000000);

  // ── Light design system ────────────────────────────────────
  // Lime + lavender on a soft off-white background. Used by all
  // in-app screens after the redesign.
  static const Color lime = Color(0xFFCBF03C); // primary accent (fills)
  static const Color limeDeep = Color(0xFF7E9B12); // lime, readable as text
  static const Color lavender = Color(0xFFCDBCF5); // secondary accent
  static const Color ink = Color(0xFF1B1B1D); // primary text / dark cards
  static const Color appBg = Color(0xFFF1F1EC); // screen background
  static const Color card = Color(0xFFFFFFFF); // card surface
  static const Color textMuted = Color(0xFF6E6E73); // secondary text
  static const Color textFaint = Color(0xFF9A9AA0); // tertiary text
  static const Color hairline = Color(0xFFE6E6E0); // borders / dividers

  /// Soft shadow used on light cards.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// App-wide light theme.
  static ThemeData get theme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: appBg,
        colorScheme: const ColorScheme.light(
          primary: lime,
          secondary: lavender,
          surface: card,
          onPrimary: ink,
        ),
        textTheme: GoogleFonts.bebasNeueTextTheme().copyWith(
          bodyMedium: GoogleFonts.inter(color: ink),
          bodySmall: GoogleFonts.inter(color: textMuted),
        ),
      );
}
