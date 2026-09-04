/// Subject Selection, the Stitch jamb_subject_selection_light screen,
/// 1:1.
///
/// The JAMB Requirements card (uppercase caption, the emerald Selected
/// 2/4 counter, the English mandatory pill and the progress rail), the
/// Available Subjects list with syllabus-coverage bar glyphs, mandatory
/// Use of English locked on, the 4-subject cap with dimmed leftovers,
/// and the Start Mock Exam button that arms only at 4/4.
/// Pops with the chosen subject-id set so the setup screen can show it.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

class JambSubjectSelectionScreen extends StatefulWidget {
  const JambSubjectSelectionScreen({super.key, this.initial});

  /// Previously chosen ids (the setup screen passes its own set).
  final Set<String>? initial;

  @override
  State<JambSubjectSelectionScreen> createState() =>
      _JambSubjectSelectionScreenState();
}

class _SelectionSubject {
  const _SelectionSubject({
    required this.id,
    required this.name,
    required this.icon,
    required this.covered,
    required this.total,
    this.amberBar = false,
    this.mandatory = false,
  });

  final String id;
  final String name;
  final IconData icon;

  /// Covered / total mini-bar glyph and the "65% Syllabus" caption.
  final int covered;
  final int total;
  final bool amberBar;
  final bool mandatory;
}

const List<_SelectionSubject> _kSelectionSubjects = <_SelectionSubject>[
  _SelectionSubject(
    id: 'english',
    name: 'Use of English',
    icon: Icons.menu_book,
    covered: 3,
    total: 3,
    mandatory: true,
  ),
  _SelectionSubject(
    id: 'math',
    name: 'Mathematics',
    icon: Icons.calculate,
    covered: 2,
    total: 3,
  ),
  _SelectionSubject(
    id: 'physics',
    name: 'Physics',
    icon: Icons.psychology,
    covered: 3,
    total: 3,
  ),
  _SelectionSubject(
    id: 'chemistry',
    name: 'Chemistry',
    icon: Icons.science,
    covered: 1,
    total: 3,
    amberBar: true,
  ),
  _SelectionSubject(
    id: 'biology',
    name: 'Biology',
    icon: Icons.biotech,
    covered: 0,
    total: 3,
  ),
];

class _JambSubjectSelectionScreenState
    extends State<JambSubjectSelectionScreen> {
  static const int _maxSelections = 4;

  late final Set<String> _selected =
      widget.initial == null || widget.initial!.isEmpty
          ? <String>{'english', 'physics'} // the Stitch initial state
          : Set<String>.of(widget.initial!);

  bool selected(String id) => _selected.contains(id);

  void _toggle(String id) {
    final _SelectionSubject s =
        _kSelectionSubjects.firstWhere((_SelectionSubject s) => s.id == id);
    if (s.mandatory) return; // English mandatory (design + JAMB rules)
    setState(() {
      if (selected(id)) {
        _selected.remove(id);
      } else if (_selected.length < _maxSelections) {
        _selected.add(id);
      }
    });
  }

  void _start() {
    if (_selected.length != _maxSelections) return;
    Navigator.of(context).pop(Set<String>.of(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final bool full = _selected.length == _maxSelections;
    final double progress = _selected.length / _maxSelections;

    return Scaffold(
      backgroundColor: context.cardLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Top bar: back + title + spacer (Stitch layout) --------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: <Widget>[
                      _RoundBack(onBack: () => Navigator.of(context).pop()),
                      const Spacer(),
                      Text('Subject Selection',
                          style: RenanceText.displayMd.copyWith(fontSize: 20)),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: <Widget>[
                      // JAMB Requirements card --------------------------
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33141C2D),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'JAMB REQUIREMENTS',
                                        style: RenanceText.overline.copyWith(
                                          color:
                                              context.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text.rich(
                                        TextSpan(
                                          children: <InlineSpan>[
                                            const TextSpan(text: 'Selected: '),
                                            TextSpan(
                                              text:
                                                  '${_selected.length}/$_maxSelections',
                                              style: RenanceText.displayMd
                                                  .copyWith(
                                                fontSize: 20,
                                                color: full
                                                    ? context.ink
                                                    : RenanceColors.emerald,
                                              ),
                                            ),
                                          ],
                                          style: RenanceText.displayMd
                                              .copyWith(fontSize: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.surfaceVariant,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.info_outline,
                                          size: 14,
                                          color: context.textSecondary),
                                      const SizedBox(width: 6),
                                      Text('English mandatory',
                                          style: RenanceText.labelMono
                                              .copyWith(
                                                  fontSize: 11,
                                                  color: RenanceColors
                                                      .textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                height: 6,
                                child: Stack(
                                  children: <Widget>[
                                    ColoredBox(
                                      color: context.surfaceVariant,
                                      child: const SizedBox.expand(),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progress,
                                      child: ColoredBox(
                                        color: full
                                            ? context.ink
                                            : RenanceColors.emerald,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Available Subjects header ------------------------
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('Available Subjects',
                                style: RenanceText.sectionTitle),
                            Text('Tap to select',
                                style: RenanceText.caption.copyWith(
                                    color: context.textSecondary)),
                          ],
                        ),
                      ),
                      // Subject rows -------------------------------------
                      for (final _SelectionSubject s in _kSelectionSubjects)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SubjectTile(
                            subject: s,
                            selected: selected(s.id),
                            dimmed:
                                !selected(s.id) && full && !s.mandatory,
                            onTap: () => _toggle(s.id),
                          ),
                        ),
                    ],
                  ),
                ),
                // Sticky Start Mock Exam --------------------------------
                _StartBar(enabled: full, onStart: _start),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 40px circular back button, surface-container fill (Stitch top bar).
class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBack,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back,
              size: 20, color: context.ink),
        ),
      ),
    );
  }
}

/// One subject row: 48px icon tile, name, syllabus mini-bars, and the
/// right-side check circle. Selected = surface-container bg with the
/// emerald 2px border; mandatory English uses the black primary style.
class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final _SelectionSubject subject;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool mandatory = subject.mandatory;
    final Color tileColor = mandatory
        ? context.ink
        : selected
            ? RenanceColors.emerald
            : context.surfaceContainer;
    final Color tileIconColor = (mandatory || selected)
        ? Colors.white
        : context.textSecondary;
    final Color borderColor = mandatory
        ? context.ink
        : selected
            ? RenanceColors.emerald
            : Colors.transparent;

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Material(
        color: selected || mandatory
            ? context.surfaceContainer
            : context.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child:
                      Icon(subject.icon, size: 24, color: tileIconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(subject.name,
                          style: RenanceText.bodyMedium.copyWith(
                              fontSize: 16, color: context.ink)),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          if (mandatory) ...<Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: RenanceColors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Mandatory',
                                style: RenanceText.caption.copyWith(
                                    color: context.textSecondary)),
                          ] else ...<Widget>[
                            for (int i = 0; i < subject.total; i++)
                              Container(
                                width: 6,
                                height: 12,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: i < subject.covered
                                      ? (subject.amberBar
                                          ? RenanceColors.amber
                                          : RenanceColors.emerald)
                                      : context.surfaceVariant,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              '${(subject.covered / subject.total * 100).round()}% Syllabus',
                              style: RenanceText.caption.copyWith(
                                  color: context.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _CheckCircle(
                  filled: selected || mandatory,
                  black: mandatory,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 24px round check: outline when empty; emerald with white check when
/// selected; black for the mandatory English row.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.filled, required this.black});

  final bool filled;
  final bool black;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? (black ? context.ink : RenanceColors.emerald)
            : Colors.transparent,
        border: filled
            ? null
            : Border.all(color: context.outlineLight),
      ),
      alignment: Alignment.center,
      child: filled
          ? const Icon(Icons.check,
              size: 14, color: Colors.white)
          : const SizedBox.shrink(),
    );
  }
}

/// Sticky Start Mock Exam: 40% opacity until exactly 4 subjects are on.
class _StartBar extends StatelessWidget {
  const _StartBar({required this.enabled, required this.onStart});

  final bool enabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                boxShadow: enabled
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: TextButton(
                onPressed: enabled ? onStart : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.rocket_launch, size: 20),
                    const SizedBox(width: 8),
                    Text('Start Mock Exam',
                        style: RenanceText.bodyMedium
                            .copyWith(color: Colors.white)),
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
