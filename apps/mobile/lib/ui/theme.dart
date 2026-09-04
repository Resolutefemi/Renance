/// Renance design system, the Stitch export as Flutter tokens.
///
/// Light tier comes from the founder's auth mockups and every Stitch
/// screen's tailwind config: blue-tinted M3 surfaces (#f9f9ff / #e7eeff),
/// ink #111c2d, black primary buttons, white cards, 12px rounding.
/// Dark tier tokens mirror the Stitch `dark-surface` palette, and the
/// full type scale (display / section-title / stat-number / body /
/// caption / label-mono) is lifted 1:1 from the export's fontSize map.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RenanceColors {
  // Light tier
  static const Color background = Color(0xFFF9F9FF);
  static const Color surfaceContainer = Color(0xFFE7EEFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainerHigh = Color(0xFFDEE8FF);
  static const Color surfaceVariant = Color(0xFFD8E3FB);
  static const Color selectionBlue = Color(0xFFD0E1FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111C2D);
  static const Color textSecondary = Color(0xFF45464D);
  static const Color secondaryContainer = Color(0xFFD8DFF9);
  static const Color secondary = Color(0xFF565E74);
  static const Color outline = Color(0xFF7E7576);
  static const Color outlineDark = Color(0xFF76777D);
  static const Color outlineLight = Color(0xFFC6C6CD);
  static const Color outlineVariant = Color(0xFFCFC4C5);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Accents
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);

  // Dark tier (Stitch full-dark screens)
  static const Color darkPage = Color(0xFF111C2D); // full-dark page ground
  static const Color darkSurface = Color(0xFF131B2E); // dark chrome container
  static const Color darkSurfaceLow = Color(0xFF17223B); // wells / tracks
  static const Color darkCard = Color(0xFF1C2638); // elevated dark card
  static const Color darkTextPrimary = Color(0xFFF0F3FF);
  static const Color darkTextSecondary = Color(0xFFA2AAB8);
  static const Color darkMuted = Color(0xFF8A94A6);
  static const Color darkOutline = Color(0xFF3A4661);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color onDarkErrorContainer = Color(0xFFFFDAD6);
}

/// The full-dark ThemeData (Settings → Appearance → Dark).
ThemeData buildRenanceDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: Colors.white,
    onPrimary: RenanceColors.darkPage,
    primaryContainer: RenanceColors.darkSurface,
    onPrimaryContainer: RenanceColors.darkTextPrimary,
    secondary: RenanceColors.darkTextSecondary,
    onSecondary: RenanceColors.darkTextPrimary,
    secondaryContainer: RenanceColors.darkSurface,
    onSecondaryContainer: RenanceColors.darkTextPrimary,
    surface: RenanceColors.darkPage,
    onSurface: RenanceColors.darkTextPrimary,
    surfaceContainerHighest: RenanceColors.darkCard,
    onSurfaceVariant: RenanceColors.darkTextSecondary,
    outline: RenanceColors.darkTextSecondary,
    outlineVariant: RenanceColors.darkOutline,
    error: RenanceColors.darkError,
    onError: Color(0xFF690005),
    errorContainer: RenanceColors.darkErrorContainer,
    onErrorContainer: Color(0xFFFFDAD6),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RenanceColors.darkPage,
    appBarTheme: const AppBarTheme(
      backgroundColor: RenanceColors.darkPage,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: RenanceColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: const CardThemeData(
      color: RenanceColors.darkCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RenanceColors.darkCard,
      hintStyle: const TextStyle(color: RenanceColors.darkTextSecondary),
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
        borderSide: const BorderSide(
            color: RenanceColors.darkTextPrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RenanceColors.darkError, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: RenanceColors.darkPage,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RenanceColors.darkTextPrimary,
        side: const BorderSide(color: RenanceColors.darkOutline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RenanceColors.darkSurface,
      selectedColor: RenanceColors.darkCard,
      side: const BorderSide(color: RenanceColors.darkOutline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(
          color: RenanceColors.darkTextPrimary, fontSize: 13),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RenanceColors.darkTextPrimary,
      contentTextStyle: TextStyle(color: RenanceColors.darkSurface),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ---------------------------------------------------------------------------
// Stitch type scale, 1:1 from the export's fontSize config.
// display-lg 28/36 -2% w700 · display-md 24/32 -1% w700 · section-title
// 18/24 -1% w600 · stat-number 24/28 -2% w700 · body-medium 15/22 w600 ·
// body-base 15/22 w400 · caption 13/18 w400 · label-mono 13/18 w500 (mono).
// ---------------------------------------------------------------------------

class RenanceText {
  static const String _fontFamily = 'Inter';
  static const String _monoFamily = 'JetBrainsMono';

  static const TextStyle displayLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: -0.02 * 28,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle displayMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 32 / 24,
    letterSpacing: -0.01 * 24,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 24 / 18,
    letterSpacing: -0.01 * 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle statNumber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.02 * 24,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyBase = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle labelMono = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  /// 11px uppercase tracking-wider label (hero-card "NEXT TARGET").
  static const TextStyle overline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w500,
  );
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
    onSurfaceVariant: RenanceColors.textSecondary,
    outline: RenanceColors.outlineDark,
    outlineVariant: RenanceColors.outlineLight,
    error: RenanceColors.error,
    onError: Colors.white,
    errorContainer: RenanceColors.errorContainer,
    onErrorContainer: const Color(0xFF93000A),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RenanceColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: RenanceColors.ink,
      displayColor: RenanceColors.ink,
    ),
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
      systemOverlayStyle: SystemUiOverlayStyle.dark,
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
        side: const BorderSide(color: RenanceColors.outlineLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RenanceColors.surfaceContainerLow,
      selectedColor: RenanceColors.selectionBlue,
      side: const BorderSide(color: RenanceColors.outlineLight),
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

/// The three Appearance options from the Stitch settings screen.
/// Mixed = light surfaces with the dark containers the player/results
/// screens use (chrome-level dark, light body).
enum RenanceThemeMode { light, mixed, dark }

/// Persists the Appearance choice and exposes it to MaterialApp.
class ThemeController extends ChangeNotifier {
  ThemeController({required SharedPreferences prefs}) : _prefs = prefs {
    final raw = prefs.getString(_kKey);
    _mode = switch (raw) {
      'dark' => RenanceThemeMode.dark,
      'mixed' => RenanceThemeMode.mixed,
      _ => RenanceThemeMode.light,
    };
  }

  static const _kKey = 'renance.theme';

  final SharedPreferences _prefs;
  RenanceThemeMode _mode = RenanceThemeMode.light;

  /// Exposed so Settings can persist its own preferences on the same
  /// SharedPreferences instance.
  SharedPreferences get prefs => _prefs;

  RenanceThemeMode get mode => _mode;

  ThemeMode get materialMode => switch (_mode) {
        RenanceThemeMode.dark => ThemeMode.dark,
        _ => ThemeMode.light, // mixed keeps the light scaffold by design
      };

  Future<void> setMode(RenanceThemeMode mode) async {
    _mode = mode;
    await _prefs.setString(_kKey, switch (mode) {
      RenanceThemeMode.dark => 'dark',
      RenanceThemeMode.mixed => 'mixed',
      RenanceThemeMode.light => 'light',
    });
    notifyListeners();
  }
}

// ---------------------------------------------------------------------
// Mode scope + theme-aware tokens
// ---------------------------------------------------------------------

/// Exposes the active Appearance tier to every screen so surfaces can
/// resolve their colors per tier without touching ThemeController.
class RenanceModeScope extends InheritedWidget {
  const RenanceModeScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final RenanceThemeMode mode;

  static RenanceThemeMode of(BuildContext context) {
    final RenanceModeScope? scope =
        context.dependOnInheritedWidgetOfExactType<RenanceModeScope>();
    return scope?.mode ?? RenanceThemeMode.light;
  }

  @override
  bool updateShouldNotify(RenanceModeScope oldWidget) =>
      oldWidget.mode != mode;
}

/// Theme-aware design tokens. Every screen resolves colors through
/// these getters so the Light, Mixed and Full-dark tiers all fall out
/// of the same markup:
///
///  * Light  — #F9F9FF page, white cards, ink text.
///  * Mixed  — light page, dark #111C2D hero/chrome (the exam player
///             treatment), light cards everywhere else.
///  * Dark   — #111C2D page throughout, #1C2638 cards, #F0F3FF text.
extension RenanceScheme on BuildContext {
  RenanceThemeMode get renanceMode => RenanceModeScope.of(this);
  bool get isDarkTier => renanceMode == RenanceThemeMode.dark;
  bool get isMixedTier => renanceMode == RenanceThemeMode.mixed;

  /// Surfaces that carry the dark chrome in mixed AND full dark.
  bool get darkChrome => isDarkTier || isMixedTier;

  // Page ground ------------------------------------------------------
  Color get pageBg =>
      isDarkTier ? RenanceColors.darkPage : RenanceColors.background;

  // Cards --------------------------------------------------------------
  Color get card =>
      isDarkTier ? RenanceColors.darkCard : RenanceColors.card;
  Color get cardLowest => isDarkTier
      ? RenanceColors.darkCard
      : RenanceColors.surfaceContainerLowest;
  Color get cardLow => isDarkTier
      ? RenanceColors.darkSurface
      : RenanceColors.surfaceContainerLow;
  Color get cardHigh => isDarkTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.surfaceContainerHigh;
  Color get cardHighest => isDarkTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.surfaceVariant;
  Color get surfaceContainer => isDarkTier
      ? RenanceColors.darkCard
      : RenanceColors.surfaceContainer;
  Color get surfaceVariant => isDarkTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.surfaceVariant;
  Color get selectionBlue => isDarkTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.selectionBlue;
  Color get secondaryContainer => isDarkTier
      ? RenanceColors.darkSurface
      : RenanceColors.secondaryContainer;

  // Hero / chrome: the big dark surface (same ink ground in every tier,
  // per the light, mixed and full-dark home designs).
  Color get heroGround => RenanceColors.darkPage;
  Color get heroCard => isDarkTier
      ? RenanceColors.darkCard
      : (isMixedTier ? RenanceColors.darkPage : RenanceColors.card);
  Color get onHeroCard => isDarkTier
      ? RenanceColors.darkTextPrimary
      : (isMixedTier ? Colors.white : RenanceColors.ink);
  Color get heroMuted => isDarkTier
      ? RenanceColors.darkTextSecondary
      : (isMixedTier ? const Color(0xFFB9C2D4) : RenanceColors.textSecondary);
  Color get heroTrack => isDarkTier || isMixedTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.surfaceVariant;

  // Ink / text ---------------------------------------------------------
  Color get ink =>
      isDarkTier ? RenanceColors.darkTextPrimary : RenanceColors.ink;
  Color get textSecondary => isDarkTier
      ? RenanceColors.darkTextSecondary
      : RenanceColors.textSecondary;
  Color get secondary => isDarkTier
      ? RenanceColors.darkTextSecondary
      : RenanceColors.secondary;
  Color get textMuted =>
      isDarkTier ? RenanceColors.darkMuted : RenanceColors.outline;

  // Outlines -----------------------------------------------------------
  Color get outline =>
      isDarkTier ? RenanceColors.darkTextSecondary : RenanceColors.outline;
  Color get outlineDark => isDarkTier
      ? RenanceColors.darkTextSecondary
      : RenanceColors.outlineDark;
  Color get outlineLight => isDarkTier
      ? RenanceColors.darkOutline
      : RenanceColors.outlineLight;
  Color get outlineVariant => isDarkTier
      ? RenanceColors.darkOutline
      : RenanceColors.outlineVariant;

  // Errors -------------------------------------------------------------
  Color get error =>
      isDarkTier ? RenanceColors.darkError : RenanceColors.error;
  Color get errorContainer => isDarkTier
      ? RenanceColors.darkErrorContainer
      : RenanceColors.errorContainer;
  Color get onErrorContainer => isDarkTier
      ? const Color(0xFFFFDAD6)
      : RenanceColors.onDarkErrorContainer;
}
