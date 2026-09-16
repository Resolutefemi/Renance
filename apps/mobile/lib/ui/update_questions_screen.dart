/// Select & Update Questions — the school app's question-update page,
/// Renance edition.
///
/// "Select subjects to download or update questions into your app."
/// Every selectable subject of the student's exam body becomes a card:
/// icon bubble, name, how many questions the bank carries, a checkbox
/// and a black "Update" pill per row. Select-All, a search field, the
/// "Last updated" stencil and the big bottom button that flips to
/// "Updating…" with per-pack progress while the chosen banks stream
/// down. All of it rides the real manifest + pack store, so updating
/// here is the same act as the sync bootstrap, just in the student's
/// hands.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'theme.dart';
class UpdateQuestionsScreen extends StatefulWidget {
  const UpdateQuestionsScreen({super.key});

  @override
  State<UpdateQuestionsScreen> createState() => _UpdateQuestionsScreenState();
}

class _UpdateQuestionsScreenState extends State<UpdateQuestionsScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  final Set<String> _selected = <String>{};
  final Set<String> _updating = <String>{};
  int _done = 0;
  bool _bulk = false;
  DateTime? _lastUpdated;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final SyncController sync = context.read<SyncController>();
    final StudentController student = context.read<StudentController>();
    final SessionStore session = context.read<SessionStore>();
    try {
      if (sync.exams.isEmpty) {
        await sync.bootstrap(profileExams: student.me?.profile?.exams ?? const <String>[]);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    final SharedPreferences prefs = session.prefs;
    final int ms = prefs.getInt('renance.lastQuestionUpdate') ?? 0;
    setState(() {
      _loading = false;
      _lastUpdated = ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    });
  }

  List<ExamMeta> _subjects(List<ExamMeta> exams) {
    final StudentController student = context.read<StudentController>();
    final String body = student.isTertiaryFocus
        ? 'University Modules'
        : (student.me?.profile?.exams.firstOrNull?.toUpperCase() ?? 'JAMB');
    final List<ExamMeta> mine = exams
        .where((ExamMeta e) =>
            e.body == body ||
            body.isEmpty ||
            (body == 'JAMB' && e.body == 'JAMB'))
        .toList();
    final List<ExamMeta> pool = mine.isNotEmpty ? mine : exams;
    if (_query.isEmpty) return pool;
    return pool
        .where((ExamMeta e) => e.title.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _stamp() async {
    final SessionStore session = context.read<SessionStore>();
    await session.prefs.setInt(
        'renance.lastQuestionUpdate', DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _lastUpdated = DateTime.now());
  }

  Future<void> _updateOne(ExamMeta exam) async {
    if (_updating.contains(exam.code)) return;
    final StudentController student = context.read<StudentController>();
    final ApiClient? api = student.api;
    if (api == null) return;
    setState(() => _updating.add(exam.code));
    try {
      final Bundle bundle = await api.bundle(exam.code);
      await student.store.savePack(bundle, exam.bundleSha256);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${exam.title}: ${bundle.questionCount} questions '
                'downloaded'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${exam.title}: ${e.message}')),
        );
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _updating.remove(exam.code);
      _done++;
    });
  }

  Future<void> _updateSelected() async {
    final List<ExamMeta> subjects = _subjects(
        context.read<SyncController>().exams);
    final List<ExamMeta> chosen = _selectAll
        ? subjects
        : subjects.where((ExamMeta e) => _selected.contains(e.code)).toList();
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one subject first.')),
      );
      return;
    }
    setState(() {
      _bulk = true;
      _done = 0;
    });
    for (final ExamMeta e in chosen) {
      await _updateOne(e);
      if (!mounted) return;
    }
    await _stamp();
    if (!mounted) return;
    setState(() => _bulk = false);
  }

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    final StudentController student = context.watch<StudentController>();
    final List<ExamMeta> subjects = _subjects(sync.exams);
    final Set<String> downloaded = student.downloaded;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.outlineVariant),
                          color: context.card,
                        ),
                        child: Icon(Icons.arrow_back,
                            size: 19, color: context.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: <Widget>[
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: RenanceText.bodySecondary.copyWith(
                                    color: context.textSecondary)),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: <Widget>[
                            Text('Select & Update Questions',
                                style: RenanceText.displayLg.copyWith(
                                    fontSize: 25)),
                            const SizedBox(height: 6),
                            Text(
                              'Select subjects to download or update '
                              'questions into your app.',
                              style: RenanceText.bodySecondary.copyWith(
                                color: context.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Select All row.
                            Row(
                              children: <Widget>[
                                Checkbox(
                                  value: _selectAll,
                                  onChanged: (bool? v) => setState(() {
                                    _selectAll = v ?? false;
                                    if (_selectAll) {
                                      _selected.addAll(
                                          subjects.map((ExamMeta e) => e.code));
                                    } else {
                                      _selected.clear();
                                    }
                                  }),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('Select All Subjects',
                                          style: RenanceText.bodyMedium),
                                      Text(
                                        '(requires more data and storage '
                                        'space)',
                                        style: RenanceText.caption.copyWith(
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Search subjects field.
                            TextField(
                              onChanged: (String v) =>
                                  setState(() => _query = v.trim().toLowerCase()),
                              decoration: InputDecoration(
                                hintText: 'Search subjects…',
                                prefixIcon: Icon(Icons.search,
                                    size: 20, color: context.outline),
                                filled: true,
                                fillColor: context.cardLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Subject cards.
                            for (final ExamMeta e in subjects)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SubjectUpdateCard(
                                  exam: e,
                                  downloaded: downloaded.contains(e.code),
                                  checked:
                                      _selected.contains(e.code) || _selectAll,
                                  updating: _updating.contains(e.code),
                                  onCheck: (bool v) => setState(() {
                                    if (v) {
                                      _selected.add(e.code);
                                    } else {
                                      _selected.remove(e.code);
                                      _selectAll = false;
                                    }
                                  }),
                                  onUpdate: () => _updateOne(e),
                                ),
                              ),
                            const SizedBox(height: 4),
                            // Last updated stencil.
                            Row(
                              children: <Widget>[
                                Text('Last updated ',
                                    style: RenanceText.bodyMedium.copyWith(
                                        fontSize: 14)),
                                Text(
                                  _lastUpdated == null
                                      ? 'never'
                                      : '${_lastUpdated!.year} '
                                          '${_month(_lastUpdated!.month)} '
                                          '${_lastUpdated!.day}',
                                  style: RenanceText.bodyMedium.copyWith(
                                    fontSize: 14,
                                    color: const Color(0xFF3B5BDB),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
            ),
            // Sticky bottom action — "Update" flipping to "Updating…".
            if (!_loading && _error == null)
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border(
                    top: BorderSide(
                      color: context.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _bulk ? null : _updateSelected,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: _bulk
                            ? context.outlineLight
                            : context.inverseChip,
                        foregroundColor: context.onInverseChip,
                      ),
                      icon: _bulk
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync, size: 19),
                      label: Text(
                        _bulk
                            ? 'Updating… ($_done)'
                            : 'Update Questions',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _month(int m) => const <String>[
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][m - 1];
}

/// One subject card of the school app's update page: dark icon bubble,
/// name + available count, checkbox and the black Update pill.
class _SubjectUpdateCard extends StatelessWidget {
  const _SubjectUpdateCard({
    required this.exam,
    required this.downloaded,
    required this.checked,
    required this.updating,
    required this.onCheck,
    required this.onUpdate,
  });

  final ExamMeta exam;
  final bool downloaded;
  final bool checked;
  final bool updating;
  final ValueChanged<bool> onCheck;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          // Dark icon bubble with the subject initial — the school
          // app's maroon bubble, Renance ink.
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.inverseChip,
            ),
            child: Text(
              exam.title.isEmpty ? '?' : exam.title[0].toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.onInverseChip,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  exam.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.bodyMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  '${downloaded ? 'Downloaded · ' : 'New: '}'
                  '${exam.questionCount} Questions Available.',
                  style: RenanceText.caption.copyWith(
                    fontSize: 12.5,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: checked,
            onChanged: (bool? v) => onCheck(v ?? false),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 2),
          // The black Update pill.
          InkWell(
            onTap: updating ? null : onUpdate,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: updating ? context.outlineLight : context.inverseChip,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (updating)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(Icons.sync,
                        size: 15, color: context.onInverseChip),
                  const SizedBox(width: 6),
                  Text(
                    updating ? '…' : 'Update',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.onInverseChip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
