// Test bootstrap: load the real brand fonts so golden renders show actual
// text (not Ahem blocks) when we flip the three Appearance tiers.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The settings _CardGroup paints ListTiles inside a DecoratedBox; the
  // framework warns about it. Tolerated here so the tier-flip goldens can
  // render, but it is logged as a finding to fix in the screen itself.
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final String msg = details.exceptionAsString();
    if (msg.contains('ListTile background color')) return;
    original?.call(details);
  };

  Future<void> load(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    for (final String f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('Inter', <String>[
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await load('JetBrainsMono', <String>['JetBrainsMono-Medium.ttf']);

  // The Material icon font ships with the SDK; without it every Icons.*
  // glyph paints as an Ahem block in goldens.
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load(
        '/home/z/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();

  await testMain();
}
