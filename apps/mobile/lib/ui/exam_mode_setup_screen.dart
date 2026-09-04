/// Mock Exam Setup, the Stitch exam_mode_setup_light screen, 1:1.
///
/// "Configure your testing environment to match official JAMB
/// conditions." The Exam Format card (Standard UTME Mock selected with
/// the 2 Hours / 4 Subjects chips, Custom Practice secondary), the
/// Subject Selection card with the English + 3 pill, mandatory Use of
/// English row with per-subject past-question year dropdowns, the
/// official-timing info notice and the sticky Begin Mock Exam button.
/// Static-first per the founder directive: selections live in local
/// state and the run hands the primary pack to the exam player.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import 'jamb_subject_selection_screen.dart';
import 'theme.dart';

/// The four Stitch subjects; ids mirror the design's data-subject keys.
class SetupSubject {
  const SetupSubject({
    required this.id,
    required this.name,
    required this.letter,
    required this.color,
    this.mandatory = false,
  });

  final String id;
  final String name;
  final String letter;
  final Color color;
  final bool mandatory;
}

const List<SetupSubject> kSetupSubjects = <SetupSubject>[
  SetupSubject(
      id: 'english',
      name: 'Use of English',
      letter: 'E',
      color: RenanceColors.ink,
      mandatory: true),
  SetupSubject(
      id: 'math',
      name: 'Mathematics',
      letter: 'M',
      color: RenanceColors.emerald),
  SetupSubject(
      id: 'physics', name: 'Physics', letter: 'P', color: RenanceColors.amber),
  SetupSubject(
      id: 'biology',
      name: 'Biology',
      letter: 'B',
      color: RenanceColors.secondaryContainer),
];

const List<String> kSetupYears = <String>['2023', '2022', '2021', 'Random'];

/// Resolves the exam the simulator actually runs: prefer a downloaded
/// pack so entry works offline, else the first manifest exam. Returns
/// null when nothing has synced yet.
ExamMeta? resolvePrimaryExam(List<ExamMeta> exams, Set<String> downloaded) {
  if (exams.isEmpty) return null;
  for (final ExamMeta e in exams) {
    if (downloaded.contains(e.code)) return e;
  }
  return exams.first;
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

  /// Hands the resolved pack to the shell's exam opener.
  final void Function(BuildContext context, ExamMeta exam) onBegin;

  @override
  State<ExamModeSetupScreen> createState() => _ExamModeSetupScreenState();
}

class _ExamModeSetupScreenState extends State<ExamModeSetupScreen> {
  bool _standard = true;
  Set<String> _selected = <String>{
    'english',
    'math',
    'physics',
    'biology',
  };
  final Map<String, String> _years = <String, String>{
    for (final SetupSubject s in kSetupSubjects) s.id: '2023',
  };

  int get _electiveCount =>
      _selected.where((String id) => id != 'english').length;

  Future<void> _openSubjectSelection() async {
    final Set<String>? result = await Navigator.of(context)
        .push<Set<String>>(MaterialPageRoute<Set<String>>(
      builder: (_) => JambSubjectSelectionScreen(initial: _selected),
    ));
    if (result == null || !mounted) return;
    setState(() => _selected = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RenanceColors.background,
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
                          const Icon(Icons.timer,
                              size: 24, color: RenanceColors.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Mock Exam Setup',
                                style: RenanceText.displayLg),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Configure your testing environment to match official JAMB conditions.',
                        style: RenanceText.bodyBase
                            .copyWith(color: RenanceColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      // Exam Format card --------------------------------
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Exam Format', style: RenanceText.sectionTitle),
                            const SizedBox(height: 12),
                            _FormatRow(
                              selected: _standard,
                              onTap: () => setState(() => _standard = true),
                              title: 'Standard UTME Mock',
                              titleColor: RenanceColors.ink,
                              chips: const <(IconData, String)>[
                                (Icons.schedule, '2 Hours'),
                                (Icons.menu_book, '4 Subjects'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _FormatRow(
                              selected: !_standard,
                              onTap: () => setState(() => _standard = false),
                              title: 'Custom Practice',
                              titleColor: RenanceColors.textSecondary,
                              caption: 'Choose specific topics and time limits.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Subject Selection card --------------------------
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
                                  onTap: _openSubjectSelection,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: RenanceColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          _electiveCount >= 3
                                              ? 'English + 3'
                                              : 'English + $_electiveCount',
                                          style: RenanceText.labelMono.copyWith(
                                            fontSize: 11,
                                            color: RenanceColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.edit,
                                            size: 12,
                                            color: RenanceColors.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (int i = 0; i < kSetupSubjects.length; i++) ...<Widget>[
                              _SubjectRow(
                                subject: kSetupSubjects[i],
                                selected: _selected.contains(kSetupSubjects[i].id),
                                year: _years[kSetupSubjects[i].id] ?? '2023',
                                onYear: (String y) => setState(
                                    () => _years[kSetupSubjects[i].id] = y),
                              ),
                              if (i < kSetupSubjects.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info notice --------------------------------------
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: RenanceColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.info_outline,
                                size: 18, color: RenanceColors.outlineDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This environment simulates official JAMB timing and rules. Pausing is disabled once the mock begins.',
                                style: RenanceText.caption
                                    .copyWith(color: RenanceColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sticky Bottom Action ---------------------------------
                _BeginBar(onBegin: _begin),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _begin() {
    final ExamMeta? exam =
        resolvePrimaryExam(widget.exams, widget.downloaded);
    if (exam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sync your packs first, then start the mock.')),
      );
      return;
    }
    widget.onBegin(context, exam);
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
        color: RenanceColors.card,
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
            color: RenanceColors.ink,
          ),
        ],
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
              ? RenanceColors.selectionBlue.withValues(alpha: 0.2)
              : RenanceColors.surfaceContainerLow,
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
              color: selected ? RenanceColors.ink : RenanceColors.outline,
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
                            .copyWith(color: RenanceColors.textSecondary)),
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
                              color: RenanceColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(icon,
                                    size: 14, color: RenanceColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(label,
                                    style: RenanceText.labelMono.copyWith(
                                        fontSize: 11,
                                        color: RenanceColors.textSecondary)),
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

/// One subject line: letter avatar, name, Mandatory caption (English)
/// and the per-subject past-question year dropdown.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.selected,
    required this.year,
    required this.onYear,
  });

  final SetupSubject subject;
  final bool selected;
  final String year;
  final ValueChanged<String> onYear;

  @override
  Widget build(BuildContext context) {
    final bool mandatory = subject.mandatory;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: mandatory
            ? RenanceColors.surfaceContainerLow.withValues(alpha: 0.5)
            : Colors.transparent,
        border: Border.all(
          color: mandatory
              ? RenanceColors.outlineVariant.withValues(alpha: 0.3)
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
              color: subject.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              subject.letter,
              style: RenanceText.displayMd.copyWith(
                fontSize: 16,
                color: subject.id == 'biology'
                    ? RenanceColors.secondary
                    : subject.color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(subject.name, style: RenanceText.bodyMedium),
                if (mandatory)
                  Text('Mandatory',
                      style: RenanceText.caption.copyWith(
                          fontSize: 11, color: RenanceColors.textSecondary)),
              ],
            ),
          ),
          // Year dropdown (2023 / 2022 / 2021 / Random).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: RenanceColors.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: year,
                items: <DropdownMenuItem<String>>[
                  for (final String y in kSetupYears)
                    DropdownMenuItem<String>(
                      value: y,
                      child: Text(y,
                          style: RenanceText.labelMono.copyWith(
                              fontSize: 12,
                              color: RenanceColors.textSecondary)),
                    ),
                ],
                onChanged: (String? v) {
                  if (v != null) onYear(v);
                },
                icon: const Icon(Icons.arrow_drop_down,
                    size: 16, color: RenanceColors.outline),
                dropdownColor: RenanceColors.card,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky black Begin Mock Exam button over a fading surface gradient.
class _BeginBar extends StatelessWidget {
  const _BeginBar({required this.onBegin});

  final VoidCallback onBegin;

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
              color: Colors.black,
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
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Begin Mock Exam',
                      style: RenanceText.bodyMedium.copyWith(color: Colors.white)),
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
