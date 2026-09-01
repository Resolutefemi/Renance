/// Renance light theme — lifted from the founder's auth mockups:
/// blue-tinted Material-3 surfaces (#f9f9ff / #e7eeff), ink #111c2d,
/// black primary buttons, white cards, 12px rounding.
library;

import 'package:flutter/material.dart';

class RenanceColors {
  static const Color background = Color(0xFFF9F9FF);
  static const Color surfaceContainer = Color(0xFFE7EEFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainerHigh = Color(0xFFDEE8FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF45464D);
  static const Color secondaryContainer = Color(0xFFD0E1FB);
  static const Color outline = Color(0xFF76777D);
  static const Color outlineVariant = Color(0xFFC6C6CD);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
}

ThemeData buildRenanceTheme() {
  final scheme = ColorScheme.light(
    primary: Colors.black,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF131B2E),
    onPrimaryContainer: Colors.white,
    secondary: const Color(0xFF505F76),
    onSecondary: Colors.white,
    secondaryContainer: RenanceColors.secondaryContainer,
    onSecondaryContainer: RenanceColors.ink,
    surface: RenanceColors.background,
    onSurface: RenanceColors.ink,
    surfaceContainerHighest: RenanceColors.surfaceContainerHigh,
    onSurfaceVariant: RenanceColors.onSurfaceVariant,
    outline: RenanceColors.outline,
    outlineVariant: RenanceColors.outlineVariant,
    error: RenanceColors.error,
    onError: Colors.white,
    errorContainer: RenanceColors.errorContainer,
    onErrorContainer: const Color(0xFF93000A),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RenanceColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: RenanceColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: RenanceColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardThemeData(
      color: RenanceColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Color(0x141C2D34),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RenanceColors.surfaceContainerLow,
      hintStyle: const TextStyle(color: RenanceColors.outline),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RenanceColors.ink, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RenanceColors.error, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RenanceColors.ink,
        side: const BorderSide(color: RenanceColors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RenanceColors.surfaceContainerLow,
      selectedColor: RenanceColors.secondaryContainer,
      side: const BorderSide(color: RenanceColors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(color: RenanceColors.ink, fontSize: 13),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RenanceColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
