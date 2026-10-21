/// The first-signup/first-login Appearance popup (founder directive,
/// 2026-09-28, restored 2026-10-02): "when student first signup on the
/// app or website display change appearance pop up that will change the
/// seed colour".
///
/// One sheet, shown once per ACCOUNT (the flag stores the account id it
/// already greeted, next to the theme keys in SharedPreferences - the
/// per-device bool it used to be suppressed fresh signups forever on
/// any device that had already met the picker, manual or Google): the
/// ten Seed Color presets - the same palette the Settings screen
/// drives, so a seed picked here re-tints EVERY screen immediately
/// (seed_palette.dart maths). COLOURS-ONLY by web parity (2026-10-13
/// founder pass: "the first-signup popup is colours-only now" - the
/// Light/Dark mode control lives in Settings after login).
///
/// Fired from the verified-email unlock, the first Google sign-in, and
/// the first login on a device that has never greeted that account - so
/// students who signed up while the popup was retired (2.6.4-2.6.7)
/// still meet the picker once.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage.dart' show SessionStore;
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

const String kAppearanceAskedKey = 'renance.appearanceAsked';

/// Shows the appearance sheet the first time [context]'s student signs
/// up or logs in on this device, then never again for THAT account.
/// Call right after session.save, BEFORE routing on.
Future<void> maybeShowFirstAppearanceSheet(BuildContext context) async {
  final SharedPreferences prefs = context.read<ThemeController>().prefs;
  // Per-ACCOUNT flag (founder bug 2026-10-05: "the appearance settings
  // pop up didn't show after i verify my email" + "make sure the
  // appearance pop up too even when a user sign up with google"): the
  // key used to hold a bare device bool, so any device that had met the
  // picker once (earlier builds popped it at register time) suppressed
  // it for EVERY later signup - manual or Google - and a fresh student
  // verified their email to silence instead of the picker. The picker
  // is a per-student moment: the key now stores the account id it
  // already greeted, so a NEW account (the 6-digit-code signup or a
  // first-time Google upsert) gets its own popup, while the same
  // account never sees it twice on this device. The legacy bool value
  // is deliberately ignored - it suppressed fresh signups for good.
  final String uid = context.read<SessionStore>().user?.id ?? '';
  final Object? askedRaw = prefs.get(kAppearanceAskedKey);
  final String? askedFor = askedRaw is String ? askedRaw : null;
  if (uid.isNotEmpty && askedFor == uid) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AppearanceSheet(),
  );
  // The one-time flag is consumed only AFTER the sheet has actually been
  // seen (founder directive 2026-10-03, "make sure it pops up for new
  // users"): if the app is killed while the sheet is open, the picker
  // fires again on the next launch - a new user can never silently miss
  // it because the flag was set too early.
  if (uid.isNotEmpty) {
    await prefs.setString(kAppearanceAskedKey, uid);
  }
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
                  MsIcon('palette',
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
                'Pick your colour - you can change it anytime in Settings.',
                style: RenanceText.bodySecondary
                    .copyWith(color: palette.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Seed presets ---------------------------------------------
              // The DEFAULT swatch leads the list (founder directive
              // 2026-10-05: "among the colour appearance pop up, add the
              // default colour to the colour list") - the classic ink &
              // paper look, tapping it clears the seed entirely.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _DefaultSeedDot(
                    selected: _seed == null,
                    onTap: () {
                      setState(() => _seed = null);
                      theme.setSeed(null);
                    },
                  ),
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
              const SizedBox(height: 16),

              TactileButton(
                onPressed: () => Navigator.of(context).pop(),
                height: 48,
                radius: BorderRadius.circular(12),
                face: palette.primary,
                onFace: palette.onPrimary,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    MsIcon('check', size: 18),
                    SizedBox(width: 8),
                    Text('Looks good'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The classic ink-and-paper swatch that leads the colour list (the
/// same cut the Settings picker drives): half black, half white, ringed
/// when it is the live choice. Tapping it clears the seed entirely.
class _DefaultSeedDot extends StatelessWidget {
  const _DefaultSeedDot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Renance default (ink and paper)',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: const ClipOval(
            child: SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[Colors.black, Colors.white],
                    stops: <double>[0.5, 0.5],
                  ),
                ),
              ),
            ),
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
              ? const MsIcon('check', size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
