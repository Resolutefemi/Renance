/// Renance design system - the 3D FLAT / TACTILE (Duolingo-style) tokens.
///
/// 2026-10-18 parity pass: this is the Dart twin of the web's
/// `apps/web/app/globals.css` @theme block (commit 5d9d184a "3D Flat /
/// Tactile (Duolingo-style) restyle across the whole web app" and every
/// founder pass since). The stock tiers now mirror the website exactly:
///
///  * Light  - clean white faces (#ffffff), swan/polar neutral wells,
///             warm eel/wolf ink, VIVID green primary #10da11 (founder
///             2026-10-15: the old #58cc02 was "too light"), cardinal
///             errors, macaw blue accents, Nunito letterforms.
///  * Mixed  - light body, dark #111c2d hero chrome (exam player).
///  * Dark   - FIXED near-black canvas (#0f1216 page, #131720 cards -
///             founder 2026-10-15 evening: the seed repaints the accent,
///             never the dark canvas), same vivid green, black ink on
///             green CTAs (#0f240f).
///
/// Token names match the web one-to-one (treefrog, macaw, cardinal,
/// swan, polar, iguana...) so the two surfaces stay auditable against
/// each other. The type scale keeps the Renance sizes but rides Nunito,
/// the web's app typeface.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'seed_palette.dart';
import 'tactile_theme.dart';

export 'seed_palette.dart'
    show SeedPalette, kSeedPresets, hexToHsl, hslToHex, normalizeHex;

class RenanceColors {
  // -- Light tier (web :root / @theme) ----------------------------------
  // surfaces - clean high-contrast white/gray (Duolingo snow/polar/swan)
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFF0F0F3);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF7F7F7); // polar
  static const Color surfaceContainerHigh = Color(0xFFEBEBEF);
  static const Color surfaceContainerHighest = Color(0xFFE5E5E8);
  static const Color surfaceVariant = Color(0xFFEBEBEF);
  static const Color card = Color(0xFFFFFFFF);

  // on-colors / ink - warm neutral Duolingo eel/wolf
  static const Color ink = Color(0xFF3C3C46); // on-background / on-surface
  static const Color eel = Color(0xFF4B4B4B);
  static const Color textSecondary = Color(0xFF777777); // wolf
  static const Color secondaryContainer = Color(0xFFF1F1F4);
  static const Color secondary = Color(0xFF6F6F7A);

  // outlines - swan light borders, hare strong borders
  static const Color outline = Color(0xFFB0B0B8);
  static const Color outlineDark = Color(0xFFAFAFAF); // hare
  static const Color outlineLight = Color(0xFFE5E5E5); // swan
  static const Color outlineVariant = Color(0xFFE5E5E5);

  // errors - cardinal red
  static const Color error = Color(0xFFFF4B4B); // cardinal
  static const Color cardinalDark = Color(0xFFEA2B2B);
  static const Color errorContainer = Color(0xFFFFEBEB);

  // selection - the Supreme option-selected macaw wash
  static const Color selectionBlue = Color(0xFFDDF4FF); // macaw-light

  // -- Duolingo saturated accents (3D Flat / Tactile palette) ----------
  static const Color primary = Color(0xFF10DA11); // brand vivid green
  static const Color primaryDeep = Color(0xFF0F240F); // black ink on green
  static const Color treefrog = Color(0xFF58CC02);
  static const Color treefrogDark = Color(0xFF58A700);
  static const Color owl = Color(0xFF89E219);
  static const Color seafoam = Color(0xFF00CD9C);
  static const Color macaw = Color(0xFF1CB0F6);
  static const Color macawDark = Color(0xFF1899D6);
  static const Color macawLight = Color(0xFFDDF4FF);
  static const Color macawRing = Color(0xFF84D8FF);
  static const Color bee = Color(0xFFFFC800);
  static const Color beeDark = Color(0xFFE6AC00);
  static const Color fox = Color(0xFFFF9600);
  static const Color cardinal = Color(0xFFFF4B4B);
  static const Color beetle = Color(0xFFCE82FF);
  static const Color humpback = Color(0xFF2B70C9);
  static const Color wolf = Color(0xFF777777);
  static const Color hare = Color(0xFFAFAFAF);
  static const Color swan = Color(0xFFE5E5E5);
  static const Color polar = Color(0xFFF7F7F7);
  static const Color iguana = Color(0xFFD7FFB8);

  // Legacy accent names kept for the screens that still reference them,
  // re-tuned to the Duolingo family (seafoam success, fox warning).
  static const Color emerald = seafoam;
  static const Color amber = fox;

  // -- Dark tier (web [data-theme='dark'], the FIXED near-black canvas) -
  // Founder directive 2026-10-15 (evening): every dark surface is a fixed
  // near-black; the seed/primary repaints the ACCENT only.
  static const Color darkPage = Color(0xFF0F1216); // full-dark page ground
  static const Color darkSurface = Color(0xFF131720); // dark card / chrome
  static const Color darkSurfaceLow = Color(0xFF11151C); // wells / tracks
  static const Color darkCard = Color(0xFF131720); // elevated dark card
  static const Color darkCardHigh = Color(0xFF191F28);
  static const Color darkCardHighest = Color(0xFF1D242E);
  static const Color darkBright = Color(0xFF161B22);
  static const Color darkDim = Color(0xFF0A0D11);
  static const Color darkLowest = Color(0xFF0C0F14);
  static const Color darkContainer = Color(0xFF151A22);
  static const Color darkTextPrimary = Color(0xFFF0F3F6);
  static const Color darkTextSecondary = Color(0xFFA6ADBA);
  static const Color darkMuted = Color(0xFF8B93A3);
  static const Color darkOutline = Color(0xFF363D49);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color onDarkErrorContainer = Color(0xFFFFDAD6);
  static const Color darkHero = Color(0xFF131720);
  static const Color darkHeroTrack = Color(0xFF191F28);
  static const Color darkSelection = Color(0xFF1A212B);
  static const Color darkAccentInk = Color(0xFF242C38);
  static const Color darkInkDeep = Color(0xFF161C26);

  // Mixed tier hero chrome (light body, dark hero - exam player).
  static const Color mixedHero = Color(0xFF111C2D);
  static const Color mixedOnHero = Color(0xFFF0F3FF);
  static const Color mixedHeroMuted = Color(0xFFB9C2D4);
  static const Color mixedHeroTrack = Color(0xFF11151C);
}

/// Squircle radius scale, the web's moderated supreme.git notch
/// (globals.css --radius-sm..3xl). Cards land on 16, heroes on 20.
class RenanceRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 11;
  static const double xl = 14;
  static const double xxl = 16;
  static const double xxxl = 20;
  static const BorderRadius card = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(xxxl));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md + 2));
  static const BorderRadius button = BorderRadius.all(Radius.circular(xl - 2));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));
}

/// The full-dark ThemeData (Settings -> Appearance -> Dark).
/// [seed] re-tints the theme-level colors (buttons, fields, app bars)
/// to match the Chrome-style seed palette the screens resolve through
/// the context getters. The canvas stays the fixed near-black ramp.
ThemeData buildRenanceDarkTheme({SeedPalette? seed}) {
  const scheme = ColorScheme.dark(
    primary: RenanceColors.primary,
    onPrimary: RenanceColors.primaryDeep,
    primaryContainer: RenanceColors.darkContainer,
    onPrimaryContainer: RenanceColors.darkTextPrimary,
    secondary: RenanceColors.darkTextSecondary,
    onSecondary: RenanceColors.darkTextPrimary,
    secondaryContainer: RenanceColors.darkSurfaceLow,
    onSecondaryContainer: RenanceColors.darkTextPrimary,
    surface: RenanceColors.darkPage,
    onSurface: RenanceColors.darkTextPrimary,
    surfaceContainerHighest: RenanceColors.darkCardHigh,
    onSurfaceVariant: RenanceColors.darkTextSecondary,
    outline: RenanceColors.darkTextSecondary,
    outlineVariant: RenanceColors.darkOutline,
    error: RenanceColors.darkError,
    onError: Color(0xFF690005),
    errorContainer: RenanceColors.darkErrorContainer,
    onErrorContainer: Color(0xFFFFDAD6),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: seed?.primary ?? scheme.primary,
      onPrimary: seed?.onPrimary ?? scheme.onPrimary,
      secondaryContainer: seed?.secondaryContainer ?? scheme.secondaryContainer,
      outline: seed?.outline ?? scheme.outline,
      outlineVariant: seed?.outlineVariant ?? scheme.outlineVariant,
      surfaceContainerHighest: seed?.cardHigh ?? scheme.surfaceContainerHighest,
    ),
    scaffoldBackgroundColor: seed?.pageBg ?? RenanceColors.darkPage,
  );

  // Nunito carries the tactile UI on both tiers; the seed-aware text
  // colours keep working (founder 2026-10-02).
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: seed?.ink ?? RenanceColors.darkTextPrimary,
      displayColor: seed?.ink ?? RenanceColors.darkTextPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: seed?.pageBg ?? RenanceColors.darkPage,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      // Web PageBar parity (2026-10-19): 48px bar, 15px w800 title.
      toolbarHeight: 48,
      titleTextStyle: const TextStyle(
        color: RenanceColors.darkTextPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    // 22px standard glyph on the dark ramp (the web's icon size).
    iconTheme: const IconThemeData(
      size: 22,
      color: RenanceColors.darkTextPrimary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: seed?.card ?? RenanceColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: RenanceColors.darkOutline, width: 2),
      ),
      titleTextStyle: const TextStyle(
        color: RenanceColors.darkTextPrimary,
        fontFamily: 'Nunito',
        fontSize: 17,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      contentTextStyle: const TextStyle(
        color: RenanceColors.darkTextPrimary,
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.45,
      ),
    ),
    cardTheme: const CardThemeData(
      color: RenanceColors.darkCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      // The tactile card treatment: white (here near-black) face with a
      // 2px outline - the web's .glass recipe on the dark ramp.
      shape: RoundedRectangleBorder(
        borderRadius: RenanceRadius.card,
        side: BorderSide(color: RenanceColors.darkOutline, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: seed?.card ?? RenanceColors.darkSurfaceLow,
      hintStyle: const TextStyle(color: RenanceColors.darkTextSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: BorderSide.none,
      ),
      // Web parity: borderless wells, the 2px PRIMARY focus ring.
      enabledBorder: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: BorderSide(
            color: seed?.primary ?? RenanceColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: const BorderSide(color: RenanceColors.darkError, width: 2),
      ),
    ),
    // ---- GLOBAL TACTILE 3D ENFORCEMENT (dark tier) ----
    filledButtonTheme: FilledButtonThemeData(
      style: tactileFilledKeyStyle(
        face: seed?.primary ?? RenanceColors.primary,
        onFace: seed?.onPrimary ?? RenanceColors.primaryDeep,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: tactileFilledKeyStyle(
        face: seed?.primary ?? RenanceColors.primary,
        onFace: seed?.onPrimary ?? RenanceColors.primaryDeep,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: tactileWhiteKeyStyle(
        face: seed?.card ?? RenanceColors.darkCard,
        outline: seed?.outlineVariant ?? RenanceColors.darkOutline,
        ink: RenanceColors.darkTextPrimary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: tactileTextActionStyle(
        // The dark tier's --color-primary-ink: lifted toward the
        // iguana tint instead of black (founder 2026-10-14 text pass).
        ink: Color.lerp(seed?.primary ?? RenanceColors.primary,
                const Color(0xFFD7FFB8), 0.42) ??
            RenanceColors.darkTextPrimary,
        wash: const Color(0x12F0F3FF),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: tactileIconKeyStyle(
        ink: RenanceColors.darkTextPrimary,
        wash: const Color(0x12F0F3FF),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: RenanceColors.darkSurfaceLow,
      selectedColor: RenanceColors.darkCard,
      side: BorderSide(color: RenanceColors.darkOutline),
      shape: RoundedRectangleBorder(borderRadius: RenanceRadius.chip),
      labelStyle: TextStyle(
          fontFamily: 'Nunito',
          color: RenanceColors.darkTextPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: seed?.primary ?? RenanceColors.primary,
      contentTextStyle: TextStyle(color: seed?.onPrimary ?? RenanceColors.primaryDeep),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: RenanceRadius.button),
    ),
  );
}

// ---------------------------------------------------------------------------
// Renance type scale - the web sizes, now riding Nunito (the 3D tactile
// typeface). display-lg 28/36 -2% w800 · display-md 24/32 -1% w800 ·
// section-title 18/24 -1% w700 · stat-number 24/28 -2% w800 ·
// body-medium 15/22 w700 · body-base 15/22 w400 · caption 13/18 w400 ·
// label-mono 13/18 w500 (mono).
// ---------------------------------------------------------------------------

class RenanceText {
  static const String _fontFamily = 'Nunito';
  static const String _monoFamily = 'JetBrainsMono';

  static const TextStyle displayLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: -0.02 * 28,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle displayMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 32 / 24,
    letterSpacing: -0.01 * 24,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 24 / 18,
    letterSpacing: -0.01 * 18,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle statNumber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.02 * 24,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w700,
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
    fontWeight: FontWeight.w600,
  );
}

ThemeData buildRenanceTheme({SeedPalette? seed}) {
  final scheme = ColorScheme.light(
    primary: RenanceColors.primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF131B2E),
    onPrimaryContainer: const Color(0xFF7C839B),
    secondary: RenanceColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: RenanceColors.secondaryContainer,
    onSecondaryContainer: const Color(0xFF55555F),
    surface: RenanceColors.background,
    onSurface: RenanceColors.ink,
    surfaceContainerHighest: RenanceColors.surfaceContainerHigh,
    onSurfaceVariant: RenanceColors.textSecondary,
    outline: RenanceColors.outline,
    outlineVariant: RenanceColors.outlineVariant,
    error: RenanceColors.error,
    onError: Colors.white,
    errorContainer: RenanceColors.errorContainer,
    onErrorContainer: const Color(0xFFB81F1F),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: seed?.primary ?? scheme.primary,
      onPrimary: seed?.onPrimary ?? scheme.onPrimary,
      secondaryContainer: seed?.secondaryContainer ?? scheme.secondaryContainer,
      onSecondaryContainer: seed?.ink ?? scheme.onSecondaryContainer,
      outline: seed?.outlineDark ?? scheme.outline,
      outlineVariant: seed?.outlineVariant ?? scheme.outlineVariant,
      surfaceContainerHighest: seed?.cardHigh ?? scheme.surfaceContainerHighest,
    ),
    scaffoldBackgroundColor: seed?.pageBg ?? RenanceColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Nunito',
      // Founder directive (2026-10-02): seed-aware text colours - a live
      // seed re-tints every theme-styled text (the "Renance"
      // wordmark included) instead of staying stock ink.
      bodyColor: seed?.ink ?? RenanceColors.ink,
      displayColor: seed?.ink ?? RenanceColors.ink,
    ),
    // Web parity 2026-10-19: the app bar IS the web's PageBar - a
    // compact 48px bar with a 15px w800 tracking-tight title (the web's
    // `text-[15px] font-extrabold`), never the old 18px w700.
    appBarTheme: AppBarTheme(
      backgroundColor: seed?.pageBg ?? RenanceColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 48,
      titleTextStyle: TextStyle(
        color: seed?.ink ?? RenanceColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    // The web's standard icon: Material Symbols at 22px (globals.css
    // `.material-symbols-outlined { font-size: 24px }` overridden to
    // 22 on nav/page-bar/list surfaces). Stock Icon() widgets default
    // to 24 - the token drags them to the site's 22 without touching
    // every call site.
    iconTheme: IconThemeData(
      size: 22,
      color: seed?.ink ?? RenanceColors.ink,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: seed?.card ?? RenanceColors.card,
      surfaceTintColor: Colors.transparent,
      // The web's sheets: card face, 2px swan outline, 16px squircle.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: RenanceColors.swan, width: 2),
      ),
      titleTextStyle: TextStyle(
        color: seed?.ink ?? RenanceColors.ink,
        fontFamily: 'Nunito',
        fontSize: 17,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      contentTextStyle: TextStyle(
        color: seed?.ink ?? RenanceColors.ink,
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.45,
      ),
    ),
    cardTheme: const CardThemeData(
      color: RenanceColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      // The tactile card treatment (web .glass): white face, 2px swan
      // outline, hard 4px ledge via TactileCard where it matters.
      shape: RoundedRectangleBorder(
        borderRadius: RenanceRadius.card,
        side: BorderSide(color: RenanceColors.swan, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: seed?.card ?? RenanceColors.polar,
      hintStyle: const TextStyle(color: RenanceColors.hare),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: BorderSide.none,
      ),
      // The web's inputs (login/register): borderless
      // bg-surface-container-low wells; focus draws the 2px PRIMARY
      // ring (ring-primary - green on the default seed), never a rest
      // border, never macaw.
      enabledBorder: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: BorderSide(
            color: seed?.primary ?? RenanceColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: RenanceRadius.field,
        borderSide: const BorderSide(color: RenanceColors.cardinal, width: 2),
      ),
    ),
    // ---- GLOBAL TACTILE 3D ENFORCEMENT (founder 2026-10-19) ----
    // Every stock Material button renders as the web's physical key:
    // FilledButton/ElevatedButton = filled key (4px extruded edge,
    // 2px press sink), OutlinedButton = white key, TextButton = the
    // web's flat text action in the small-text primary ink,
    // IconButton = the site's 36px squircle press chip.
    filledButtonTheme: FilledButtonThemeData(
      style: tactileFilledKeyStyle(
        face: seed?.primary ?? RenanceColors.primary,
        onFace: seed?.onPrimary ?? Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: tactileFilledKeyStyle(
        face: seed?.primary ?? RenanceColors.primary,
        onFace: seed?.onPrimary ?? Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: tactileWhiteKeyStyle(
        face: seed?.card ?? RenanceColors.card,
        outline: seed?.outlineVariant ?? RenanceColors.swan,
        ink: seed?.ink ?? RenanceColors.ink,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: tactileTextActionStyle(
        // --color-primary-ink: the seed darkened 28% toward black so
        // small green labels stay readable on white cards.
        ink: Color.lerp(seed?.primary ?? RenanceColors.primary,
                Colors.black, 0.28) ??
            RenanceColors.primary,
        wash: RenanceColors.polar,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: tactileIconKeyStyle(
        ink: seed?.ink ?? RenanceColors.ink,
        wash: RenanceColors.polar,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: seed?.cardLow ?? RenanceColors.polar,
      selectedColor: seed?.selectionBlue ?? RenanceColors.selectionBlue,
      side: BorderSide(color: seed?.outlineVariant ?? RenanceColors.swan),
      shape: const RoundedRectangleBorder(borderRadius: RenanceRadius.chip),
      labelStyle: TextStyle(
          fontFamily: 'Nunito',
          color: seed?.ink ?? RenanceColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: seed?.accentInk ?? RenanceColors.ink,
      contentTextStyle: TextStyle(color: seed?.onPrimary ?? Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: RenanceRadius.button),
    ),
  );
}

/// The three Appearance options. Mixed = light surfaces with the dark
/// containers the player/results screens use (chrome-level dark, light
/// body) - exactly the web's [data-theme='mixed'].
enum RenanceThemeMode { light, mixed, dark }

/// Persists the Appearance choice + the Chrome-style seed colour and
/// exposes both to MaterialApp.
class ThemeController extends ChangeNotifier {
  ThemeController({required SharedPreferences prefs}) : _prefs = prefs {
    final raw = prefs.getString(_kKey);
    _mode = switch (raw) {
      'dark' => RenanceThemeMode.dark,
      'mixed' => RenanceThemeMode.mixed,
      _ => RenanceThemeMode.light,
    };
    _seed = prefs.getString(_kSeedKey);
  }

  static const _kKey = 'renance.theme';
  static const _kSeedKey = 'renance.seed';

  final SharedPreferences _prefs;
  RenanceThemeMode _mode = RenanceThemeMode.light;
  String? _seed;

  /// Exposed so Settings can persist its own preferences on the same
  /// SharedPreferences instance.
  SharedPreferences get prefs => _prefs;

  RenanceThemeMode get mode => _mode;

  /// The stored seed hex (null = the classic look).
  String? get seed => _seed;

  /// The palette for the CURRENT tier, or null when no seed is set.
  SeedPalette? get palette =>
      _seed == null ? null : SeedPalette.from(_seed!, _mode);

  /// The seed palette for any tier (settings preview / MaterialApp).
  SeedPalette? paletteFor(RenanceThemeMode mode) =>
      _seed == null ? null : SeedPalette.from(_seed!, mode);

  /// Chrome-appearance theming: set (or clear) the seed colour and
  /// re-tint every screen. Same localStorage key as the website so the
  /// choice reads identically on both surfaces.
  Future<void> setSeed(String? hex) async {
    final String? next = hex == null ? null : normalizeHex(hex);
    _seed = next;
    if (next == null) {
      await _prefs.remove(_kSeedKey);
    } else {
      await _prefs.setString(_kSeedKey, next);
    }
    notifyListeners();
  }

  /// One-time seed reset (founder directive 2026-10-19, the pixel-parity
  /// overhaul): clears any stored Chrome-style seed ONCE so the app
  /// opens on the website's default brand green, exactly like
  /// renance.app. The flag key makes it self-disarming - a fresh pick
  /// in Settings -> Appearance sticks forever afterwards.
  static const String _kSeedResetFlag = 'renance.seed.reset.v1';

  Future<void> migrateSeedToWebDefault() async {
    if (_prefs.getBool(_kSeedResetFlag) ?? false) return;
    await _prefs.setBool(_kSeedResetFlag, true);
    if (_seed != null) {
      _seed = null;
      await _prefs.remove(_kSeedKey);
      notifyListeners();
    }
  }

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

/// Exposes the active Appearance tier + the optional seed palette to
/// every screen so surfaces can resolve their colors per tier without
/// touching ThemeController.
class RenanceModeScope extends InheritedWidget {
  const RenanceModeScope({
    super.key,
    required this.mode,
    this.palette,
    required super.child,
  });

  final RenanceThemeMode mode;

  /// Non-null when a seed colour is live: every getter below resolves
  /// from here first, so one seed repaints the whole app (the web's
  /// CSS custom properties, translated to Flutter).
  final SeedPalette? palette;

  static RenanceModeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RenanceModeScope>();
  }

  static RenanceThemeMode of(BuildContext context) {
    return maybeOf(context)?.mode ?? RenanceThemeMode.light;
  }

  @override
  bool updateShouldNotify(RenanceModeScope oldWidget) =>
      oldWidget.mode != mode || oldWidget.palette != palette;
}

/// Theme-aware design tokens. Every screen resolves colors through
/// these getters so the Light, Mixed and Full-dark tiers all fall out
/// of the same markup - now mirroring the web's 3D tactile palette:
///
///  * Light  - white page, white cards, eel/wolf ink, green #10da11 CTA.
///  * Mixed  - light page, dark #111C2D hero chrome (the exam player
///             treatment), light cards everywhere else.
///  * Dark   - fixed near-black #0F1216 page, #131720 cards, #F0F3F6
///             text, green CTA with #0F240F ink.
extension RenanceScheme on BuildContext {
  RenanceThemeMode get renanceMode => RenanceModeScope.of(this);
  SeedPalette? get _pal => RenanceModeScope.maybeOf(this)?.palette;
  bool get isDarkTier => renanceMode == RenanceThemeMode.dark;
  bool get isMixedTier => renanceMode == RenanceThemeMode.mixed;

  /// Surfaces that carry the dark chrome in mixed AND full dark.
  bool get darkChrome => isDarkTier || isMixedTier;

  /// The student's colour when a seed is live: the vivid brand green in
  /// stock tiers (the web's bg-primary), on both light and dark.
  Color get primary => _pal?.primary ?? RenanceColors.primary;
  Color get onPrimary =>
      _pal?.onPrimary ??
      (isDarkTier ? RenanceColors.primaryDeep : Colors.white);

  // Page ground ------------------------------------------------------
  Color get pageBg => _pal?.pageBg ??
      (isDarkTier ? RenanceColors.darkPage : RenanceColors.background);

  // Cards --------------------------------------------------------------
  Color get card => _pal?.card ??
      (isDarkTier ? RenanceColors.darkCard : RenanceColors.card);
  Color get cardLowest => _pal?.cardLowest ?? (isDarkTier
      ? RenanceColors.darkLowest
      : RenanceColors.surfaceContainerLowest);
  Color get cardLow => _pal?.cardLow ?? (isDarkTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.surfaceContainerLow);
  Color get cardHigh => _pal?.cardHigh ?? (isDarkTier
      ? RenanceColors.darkCardHigh
      : RenanceColors.surfaceContainerHigh);
  Color get cardHighest => _pal?.cardHighest ?? (isDarkTier
      ? RenanceColors.darkCardHighest
      : RenanceColors.surfaceContainerHighest);
  Color get surfaceContainer => _pal?.surfaceContainer ?? (isDarkTier
      ? RenanceColors.darkContainer
      : RenanceColors.surfaceContainer);
  Color get surfaceVariant => _pal?.surfaceVariant ?? (isDarkTier
      ? RenanceColors.darkCardHigh
      : RenanceColors.surfaceVariant);
  Color get selectionBlue => _pal?.selectionBlue ?? (isDarkTier
      ? RenanceColors.darkSelection
      : RenanceColors.selectionBlue);
  Color get secondaryContainer => _pal?.secondaryContainer ?? (isDarkTier
      ? RenanceColors.darkSurfaceLow
      : RenanceColors.secondaryContainer);

  // Hero / chrome ------------------------------------------------------
  // The web's --color-hero: a WHITE band in light (the "dark cards
  // banned" pass), the #111C2D chrome in mixed, #131720 in full dark.
  Color get heroGround => _pal?.heroCard ?? (isDarkTier
      ? RenanceColors.darkHero
      : (isMixedTier ? RenanceColors.mixedHero : RenanceColors.background));
  Color get heroCard => _pal?.heroCard ?? (isDarkTier
      ? RenanceColors.darkCard
      : (isMixedTier ? RenanceColors.mixedHero : RenanceColors.card));
  Color get onHeroCard => _pal?.onHeroCard ?? (isDarkTier
      ? RenanceColors.darkTextPrimary
      : (isMixedTier ? RenanceColors.mixedOnHero : RenanceColors.ink));
  Color get heroMuted => _pal?.heroMuted ?? (isDarkTier
      ? RenanceColors.darkTextSecondary
      : (isMixedTier ? RenanceColors.mixedHeroMuted : RenanceColors.textSecondary));
  Color get heroTrack => _pal?.heroTrack ?? (isDarkTier
      ? RenanceColors.darkHeroTrack
      : (isMixedTier ? RenanceColors.mixedHeroTrack : RenanceColors.surfaceVariant));

  /// The hero progress fill / solid hero CTA - the web's bg-hero-cta:
  /// the vivid green (seed when live) with black ink in full dark.
  Color get heroCta => _pal?.heroCta ?? (isMixedTier
      ? RenanceColors.primary
      : RenanceColors.primary);
  Color get onHeroCta => _pal?.onHeroCta ?? (isDarkTier
      ? RenanceColors.primaryDeep
      : (isMixedTier ? Colors.white : Colors.white));

  // Ink / text ---------------------------------------------------------
  Color get ink => _pal?.ink ??
      (isDarkTier ? RenanceColors.darkTextPrimary : RenanceColors.ink);
  Color get textSecondary => _pal?.textSecondary ?? (isDarkTier
      ? RenanceColors.darkTextSecondary
      : RenanceColors.textSecondary);
  Color get secondary => _pal?.secondary ?? (isDarkTier
      ? RenanceColors.darkTextSecondary
      : RenanceColors.secondary);
  Color get textMuted => _pal?.textMuted ??
      (isDarkTier ? RenanceColors.darkMuted : RenanceColors.hare);

  // Outlines -----------------------------------------------------------
  Color get outline => _pal?.outline ??
      (isDarkTier ? RenanceColors.darkTextSecondary : RenanceColors.outline);
  Color get outlineDark => _pal?.outlineDark ?? (isDarkTier
      ? RenanceColors.darkTextSecondary
      : RenanceColors.outlineDark);
  Color get outlineLight => _pal?.outlineLight ?? (isDarkTier
      ? RenanceColors.darkOutline
      : RenanceColors.outlineLight);
  Color get outlineVariant => _pal?.outlineVariant ?? (isDarkTier
      ? RenanceColors.darkOutline
      : RenanceColors.outlineVariant);

  // Errors (never seeded - the palette keeps signals honest) -------------
  Color get error =>
      isDarkTier ? RenanceColors.darkError : RenanceColors.error;
  Color get errorContainer => isDarkTier
      ? RenanceColors.darkErrorContainer
      : RenanceColors.errorContainer;
  Color get onErrorContainer => isDarkTier
      ? const Color(0xFFFFDAD6)
      : const Color(0xFFB81F1F);

  // The "ink bubble" treatment (level bubbles, Lvl chips, solid CTAs,
  // the R tile and the Tutor tile): the web paints these bg-primary -
  // the vivid green (seed when live) - so a live seed lights them up
  // in the student's colour. Stock tiers keep the brand green; the
  // label ink is black-on-green in full dark (founder 2026-10-15).
  Color get inverseChip => _pal?.primary ?? RenanceColors.primary;
  Color get onInverseChip => _pal?.onPrimary ?? onPrimary;

  // --color-primary-ink, the web's small-text primary: darkened toward
  // black on the light tier (mix 72%), lifted toward the iguana tint on
  // the dark tier (mix 58%) so green labels stay readable on #131720.
  Color get primaryInk => isDarkTier
      ? Color.lerp(primary, const Color(0xFFD7FFB8), 0.42) ?? primary
      : Color.fromARGB(
          (primary.a * 255.0).round().clamp(0, 255),
          ((primary.r * 255.0) * 0.72).round().clamp(0, 255),
          ((primary.g * 255.0) * 0.72).round().clamp(0, 255),
          ((primary.b * 255.0) * 0.72).round().clamp(0, 255),
        );
}
