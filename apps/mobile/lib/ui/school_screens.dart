/// The school workspace (For Schools) in the app.
///
/// Doctrine: management and teachers get EXACTLY syllabus, scheme of
/// work and notes here - results, teachers and enrollment stay on the
/// web. The note reader is deliberately BLACK & WHITE ONLY (ink on
/// paper), matching the printed PDF handouts the web portal exports.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'renance_logo.dart' show LogoActivityIndicator;
import 'theme.dart';

/// Home for signed-in school staff (management or teacher). Loads the
/// memberships, downloads the pack for the active school and opens the
/// shared read-only browse experience.
class SchoolHomeScreen extends StatefulWidget {
  const SchoolHomeScreen({super.key});

  @override
  State<SchoolHomeScreen> createState() => _SchoolHomeScreenState();
}

class _SchoolHomeScreenState extends State<SchoolHomeScreen> {
  bool _booted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadContexts();
    await school.refreshPacks();
    if (!mounted) return;

    if (school.contexts.isEmpty) {
      // Maybe the pack was downloaded earlier under this account.
      if (school.packs.isEmpty) {
        setState(() {
          _error =
              'No school membership found for this account. Sign in with the account your school created, or register the school on the web.';
          _booted = true;
        });
        return;
      }
    }

    // Ensure the first membership's pack is on the device.
    if (school.contexts.isNotEmpty) {
      final String id = school.contexts.first.school.id;
      if (!school.packs.containsKey(id)) {
        await school.download(id);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _booted = true);
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();

    if (!_booted && school.contexts.isEmpty) {
      return Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(title: const Text('School workspace')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const LogoActivityIndicator(label: 'Opening your school…'),
              if (school.lastError != null) ...<Widget>[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    school.lastError!,
                    textAlign: TextAlign.center,
                    style: RenanceText.bodySecondary.copyWith(color: context.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (school.packs.isEmpty) {
      return Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(title: const Text('School workspace')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.school_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Download your school pack to browse the syllabus, scheme of work, notes and exam bank offline.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodyBase.copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: school.contexts.isEmpty
                      ? null
                      : () => school.download(school.contexts.first.school.id),
                  child: const Text('Download school pack'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final SchoolPack pack =
        school.packs[school.contexts.firstOrNull?.school.id] ??
            school.packs.values.first;
    return SchoolPackViewerScreen(pack: pack, embeddedHome: true);
  }
}

/// The read-only school pack browser: class → subject → term → topic →
/// note. Notes render BLACK ON WHITE regardless of app theme - the
/// print-house look, identical to the PDF handouts.
class SchoolPackViewerScreen extends StatefulWidget {
  const SchoolPackViewerScreen({super.key, required this.pack, this.embeddedHome = false});

  final SchoolPack pack;
  final bool embeddedHome;

  @override
  State<SchoolPackViewerScreen> createState() => _SchoolPackViewerScreenState();
}

class _SchoolPackViewerScreenState extends State<SchoolPackViewerScreen> {
  String? _classId;
  String? _subjectId;
  bool _bankView = false;

  @override
  void initState() {
    super.initState();
    final List<SchoolPackSyllabus> branches = widget.pack.syllabus;
    if (branches.isNotEmpty) {
      _classId = branches.first.classId;
      _subjectId = branches.first.subjectId;
    }
  }

  List<SchoolPackSyllabus> get _branches => widget.pack.syllabus;

  List<SchoolPackSyllabus> get _classBranches => _branches
      .where((SchoolPackSyllabus b) => _classId == null || b.classId == _classId)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final List<String> classNames = <String>{
      for (final SchoolPackSyllabus b in _branches) b.className,
    }.toList()..sort();

    final SchoolPackSyllabus? branch =
        _branches.where((SchoolPackSyllabus b) => b.classId == _classId && b.subjectId == _subjectId).firstOrNull;

    final List<String> subjectNames = <String>{
      for (final SchoolPackSyllabus b in _classBranches) b.subject,
    }.toList()..sort();

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(widget.embeddedHome ? 'School workspace' : widget.pack.school.name),
        actions: <Widget>[
          if (!widget.embeddedHome)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 22),
              tooltip: 'Update pack',
              onPressed: () async {
                final SchoolController school = context.read<SchoolController>();
                await school.loadContexts();
                final SchoolContextModel? ctx = school.contexts
                    .where((SchoolContextModel c) => c.school.id == widget.pack.school.id)
                    .firstOrNull;
                if (ctx != null && context.mounted) {
                  await school.download(ctx.school.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('School pack refreshed.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _branches.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This school has no syllabus content yet - management can build it on the web portal.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodyBase.copyWith(color: context.textSecondary),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // The staff desk: the live services riding on top of the
                // offline library. Attendance marks any class a teacher
                // covers; the enrollment desk is management's to fill.
                _StaffDeskCard(schoolId: widget.pack.school.id),
                const SizedBox(height: 12),
                // Compact stats strip: what the pack carries, so staff
                // see the size of their offline library at a glance.
                Row(
                  children: <Widget>[
                    _PackStat(label: 'Topics', value: widget.pack.topicCount),
                    const SizedBox(width: 8),
                    _PackStat(label: 'Notes subjects', value: _branches.length),
                    const SizedBox(width: 8),
                    _PackStat(label: 'Bank Qs', value: widget.pack.examBank.length),
                  ],
                ),
                const SizedBox(height: 12),
                // Two reading modes: the syllabus tree, or the exam
                // question bank riding in the pack.
                if (widget.pack.examBank.isNotEmpty) ...<Widget>[
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                          value: false, icon: Icon(Icons.menu_book_outlined, size: 18), label: Text('Syllabus')),
                      ButtonSegment<bool>(
                          value: true, icon: Icon(Icons.quiz_outlined, size: 18), label: Text('Exam bank')),
                    ],
                    selected: <bool>{_bankView},
                    onSelectionChanged: (Set<bool> s) => setState(() => _bankView = s.first),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_bankView)
                  ..._bankSection()
                else ...<Widget>[
                _dropdown(
                  value: _classId,
                  items: classNames,
                  labelFor: (String v) => v,
                  hint: 'Class',
                  onChanged: (String? v) => setState(() {
                    _classId = v;
                    final List<SchoolPackSyllabus> remaining = _branches
                        .where((SchoolPackSyllabus b) => b.classId == v)
                        .toList(growable: false);
                    _subjectId = remaining.isNotEmpty ? remaining.first.subjectId : null;
                  }),
                ),
                const SizedBox(height: 10),
                _dropdown(
                  value: _subjectId,
                  items: subjectNames,
                  labelFor: (String v) => v,
                  hint: 'Subject',
                  onChanged: (String? v) => setState(() => _subjectId = v),
                ),
                const SizedBox(height: 16),
                if (branch == null)
                  Text(
                    'No syllabus for this selection yet.',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                  )
                else
                  ..._termsInOrder(branch),
                ],
              ],
            ),
    );
  }

  /// The offline exam bank: every question in the pack, grouped by
  /// subject, with the answer reveal kept one tap away so the sheet
  /// can be used as a quick oral quiz in class.
  List<Widget> _bankSection() {
    if (widget.pack.examBank.isEmpty) {
      return <Widget>[
        Text(
          'The exam bank is empty. Management can pour the starter bank on the web portal.',
          style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
        ),
      ];
    }
    final Map<String, List<SchoolPackExamQuestion>> bySubject =
        <String, List<SchoolPackExamQuestion>>{};
    for (final SchoolPackExamQuestion q in widget.pack.examBank) {
      (bySubject[q.subject.isEmpty ? 'General' : q.subject] ??= <SchoolPackExamQuestion>[])
          .add(q);
    }
    final List<String> subjects = bySubject.keys.toList()..sort();
    return <Widget>[
      for (final String s in subjects) ...<Widget>[
        Text(
          s,
          style: RenanceText.sectionTitle.copyWith(color: context.ink),
        ),
        const SizedBox(height: 8),
        for (final SchoolPackExamQuestion q in bySubject[s]!)
          _BankQuestionCard(question: q),
        const SizedBox(height: 14),
      ],
    ];
  }

  List<Widget> _termsInOrder(SchoolPackSyllabus branch) {
    final List<SchoolSyllabusTerm> terms = branch.terms.toList()
      ..sort((SchoolSyllabusTerm a, SchoolSyllabusTerm b) => a.term.compareTo(b.term));
    return <Widget>[
      for (final SchoolSyllabusTerm t in terms) ...<Widget>[
        _TermCard(
          term: t,
          className: branch.className,
          subject: branch.subject,
        ),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required String Function(String) labelFor,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: <DropdownMenuItem<String>>[
        for (final String it in items)
          DropdownMenuItem<String>(value: it, child: Text(labelFor(it))),
      ],
      onChanged: onChanged,
    );
  }
}

/// One term: the scheme of work strip + the topic list opening the
/// black & white note reader.
class _TermCard extends StatelessWidget {
  const _TermCard({required this.term, required this.className, required this.subject});

  final SchoolSyllabusTerm term;
  final String className;
  final String subject;

  String get _termName {
    switch (term.term) {
      case 1:
        return 'First Term';
      case 2:
        return 'Second Term';
      default:
        return 'Third Term';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$_termName${term.session.isEmpty ? '' : ' · ${term.session}'}',
              style: RenanceText.sectionTitle.copyWith(color: context.ink),
            ),
            if (term.schemeOfWork.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Scheme of work',
                style: RenanceText.labelMono.copyWith(color: context.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 4),
              ...term.schemeOfWork.map(
                (SchemeWeek w) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Week ${w.week}: ${w.topic}',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 12.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (term.topics.isEmpty)
              Text(
                'No topics yet.',
                style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
              )
            else
              ...term.topics.map(
                (SchoolTopicInfo t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(
                    t.title,
                    style: RenanceText.bodyBase.copyWith(color: context.ink, fontWeight: FontWeight.w500),
                  ),
                  subtitle: t.week > 0
                      ? Text('Week ${t.week}', style: RenanceText.caption.copyWith(color: context.textSecondary))
                      : null,
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _NoteReaderScreen(
                      topic: t,
                      schoolName: '',
                      className: className,
                      subject: subject,
                      termName: _termName,
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One small stat chip for the pack stats strip.
class _PackStat extends StatelessWidget {
  const _PackStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: context.textSecondary.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$value',
              style: RenanceText.sectionTitle.copyWith(color: context.ink),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: RenanceText.labelMono.copyWith(color: context.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bank question card: the options stay visible, the correct
/// answer and explanation reveal on tap, so a teacher can run a quick
/// oral quiz from the offline pack.
class _BankQuestionCard extends StatefulWidget {
  const _BankQuestionCard({required this.question});

  final SchoolPackExamQuestion question;

  @override
  State<_BankQuestionCard> createState() => _BankQuestionCardState();
}

class _BankQuestionCardState extends State<_BankQuestionCard> {
  bool _revealed = false;

  String get _termName {
    switch (widget.question.term) {
      case 1:
        return 'First Term';
      case 2:
        return 'Second Term';
      default:
        return 'Third Term';
    }
  }

  @override
  Widget build(BuildContext context) {
    final SchoolPackExamQuestion q = widget.question;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _revealed = !_revealed),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${q.marks > 1 ? '${q.marks} marks' : '1 mark'} · $_termName${q.band.isEmpty ? '' : ' · ${q.band}'}',
                style: RenanceText.labelMono.copyWith(color: context.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                q.question,
                style: RenanceText.bodyBase.copyWith(color: context.ink),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${String.fromCharCode(65 + i)}.  ',
                        style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                      ),
                      Expanded(
                        child: Text(
                          q.options[i],
                          style: RenanceText.bodySecondary.copyWith(
                            color: _revealed && i == q.answerIndex
                                ? context.ink
                                : context.textSecondary,
                            fontWeight: _revealed && i == q.answerIndex
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_revealed && q.explanation.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  q.explanation,
                  style: RenanceText.bodySecondary.copyWith(
                    color: context.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The note reader - deliberately BLACK & WHITE ONLY: white paper, black
/// ink, no theme colours. The same look as the printed handout.
class _NoteReaderScreen extends StatelessWidget {
  const _NoteReaderScreen({
    required this.topic,
    required this.schoolName,
    required this.className,
    required this.subject,
    required this.termName,
  });

  final SchoolTopicInfo topic;
  final String schoolName;
  final String className;
  final String subject;
  final String termName;

  @override
  Widget build(BuildContext context) {
    // Paper chrome: pure white ground, pure black ink - in BOTH tiers.
    const Color paper = Colors.white;
    const Color ink = Colors.black;

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        // The reader keeps the paper look even in dark mode: a white
        // app bar with black icons, exactly like the handout header.
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0.5,
        title: Text(
          topic.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: <Widget>[
          Text(
            '$className · $subject · $termName',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          if (topic.week > 0)
            Text(
              'Week ${topic.week}',
              textAlign: TextAlign.center,
              style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
            ),
          const SizedBox(height: 16),
          Container(height: 1, color: ink),
          const SizedBox(height: 20),
          for (final String para in topic.content.split(RegExp(r'\n\s*\n')))
            if (para.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  para.trim().replaceAll(RegExp(r'\s+'), ' '),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 15.5,
                    height: 1.65,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          const SizedBox(height: 24),
          Container(height: 1, color: ink),
          const SizedBox(height: 10),
          Text(
            schoolName.isEmpty ? 'Renance school notes' : schoolName,
            textAlign: TextAlign.center,
            style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ============================================================ attendance

/// The daily register: pick a class, mark every pupil, save. Management
/// marks any class; a teacher marks the classes assigned to them.
class SchoolAttendanceScreen extends StatefulWidget {
  const SchoolAttendanceScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<SchoolAttendanceScreen> createState() => _SchoolAttendanceScreenState();
}

class _SchoolAttendanceScreenState extends State<SchoolAttendanceScreen> {
  String? _classId;
  DateTime _day = DateTime.now();
  bool _booted = false;

  String get _dayISO {
    final String m = _day.month.toString().padLeft(2, '0');
    final String d = _day.day.toString().padLeft(2, '0');
    return '${_day.year}-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadRoster(widget.schoolId);
    if (!mounted) return;
    if (school.classes.isNotEmpty && _classId == null) {
      _classId = school.classes.first.id;
      await school.loadAttendanceDay(widget.schoolId, _classId!, _dayISO);
    }
    if (mounted) setState(() => _booted = true);
  }

  Future<void> _pickDay() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
    final SchoolController school = context.read<SchoolController>();
    if (_classId != null) {
      await school.loadAttendanceDay(widget.schoolId, _classId!, _dayISO);
    }
  }

  Future<void> _save() async {
    final SchoolController school = context.read<SchoolController>();
    final int? saved =
        await school.saveAttendanceDay(widget.schoolId, _classId ?? '', _dayISO);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? (school.lastError ?? 'Could not save the register.')
              : 'Register saved for $saved ${saved == 1 ? 'pupil' : 'pupils'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final List<SchoolStudentModel> roster = school.roster
        .where((SchoolStudentModel s) => s.status == 'active')
        .toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(title: const Text('Daily register')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.ink,
        foregroundColor: context.pageBg,
        icon: const Icon(Icons.check),
        label: const Text('Save register'),
        onPressed: _classId == null || roster.isEmpty ? null : _save,
      ),
      body: _booted && school.rosterLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _classId,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<String>>[
                          for (final SchoolClassInfo c in school.classes)
                            DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (String? v) async {
                          setState(() => _classId = v);
                          if (v != null) {
                            await school.loadAttendanceDay(
                                widget.schoolId, v, _dayISO);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(_dayISO.substring(5)),
                      onPressed: _pickDay,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // One tap fills every empty cell: the classic start of
                // the morning register.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Mark the rest present'),
                    onPressed: roster.isEmpty
                        ? null
                        : () => school.markAllPresent(roster),
                  ),
                ),
                if (school.rosterError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      school.rosterError!,
                      style: RenanceText.bodySecondary
                          .copyWith(color: context.error),
                    ),
                  ),
                const SizedBox(height: 4),
                if (roster.isEmpty && !school.rosterLoading)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No active pupils in this class yet. Enroll them under Student details.',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodyBase
                          .copyWith(color: context.textSecondary),
                    ),
                  )
                else
                  ...<Widget>[
                    for (final SchoolStudentModel s in roster)
                      _AttendanceRow(student: s),
                  ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

/// One pupil on the register: name, admission number and the four-way
/// mark. Strict black and white: the school desk never takes theme colors.
class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.student});

  final SchoolStudentModel student;

  static const Map<String, String> _labels = <String, String>{
    'present': 'Present',
    'late': 'Late',
    'absent': 'Absent',
    'excused': 'Excused',
  };

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final AttendanceEntryModel? mark = school.marks[student.id];
    final String status = mark?.status ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    student.fullName,
                    style: RenanceText.bodyBase
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  student.admissionNo,
                  style: RenanceText.bodySecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final MapEntry<String, String> e in _labels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: status == e.key,
                    onSelected: (_) => context.read<SchoolController>().mark(
                          student.id,
                          e.key,
                          note: mark?.note ?? '',
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================== student details

/// The enrollment desk: browse a class roster, add pupils with full
/// details, edit any field. Writes stay management-only; teachers read.
class SchoolStudentDetailsScreen extends StatefulWidget {
  const SchoolStudentDetailsScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<SchoolStudentDetailsScreen> createState() =>
      _SchoolStudentDetailsScreenState();
}

class _SchoolStudentDetailsScreenState
    extends State<SchoolStudentDetailsScreen> {
  String? _classId;
  String _query = '';
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadRoster(widget.schoolId);
    if (!mounted) return;
    if (school.classes.isNotEmpty && _classId == null) {
      _classId = school.classes.first.id;
      await school.loadRoster(widget.schoolId, classId: _classId!);
    }
    if (mounted) setState(() => _booted = true);
  }

  Future<void> _editStudent(SchoolStudentModel? existing) async {
    final SchoolController school = context.read<SchoolController>();
    if (school.classes.isEmpty) return;
    final SchoolStudentModel? saved = await showModalBottomSheet<
        SchoolStudentModel>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _StudentEditorSheet(
        schoolId: widget.schoolId,
        classes: school.classes,
        initialClassId: _classId ?? school.classes.first.id,
        existing: existing,
      ),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${saved.fullName} saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final String q = _query.trim().toLowerCase();
    final List<SchoolStudentModel> roster = school.roster
        .where((SchoolStudentModel s) =>
            q.isEmpty ||
            s.fullName.toLowerCase().contains(q) ||
            s.admissionNo.toLowerCase().contains(q))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(title: const Text('Student details')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.ink,
        foregroundColor: context.pageBg,
        icon: const Icon(Icons.person_add),
        label: const Text('Add student'),
        onPressed: () => _editStudent(null),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _classId,
            decoration: const InputDecoration(
              labelText: 'Class',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: <DropdownMenuItem<String>>[
              for (final SchoolClassInfo c in school.classes)
                DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (String? v) async {
              setState(() => _classId = v);
              await school.loadRoster(widget.schoolId, classId: v ?? '');
            },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name or admission number',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          if (school.rosterError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                school.rosterError!,
                style: RenanceText.bodySecondary.copyWith(color: context.error),
              ),
            ),
          if (!school.rosterLoading && roster.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _booted
                    ? 'No student matches. Use Add student to enroll one.'
                    : 'Loading the roster...',
                textAlign: TextAlign.center,
                style: RenanceText.bodyBase
                    .copyWith(color: context.textSecondary),
              ),
            )
          else
            ...<Widget>[
              for (final SchoolStudentModel s in roster)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      s.fullName,
                      style: RenanceText.bodyBase
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${s.admissionNo} · ${s.sex.isEmpty ? '-' : s.sex}'
                      '${s.guardianName.isEmpty ? '' : ' · Guardian: ${s.guardianName}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editStudent(s),
                  ),
                ),
            ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// The enrollment form sheet. Every field the web portal writes is here:
/// name, admission number, sex, date of birth and the guardian trio.
class _StudentEditorSheet extends StatefulWidget {
  const _StudentEditorSheet({
    required this.schoolId,
    required this.classes,
    required this.initialClassId,
    this.existing,
  });

  final String schoolId;
  final List<SchoolClassInfo> classes;
  final String initialClassId;
  final SchoolStudentModel? existing;

  @override
  State<_StudentEditorSheet> createState() => _StudentEditorSheetState();
}

class _StudentEditorSheetState extends State<_StudentEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.fullName ?? '');
  late final TextEditingController _admission =
      TextEditingController(text: widget.existing?.admissionNo ?? '');
  late final TextEditingController _dob =
      TextEditingController(text: widget.existing?.dob ?? '');
  late final TextEditingController _guardianName =
      TextEditingController(text: widget.existing?.guardianName ?? '');
  late final TextEditingController _guardianPhone =
      TextEditingController(text: widget.existing?.guardianPhone ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.existing?.address ?? '');
  late String _classId = widget.existing?.classId.isNotEmpty == true
      ? widget.existing!.classId
      : widget.initialClassId;
  late String _sex = widget.existing?.sex ?? 'M';
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  Future<void> _save() async {
    final String name = _name.text.trim();
    final String admission = _admission.text.trim();
    if (name.isEmpty || admission.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name and admission number are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    final SchoolController school = context.read<SchoolController>();
    final SchoolStudentModel? saved = await school.saveStudent(
      widget.schoolId,
      isNew: _isNew,
      session: '2025/2026',
      student: SchoolStudentModel(
        id: widget.existing?.id ?? '',
        fullName: name,
        admissionNo: admission,
        classId: _classId,
        sex: _sex,
        dob: _dob.text.trim(),
        guardianName: _guardianName.text.trim(),
        guardianPhone: _guardianPhone.text.trim(),
        address: _address.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(school.lastError ?? 'Could not save the student.')),
      );
      return;
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isNew ? 'Enroll a student' : 'Edit student details',
              style: RenanceText.bodyBase.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _admission,
              decoration: const InputDecoration(
                labelText: 'Admission number',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _classId,
              decoration: const InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: <DropdownMenuItem<String>>[
                for (final SchoolClassInfo c in widget.classes)
                  DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (String? v) => setState(() => _classId = v ?? _classId),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'M', label: Text('Male')),
                ButtonSegment<String>(value: 'F', label: Text('Female')),
              ],
              selected: <String>{_sex},
              onSelectionChanged: (Set<String> v) =>
                  setState(() => _sex = v.first),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dob,
              decoration: const InputDecoration(
                labelText: 'Date of birth (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _guardianName,
              decoration: const InputDecoration(
                labelText: 'Guardian name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _guardianPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Guardian phone',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Home address',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_isNew ? 'Enroll student' : 'Save changes'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================ staff desk

/// The two live desk services a school user opens straight from the
/// workspace home: the daily register and the enrollment desk.
class _StaffDeskCard extends StatelessWidget {
  const _StaffDeskCard({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final String role =
        school.contexts.firstOrNull?.member.role ?? 'teacher';
    final bool isManagement = role == 'management';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Staff desk',
              style: RenanceText.bodyBase.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isManagement
                  ? 'Mark the daily register and keep every pupil record current.'
                  : 'Mark the daily register for the classes you cover.',
              style: RenanceText.bodySecondary,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Attendance'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SchoolAttendanceScreen(schoolId: schoolId),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('Students'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SchoolStudentDetailsScreen(schoolId: schoolId),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
