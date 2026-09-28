/// The first-signup Appearance popup (founder directive, 2026-09-28):
/// "when student first signup on the app or website display change
/// appearance pop up that will change the seed colour".
///
/// One sheet, shown exactly once per device (the flag lives in
/// SharedPreferences next to the theme keys): the Chrome-style Mode
/// switch (Light / Mixed / Dark) and the ten Seed Color presets - the
/// same palette the Settings screen drives, so a seed picked here
/// re-tints EVERY screen immediately (seed_palette.dart maths).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

const String kAppearanceAskedKey = 'renance.appearanceAsked';

/// Shows the appearance sheet the first time [context]'s student signs
/// up (manual or Google), then never again. Call right after
/// session.save in the signup flows, BEFORE routing on.
Future<void> maybeShowFirstAppearanceSheet(BuildContext context) async {
  final SharedPreferences prefs =
      context.read<ThemeController>().prefs;
  if (prefs.getBool(kAppearanceAskedKey) ?? false) return;
  await prefs.setBool(kAppearanceAskedKey, true);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AppearanceSheet(),
  );
}

class AppearanceSheet extends StatefulWidget {
  const AppearanceSheet({super.key});

  @override
  State<AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<AppearanceSheet> {
  late RenanceThemeMode _mode;
  String? _seed;

  @override
  void initState() {
    super.initState();
    final ThemeController theme = context.read<ThemeController>();
    _mode = theme.mode;
    _seed = theme.seed;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.read<ThemeController>();
    // The sheet previews through the LIVE theme controller: a tap
    // re-tints the whole app behind the sheet, exactly like Chrome.
    final SeedPalette palette = SeedPalette.from(
      _seed ?? '#13dc1b',
      _mode,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.outlineLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.palette_outlined,
                      size: 22, color: palette.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Make Renance yours',
                      style: RenanceText.sectionTitle
                          .copyWith(color: palette.ink, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pick an appearance - you can change it anytime in Settings.',
                style: RenanceText.bodySecondary
                    .copyWith(color: palette.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Mode -----------------------------------------------------
              SegmentedButton<RenanceThemeMode>(
                segments: const <ButtonSegment<RenanceThemeMode>>[
                  ButtonSegment<RenanceThemeMode>(
                      value: RenanceThemeMode.light, label: Text('Light')),
                  ButtonSegment<RenanceThemeMode>(
                      value: RenanceThemeMode.mixed, label: Text('Mixed')),
                  ButtonSegment<RenanceThemeMode>(
                      value: RenanceThemeMode.dark, label: Text('Dark')),
                ],
                selected: <RenanceThemeMode>{_mode},
                onSelectionChanged: (Set<RenanceThemeMode> s) {
                  setState(() => _mode = s.first);
                  theme.setMode(_mode);
                },
              ),
              const SizedBox(height: 16),

              // Seed presets ---------------------------------------------
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final ({String hex, String name}) p in kSeedPresets)
                    _SeedDot(
                      hex: p.hex,
                      name: p.name,
                      selected:
                          _seed != null && _seed!.toLowerCase() == p.hex,
                      onTap: () {
                        setState(() => _seed = p.hex);
                        theme.setSeed(p.hex);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Default (no seed) option ---------------------------------
              TextButton.icon(
                onPressed: () {
                  setState(() => _seed = null);
                  theme.setSeed(null);
                },
                icon: Icon(
                  _seed == null ? Icons.check : Icons.radio_button_unchecked,
                  size: 16,
                  color: palette.primary,
                ),
                label: const Text('Keep the classic ink & paper look'),
              ),
              const SizedBox(height: 10),

              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Looks good'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeedDot extends StatelessWidget {
  const _SeedDot({
    required this.hex,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(int.parse(hex.replaceFirst('#', '0xff')));
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: selected ? 10 : 4,
                spreadRadius: selected ? 2 : 0,
              ),
            ],
          ),
          child: selected
              ? const Icon(Icons.check, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
