/// Study Past Questions - the school app's study page, Renance edition,
/// 1:1 with the website's /study-past-questions setup.
///
/// The Renance top bar (round back + title over the flat page), the
/// emerald "Update Questions" banner that opens the Select & Update
/// page, and the five-pick form - Subject, Examination Type,
/// Examination Year, Question type, Question Topic - with the big
/// "Start Study" button.
///
/// Start Study opens the reader (study_reader_screen.dart): untimed,
/// browsable question cards over the whole bank with year/type/topic
/// filters and explanations - the website's reader experience. No
/// compose machinery, no submit ceremony.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../papers.dart' show subjectName;
import '../storage.dart';
import 'exam_mode_setup_screen.dart';
import 'msymbols.dart';
import 'study_reader_screen.dart';
import 'tactile.dart';
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
  String _topic = ''; // '' = All topics; options come from the bank
  List<String> _topics = const <String>[];
  bool _topicsLoading = false;
  bool _starting = false;

  /// The backing bank pack of the picked subject ("jamb-biology-bank",
  /// a uni course pack, a post-utme bank) - the reader reads it
  /// directly, exactly like the website's reader does.
  String get _bankCode {
    if (_body == 'university' || _body == 'post-utme') return _subject;
    return '$_body-$_subject-bank';
  }

  ExamMeta? get _bankMeta {
    for (final ExamMeta e in _exams) {
      if (e.code == _bankCode) return e;
    }
    return null;
  }

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
      _loadTopics();
    });
  }

  List<ExamMeta> get _exams => context.read<SyncController>().exams;

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

  /// Years of the SELECTED subject's bank (the manifest's per-pack
  /// year list) - the web's Year dropdown semantics. The old pool
  /// merged every body bank's years, offering years the picked bank
  /// never carried (a year pick then filtered everything out server-
  /// side or matched nothing - the founder's "year select does not
  /// work" report).
  List<String> get _years {
    final List<int> years = _bankMeta?.years ?? const <int>[];
    final List<int> sorted = years.toList()..sort((int a, int b) => b.compareTo(a));
    return <String>['All', ...sorted.map((int y) => '$y')];
  }

  /// Topic options for the picked subject, read from the bank pack
  /// itself (local first, fetch-and-cache as fallback) - the web's
  /// Topic dropdown. Fails soft: "All topics" only.
  Future<void> _loadTopics() async {
    if (_subject.isEmpty) {
      setState(() => _topics = const <String>[]);
      return;
    }
    setState(() => _topicsLoading = true);
    try {
      final Bundle? bundle = await context
          .read<SyncController>()
          .loadBank(_bankCode, _bankMeta?.bundleSha256 ?? '');
      if (!mounted) return;
      final Set<String> set = <String>{};
      for (final BundleQuestion q in bundle?.questions ?? const <BundleQuestion>[]) {
        if (q.topic.isNotEmpty) set.add(q.topic);
      }
      final List<String> list = set.toList()..sort();
      setState(() {
        _topics = list.take(400).toList();
        _topicsLoading = false;
        _topic = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topics = const <String>[];
        _topicsLoading = false;
        _topic = '';
      });
    }
  }

  /// Start Study opens the READER (founder: make the app's study look
  /// like the website's) - untimed browsable cards over the whole bank
  /// with year/type/topic filters and explanations, never a submitted
  /// quiz. The year pin rides along and the reader filters the bank's
  /// own question data client-side, so "2023" shows exactly 2023's
  /// questions - the old composed-paper path ignored the pin.
  void _start() {
    if (_subject.isEmpty || _starting) return;
    setState(() => _starting = true);
    final int? year = _year == 'All' ? null : int.tryParse(_year);
    final String topic = _topic;
    final String title = '${_subjectLabel(_subject)} · Study';
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => StudyReaderScreen(
              bank: _bankCode,
              sha: _bankMeta?.bundleSha256 ?? '',
              title: title,
              initialYear: year,
              initialTopic: topic,
              initialQt: switch (_qType) {
                'Objective' => 'objective',
                'Theory' => 'theory',
                _ => 'all',
              },
            ),
          ),
        )
        .whenComplete(() {
      if (mounted) setState(() => _starting = false);
    });
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
            // ---- top bar: the Renance round back + title -----------
            // The off-system cream band and the outlined circle back
            // are gone (founder directive 2026-10-05: the study page
            // reads Renance now - flat surfaces, token colours, the
            // Stitch round back every other page wears).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: <Widget>[
                  TactileBackKey(
                    onTap: () => Navigator.of(context).pop(),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Study Past Questions',
                            style: RenanceText.sectionTitle
                                .copyWith(fontSize: 19)),
                        const SizedBox(height: 2),
                        Text(
                          'Get all exam questions from 1978 till date',
                          style: RenanceText.caption.copyWith(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(alignment: Alignment.center,
                    
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: RenanceColors.emerald,
                    ),
                    child: const MsIcon('menu_book',
                        size: 20, color: Colors.white),
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
                          color: RenanceColors.emerald
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: RenanceColors.emerald
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
                                  MsIcon('chevron_right',
                                      size: 17, color: context.ink),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: MsIcon('chevron_right',
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
                          color: context.textSecondary,
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
                        _year = 'All';
                      }),
                    ),
                    // Focus IS the exam type (founder rule): the study
                    // page opens on the student's active focus and never
                    // offers a switcher - the desk tiles deep-link the
                    // other foci.
                    _FocusChip(label: _bodyLabel),
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
                    // Topic options come straight from the picked bank
                    // (the web's Topic dropdown); fails soft to All.
                    _PickerField(
                      value: _topicsLoading
                          ? 'Loading topics…'
                          : _topic.isEmpty ? 'All topics' : _topic,
                      items: _topics,
                      enabled: _topics.isNotEmpty && !_topicsLoading,
                      onChanged: (String v) =>
                          setState(() => _topic = v),
                    ),
                    const SizedBox(height: 24),
                    // ---- Start Study ----------------------------------
                    TactileButton(
                      onPressed: _starting ? null : _start,
                      height: 54,
                      radius: BorderRadius.circular(12),
                      face: context.inverseChip,
                      onFace: context.onInverseChip,
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
          icon: MsIcon('arrow_drop_down',
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

/// The static focus chip replacing the old Examination Type picker: the
/// study page IS the focus's study page (founder rule).
class _FocusChip extends StatelessWidget {
  const _FocusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.ink.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          MsIcon('bookmark', size: 18, color: context.textMuted),
          const SizedBox(width: 10),
          Text(
            'Focus',
            style: RenanceText.bodyMedium.copyWith(color: context.textMuted),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              // The body tag pill rides the theme colour (founder
              // directive 2026-10-02) - the old ink bubble.
              color: context.inverseChip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              switch (label) {
                'POST-UTME' => 'Post UTME',
                'University Modules' => 'School Desk',
                _ => label,
              },
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.onInverseChip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
