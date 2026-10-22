/// The launcher-icon appearance switch (founder pass IX): the app icon
/// adapts to the appearance setting EXACTLY like the website favicon.
/// Two launcher activity-aliases ship in the AndroidManifest -
/// .LauncherLight (brand green ground) and .LauncherDark (the dark-page
/// navy ground) - and this helper flips the live one through the
/// native 'renance/appIcon' channel. Dark mode -> dark icon; Light and
/// Mixed keep the light icon (Mixed is a light scaffold by design).
/// Everything is best-effort: pre-Android, an engine that is not up yet
/// or a rejected call simply leaves the current icon in place.
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
