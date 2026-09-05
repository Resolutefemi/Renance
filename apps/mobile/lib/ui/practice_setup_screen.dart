/// Practice Settings, the Stitch practice_mode_setup_light screen, 1:1.
///
/// "Configure your JAMB practice session." The Past Question Year grid
/// (2024 / 2023 / 2022 / Random), the Question Count stepper with the
/// big stat and the 10 / 20 / 40 / 50 presets, the Timer grid (No
/// timer / 15m / 30m / 60m), the Shuffle Questions / Shuffle Options /
/// Show Answer Instantly toggle rows and the sticky Start Practice
/// button. Pops with a PracticeSetupResult so the caller can run the
/// pack with the chosen overrides.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

/// What Start Practice hands back to the caller.
class PracticeSetupResult {
  const PracticeSetupResult({
    required this.year,
    required this.questionCount,
    required this.timerMinutes,
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.showAnswerInstantly,
  });

  final String year; // 2024 | 2023 | 2022 | Random
  final int questionCount;

  /// null = the "No timer" option.
  final int? timerMinutes;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showAnswerInstantly;
}

class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  String _year = '2024';
  int _count = 40;
  int? _timerMinutes = 60;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;
  bool _showAnswerInstantly = false;

  static const List<String> _years = <String>['2024', '2023', '2022', 'Random'];
  static const List<int?> _timers = <int?>[null, 15, 30, 60];
  static const List<int> _presets = <int>[10, 20, 40, 50];

  void _finish() {
    Navigator.of(context).pop(PracticeSetupResult(
      year: _year,
      questionCount: _count,
      timerMinutes: _timerMinutes,
      shuffleQuestions: _shuffleQuestions,
      shuffleOptions: _shuffleOptions,
      showAnswerInstantly: _showAnswerInstantly,
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
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon:
                            const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: context.ink,
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
                                Icon(Icons.history,
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
                                    for (final String y in _years)
                                      _GridChoice(
                                        label: y,
                                        selected: _year == y,
                                        onTap: () =>
                                            setState(() => _year = y),
                                      ),
                                  ],
                                );
                              },
                            ),
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
                                Icon(Icons.format_list_numbered,
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
                                  icon: Icons.remove,
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
                                  icon: Icons.add,
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
                                Icon(Icons.timer,
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
                              icon: Icons.shuffle,
                              label: 'Shuffle Questions',
                              value: _shuffleQuestions,
                              first: true,
                              onChanged: (bool v) =>
                                  setState(() => _shuffleQuestions = v),
                            ),
                            _ToggleRow(
                              icon: Icons.format_list_bulleted,
                              label: 'Shuffle Options',
                              value: _shuffleOptions,
                              onChanged: (bool v) =>
                                  setState(() => _shuffleOptions = v),
                            ),
                            _ToggleRow(
                              icon: Icons.bolt,
                              label: 'Show Answer Instantly',
                              value: _showAnswerInstantly,
                              onChanged: (bool v) => setState(
                                  () => _showAnswerInstantly = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sticky CTA --------------------------------------------
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x00F9F9FF),
                        Color(0xE6F9F9FF),
                        Color(0xFFF9F9FF),
                      ],
                      stops: <double>[0.0, 0.4, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.inverseChip,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: context.onInverseChip,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(Icons.play_arrow, size: 22),
                              const SizedBox(width: 8),
                              Text('Start Practice',
                                  style: RenanceText.bodyMedium
                                      .copyWith(color: context.onInverseChip)),
                            ],
                          ),
                        ),
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

  final IconData icon;
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
          child: Icon(icon, size: 22, color: context.ink),
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

  final IconData icon;
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
          Icon(icon, size: 22, color: context.textSecondary),
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
