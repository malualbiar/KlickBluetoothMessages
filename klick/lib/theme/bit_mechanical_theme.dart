import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LcdThemeMode {
  amberGold,
  cyberGreen,
  glacierCyan,
  boneWhite,
}

class BitMechanicalTheme {
  // Hardware Chassis Colors
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  static const Color hardwareBody = Color(0xFF131313);
  static const Color hardwareKeyBase = Color(0xFF1A1A1A);
  static const Color hardwareKeyTopHighlight = Color(0xFF333333);
  static const Color hardwareKeyActive = Color(0xFF111111);
  static const Color hardwareDpadCenterStart = Color(0xFF2A2A2A);
  static const Color hardwareDpadCenterEnd = Color(0xFF111111);

  static const Color outline = Color(0xFF9B8F7A);
  static const Color outlineVariant = Color(0xFF4E4634);
  static const Color primaryAmber = Color(0xFFFFD05E);
  static const Color primaryContainer = Color(0xFFE6B325);
  static const Color surfaceTint = Color(0xFFF3BF32);

  // LCD Color Palettes
  static Color getLcdBackground(LcdThemeMode mode) {
    switch (mode) {
      case LcdThemeMode.amberGold:
        return const Color(0xFFE6B325); // Golden yellow LCD
      case LcdThemeMode.cyberGreen:
        return const Color(0xFF38D45B); // Matrix phosphor green
      case LcdThemeMode.glacierCyan:
        return const Color(0xFF70C2FF); // Cold blue LCD
      case LcdThemeMode.boneWhite:
        return const Color(0xFFE2DFD8); // Monochrome vintage paper
    }
  }

  static Color getLcdInk(LcdThemeMode mode) {
    return const Color(0xFF111111);
  }

  static Color getLcdInkDim(LcdThemeMode mode) {
    return const Color(0xFF333333);
  }

  static String getThemeName(LcdThemeMode mode) {
    switch (mode) {
      case LcdThemeMode.amberGold:
        return 'AMBER GOLD';
      case LcdThemeMode.cyberGreen:
        return 'PHOSPHOR GREEN';
      case LcdThemeMode.glacierCyan:
        return 'GLACIER CYAN';
      case LcdThemeMode.boneWhite:
        return 'BONE WHITE';
    }
  }

  // Typography helpers with GoogleFonts
  static TextStyle headlineLg({Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.spaceMono(
      fontSize: 22,
      fontWeight: fontWeight ?? FontWeight.w700,
      letterSpacing: -0.5,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle headlineMd({Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.spaceMono(
      fontSize: 16,
      fontWeight: fontWeight ?? FontWeight.w700,
      letterSpacing: 0,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle bodyLg({Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 14,
      fontWeight: fontWeight ?? FontWeight.w600,
      letterSpacing: -0.2,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle bodyMd({Color? color, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: fontWeight ?? FontWeight.w500,
      letterSpacing: 0,
      height: height,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle labelCaps({Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 11,
      fontWeight: fontWeight ?? FontWeight.w800,
      letterSpacing: 1.2,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle statusPixel({
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? fontSize,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 10,
      fontWeight: fontWeight ?? FontWeight.w700,
      letterSpacing: letterSpacing ?? 0.5,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle headlineMono({
    Color? color,
    double fontSize = 16,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceMono(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w700,
      letterSpacing: letterSpacing ?? 0,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle bodyMono({
    Color? color,
    double fontSize = 12,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      letterSpacing: letterSpacing ?? 0,
      height: height,
      color: color ?? const Color(0xFF111111),
    );
  }

  static TextStyle hardwareKeyText({Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 11,
      fontWeight: fontWeight ?? FontWeight.w700,
      letterSpacing: 0.5,
      color: color ?? primaryAmber,
    );
  }
}
