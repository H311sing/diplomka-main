import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFFFF6B35);
  static const Color accent = Color(0xFFFFD23F);
  static const Color dark = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color cardBg = Color(0x99000000);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: surface,
    ),
    textTheme: GoogleFonts.bebasNeueTextTheme().copyWith(
      bodyMedium: GoogleFonts.inter(color: Colors.white70),
      bodySmall: GoogleFonts.inter(color: Colors.white54),
    ),
  );
}