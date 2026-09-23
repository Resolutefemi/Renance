/// Settings, the Stitch settings screen with the founder's Appearance
/// control fully functional - Mode (Light / Mixed / Dark) plus the
/// Chrome-style Seed Colour picker that re-tints every ink surface in
/// the product (seed_palette.dart, the Dart twin of the web's
/// lib/theme.ts). Learning: daily goal + study reminder preference.
/// Data & Offline: the real on-device pack meter + clear-offline action.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _seedOpen = false;
  int _dailyGoal = 25;
  int _packBytes = 0;
  String? _seed;
  String _hexDraft = '#13dc1b';

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
      _seed = context.read<ThemeController>().seed;
      _hexDraft = _seed ?? '#13dc1b';
    });
  }

  void _applySeed(String? hex) {
    final String? next = hex == null ? null : normalizeHex(hex);
    context.read<ThemeController>().setSeed(next);
    if (!mounted) return;
    setState(() {
      _seed = next;
      if (next != null) _hexDraft = next;
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
    final ({double h, double s, double l}) hsl =
        hexToHsl(_seed ?? '#13dc1b');

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
          // Seed Color (the Chrome-appearance theming) ----------------------
          const SizedBox(height: 12),
          _SeedPanel(
            open: _seedOpen,
            onToggle: () => setState(() => _seedOpen = !_seedOpen),
            seed: _seed,
            hsl: hsl,
            hexDraft: _hexDraft,
            onHexDraft: (v) => setState(() => _hexDraft = v),
            onApply: _applySeed,
          ),
          if (_seed != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Seed ${_seed!.toUpperCase()} is live: buttons, tiles, headers '
              'and surfaces are tinted with it across the app. Open Seed '
              'Color above to change or reset it.',
              style: RenanceText.caption.copyWith(color: context.textSecondary, height: 1.45),
            ),
          ],
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
              activeThumbColor: context.primary,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
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
              trailing: Text('2.5.0',
                  style: RenanceText.labelMono.copyWith(fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }
}

/// The expandable Seed Color section - the web AppearancePanel's picker,
/// 1:1: current-colour row with Reset, ten preset swatches, the 2-D
/// saturation × brightness field, the rainbow hue rail and the hex box.
class _SeedPanel extends StatelessWidget {
  const _SeedPanel({
    required this.open,
    required this.onToggle,
    required this.seed,
    required this.hsl,
    required this.hexDraft,
    required this.onHexDraft,
    required this.onApply,
  });

  final bool open;
  final VoidCallback onToggle;
  final String? seed;
  final ({double h, double s, double l}) hsl;
  final String hexDraft;
  final ValueChanged<String> onHexDraft;
  final ValueChanged<String?> onApply;

  @override
  Widget build(BuildContext context) {
    final Color current = Color(int.parse(
        (seed ?? hslToHex(hsl.h, hsl.s, hsl.l)).replaceFirst('#', '0xff')));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x0F141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // header row: expand/collapse -------------------------------
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Icon(Icons.palette_outlined,
                      size: 22, color: context.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Seed Color',
                            style: RenanceText.sectionTitle),
                        const SizedBox(height: 1),
                        Text('Re-tints every surface, like Chrome appearance',
                            style: RenanceText.caption
                                .copyWith(color: context.textSecondary)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // current colour row --------------------------------
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.cardLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: current,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                seed == null
                                    ? 'Renance default'
                                    : seed!.toUpperCase(),
                                style: RenanceText.bodyMedium,
                              ),
                              Text(
                                seed == null
                                    ? 'The classic ink and paper look'
                                    : 'Custom tint active',
                                style: RenanceText.caption.copyWith(
                                    color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (seed != null)
                          OutlinedButton(
                            onPressed: () => onApply(null),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              side: BorderSide(color: context.outlineVariant),
                            ),
                            child: Text('Reset',
                                style: RenanceText.caption
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // preset swatches -------------------------------------
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      for (final (:hex, :name) in kSeedPresets)
                        _Swatch(
                          hex: hex,
                          name: name,
                          selected:
                              seed?.toLowerCase() == hex.toLowerCase(),
                          onTap: () => onApply(hex),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // saturation × brightness field ------------------------
                  _SaturationField(
                    hue: hsl.h,
                    s: hsl.s,
                    l: hsl.l,
                    onChange: (double s, double l) =>
                        onApply(hslToHex(hsl.h, s, l)),
                  ),
                  const SizedBox(height: 16),
                  // hue rail ---------------------------------------------
                  _HueRail(
                    hue: hsl.h,
                    s: hsl.s,
                    l: hsl.l,
                    onChange: (double h) {
                      // keep the pick visible when the old colour sat at
                      // an extreme, same guard as the web.
                      final double nextL =
                          hsl.l > 96 || hsl.l < 4 ? 50 : hsl.l;
                      onApply(hslToHex(h, math.max(hsl.s, 45), nextL));
                    },
                  ),
                  const SizedBox(height: 12),
                  // hex box ----------------------------------------------
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.cardLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: current,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('#',
                            style: RenanceText.labelMono
                                .copyWith(color: context.textSecondary)),
                        Expanded(
                          child: _HexField(
                            draft: hexDraft,
                            inkColor: context.ink,
                            hintColor: context.outline,
                            onDraft: onHexDraft,
                            onApply: onApply,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hex input box. Owns its controller; syncs when the draft changes
/// from outside (swatch taps, field drags) without fighting the cursor.
class _HexField extends StatefulWidget {
  const _HexField({
    required this.draft,
    required this.inkColor,
    required this.hintColor,
    required this.onDraft,
    required this.onApply,
  });

  final String draft;
  final Color inkColor;
  final Color hintColor;
  final ValueChanged<String> onDraft;
  final ValueChanged<String?> onApply;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _body(widget.draft));
  }

  @override
  void didUpdateWidget(_HexField old) {
    super.didUpdateWidget(old);
    final String next = _body(widget.draft);
    if (next != _controller.text) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  static String _body(String hex) => hex.replaceFirst(RegExp(r'^#'), '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (String v) {
        final String clean = v.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
        final String trimmed = clean.length > 6
            ? clean.substring(0, 6)
            : clean;
        widget.onDraft('#$trimmed');
        if (trimmed.length == 6 || trimmed.length == 3) {
          widget.onApply('#$trimmed');
        }
      },
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        hintText: '13DC1B',
        hintStyle: TextStyle(color: widget.hintColor),
      ),
      style: RenanceText.labelMono.copyWith(
        fontSize: 15,
        letterSpacing: 1,
        color: widget.inkColor,
      ),
      autocorrect: false,
      enableSuggestions: false,
    );
  }
}

/// One preset colour dot with the selection ring.
class _Swatch extends StatelessWidget {
  const _Swatch({
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
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Color(int.parse(hex.replaceFirst('#', '0xff'))),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.ink : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 2-D saturation (→) × brightness (↑) field with a draggable thumb -
/// the Chrome colour-picker square.
class _SaturationField extends StatefulWidget {
  const _SaturationField({
    required this.hue,
    required this.s,
    required this.l,
    required this.onChange,
  });

  final double hue;
  final double s;
  final double l;
  final void Function(double s, double l) onChange;

  @override
  State<_SaturationField> createState() => _SaturationFieldState();
}

class _SaturationFieldState extends State<_SaturationField> {
  final GlobalKey _key = GlobalKey();

  void _emit(Offset global) {
    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size size = box.size;
    final Offset local = box.globalToLocal(global);
    final double s = (local.dx / size.width).clamp(0.0, 1.0) * 100;
    final double l = (1 - (local.dy / size.height).clamp(0.0, 1.0)) * 100;
    widget.onChange(s.roundToDouble(), l.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        key: _key,
        behavior: HitTestBehavior.opaque,
        onPanDown: (DragDownDetails d) => _emit(d.globalPosition),
        onPanUpdate: (DragUpdateDetails d) => _emit(d.globalPosition),
        onTapDown: (TapDownDetails d) => _emit(d.globalPosition),
        child: Container(
          height: 176,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: <Color>[
                Colors.white,
                Color(int.parse(
                    hslToHex(widget.hue, 100, 50).replaceFirst('#', '0xff'))),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 1.0),
                ],
                stops: const <double>[0, 1],
              ),
            ),
            child: Align(
              alignment: Alignment(
                (widget.s / 100) * 2 - 1,
                ((100 - widget.l) / 100) * 2 - 1,
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rainbow hue rail with a circular thumb - a one-dimensional drag
/// surface, same interaction as the Chrome picker.
class _HueRail extends StatefulWidget {
  const _HueRail({
    required this.hue,
    required this.s,
    required this.l,
    required this.onChange,
  });

  final double hue;
  final double s;
  final double l;
  final ValueChanged<double> onChange;

  @override
  State<_HueRail> createState() => _HueRailState();
}

class _HueRailState extends State<_HueRail> {
  final GlobalKey _key = GlobalKey();

  void _emit(Offset global) {
    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset local = box.globalToLocal(global);
    final double h =
        ((local.dx / box.size.width).clamp(0.0, 1.0) * 360);
    widget.onChange(h.roundToDouble());
  }

  static const List<Color> _rainbow = <Color>[
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails d) => _emit(d.globalPosition),
      onPanDown: (DragDownDetails d) => _emit(d.globalPosition),
      onPanUpdate: (DragUpdateDetails d) => _emit(d.globalPosition),
      child: SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _rainbow),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Align(
              alignment: Alignment((widget.hue / 360) * 2 - 1, 0),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(int.parse(
                      hslToHex(widget.hue, 100, 50).replaceFirst('#', '0xff'))),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Light / Mixed / Dark segmented control with the sliding pill.
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

/// A rounded card group with hairline dividers between rows.
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
