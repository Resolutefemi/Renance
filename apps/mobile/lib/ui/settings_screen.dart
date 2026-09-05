/// Settings, the Stitch settings_light screen, 1:1.
///
/// Appearance: the Light / Mixed / Dark segmented control with the sliding
/// selection pill, wired to ThemeController (real theme switching).
/// Learning: daily goal + study reminder preference (persisted locally).
/// Data & Offline: the real on-device pack meter + clear-offline action.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers.dart';
import '../storage.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _reminders = true;
  int _dailyGoal = 25;
  int _packBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final SharedPreferences prefs = context.read<ThemeController>().prefs;
    final PackStore store = context.read<PackStore>();
    final sizes = await store.packSizes();
    if (!mounted) return;
    setState(() {
      _reminders = prefs.getBool('renance.reminders') ?? true;
      _dailyGoal = prefs.getInt('renance.dailyGoal') ?? 25;
      _packBytes = sizes.values.fold(0, (int a, int b) => a + b);
    });
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text('Settings', style: RenanceText.sectionTitle),
        backgroundColor: context.pageBg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: <Widget>[
          // Appearance -----------------------------------------------------
          Text('APPEARANCE', style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          _AppearanceSwitch(mode: theme.mode, onPick: theme.setMode),
          // Learning -------------------------------------------------------
          const SizedBox(height: 24),
          Text('LEARNING', style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          _CardGroup(children: <Widget>[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: context.selectionBlue,
                child: Icon(Icons.flag,
                    size: 18, color: context.ink),
              ),
              title: const Text('Daily Goal', style: RenanceText.bodyBase),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('$_dailyGoal mins',
                      style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
                  Icon(Icons.chevron_right,
                      color: context.outlineLight),
                ],
              ),
              onTap: () async {
                final ThemeController theme = context.read<ThemeController>();
                final int? picked = await showDialog<int>(
                  context: context,
                  builder: (BuildContext ctx) => SimpleDialog(
                    title: const Text('Daily Goal'),
                    children: <int>[15, 25, 40, 60]
                        .map((int m) => SimpleDialogOption(
                              onPressed: () => Navigator.of(ctx).pop(m),
                              child: Text('$m mins',
                                  style: RenanceText.bodyBase),
                            ))
                        .toList(),
                  ),
                );
                if (picked != null) {
                  await theme.prefs.setInt('renance.dailyGoal', picked);
                  if (!mounted) return;
                  setState(() => _dailyGoal = picked);
                }
              },
            ),
            SwitchListTile(
              secondary: CircleAvatar(
                radius: 16,
                backgroundColor: context.secondaryContainer,
                child: Icon(Icons.notifications_active,
                    size: 18, color: context.ink),
              ),
              title: const Text('Study Reminders', style: RenanceText.bodyBase),
              subtitle: Text(
                _reminders ? 'Daily at 8:00 PM' : 'Off',
                style: RenanceText.caption.copyWith(color: context.textSecondary),
              ),
              value: _reminders,
              activeThumbColor: Colors.black,
              onChanged: (bool v) async {
                final ThemeController theme = context.read<ThemeController>();
                await theme.prefs.setBool('renance.reminders', v);
                if (!mounted) return;
                setState(() => _reminders = v);
              },
            ),
          ]),
          // Data & Offline -------------------------------------------------
          const SizedBox(height: 24),
          Text('DATA & OFFLINE', style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          _CardGroup(children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Offline packs',
                          style: RenanceText.bodyBase),
                      Text(_fmtBytes(_packBytes),
                          style:
                              RenanceText.labelMono.copyWith(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _packBytes == 0 ? 0 : 0.12,
                      minHeight: 8,
                      backgroundColor: context.surfaceContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          RenanceColors.emerald),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Packs live on this device so you can practice with '
                    'zero network. Clearing them frees space; they '
                    're-download on the next sync.',
                    style: RenanceText.caption.copyWith(color: context.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: context.errorContainer,
                child: Icon(Icons.delete_outline,
                    size: 18, color: context.error),
              ),
              title: const Text('Clear offline packs',
                  style: RenanceText.bodyBase),
              onTap: () async {
                final PackStore store = context.read<PackStore>();
                final StudentController student =
                    context.read<StudentController>();
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: const Text('Clear offline packs?'),
                    content: const Text(
                        'Every downloaded pack is removed from this device. '
                        'They re-download automatically on your next sync.'),
                    actions: <Widget>[
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Keep')),
                      FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) {
                  await store.clearPacks();
                  await student.refreshDownloaded();
                  if (!mounted) return;
                  setState(() => _packBytes = 0);
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Offline packs cleared.')));
                }
              },
            ),
          ]),
          // About ----------------------------------------------------------
          const SizedBox(height: 24),
          Text('ABOUT', style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          _CardGroup(children: <Widget>[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Version', style: RenanceText.bodyBase),
              trailing: Text('1.1.0 (Stitch)',
                  style: RenanceText.labelMono.copyWith(fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }
}

/// The Light / Mixed / Dark segmented control with the sliding blue pill.
class _AppearanceSwitch extends StatelessWidget {
  const _AppearanceSwitch({required this.mode, required this.onPick});

  final RenanceThemeMode mode;
  final ValueChanged<RenanceThemeMode> onPick;

  @override
  Widget build(BuildContext context) {
    const List<(RenanceThemeMode, IconData, String)> options = <(
      RenanceThemeMode,
      IconData,
      String
    )>[
      (RenanceThemeMode.light, Icons.light_mode, 'Light'),
      (RenanceThemeMode.mixed, Icons.contrast, 'Mixed'),
      (RenanceThemeMode.dark, Icons.dark_mode, 'Dark'),
    ];
    final int index =
        options.indexWhere(((RenanceThemeMode, IconData, String) o) => o.$1 == mode);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        return Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x0F141C2D),
                  blurRadius: 3,
                  offset: Offset(0, 1)),
            ],
          ),
          child: Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                left: 4 + index * ((w - 8) / 3),
                top: 4,
                bottom: 4,
                width: (w - 8) / 3 - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.selectionBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Row(
                children: options
                    .map(
                      ((RenanceThemeMode, IconData, String) o) => Expanded(
                        child: InkWell(
                          onTap: () => onPick(o.$1),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                o.$2,
                                size: 20,
                                color: o.$1 == mode
                                    ? context.ink
                                    : context.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                o.$3,
                                style: RenanceText.bodyMedium.copyWith(
                                  color: o.$1 == mode
                                      ? context.ink
                                      : context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // The shadow lives on the outer Container; the group color belongs on
    // a Material so the ListTiles inside paint (and ink) on a Material
    // surface instead of tripping the DecoratedBox-background assert.
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Color(0x0F141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Material(
        color: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                Container(height: 1, color: context.surfaceContainer),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
