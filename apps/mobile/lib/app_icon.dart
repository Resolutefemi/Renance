/// The launcher-icon appearance switch (founder pass IX, RETIRED
/// 2026-10-23 after the "Renance keeps stopping" crash loop): the
/// alias/PackageManager mechanism is gone from the manifest and the
/// native side answers without mutating anything. This helper stays so
/// existing callers (Appearance picker) keep compiling and hitting a
/// harmless no-op. The standard adaptive icon serves both tiers.
library;

import 'dart:io';

import 'package:flutter/services.dart';

import 'ui/theme.dart';

class RenanceAppIcon {
  RenanceAppIcon._();

  static const MethodChannel _channel = MethodChannel('renance/appIcon');

  /// Applies the launcher variant for [mode]. Safe to call anywhere,
  /// any number of times - a no-op off Android or when the variant is
  /// already live (the native side answers and the launcher refreshes
  /// on its own schedule).
  static Future<void> apply(RenanceThemeMode mode) async {
    if (!Platform.isAndroid) return;
    final String variant = mode == RenanceThemeMode.dark ? 'dark' : 'light';
    try {
      await _channel.invokeMethod<bool>(
        'setVariant',
        <String, String>{'variant': variant},
      );
    } catch (_) {
      // Sugar, never a gate - the icon stays whatever it was.
    }
  }
}
