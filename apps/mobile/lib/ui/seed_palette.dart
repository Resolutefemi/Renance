/// Renance seed-colour engine — the Dart port of the web's
/// `apps/web/lib/theme.ts`.
///
/// The founder's Chrome-appearance theming: one seed colour expands into
/// the full token palette (surfaces, containers, ink, primaries, outlines,
/// hero chrome) for each appearance tier — Light, Mixed, Dark — and every
/// screen re-tints because they all resolve colours through the
/// `RenanceScheme` context getters in theme.dart. The maths below is a
/// 1:1 translation of the web implementation so a seed picked on the
/// website looks identical inside the app.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// hex (#rgb / #rrggbb) → HSL (h 0-360, s 0-100, l 0-100).
/// Unparseable input falls back to the Renance green, same as the web.
({double h, double s, double l}) hexToHsl(String hex) {
  final RegExpMatch? m =
      RegExp(r'^#?([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false)
          .firstMatch(hex.trim());
  if (m == null) return (h: 145.0, s: 78.0, l: 48.0);
  String body = m.group(1)!;
  if (body.length == 3) {
    body = body.split('').map((c) => c + c).join();
  }
  final double r = int.parse(body.substring(0, 2), radix: 16) / 255;
  final double g = int.parse(body.substring(2, 4), radix: 16) / 255;
  final double b = int.parse(body.substring(4, 6), radix: 16) / 255;
  final double max = math.max(r, math.max(g, b));
  final double min = math.min(r, math.min(g, b));
  final double l = (max + min) / 2;
  if (max == min) return (h: 0.0, s: 0.0, l: l * 100);
  final double d = max - min;
  final double s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  double h;
  if (max == r) {
    h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  } else if (max == g) {
    h = ((b - r) / d + 2) / 6;
  } else {
    h = ((r - g) / d + 4) / 6;
  }
  return (h: h * 360, s: s * 100, l: l * 100);
}

/// HSL (h 0-360, s/l 0-100 clamped) → #rrggbb.
String hslToHex(double h, double s, double l) {
  h = ((h % 360) + 360) % 360;
  s = math.min(100, math.max(0, s)) / 100;
  l = math.min(100, math.max(0, l)) / 100;
  final double c = (1 - (2 * l - 1).abs()) * s;
  final double x = c * (1 - ((h / 60) % 2 - 1).abs());
  final double m = l - c / 2;
  double r = 0, g = 0, b = 0;
  if (h < 60) {
    r = c; g = x;
  } else if (h < 120) {
    r = x; g = c;
  } else if (h < 180) {
    g = c; b = x;
  } else if (h < 240) {
    g = x; b = c;
  } else if (h < 300) {
    r = x; b = c;
  } else {
    r = c; b = x;
  }
  String to(double v) =>
      ((v + m) * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${to(r)}${to(g)}${to(b)}';
}

/// Normalises #abc → #aabbcc (lowercase), null when invalid.
String? normalizeHex(String hex) {
  final RegExpMatch? m =
      RegExp(r'^#?([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false)
          .firstMatch(hex.trim());
  if (m == null) return null;
  String body = m.group(1)!.toLowerCase();
  if (body.length == 3) {
    body = body.split('').map((c) => c + c).join();
  }
  return '#$body';
}

/// WCAG-ish relative luminance (0 black → 1 white).
double luminance(String hex) {
  final String body = hex.replaceFirst('#', '');
  double ch(int i) {
    final double v = int.parse(body.substring(i, i + 2), radix: 16) / 255;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(0) + 0.7152 * ch(1) + 0.0722 * ch(2);
}

Color _c(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));

double _l0(String hex) => hexToHsl(hex).l;

/// The seed palette for one appearance tier. Fields mirror the context
/// getters 1:1; `null` fields fall back to the stock Stitch tokens.
@immutable
class SeedPalette {
  const SeedPalette({
    required this.pageBg,
    required this.card,
    required this.cardLowest,
    required this.cardLow,
    required this.cardHigh,
    required this.cardHighest,
    required this.surfaceContainer,
    required this.surfaceVariant,
    required this.selectionBlue,
    required this.secondaryContainer,
    required this.ink,
    required this.textSecondary,
    required this.secondary,
    required this.textMuted,
    required this.outline,
    required this.outlineDark,
    required this.outlineLight,
    required this.outlineVariant,
    required this.accentInk,
    required this.inkDeep,
    required this.heroCard,
    required this.onHeroCard,
    required this.heroMuted,
    required this.heroTrack,
    required this.heroCta,
    required this.onHeroCta,
    required this.primary,
    required this.onPrimary,
    required this.progressFill,
  });

  final Color pageBg;
  final Color card;
  final Color cardLowest;
  final Color cardLow;
  final Color cardHigh;
  final Color cardHighest;
  final Color surfaceContainer;
  final Color surfaceVariant;
  final Color selectionBlue;
  final Color secondaryContainer;
  final Color ink;
  final Color textSecondary;
  final Color secondary;
  final Color textMuted;
  final Color outline;
  final Color outlineDark;
  final Color outlineLight;
  final Color outlineVariant;
  final Color accentInk;
  final Color inkDeep;
  final Color heroCard;
  final Color onHeroCard;
  final Color heroMuted;
  final Color heroTrack;
  final Color heroCta;
  final Color onHeroCta;
  final Color primary;
  final Color onPrimary;

  /// The hero/syllabus progress fill — heroCta where the web paints
  /// bg-hero-cta, else the readable inverse of the hero card.
  final Color progressFill;

  /// Expand one seed into the tier's palette — the Dart twin of
  /// buildPalette() in apps/web/lib/theme.ts.
  factory SeedPalette.from(String seedHex, RenanceThemeMode mode) {
    final ({double h, double s, double l}) hsl = hexToHsl(seedHex);
    final double hue = hsl.h.roundToDouble();
    final double sat = math.max(30, math.min(100, hsl.s));

    if (mode == RenanceThemeMode.dark) {
      final String primaryHex =
          hslToHex(hue, sat, math.min(76, math.max(58, _l0(seedHex))));
      final Color primary = _c(primaryHex);
      final Color onPrimary = luminance(primaryHex) > 0.42
          ? _c(hslToHex(hue, 42, 10))
          : _c('#0b1120');
      return SeedPalette(
        pageBg: _c(hslToHex(hue, 34, 9)),
        card: _c(hslToHex(hue, 30, 14)),
        cardLowest: _c(hslToHex(hue, 30, 11)),
        cardLow: _c(hslToHex(hue, 30, 10)),
        cardHigh: _c(hslToHex(hue, 28, 17)),
        cardHighest: _c(hslToHex(hue, 28, 20)),
        surfaceContainer: _c(hslToHex(hue, 28, 14)),
        surfaceVariant: _c(hslToHex(hue, 28, 17)),
        selectionBlue: _c(hslToHex(hue, 30, 19)),
        secondaryContainer: _c(hslToHex(hue, 24, 15)),
        ink: _c(hslToHex(hue, 60, 96)),
        textSecondary: _c(hslToHex(hue, 14, 72)),
        secondary: _c(hslToHex(hue, 14, 72)),
        textMuted: _c(hslToHex(hue, 14, 72)),
        outline: _c(hslToHex(hue, 14, 66)),
        outlineDark: _c(hslToHex(hue, 14, 66)),
        outlineLight: _c(hslToHex(hue, 20, 28)),
        outlineVariant: _c(hslToHex(hue, 20, 28)),
        accentInk: _c(hslToHex(hue, 34, 17)),
        inkDeep: _c(hslToHex(hue, 32, 12)),
        heroCard: _c(hslToHex(hue, 30, 14)),
        onHeroCard: _c(hslToHex(hue, 60, 96)),
        heroMuted: _c(hslToHex(hue, 14, 72)),
        heroTrack: _c(hslToHex(hue, 28, 17)),
        heroCta: primary,
        onHeroCta: onPrimary,
        primary: primary,
        onPrimary: onPrimary,
        progressFill: primary,
      );
    }

    // Light body (also the base of Mixed): the seed tints the neutrals
    // and drives the primary actions — the "black" becomes the colour.
    final String primaryHex = hslToHex(
      hue,
      sat,
      math.min(46, math.max(30, _l0(seedHex) > 55 ? 38 : _l0(seedHex) * 0.72)),
    );
    final Color primary = _c(primaryHex);
    final Color onPrimary =
        luminance(primaryHex) > 0.5 ? _c(hslToHex(hue, 42, 12)) : Colors.white;
    final Color onSurface = _c(hslToHex(hue, 40, 12));

    if (mode == RenanceThemeMode.mixed) {
      final String heroCtaHex =
          hslToHex(hue, sat, math.min(76, math.max(58, _l0(seedHex))));
      final Color heroCta = _c(heroCtaHex);
      final Color onHeroCta = luminance(heroCtaHex) > 0.42
          ? _c(hslToHex(hue, 42, 10))
          : _c('#0b1120');
      final Color onHero = _c(hslToHex(hue, 60, 96));
      return SeedPalette(
        pageBg: _c(hslToHex(hue, 46, 98)),
        card: Colors.white,
        cardLowest: Colors.white,
        cardLow: _c(hslToHex(hue, 50, 96.5)),
        cardHigh: _c(hslToHex(hue, 46, 91)),
        cardHighest: _c(hslToHex(hue, 44, 89)),
        surfaceContainer: _c(hslToHex(hue, 48, 93.5)),
        surfaceVariant: _c(hslToHex(hue, 44, 89)),
        selectionBlue: _c(hslToHex(hue, 48, 91)),
        secondaryContainer: _c(hslToHex(hue, 42, 91)),
        ink: onSurface,
        textSecondary: _c(hslToHex(hue, 12, 30)),
        secondary: _c(hslToHex(hue, 18, 40)),
        textMuted: _c(hslToHex(hue, 12, 30)),
        outline: _c(hslToHex(hue, 6, 46)),
        outlineDark: _c(hslToHex(hue, 6, 46)),
        outlineLight: _c(hslToHex(hue, 12, 79)),
        outlineVariant: _c(hslToHex(hue, 12, 79)),
        accentInk: _c(hslToHex(hue, 40, 13)),
        inkDeep: _c(hslToHex(hue, 38, 12)),
        heroCard: _c(hslToHex(hue, 40, 12)),
        onHeroCard: onHero,
        heroMuted: _c(hslToHex(hue, 20, 72)),
        heroTrack: _c(hslToHex(hue, 30, 16)),
        heroCta: heroCta,
        onHeroCta: onHeroCta,
        primary: primary,
        onPrimary: onPrimary,
        progressFill: onHero,
      );
    }

    // Plain light: white band, seed CTA (the old black button).
    return SeedPalette(
      pageBg: _c(hslToHex(hue, 46, 98)),
      card: Colors.white,
      cardLowest: Colors.white,
      cardLow: _c(hslToHex(hue, 50, 96.5)),
      cardHigh: _c(hslToHex(hue, 46, 91)),
      cardHighest: _c(hslToHex(hue, 44, 89)),
      surfaceContainer: _c(hslToHex(hue, 48, 93.5)),
      surfaceVariant: _c(hslToHex(hue, 44, 89)),
      selectionBlue: _c(hslToHex(hue, 48, 91)),
      secondaryContainer: _c(hslToHex(hue, 42, 91)),
      ink: onSurface,
      textSecondary: _c(hslToHex(hue, 12, 30)),
      secondary: _c(hslToHex(hue, 18, 40)),
      textMuted: _c(hslToHex(hue, 12, 30)),
      outline: _c(hslToHex(hue, 6, 46)),
      outlineDark: _c(hslToHex(hue, 6, 46)),
      outlineLight: _c(hslToHex(hue, 12, 79)),
      outlineVariant: _c(hslToHex(hue, 12, 79)),
      accentInk: _c(hslToHex(hue, 40, 13)),
      inkDeep: _c(hslToHex(hue, 38, 12)),
      heroCard: Colors.white,
      onHeroCard: onSurface,
      heroMuted: _c(hslToHex(hue, 12, 30)),
      heroTrack: _c(hslToHex(hue, 44, 89)),
      heroCta: primary,
      onHeroCta: onPrimary,
      primary: primary,
      onPrimary: onPrimary,
      progressFill: primary,
    );
  }
}

/// The ten preset swatches, 1:1 with the web's SEED_PRESETS.
const List<({String hex, String name})> kSeedPresets = <({
  String hex,
  String name
})>[
  (hex: '#13dc1b', name: 'Renance Green'),
  (hex: '#1a73e8', name: 'Chrome Blue'),
  (hex: '#8b5cf6', name: 'Violet'),
  (hex: '#10b981', name: 'Emerald'),
  (hex: '#f59e0b', name: 'Amber'),
  (hex: '#f43f5e', name: 'Rose'),
  (hex: '#06b6d4', name: 'Cyan'),
  (hex: '#f97316', name: 'Orange'),
  (hex: '#6366f1', name: 'Indigo'),
  (hex: '#ec4899', name: 'Pink'),
];
