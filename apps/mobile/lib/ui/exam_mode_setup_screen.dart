/// Mock Exam Setup, the Stitch exam_mode_setup_light screen - now wired
/// to the real composed-paper engine.
///
/// "Configure your testing environment to match official JAMB
/// conditions." The Exam Format card (Standard UTME Mock with the
/// 2 Hours / 4 Subjects chips, Custom Practice secondary), the Subject
/// Selection card (English mandatory + electives from the live manifest
/// banks), per-subject past-question year dropdowns, the
/// official-timing info notice and the sticky Begin Mock Exam button.
///
/// Begin composes a CANONICAL paper code (lib/papers.dart mirrors the
/// server grammar) - jamb-mock-… for the standard mock, jamb-custom-…
/// / waec-custom-… / neco-custom-… for custom practice - so the server
/// serves exactly the subjects, years and size the candidate chose.
/// The old "first downloaded pack" shortcut that made every Begin open
/// the same accounting bank is gone.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../papers.dart';
import 'jamb_subject_selection_screen.dart';
import 'theme.dart';

const List<String> kSetupYears = <String>['2023', '2022', '2021', 'Random'];

const List<int> kCustomCounts = <int>[10, 20, 40, 60];
const List<(String, int?)> kCustomTimers = <(String, int?)>[
  ('Untimed', null),
  ('15 min', 15),
  ('30 min', 30),
  ('60 min', 60),
];

/// Base bank slugs for one exam body straight from the manifest
/// ("jamb-biology-bank" -> "biology"), enrichment variants excluded so
/// only selectable subjects appear.
List<String> bankSlugsFor(List<ExamMeta> exams, String body) {
  final Set<String> slugs = <String>{};
  for (final ExamMeta e in exams) {
    final String code = e.code;
    if (!code.startsWith('$body-') || !code.endsWith('-bank')) continue;
    final String slug = code.substring(body.length + 1, code.length - 5);
    if (slug.endsWith('-enrich') ||
        slug.endsWith('-sim') ||
        slug.endsWith('-theory')) {
      continue;
    }
    slugs.add(slug);
  }
  final List<String> list = slugs.toList()..sort();
  return list;
}

class ExamModeSetupScreen extends StatefulWidget {
  const ExamModeSetupScreen({
    super.key,
    required this.exams,
    required this.downloaded,
    required this.onBegin,
  });

  final List<ExamMeta> exams;
  final Set<String> downloaded;

  /// Hands the composed paper to the shell's exam opener. The shell's
  /// opener takes the same optional overrides, so custom-practice runs
  /// carry the chosen timer (or the untimed count-up clock).
  final void Function(
    BuildContext context,
    ExamMeta exam, {
    int? durationOverrideMinutes,
    bool untimed,
  }) onBegin;

  @override
  State<ExamModeSetupScreen> createState() => _ExamModeSetupScreenState();
}

class _ExamModeSetupScreenState extends State<ExamModeSetupScreen> {
  /// Exam body whose banks the paper composes from.
  String _body = 'jamb';

  /// Standard UTME Mock vs Custom Practice (JAMB mode only; WAEC/NECO
  /// always run the custom family).
  bool _standard = true;

  /// Selected bank slugs; English stays pinned for the standard mock.
  Set<String> _selected = <String>{
    'english',
    'mathematics',
    'physics',
    'biology',
  };

  /// Per-subject past-question year ("Random" = null).
  final Map<String, String> _years = <String, String>{};

  int _count = 40;
  int? _timerMinutes = 60;

  int get _electiveCount =>
      _selected.where((String id) => id != 'english').length;

  List<String> get _bodySlugs => bankSlugsFor(widget.exams, _body);

  String _bodyLabel() => switch (_body) {
        'waec' => 'WASSCE',
        'neco' => 'NECO',
        _ => 'JAMB UTME',
      };

  void _switchBody(String body) {
    if (_body == body) return;
    final List<String> slugs = bankSlugsFor(widget.exams, body);
    final Set<String> next = <String>{'english'};
    for (final String s in const <String>['mathematics', 'biology', 'chemistry']) {
      if (slugs.contains(s)) next.add(s);
    }
    if (next.length < 2 && slugs.isNotEmpty) next.add(slugs.first);
    setState(() {
      _body = body;
      _standard = body == 'jamb';
      _selected = next;
    });
  }

  Future<void> _openSubjectSelection() async {
    final Set<String>? result = await Navigator.of(context)
        .push<Set<String>>(MaterialPageRoute<Set<String>>(
      builder: (_) => JambSubjectSelectionScreen(
        initial: _selected,
        mandatoryEnglish: _standard,
        availableSlugs: _bodySlugs,
      ),
    ));
    if (result == null || !mounted) return;
    setState(() => _selected = result);
  }

  int? _yearOf(String slug) {
    final String v = _years[slug] ?? '2023';
    return v == 'Random' ? null : int.parse(v);
  }

  void _begin() {
    if (_body == 'jamb' && _standard) {
      final List<String> electives =
          _selected.where((String s) => s != 'english').toList()..sort();
      if (electives.isEmpty) {
        _snack('Pick at least one elective beside Use of English.');
        return;
      }
      // Years align with the full subject list, English first.
      final List<String> subjects = <String>['english', ...electives];
      final List<int?> years = subjects.map(_yearOf).toList();
      final bool anyPinned = years.any((int? y) => y != null);
      final String code = buildMockCode(
        electives,
        years: anyPinned ? years : null,
      );
      widget.onBegin(
          context, mockExamMeta(code, electives));
      return;
    }
    // Custom practice, any body: subjects fully sorted, >= 1.
    final List<String> subjects = _selected.toList()..sort();
    if (subjects.isEmpty) {
      _snack('Pick at least one subject.');
      return;
    }
    final String code = buildCustomCode(
      subjects,
      body: _body,
      count: _count,
      timer: _timerMinutes,
    );
    widget.onBegin(
      context,
      customExamMeta(code, _body, subjects,
          count: _count, timerMinutes: _timerMinutes),
      durationOverrideMinutes: _timerMinutes,
      untimed: _timerMinutes == null,
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool jambMode = _body == 'jamb';
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _BackBar(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      // Header Area -------------------------------------
                      Row(
                        children: <Widget>[
                          Icon(Icons.timer, size: 24, color: context.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              jambMode
                                  ? 'Mock Exam Setup'
                                  : '${_bodyLabel()} Practice Setup',
                              style: RenanceText.displayLg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        jambMode
                            ? 'Configure your testing environment to match official JAMB conditions.'
                            : 'Compose a practice paper from the ${_bodyLabel()} past-question banks.',
                        style: RenanceText.bodyBase
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      // Exam body switch --------------------------------
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Exam Body', style: RenanceText.sectionTitle),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                for (final (String body, String label)
                                    in const <(String, String)>[
                                      ('jamb', 'JAMB'),
                                      ('waec', 'WASSCE'),
                                      ('neco', 'NECO'),
                                    ]) ...<Widget>[
                                  Expanded(
                                    child: _BodyChip(
                                      label: label,
                                      selected: _body == body,
                                      onTap: () => _switchBody(body),
                                    ),
                                  ),
                                  if (body != 'neco') const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Exam Format card (JAMB only) ---------------------
                      if (jambMode) ...<Widget>[
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Exam Format',
                                  style: RenanceText.sectionTitle),
                              const SizedBox(height: 12),
                              _FormatRow(
                                selected: _standard,
                                onTap: () => setState(() => _standard = true),
                                title: 'Standard UTME Mock',
                                titleColor: context.ink,
                                chips: const <(IconData, String)>[
                                  (Icons.schedule, '2 Hours'),
                                  (Icons.menu_book, '4 Subjects'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _FormatRow(
                                selected: !_standard,
                                onTap: () =>
                                    setState(() => _standard = false),
                                title: 'Custom Practice',
                                titleColor: context.textSecondary,
                                caption:
                                    'Choose specific subjects, question count and time limits.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Subject Selection card ---------------------------
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text('Subject Selection',
                                    style: RenanceText.sectionTitle),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: jambMode
                                      ? _openSubjectSelection
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: jambMode
                                          ? context.surfaceContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          jambMode
                                              ? (_standard
                                                  ? 'English + $_electiveCount'
                                                  : '${_selected.length} subjects')
                                              : '${_selected.length} picked',
                                          style: RenanceText.labelMono.copyWith(
                                            fontSize: 11,
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        if (jambMode) ...<Widget>[
                                          const SizedBox(width: 2),
                                          Icon(Icons.edit,
                                              size: 12,
                                              color: context.textSecondary),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (jambMode)
                              for (final String slug in _orderedSelected())
                                _SubjectRow(
                                  name: subjectName(slug),
                                  letter: subjectName(slug).isEmpty
                                      ? '?'
                                      : subjectName(slug)[0],
                                  mandatory: _standard && slug == 'english',
                                  year: _years[slug] ?? '2023',
                                  years: kSetupYears,
                                  onYear: (String y) =>
                                      setState(() => _years[slug] = y),
                                  onRemove: (_standard && slug == 'english')
                                      ? null
                                      : () => setState(
                                          () => _selected.remove(slug)),
                                )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  for (final String slug in _bodySlugs)
                                    _SubjectChip(
                                      label: subjectName(slug),
                                      selected:
                                          _selected.contains(slug),
                                      onTap: () => setState(() {
                                        if (!_selected.add(slug)) {
                                          _selected.remove(slug);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            if (jambMode) ...<Widget>[
                              const SizedBox(height: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: _openSubjectSelection,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: context.outlineVariant),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(Icons.add,
                                          size: 16,
                                          color: context.textSecondary),
                                      const SizedBox(width: 6),
                                      Text('Add or remove subjects',
                                          style: RenanceText.caption.copyWith(
                                              color: context.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Custom-practice size + timer ---------------------
                      if (!jambMode || !_standard) ...<Widget>[
                        const SizedBox(height: 16),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Questions', style: RenanceText.sectionTitle),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  for (final int c in kCustomCounts) ...<Widget>[
                                    Expanded(
                                      child: _BodyChip(
                                        label: '$c',
                                        selected: _count == c,
                                        onTap: () =>
                                            setState(() => _count = c),
                                      ),
                                    ),
                                    if (c != kCustomCounts.last)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text('Timer', style: RenanceText.sectionTitle),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  for (int i = 0; i < kCustomTimers.length; i++) ...<Widget>[
                                    Expanded(
                                      child: _BodyChip(
                                        label: kCustomTimers[i].$1,
                                        selected: _timerMinutes == kCustomTimers[i].$2,
                                        onTap: () =>
                                            setState(() => _timerMinutes = kCustomTimers[i].$2),
                                      ),
                                    ),
                                    if (i < kCustomTimers.length - 1)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Info notice --------------------------------------
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(Icons.info_outline,
                                size: 18, color: context.outlineDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                jambMode && _standard
                                    ? 'This environment simulates official JAMB timing and rules. Pausing is disabled once the mock begins.'
                                    : 'The paper is composed from the real ${_bodyLabel()} past-question banks and graded on the Renance servers.',
                                style: RenanceText.caption
                                    .copyWith(color: context.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sticky Bottom Action ---------------------------------
                _BeginBar(
                  label: jambMode && _standard
                      ? 'Begin Mock Exam'
                      : 'Begin Practice',
                  onBegin: _begin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// English first, then the electives alphabetically - the order the
  /// mock lists on screen and in the code.
  List<String> _orderedSelected() {
    final List<String> rest = _selected.where((String s) => s != 'english').toList()
      ..sort();
    if (_selected.contains('english')) return <String>['english', ...rest];
    return rest;
  }
}

/// White card, rounded-xl, the Stitch shadow token.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x141C2D34),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Top LHS back bar (founder rule: every page gets a back button).
class _BackBar extends StatelessWidget {
  const _BackBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: context.ink,
          ),
        ],
      ),
    );
  }
}

/// One pill of the body switch / count / timer rows.
class _BodyChip extends StatelessWidget {
  const _BodyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.selectionBlue.withValues(alpha: 0.25) : context.cardLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? context.selectionBlue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: RenanceText.labelMono.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? context.ink : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Selectable subject pill (WAEC/NECO inline picking).
class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.selectionBlue.withValues(alpha: 0.25) : context.cardLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? context.selectionBlue : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected) ...<Widget>[
              Icon(Icons.check, size: 14, color: context.ink),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: RenanceText.bodyMedium.copyWith(
                fontSize: 13,
                color: selected ? context.ink : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the Exam Format card: radio, title, optional caption and
/// the 2 Hours / 4 Subjects chips of the selected Standard UTME Mock.
class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.titleColor,
    this.caption,
    this.chips,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final Color titleColor;
  final String? caption;
  final List<(IconData, String)>? chips;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? context.selectionBlue.withValues(alpha: 0.2)
              : context.cardLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? context.ink : context.outline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: RenanceText.bodyMedium.copyWith(color: titleColor)),
                  if (caption != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(caption!,
                        style: RenanceText.caption
                            .copyWith(color: context.textSecondary)),
                  ],
                  if (chips != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final (IconData icon, String label) in chips!)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.cardLow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(icon,
                                    size: 14, color: context.textSecondary),
                                const SizedBox(width: 4),
                                Text(label,
                                    style: RenanceText.labelMono.copyWith(
                                        fontSize: 11,
                                        color: context.textSecondary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selected-subject line: letter avatar, name, Mandatory caption
/// (standard-mock English) and the per-subject past-question year
/// dropdown. Electives can be removed straight from the row.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.name,
    required this.letter,
    required this.mandatory,
    required this.year,
    required this.years,
    required this.onYear,
    this.onRemove,
  });

  final String name;
  final String letter;
  final bool mandatory;
  final String year;
  final List<String> years;
  final ValueChanged<String> onYear;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: mandatory
            ? context.cardLow.withValues(alpha: 0.5)
            : Colors.transparent,
        border: Border.all(
          color: mandatory
              ? context.outlineVariant.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.selectionBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: RenanceText.displayMd.copyWith(
                fontSize: 16,
                color: context.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: RenanceText.bodyMedium),
                if (mandatory)
                  Text('Mandatory',
                      style: RenanceText.caption.copyWith(
                          fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
          // Year dropdown (2023 / 2022 / 2021 / Random).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: years.contains(year) ? year : years.first,
                items: <DropdownMenuItem<String>>[
                  for (final String y in years)
                    DropdownMenuItem<String>(
                      value: y,
                      child: Text(y,
                          style: RenanceText.labelMono.copyWith(
                              fontSize: 12, color: context.textSecondary)),
                    ),
                ],
                onChanged: (String? v) {
                  if (v != null) onYear(v);
                },
                icon: Icon(Icons.arrow_drop_down,
                    size: 16, color: context.outline),
                dropdownColor: context.card,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              color: context.textSecondary,
              tooltip: 'Remove $name',
            ),
        ],
      ),
    );
  }
}

/// Sticky black Begin button over a fading surface gradient.
class _BeginBar extends StatelessWidget {
  const _BeginBar({required this.onBegin, this.label = 'Begin Mock Exam'});

  final VoidCallback onBegin;
  final String label;

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
              onPressed: onBegin,
              style: TextButton.styleFrom(
                foregroundColor: context.onInverseChip,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(label,
                      style: RenanceText.bodyMedium
                          .copyWith(color: context.onInverseChip)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
