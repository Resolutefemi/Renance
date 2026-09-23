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
