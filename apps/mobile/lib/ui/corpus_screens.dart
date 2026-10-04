import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'renance_logo.dart' show LogoActivityIndicator;
import 'theme.dart';

/// The national curriculum bank (scheme of work + lesson notes) served
/// straight from the codebase corpus through the study API. Founder
/// directive: the corpus lives in the repo, never in Neon, so this
/// browser reads it directly and caches it in memory for the session.
///
/// Doctrine for school accounts in the app: syllabus, scheme of work
/// and notes are exactly what the corpus offers, and the note reader
/// keeps the BLACK & WHITE paper look of the printed handouts.
class CorpusBrowserScreen extends StatefulWidget {
  const CorpusBrowserScreen({super.key});

  @override
  State<CorpusBrowserScreen> createState() => _CorpusBrowserScreenState();
}

class _CorpusBrowserScreenState extends State<CorpusBrowserScreen> {
  List<CorpusClassModel>? _classes;
  CorpusClassModel? _class;
  CorpusSubjectModel? _subject;
  int _term = 1;
  bool _loadingTerms = false;
  String? _error;
  List<CorpusSchemeTermModel> _schemes = const <CorpusSchemeTermModel>[];
  List<CorpusNotesTermModel> _notes = const <CorpusNotesTermModel>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    final List<CorpusClassModel> classes = await school.loadCorpusClasses();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _error = classes.isEmpty ? (school.lastError ?? 'The corpus is empty.') : null;
      _class = classes.isNotEmpty ? classes.first : null;
    });
    _pickSubject(_class?.subjects.isNotEmpty == true ? _class!.subjects.first : null);
  }
  Future<void> _pickClass(CorpusClassModel? cls) async {
    setState(() {
      _class = cls;
      _subject = null;
      _schemes = const <CorpusSchemeTermModel>[];
      _notes = const <CorpusNotesTermModel>[];
    });
    _pickSubject(cls?.subjects.isNotEmpty == true ? cls!.subjects.first : null);
  }

  Future<void> _pickSubject(CorpusSubjectModel? sub) async {
    setState(() => _subject = sub);
    if (sub == null || _class == null) return;
    final List<int> available = sub.availableTerms;
    setState(() => _term = available.contains(_term) ? _term : (available.isNotEmpty ? available.first : 1));
    await _loadTerms();
  }

  Future<void> _loadTerms() async {
    final String? classId = _class?.id;
    final String? subjectId = _subject?.id;
    if (classId == null || subjectId == null) return;
    setState(() => _loadingTerms = true);
    final SchoolController school = context.read<SchoolController>();
    final List<CorpusSchemeTermModel> schemes = await school.loadCorpusSchemes(classId, subjectId);
    final List<CorpusNotesTermModel> notes = await school.loadCorpusNotes(classId, subjectId);
    if (!mounted) return;
    setState(() {
      _schemes = schemes;
      _notes = notes;
      _loadingTerms = false;
      _error = schemes.isEmpty && notes.isEmpty ? school.lastError : null;
    });
  }

  String _termName(int t) => switch (t) {
        1 => 'First term',
        2 => 'Second term',
        _ => 'Third term',
      };

  @override
  Widget build(BuildContext context) {
    final List<CorpusClassModel> classes = _classes ?? const <CorpusClassModel>[];
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(title: const Text('Curriculum bank')),
      body: _classes == null
          ? Center(child: const LogoActivityIndicator(label: 'Opening the bank…'))
          : classes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _error ?? 'The national corpus is not available right now.',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodyBase.copyWith(color: context.textSecondary),
                    ),
                  ),
                )
              : _buildBrowser(context, classes),
    );
  }

  Widget _buildBrowser(BuildContext context, List<CorpusClassModel> classes) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Scheme of work and lesson notes for every class, fetched straight from the Renance codebase.',
          style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 14),
        _classDropdown(classes),
        const SizedBox(height: 10),
        _subjectDropdown(),
        const SizedBox(height: 14),
        if (_subject != null && _subject!.availableTerms.length > 1) ...<Widget>[
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              for (final int t in _subject!.availableTerms)
                ButtonSegment<int>(value: t, label: Text(_termName(t))),
            ],
            selected: <int>{_term},
            onSelectionChanged: (Set<int> s) => setState(() => _term = s.first),
          ),
          const SizedBox(height: 16),
        ],
        if (_loadingTerms)
          const Center(child: LogoActivityIndicator(label: 'Loading the term…'))
        else ...<Widget>[
          _schemeSection(context),
          const SizedBox(height: 16),
          _notesSection(context),
        ],
      ],
    );
  }

  Widget _classDropdown(List<CorpusClassModel> classes) {
    return DropdownButtonFormField<String>(
      initialValue: _class?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Class',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: <DropdownMenuItem<String>>[
        for (final CorpusClassModel c in classes)
          DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
      ],
      onChanged: (String? v) {
        final CorpusClassModel cls = classes.firstWhere((CorpusClassModel c) => c.id == v);
        _pickClass(cls);
      },
    );
  }

  Widget _subjectDropdown() {
    final List<CorpusSubjectModel> subjects = _class?.subjects ?? const <CorpusSubjectModel>[];
    return DropdownButtonFormField<String>(
      initialValue: _subject?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Subject',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: <DropdownMenuItem<String>>[
        for (final CorpusSubjectModel s in subjects)
          DropdownMenuItem<String>(value: s.id, child: Text(s.name)),
      ],
      onChanged: (String? v) {
        final CorpusSubjectModel sub = subjects.firstWhere((CorpusSubjectModel s) => s.id == v);
        _pickSubject(sub);
      },
    );
  }

  Widget _schemeSection(BuildContext context) {
    final CorpusSchemeTermModel? scheme =
        _schemes.where((CorpusSchemeTermModel s) => s.term == _term).firstOrNull;
    if (scheme == null || scheme.weeks.isEmpty) {
      return Text(
        'No scheme of work for ${_termName(_term)} yet.',
        style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_termName(_term)} scheme of work',
              style: RenanceText.sectionTitle.copyWith(color: context.ink),
            ),
            const SizedBox(height: 8),
            for (final SchemeWeek w in scheme.weeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Week ${w.week}: ${w.topic}',
                  style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notesSection(BuildContext context) {
    final CorpusNotesTermModel? notes =
        _notes.where((CorpusNotesTermModel n) => n.term == _term).firstOrNull;
    if (notes == null || notes.topics.isEmpty) {
      return Text(
        'No lesson notes for ${_termName(_term)} yet.',
        style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${_termName(_term)} lesson notes',
          style: RenanceText.sectionTitle.copyWith(color: context.ink),
        ),
        const SizedBox(height: 8),
        for (final SchoolTopicInfo t in notes.topics)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.bodyBase.copyWith(color: context.ink, fontWeight: FontWeight.w600),
                ),
                subtitle: t.week > 0
                    ? Text(
                        'Week ${t.week}',
                        style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 12),
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openNote(t),
              ),
            ),
          ),
      ],
    );
  }

  void _openNote(SchoolTopicInfo topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CorpusNoteReaderScreen(
          topic: topic,
          className: _class?.name ?? '',
          subject: _subject?.name ?? '',
          termName: _termName(_term),
        ),
      ),
    );
  }
}

/// The corpus note reader: the same BLACK & WHITE paper experience as
/// the school pack note reader, headed with the corpus branding.
class CorpusNoteReaderScreen extends StatelessWidget {
  const CorpusNoteReaderScreen({
    super.key,
    required this.topic,
    required this.className,
    required this.subject,
    required this.termName,
  });

  final SchoolTopicInfo topic;
  final String className;
  final String subject;
  final String termName;

  @override
  Widget build(BuildContext context) {
    const Color paper = Colors.white;
    const Color ink = Colors.black;

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
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
            'Renance national curriculum corpus',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
