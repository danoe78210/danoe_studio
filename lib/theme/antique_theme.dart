import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ══════════════════════════════════════════════════════════════
///  DANOË STUDIO — Design Tokens "Bibliothèque gothique"
/// ══════════════════════════════════════════════════════════════
class AntiqueTheme {
  AntiqueTheme._();

  // ── 🎨 Palette de couleurs ──
  static const Color inkBlack = Color(0xFF0F0B08); // encre profonde
  static const Color leatherDark = Color(0xFF1F1208); // cuir très sombre
  static const Color leatherWarm = Color(0xFF2A1810); // cuir sombre
  static const Color leatherDeep = Color(0xFF3A2211); // cuir chaud
  static const Color brass = Color(0xFFB8860B); // laiton vieilli
  static const Color agedGold = Color(0xFFD4A84B); // or patiné
  static const Color candleGlow = Color(0xFFFFD88A); // lueur de bougie
  static const Color parchment = Color(0xFFE8D9B0); // parchemin clair
  static const Color parchmentMid = Color(0xFFD4BF8A); // parchemin moyen
  static const Color parchmentDark = Color(0xFFC9B584); // parchemin ombré
  static const Color inkSepia = Color(0xFF3B2F1E); // encre sépia
  static const Color bloodInk = Color(0xFF8B1A1A); // encre rouge sombre
  static const Color verdigris = Color(
    0xFF4E8577,
  ); // vert-de-gris (cuivre oxydé)

  // ── 🌅 Dégradés ──
  static const LinearGradient leatherGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A2211), Color(0xFF1F1208), Color(0xFF2A1810)],
  );

  static const LinearGradient parchmentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3E7C9), Color(0xFFE9D9B4), Color(0xFFD4BF8A)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE0B458), Color(0xFFB8860B), Color(0xFF8B6508)],
  );

  static const RadialGradient candleRadial = RadialGradient(
    colors: [Color(0x44FFD88A), Color(0x00FFD88A)],
  );

  // ── ✒️ Typographies ──
  static TextStyle get displayLarge => GoogleFonts.cinzel(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: agedGold,
    letterSpacing: 4,
    shadows: [
      Shadow(
        color: inkBlack.withValues(alpha: 0.8),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static TextStyle get titlePage => GoogleFonts.cormorantGaramond(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: inkSepia,
    fontStyle: FontStyle.italic,
    height: 1.4,
  );

  static TextStyle get bodyText => GoogleFonts.crimsonText(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: inkSepia,
    height: 1.6,
    letterSpacing: 0.2,
  );

  static TextStyle get caption => GoogleFonts.cinzel(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: brass,
    letterSpacing: 2,
  );

  static TextStyle get labelRuban => GoogleFonts.cinzel(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFFFFFFF),
    letterSpacing: 1.2,
    shadows: [Shadow(color: inkBlack.withValues(alpha: 0.6), blurRadius: 2)],
  );

  // ── 🎛️ ThemeData complet ──
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: inkBlack,
    colorScheme: const ColorScheme.dark(
      primary: agedGold,
      secondary: brass,
      surface: leatherDark,
      onSurface: parchment,
      error: bloodInk,
    ),
    textTheme: TextTheme(
      displayLarge: displayLarge,
      titleMedium: titlePage,
      bodyLarge: bodyText,
      labelSmall: caption,
    ),
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1B2036),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
