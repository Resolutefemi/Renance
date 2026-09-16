/// Saved Questions — the Myschool bookmark feature, Renance edition.
///
/// The bookmark pill in the explanation sheet ("Save") stores the full
/// question snapshot on-device (SharedPreferences JSON), so a saved
/// question re-opens offline with its options — and, when it was saved
/// from a graded review, its correct option + explanation travel with
/// it. The Saved Questions screen lists them in Myschool's white-card
/// language and opens the same reader.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../qtext.dart';
import 'explanation_sheet.dart';
import 'theme.dart';

// ------------------------------------------------------------------ store

/// One saved question snapshot. Everything the reader needs, no lookups.
class SavedQuestion {
  SavedQuestion({
    required this.id,
    required this.code,
    required this.title,
    required this.stem,
    required this.options,
    required this.savedAt,
    this.topic = '',
    this.year = 0,
    this.image = '',
    this.passage = '',
    this.correct = '',
    this.explanation = '',
    this.attemptId = '',
  });

  final String id;
  final String code;
  final String title;
  final String stem;
  final Map<String, String> options;
  final DateTime savedAt;
  final String topic;
  final int year;
  final String image;
  final String passage;

  /// Filled when saved from a graded review — the reader then shows the
  /// correct option + explanation without any network.
  final String correct;
  final String explanation;
  final String attemptId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'title': title,
        'stem': stem,
        'options': options,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'topic': topic,
        'year': year,
        'image': image,
        'passage': passage,
        'correct': correct,
        'explanation': explanation,
        'attemptId': attemptId,
      };

  factory SavedQuestion.fromJson(Map<String, dynamic> j) => SavedQuestion(
        id: (j['id'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        stem: (j['stem'] ?? '') as String,
        options: ((j['options'] as Map<dynamic, dynamic>?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (j['savedAt'] ?? 0) as int,
        ),
        topic: (j['topic'] ?? '') as String,
        year: (j['year'] ?? 0) as int,
        image: (j['image'] ?? '') as String,
        passage: (j['passage'] ?? '') as String,
        correct: (j['correct'] ?? '') as String,
        explanation: (j['explanation'] ?? '') as String,
        attemptId: (j['attemptId'] ?? '') as String,
      );
}

/// On-device saved-question store, the bookmark backbone.
class SavedStore {
  SavedStore(this._prefs);

  final SharedPreferences _prefs;
  static const _kKey = 'renance.savedQuestions';

  List<SavedQuestion> _cache = <SavedQuestion>[];
  bool _loaded = false;

  List<SavedQuestion> load() {
    if (_loaded) return _cache;
    final raw = _prefs.getString(_kKey);
    _cache = <SavedQuestion>[];
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _cache = list
            .map((dynamic e) =>
                SavedQuestion.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } on FormatException {
        _cache = <SavedQuestion>[];
      }
    }
    _loaded = true;
    return _cache;
  }

  bool isSaved(String questionId) =>
      load().any((SavedQuestion q) => q.id == questionId);

  Future<void> add(SavedQuestion q) async {
    final List<SavedQuestion> list = load()
      ..removeWhere((SavedQuestion e) => e.id == q.id)
      ..insert(0, q);
    await _persist(list);
  }

  Future<void> remove(String questionId) async {
    final List<SavedQuestion> list = load()
      ..removeWhere((SavedQuestion e) => e.id == questionId);
    await _persist(list);
  }

  Future<void> toggle(SavedQuestion q) async {
    if (isSaved(q.id)) {
      await remove(q.id);
    } else {
      await add(q);
    }
  }

  Future<void> _persist(List<SavedQuestion> list) async {
    _cache = list;
    await _prefs.setString(
      _kKey,
      jsonEncode(list.map((SavedQuestion q) => q.toJson()).toList()),
    );
  }
}

/// Convenience lookup: the shell's SharedPreferences, read-only.
SharedPreferences? _prefsSingleton;
Future<SavedStore> savedStoreOf(BuildContext context) async {
  _prefsSingleton ??= await SharedPreferences.getInstance();
  return SavedStore(_prefsSingleton!);
}

// ----------------------------------------------------------------- screen

/// The Saved Questions screen — Myschool's white-card list, Renance
/// language: one card per saved question, stem preview + source +
/// saved-date, tap to open the reader, long-press or trailing button to
/// remove.
class SavedQuestionsScreen extends StatefulWidget {
  const SavedQuestionsScreen({super.key});

  @override
  State<SavedQuestionsScreen> createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  List<SavedQuestion> _saved = <SavedQuestion>[];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final SavedStore store = await savedStoreOf(context);
    if (!mounted) return;
    setState(() {
      _saved = store.load();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<SavedQuestion> shown = _query.isEmpty
        ? _saved
        : _saved
            .where((SavedQuestion q) =>
                q.stem.toLowerCase().contains(_query) ||
                q.title.toLowerCase().contains(_query))
            .toList();

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Back bar — every page gets a back button (founder rule).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: <Widget>[
                    _RoundBack(onBack: () => Navigator.of(context).pop()),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Saved Questions',
                          style: RenanceText.sectionTitle),
                    ),
                    if (_saved.isNotEmpty)
                      Text(
                        '${_saved.length}',
                        style: RenanceText.labelMono.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Questions you bookmarked while studying, kept on this '
                'device even offline.',
                style: RenanceText.caption.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
            // Search field — Myschool's "Search Question" bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                onChanged: (String v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search Question',
                  prefixIcon:
                      Icon(Icons.search, size: 20, color: context.outline),
                  filled: true,
                  fillColor: context.card,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.ink, width: 1.2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : shown.isEmpty
                      ? _EmptySaved(
                          empty: _saved.isEmpty && _query.isEmpty,
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: shown.length,
                            itemBuilder: (BuildContext context, int i) =>
                                Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SavedCard(
                                question: shown[i],
                                onOpen: () => _open(shown[i]),
                                onRemove: () => _remove(shown[i]),
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

  Future<void> _open(SavedQuestion q) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => SavedReaderSheet(question: q),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _remove(SavedQuestion q) async {
    HapticFeedback.lightImpact();
    final SavedStore store = await savedStoreOf(context);
    await store.remove(q.id);
    if (!mounted) return;
    setState(() => _saved.removeWhere((SavedQuestion e) => e.id == q.id));
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBack,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.outlineVariant),
          color: context.card,
        ),
        child: Icon(Icons.arrow_back, size: 20, color: context.ink),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved({required this.empty});
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: <Widget>[
        const SizedBox(height: 60),
        Icon(Icons.bookmark_border, size: 44, color: context.outlineLight),
        const SizedBox(height: 14),
        Text(
          empty
              ? 'Nothing saved yet.\nTap "Save" on any question you want to keep.'
              : 'No saved question matches your search.',
          textAlign: TextAlign.center,
          style: RenanceText.bodySecondary.copyWith(
            color: context.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.question,
    required this.onOpen,
    required this.onRemove,
  });

  final SavedQuestion question;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.bookmark, size: 15, color: context.ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      question.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onRemove,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: context.error),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              QuestionText(
                question.stem,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: RenanceText.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (question.topic.isNotEmpty) ...<Widget>[
                    _MiniChip(label: question.topic),
                    const SizedBox(width: 6),
                  ],
                  if (question.year > 0) ...<Widget>[
                    _MiniChip(label: '${question.year}'),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Text(
                    _fmtDate(question.savedAt),
                    style: RenanceText.caption.copyWith(
                      fontSize: 11,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.cardLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: RenanceText.caption.copyWith(
          fontSize: 10.5,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

/// The reader for a saved question: the explanation sheet's layout with
/// the snapshot's data. When the snapshot carries the graded fields
/// (correct + explanation), the reader shows them; the AI pill only
/// appears when an attempt context exists.
class SavedReaderSheet extends StatelessWidget {
  const SavedReaderSheet({super.key, required this.question});

  final SavedQuestion question;

  @override
  Widget build(BuildContext context) {
    return ExplanationSheet(
      title: 'Saved Question',
      questionNumber: null,
      stem: question.stem,
      passage: question.passage,
      image: question.image,
      topic: question.topic,
      year: question.year,
      options: question.options,
      correct: question.correct,
      explanation: question.explanation,
      attemptId: question.attemptId,
      questionId: question.id,
      saved: true,
      onToggleSave: () async {
        final SavedStore store = await savedStoreOf(context);
        await store.remove(question.id);
      },
    );
  }
}
