/// Practice Settings, the Stitch practice_mode_setup_light screen, 1:1.
///
/// "Configure your JAMB practice session." The Past Question Year grid
/// (the pack's own years / Random), the Question Count stepper with the
/// big stat and the 10 / 20 / 40 / 50 presets, the Timer grid (No
/// timer / 15m / 30m / 60m), the Shuffle Questions toggle row and the
/// sticky Start Practice button. Pops with a PracticeSetupResult the
/// caller turns into a REAL jamb-pick-… practice code (year pin +
/// subset size) or a straight full-pack open - the year and count are
/// no longer decorative.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

/// What Start Practice hands back to the caller.
class PracticeSetupResult {
  const PracticeSetupResult({
    required this.year,
    required this.questionCount,
    required this.timerMinutes,
    required this.shuffleQuestions,
  });

  /// Pinned exam year, or null for Random.
  final int? year;
  final int questionCount;

  /// null = the "No timer" option.
  final int? timerMinutes;
  final bool shuffleQuestions;
}

class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key, this.exam});

  /// The pack being practised; its real exam years drive the year chips
  /// when the manifest carries them.
  final ExamMeta? exam;

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  static const List<int?> _timers = <int?>[null, 15, 30, 60];
  static const List<int> _presets = <int>[10, 20, 40, 50];

  int? _year; // null = Random
  int _count = 40;
  int? _timerMinutes = 60;
  bool _shuffleQuestions = true;

  /// Random FIRST (founder directive 2026-10-02), then the pack's own
  /// exam years newest-first - every year the manifest carries, not just
  /// the newest three (the old newest-3 slice showed only 2023/2022/
  /// 2021 on most packs).
  ///
  /// NO fallback span: the old 1978-2025 filler offered years a pack
  /// with no year metadata cannot serve, so every pick errored server-
  /// side ("has no objective questions for 2015") - the tester report
  /// "U cant pick any year it returns an error" (2026-10-06). A pack
  /// without manifest years now offers Random only, with the hint row
  /// below telling the student why.
  late final bool _hasYearList =
      (widget.exam?.years ?? const <int>[]).isNotEmpty;
  late final List<int?> _yearChoices = <int?>[
    null, // Random
    ...(() {
      final List<int> ys = (widget.exam?.years ?? const <int>[]).toList()
        ..sort((int a, int b) => b.compareTo(a));
      return ys;
    })(),
  ];

  void _finish() {
    Navigator.of(context).pop(PracticeSetupResult(
      year: _year,
      questionCount: _count,
      timerMinutes: _timerMinutes,
      shuffleQuestions: _shuffleQuestions,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: <Widget>[
                      TactileBackKey(
                        onTap: () => Navigator.of(context).pop(),
                        size: 40,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      Text('Practice Settings',
                          style: RenanceText.displayLg),
                      const SizedBox(height: 6),
                      Text('Configure your JAMB practice session.',
                          style: RenanceText.bodyMedium
                              .copyWith(color: context.textSecondary)),
                      const SizedBox(height: 24),
                      // Past Question Year ------------------------------
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                MsIcon('history',
                                    size: 22, color: context.outlineLight),
                                const SizedBox(width: 12),
                                Text('Past Question Year',
                                    style: RenanceText.sectionTitle),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (BuildContext context,
                                  BoxConstraints c) {
                                final int cols =
                                    c.maxWidth >= 560 ? 4 : 2;
                                return GridView.count(
                                  crossAxisCount: cols,
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: cols == 4 ? 2.6 : 2.9,
                                  children: <Widget>[
                                    for (final int? y in _yearChoices)
                                      _GridChoice(
                                        label: y == null ? 'Random' : '$y',
                                        selected: _year == y,
                                        onTap: () =>
                                            setState(() => _year = y),
                                      ),
                                  ],
                                );
                              },
                            ),
                            if (!_hasYearList) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                'This pack plays Random for now - year '
                                'practice unlocks when its past questions '
                                'carry exam years.',
                                style: RenanceText.caption
                                    .copyWith(color: context.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Question Count ----------------------------------
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                MsIcon('format_list_numbered',
                                    size: 22,
                                    color: context.outlineLight),
                                const SizedBox(width: 12),
                                Text('Question Count',
                                    style: RenanceText.sectionTitle),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                _RoundStep(
                                  icon: 'remove',
                                  onTap: () => setState(() {
                                    if (_count > 5) _count -= 5;
                                  }),
                                ),
                                Column(
                                  children: <Widget>[
                                    Text('$_count',
                                        style: RenanceText.statNumber
                                            .copyWith(fontSize: 32)),
                                    Text('Questions',
                                        style: RenanceText.labelMono.copyWith(
                                            color: RenanceColors
                                                .textSecondary)),
                                  ],
                                ),
                                _RoundStep(
                                  icon: 'add',
                                  onTap: () => setState(() {
                                    if (_count < 100) _count += 5;
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: <Widget>[
                                for (int i = 0; i < _presets.length; i++)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          right: i == _presets.length - 1
                                              ? 0
                                              : 8),
                                      child: _PresetButton(
                                        label: '${_presets[i]}',
                                        selected: _count == _presets[i],
                                        onTap: () => setState(
                                            () => _count = _presets[i]),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Timer --------------------------------------------
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                MsIcon('timer',
                                    size: 22, color: context.outlineLight),
                                const SizedBox(width: 12),
                                Text('Timer', style: RenanceText.sectionTitle),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (BuildContext context,
                                  BoxConstraints c) {
                                final int cols =
                                    c.maxWidth >= 560 ? 4 : 2;
                                return GridView.count(
                                  crossAxisCount: cols,
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: cols == 4 ? 2.6 : 2.9,
                                  children: <Widget>[
                                    for (final int? t in _timers)
                                      _GridChoice(
                                        label:
                                            t == null ? 'No timer' : '${t}m',
                                        selected: _timerMinutes == t,
                                        onTap: () => setState(
                                            () => _timerMinutes = t),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Toggles ------------------------------------------
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: _cardDecoration(context),
                        child: Column(
                          children: <Widget>[
                            _ToggleRow(
                              icon: 'shuffle',
                              label: 'Shuffle Questions',
                              value: _shuffleQuestions,
                              first: true,
                              onChanged: (bool v) =>
                                  setState(() => _shuffleQuestions = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sticky CTA --------------------------------------------
                DecoratedBox(
                  // The sticky footer's scrim rides the PAGE token: white
                  // fade on the light tier, near-black fade on the dark
                  // tier (the fixed white wash used to glare in dark).
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: context.darkChrome
                          ? const <Color>[
                              Color(0x000F1216),
                              Color(0xE60F1216),
                              Color(0xFF0F1216),
                            ]
                          : const <Color>[
                              Color(0x00F9F9FF),
                              Color(0xE6F9F9FF),
                              Color(0xFFFFFFFF),
                            ],
                      stops: const <double>[0.0, 0.4, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TactileButton(
                      onPressed: _finish,
                      height: 52,
                      radius: BorderRadius.circular(10),
                      face: context.inverseChip,
                      onFace: context.onInverseChip,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const MsIcon('play_arrow', size: 22, fill: true),
                          const SizedBox(width: 8),
                          Text('Start Practice',
                              style: RenanceText.bodyMedium
                                  .copyWith(color: context.onInverseChip)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: context.card,
  borderRadius: BorderRadius.circular(12),
  boxShadow: const <BoxShadow>[
    BoxShadow(
      color: Color(0x141C2D34),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ],
);

/// White rounded card wrapper used by the three setup cards.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: child,
    );
  }
}

/// 48px circular stepper button (remove / add).
class _RoundStep extends StatelessWidget {
  const _RoundStep({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardLow,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: MsIcon(icon, size: 22, color: context.ink),
        ),
      ),
    );
  }
}

/// Year / timer grid cell: selection-blue with the ink 2px border when
/// selected, surface-container-low otherwise.
class _GridChoice extends StatelessWidget {
  const _GridChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.selectionBlue
          : context.cardLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? context.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(label,
              style: RenanceText.bodyMedium.copyWith(color: context.ink)),
        ),
      ),
    );
  }
}

/// 10 / 20 / 40 / 50 preset chip under the count stepper.
class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.selectionBlue
          : context.cardLow,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: selected
                ? RenanceText.bodyMedium.copyWith(color: context.ink)
                : RenanceText.bodyBase.copyWith(color: context.ink),
          ),
        ),
      ),
    );
  }
}

/// Toggle row with the Stitch switch: black track + white right thumb
/// when on; surface-container-high track + grey left thumb when off.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.first = false,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(color: context.cardLow)),
      ),
      child: Row(
        children: <Widget>[
          MsIcon(icon, size: 22, color: context.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: RenanceText.bodyMedium),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 24,
              decoration: BoxDecoration(
                color: value
                    ? context.ink
                    : context.cardHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value
                        ? context.card
                        : context.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
