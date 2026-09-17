/// Study Past Questions — the school app's study page, Renance edition.
///
/// The tinted header band ("Get all exam questions from 1978 till
/// date"), the green "Update Questions" banner that opens the Select &
/// Update page, and the five-pick form — Subject, Examination Type,
/// Examination Year, Question type, Question Topic — with the big
/// "Start Study" button.
///
/// Start Study composes a real custom paper (subject + year + size via
/// lib/papers.dart) and opens it in study mode: untimed, browsable,
/// submit-and-reveal.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../papers.dart';
import '../storage.dart';
import 'exam_mode_setup_screen.dart';
import 'exam_screen.dart';
import 'university_screens.dart';
import 'update_questions_screen.dart';
import 'theme.dart';

class StudySetupScreen extends StatefulWidget {
  const StudySetupScreen({super.key, this.onOpenExam});

  /// Hands the composed study paper to the shell's exam opener.
  final void Function(
    BuildContext context,
    ExamMeta exam, {
    int? durationOverrideMinutes,
    bool untimed,
  })? onOpenExam;

  @override
  State<StudySetupScreen> createState() => _StudySetupScreenState();
}

class _StudySetupScreenState extends State<StudySetupScreen> {
  String _body = 'jamb';
  String _subject = '';
  String _year = 'All'; // All | 2023 | 2022 | ...
  String _qType = 'All'; // All | Objective | Theory
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final StudentController student = context.read<StudentController>();
      final String exam = student.me?.profile?.exams.firstOrNull ?? 'JAMB';
      setState(() {
        _body = switch (exam) {
          'WAEC' => 'waec',
          'NECO' => 'neco',
          'POST-UTME' => 'post-utme',
          'University Modules' => 'university',
          _ => 'jamb',
        };
        final List<String> slugs = _slugs;
        _subject = slugs.isNotEmpty ? slugs.first : '';
      });
    });
  }

  List<ExamMeta> get _exams => context.read<SyncController>().exams;

  List<ExamMeta> get _bodyExams =>
      _exams.where((ExamMeta e) => e.body == _bodyLabel).toList();

  String get _bodyLabel => switch (_body) {
        'waec' => 'WAEC',
        'neco' => 'NECO',
        'post-utme' => 'POST-UTME',
        'university' => 'University Modules',
        _ => 'JAMB',
      };

  /// The Post UTME school pick ( SharedPreferences), when it still has
  /// banked prep packs.
  String? get _postUtmeSchoolSlug {
    final String? slug = context
        .read<SessionStore>()
        .prefs
        .getString(kPostUtmeSchoolPickKey);
    if (slug == null) return null;
    return postUtmeCourses(_exams).containsKey(slug) ? slug : null;
  }

  /// Study subjects for the active examination type. Secondary bodies
  /// map their bank slugs; the tertiary body maps the university packs
  /// (each course pack becomes one studyable "subject"); Post UTME maps
  /// the picked school's prep packs plus the general practice banks.
  List<String> get _slugs {
    if (_body == 'university') {
      return <String>[
        for (final ExamMeta e in _exams)
          if (e.body == 'University Modules') e.code,
      ];
    }
    if (_body == 'post-utme') {
      final List<String> slugs = <String>[];
      final String? school = _postUtmeSchoolSlug;
      if (school != null) {
        for (final UniCourse c in postUtmeCourses(_exams)[school] ?? const <UniCourse>[]) {
          slugs.add(c.exam.code);
        }
      }
      for (final ExamMeta e in _exams) {
        if (e.body == 'POST-UTME') slugs.add(e.code);
      }
      return slugs;
    }
    return bankSlugsFor(_exams, _body);
  }

  String _subjectLabel(String slug) {
    if (_body == 'university' || _body == 'post-utme') {
      for (final ExamMeta e in _exams) {
        if (e.code == slug) return e.title;
      }
      return slug;
    }
    return subjectName(slug);
  }

  List<String> get _years {
    final Set<int> years = <int>{};
    for (final ExamMeta e in _bodyExams) {
      years.addAll(e.years);
    }
    final List<int> sorted = years.toList()..sort((int a, int b) => b.compareTo(a));
    return <String>['All', ...sorted.take(12).map((int y) => '$y')];
  }

  Future<void> _start() async {
    if (_subject.isEmpty || _starting) return;
    setState(() => _starting = true);
    try {
      final int? year = _year == 'All' ? null : int.tryParse(_year);
      final String code;
      final String title;
      if (_body == 'university' || _body == 'post-utme') {
        // Tertiary + Post UTME: carve a study slice from the chosen pack.
        // The pick grammar takes count only for these banks — years stay
        // a secondary-body feature.
        code = buildPickCode(_subject, count: 60);
        title = '${_subjectLabel(_subject)} · Study';
      } else {
        code = buildCustomCode(
          <String>[_subject],
          body: _body,
          count: 60,
          year: year,
        );
        title = '${subjectName(_subject)} · Study';
      }
      final ExamMeta meta = composedExamMeta(
        code: code,
        title: title,
        body: _bodyLabel,
        questionCount: 60,
        durationMinutes: null,
      );
      if (!mounted) return;
      // Study mode: untimed paper that lands in the Past Questions
      // reader once graded — the school app's study semantics.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamScreen(exam: meta, studyMode: true),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> slugs = _slugs;
    if (_subject.isEmpty && slugs.isNotEmpty) _subject = slugs.first;
    if (!slugs.contains(_subject) && slugs.isNotEmpty) _subject = slugs.first;

    return Scaffold(
      backgroundColor: context.cardLowest,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ---- tinted header band --------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              color: context.isDarkTier
                  ? context.cardLow
                  : const Color(0xFFFDF1EE),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: context.outlineVariant),
                        color: context.card,
                      ),
                      child:
                          Icon(Icons.arrow_back, size: 20, color: context.ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 6),
                        Text('Study Past Questions',
                            style: RenanceText.sectionTitle.copyWith(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Get all exam questions from 1978 till date',
                          style: RenanceText.bodySecondary.copyWith(
                            fontSize: 14,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                    child: const Icon(Icons.menu_book,
                        size: 22, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  // ---- green Update Questions banner ----------------
                  InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const UpdateQuestionsScreen()),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: context.cardLowest,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x14141C2D),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Update Questions',
                                    style: RenanceText.bodyMedium.copyWith(
                                        fontSize: 13.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      size: 17, color: context.ink),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Icon(Icons.chevron_right,
                                  size: 18, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Update your questions regularly to download the '
                        'latest questions, answers, explanations, and '
                        'corrections.',
                        style: RenanceText.caption.copyWith(
                          fontSize: 13,
                          height: 1.5,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ---- the five-pick form ---------------------------
                    _FieldLabel('Subject'),
                    _PickerField(
                      value: _subject.isEmpty
                          ? 'Select Subject'
                          : _subjectLabel(_subject),
                      items: <String>[
                        for (final String s in slugs) _subjectLabel(s)
                      ],
                      onChanged: (String name) => setState(() {
                        for (final String s in slugs) {
                          if (_subjectLabel(s) == name) _subject = s;
                        }
                      }),
                    ),
                    _FieldLabel('Examination Type'),
                    _PickerField(
                      value: switch (_bodyLabel) {
                        'POST-UTME' => 'Post UTME',
                        'University Modules' => 'School Desk (University)',
                        _ => _bodyLabel,
                      },
                      items: const <String>[
                        'JAMB',
                        'WAEC',
                        'NECO',
                        'Post UTME',
                        'School Desk (University)',
                      ],
                      onChanged: (String v) => setState(() {
                        _body = switch (v) {
                          'WAEC' => 'waec',
                          'NECO' => 'neco',
                          'Post UTME' => 'post-utme',
                          'School Desk (University)' => 'university',
                          _ => 'jamb',
                        };
                        final List<String> next = _slugs;
                        _subject =
                            next.contains(_subject) ? _subject : next.firstOrNull ?? '';
                      }),
                    ),
                    _FieldLabel('Examination Year'),
                    _PickerField(
                      value: _year,
                      items: _years,
                      onChanged: (String v) => setState(() => _year = v),
                    ),
                    _FieldLabel('Question type'),
                    _PickerField(
                      value: _qType,
                      items: const <String>['All', 'Objective', 'Theory'],
                      onChanged: (String v) => setState(() => _qType = v),
                    ),
                    _FieldLabel('Question Topic'),
                    // Topic pinning arrives with the syllabus map bridge;
                    // All stays the honest default.
                    _PickerField(
                      value: 'All',
                      items: const <String>['All'],
                      enabled: false,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 24),
                    // ---- Start Study ----------------------------------
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _starting ? null : _start,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: context.inverseChip,
                          foregroundColor: context.onInverseChip,
                        ),
                        child: _starting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Start Study',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 7),
      child: Text(text,
          style: RenanceText.bodyMedium.copyWith(fontSize: 15.5)),
    );
  }
}

/// The white outlined dropdown, Myschool's form field grammar.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.firstOrNull,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down,
              size: 24, color: context.textSecondary),
          dropdownColor: context.cardLowest,
          hint: Text(value,
              style: RenanceText.bodyBase.copyWith(
                  color: enabled ? null : context.textSecondary)),
          items: <DropdownMenuItem<String>>[
            for (final String it in items)
              DropdownMenuItem<String>(
                value: it,
                child: Text(it,
                    style: RenanceText.bodyBase.copyWith(fontSize: 15)),
              ),
          ],
          onChanged: enabled
              ? (String? v) {
                  if (v != null) onChanged(v);
                }
              : null,
        ),
      ),
    );
  }
}
