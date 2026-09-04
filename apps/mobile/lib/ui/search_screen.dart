/// Search, the Stitch search_light screen, 1:1.
///
/// One field, four shelves: packs, lessons, flashcard decks and syllabus
/// topics. Everything is matched on-device against data the app already
/// holds (manifest, lesson metas, deck metas, syllabus trees), so search
/// works offline and leaks nothing. Results are grouped with counts and
/// each row routes into its shelf's screen.
///
/// Wide windows (desktop, >= 700 px) keep the column centered at a
/// readable measure. The pure matcher [rankSearch] is unit-tested.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'exam_screen.dart' show ExamScreen;
import 'lessons_screen.dart' show LessonReaderScreen;
import 'pack_detail_screen.dart' show PackDetailScreen;
import 'flashcards_screen.dart' show FlashcardsScreen;
import 'renance_logo.dart';
import 'theme.dart';

/// Syllabus bodies searched for topics (mirrors syllabus_screen's list).
const List<(String, String)> kSearchBodies = <(String, String)>[
  ('jamb', 'JAMB'),
  ('waec', 'WAEC'),
  ('university-modules', 'University'),
];

// ------------------------------------------------------------------ model

enum SearchShelf { packs, lessons, decks, topics }

class SearchHit {
  const SearchHit({
    required this.shelf,
    required this.title,
    required this.subtitle,
    this.payload,
  });

  final SearchShelf shelf;
  final String title;
  final String subtitle;
  final Object? payload; // ExamMeta | LessonMeta | FlashcardDeckMeta | (body, topic)

  IconData get icon => switch (shelf) {
        SearchShelf.packs => Icons.description_outlined,
        SearchShelf.lessons => Icons.menu_book_outlined,
        SearchShelf.decks => Icons.style_outlined,
        SearchShelf.topics => Icons.account_tree_outlined,
      };
}

/// Pure matcher: every whitespace-separated token must appear in the
/// haystack; the score prefers prefix hits and earlier positions so the
/// best rows float up. Empty or blank queries match nothing.
int rankSearch(String query, Iterable<String> haystacks) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  final List<String> needles = q.split(RegExp(r'\s+'));
  final String joined = haystacks.join('\n').toLowerCase();
  int score = 0;
  for (final String needle in needles) {
    final int at = joined.indexOf(needle);
    if (at < 0) return 0; // AND semantics: a missed token kills the row
    score += 100 - (at > 90 ? 90 : at);
    if (haystacks.any((String h) => h.toLowerCase().startsWith(needle))) {
      score += 40; // title prefix matches are the user's likely intent
    }
  }
  return score;
}

// ----------------------------------------------------------------- screen

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _indexing = true;
  bool _indexFailed = false;
  List<SearchHit> _index = <SearchHit>[];

  @override
  void initState() {
    super.initState();
    _buildIndex();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Assembles the searchable corpus from controllers (packs arrive with
  /// the shell; lessons and decks load on demand; syllabus trees are
  /// fetched per body). Failure degrades to searching what we already
  /// hold: search never blocks on the network.
  Future<void> _buildIndex() async {
    final SyncController sync = context.read<SyncController>();
    final LessonsController lessons = context.read<LessonsController>();
    final FlashcardsController cards = context.read<FlashcardsController>();
    final ApiClient api = context.read<ApiClient>();

    final List<SearchHit> hits = <SearchHit>[
      for (final ExamMeta e in sync.exams)
        SearchHit(
          shelf: SearchShelf.packs,
          title: e.title,
          subtitle: <String>[
            e.body,
            if (e.category.isNotEmpty) e.category,
            '${e.questionCount} questions',
          ].where((String s) => s.isNotEmpty).join(' · '),
          payload: e,
        ),
    ];

    try {
      await lessons.load();
      hits.addAll(<SearchHit>[
        for (final LessonMeta l in lessons.lessons)
          SearchHit(
            shelf: SearchShelf.lessons,
            title: l.title,
            subtitle: '${l.minutes} min read'
                '${l.subject.isEmpty ? '' : ' · ${l.subject}'}',
            payload: l,
          ),
      ]);
      await cards.loadDecks();
      hits.addAll(<SearchHit>[
        for (final FlashcardDeckMeta d in cards.decks)
          SearchHit(
            shelf: SearchShelf.decks,
            title: d.title,
            subtitle: '${d.cardCount} cards',
            payload: d,
          ),
      ]);
      for (final (String slug, String label) in kSearchBodies) {
        final SyllabusTree tree = await api.syllabus(slug);
        for (final SyllabusSubject subject in tree.subjects) {
          for (final SyllabusSection section in subject.sections) {
            for (final SyllabusTopic topic in section.topics) {
              hits.add(SearchHit(
                shelf: SearchShelf.topics,
                title: topic.topic,
                subtitle: '$label · ${subject.subject}',
                payload: (slug, topic.topic),
              ));
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _index = hits;
        _indexing = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _index = hits; // degrade to whatever the device already holds
        _indexing = false;
        _indexFailed = hits.isEmpty;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
    if (value.isEmpty && mounted) setState(() => _query = '');
  }

  Map<SearchShelf, List<SearchHit>> get _grouped {
    final Map<SearchShelf, List<SearchHit>> out = <SearchShelf, List<SearchHit>>{};
    if (_query.trim().isEmpty) return out;
    final List<(int, SearchHit)> scored = <(int, SearchHit)>[];
    for (final SearchHit hit in _index) {
      final int score = rankSearch(_query, <String>[hit.title, hit.subtitle]);
      if (score > 0) scored.add((score, hit));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (int _, SearchHit hit) in scored) {
      (out[hit.shelf] ??= <SearchHit>[]).add(hit);
    }
    return out;
  }

  void _open(SearchHit hit) {
    final NavigatorState nav = Navigator.of(context);
    switch (hit.shelf) {
      case SearchShelf.packs:
        final ExamMeta exam = hit.payload! as ExamMeta;
        nav.push<void>(MaterialPageRoute<void>(
          builder: (_) => PackDetailScreen(
            exam: exam,
            onStart: (
              BuildContext ctx,
              ExamMeta meta, {
              int? durationOverrideMinutes,
              bool untimed = false,
            }) {
              Navigator.of(ctx).push<void>(MaterialPageRoute<void>(
                builder: (_) => ExamScreen(
                  exam: meta,
                  durationOverrideMinutes: durationOverrideMinutes,
                  untimed: untimed,
                ),
              ));
            },
          ),
        ));
      case SearchShelf.lessons:
        final LessonMeta lesson = hit.payload! as LessonMeta;
        nav.push<void>(MaterialPageRoute<void>(
          builder: (_) => LessonReaderScreen(
            slug: lesson.slug,
            title: lesson.title,
          ),
        ));
      case SearchShelf.decks:
        // The decks screen is the shelf: open it and let the student pick
        // the deck (it already carries per-deck state and voice controls).
        nav.push<void>(MaterialPageRoute<void>(
          builder: (_) => const FlashcardsScreen(),
        ));
      case SearchShelf.topics:
        nav.pop(); // back to home; syllabus is reachable from the launcher
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<SearchShelf, List<SearchHit>> groups = _grouped;
    final int total = groups.values.fold<int>(0, (int n, List<SearchHit> l) => n + l.length);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: <Widget>[
                _SearchBar(
                  controller: _controller,
                  focus: _focus,
                  onChanged: _onChanged,
                  autofocus: true,
                ),
                Expanded(
                  child: _query.trim().isEmpty
                      ? _EmptyQuery(indexing: _indexing, indexFailed: _indexFailed)
                      : total == 0
                          ? const _NoResults()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: <Widget>[
                                for (final SearchShelf shelf in SearchShelf.values)
                                  if (groups.containsKey(shelf))
                                    ...<Widget>[
                                      _ShelfHeader(
                                          label: _shelfLabel(shelf),
                                          count: groups[shelf]!.length),
                                      for (final SearchHit hit
                                          in groups[shelf]!.take(6))
                                        _HitRow(
                                          hit: hit,
                                          onTap: () => _open(hit),
                                        ),
                                    ],
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shelfLabel(SearchShelf shelf) => switch (shelf) {
        SearchShelf.packs => 'Packs',
        SearchShelf.lessons => 'Lessons',
        SearchShelf.decks => 'Flashcards',
        SearchShelf.topics => 'Syllabus topics',
      };
}

// -------------------------------------------------------------- search bar

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.autofocus,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: context.ink,
          ),
          SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: RenanceText.bodyBase,
              decoration: InputDecoration(
                hintText: 'Search packs, lessons, decks, topics',
                hintStyle: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                prefixIcon: Icon(Icons.search,
                    color: context.textSecondary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ states

class _EmptyQuery extends StatelessWidget {
  const _EmptyQuery({required this.indexing, required this.indexFailed});

  final bool indexing;
  final bool indexFailed;

  @override
  Widget build(BuildContext context) {
    if (indexing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: RenanceMark(size: 40),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const SizedBox(height: 24),
        Text('Search Renance', style: RenanceText.sectionTitle),
        const SizedBox(height: 8),
        Text(
          indexFailed
              ? 'Only what is already on this device is searchable right now. Reconnect once to index everything.'
              : 'Find a practice pack, a lesson, a flashcard deck or any syllabus topic. Try "cells", "essay" or "Newton".',
          style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off,
                size: 40, color: context.outlineLight),
            const SizedBox(height: 12),
            Text('Nothing matches yet', style: RenanceText.sectionTitle),
            const SizedBox(height: 6),
            Text(
              'Check the spelling or try a shorter word.',
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- rows

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: <Widget>[
          Text(label, style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const Spacer(),
          Text('$count', style: RenanceText.labelMono),
        ],
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.cardHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(hit.icon, size: 20, color: context.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hit.title,
                        style: RenanceText.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hit.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          hit.subtitle,
                          style: RenanceText.caption.copyWith(color: context.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: context.outlineLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
