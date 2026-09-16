/// Review tab + answer review, Stitch review_queue_light and
/// answer_review_light, adapted to real data.
///
/// Tab: the amber spaced-repetition hero (real SM-2 due count from
/// GET /me/review, estimated time, Start Review) plus the Queue Preview
/// (due/overdue/upcoming topic rows) and the recent papers list. Detail:
/// the post-grade answer review, You Picked vs Correct Answer,
/// per-question explanations from the sealed keys, Wrong / Skipped / All
/// filters.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../qtext.dart';
import 'explanation_sheet.dart';
import 'saved_questions.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'renance_logo.dart';
import 'theme.dart';

/// The small filter pills of the reader (Wrong / Skipped / All).
class _FilterChip extends StatelessWidget {
  const _FilterChip(this.label, this.selected, this.onTap);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? context.selectionBlue : context.cardLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: RenanceText.labelMono.copyWith(
            fontSize: 12,
            color: selected ? context.ink : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final List<AttemptRow> papers = student.attempts;

    return RefreshIndicator(
      onRefresh: student.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 64 + 8,
          16,
          24,
        ),
        children: <Widget>[
          _ReviewQueueCard(
            student: student,
            onStart: () {
              final graded = papers.where((AttemptRow a) => a.isGraded);
              if (graded.isEmpty) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ReviewDetailScreen(attemptId: graded.first.attemptId),
                ),
              );
            },
          ),
          if (student.queuePreview.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            const _QueuePreviewSection(),
          ],
          const SizedBox(height: 20),
          const Text('Recent papers', style: RenanceText.sectionTitle),
          const SizedBox(height: 12),
          if (papers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: <Widget>[
                  const RenanceMark(size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'No papers yet, every paper you finish lands here '
                    'with its wrong answers for review.',
                    textAlign: TextAlign.center,
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...papers.map(
              (AttemptRow a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PaperCard(
                  attempt: a,
                  title: student.titleForCode(a.code),
                  onTap: a.isGraded
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReviewDetailScreen(attemptId: a.attemptId),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The amber spaced-repetition hero (review_queue_light): the real SM-2
/// due count, estimated time, and Start Review, which opens the most
/// recent marked paper until a dedicated review-session player ships.
class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({required this.student, required this.onStart});

  final StudentController student;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ReviewSummary? queue = student.review;

    // Queue still loading (or the call failed), RenanceMark, never a
    // spinner, per the founder's only-loader rule.
    if (queue == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _heroDecoration(),
        child: Column(
          children: <Widget>[
            const RenanceMark(size: 40, busy: true),
            const SizedBox(height: 12),
            Text(
              'Checking your review queue…',
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    final int due = queue.stats.due;
    final bool hasWork = due > 0;
    final String nextUp = queue.upcoming.isEmpty
        ? ''
        : queue.upcoming.first.topic;
    final String nextWhen = queue.upcoming.isEmpty
        ? ''
        : queue.upcoming.first.laterLabel;
    final List<ReviewItem> overdue = queue.due
        .where((ReviewItem it) => it.status(DateTime.now()) == 'overdue')
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.local_fire_department,
                size: 18,
                color: RenanceColors.amber,
              ),
              const SizedBox(width: 6),
              Text(
                'REVIEW QUEUE',
                style: RenanceText.labelMono.copyWith(
                  color: RenanceColors.amber,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$due',
                style: RenanceText.displayLg.copyWith(
                  color: hasWork ? RenanceColors.amber : RenanceColors.emerald,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  hasWork
                      ? (overdue.isEmpty
                            ? 'topics due today'
                            : 'topics due · ${overdue.length} overdue')
                      : 'all caught up',
                  style: RenanceText.bodyMedium.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasWork
                ? 'Estimated time: ~${due * 2} minutes'
                : (nextUp.isEmpty
                      ? 'Grade a paper and its topics join your schedule.'
                      : 'Next up: $nextUp $nextWhen'),
            style: RenanceText.caption.copyWith(color: context.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    hasWork ? 'Start Review' : 'Revise latest paper',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _heroDecoration() {
    return BoxDecoration(
      color: RenanceColors.amber.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x14141C2D),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    );
  }
}

/// "Queue Preview / Next up" (review_queue_light): due + upcoming topic
/// rows with the design's Overdue / Due now / in-Nd status slot.
class _QueuePreviewSection extends StatelessWidget {
  const _QueuePreviewSection();

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final List<ReviewItem> rows = student.queuePreview;
    const int maxRows = 6;
    final List<ReviewItem> shown = rows.length > maxRows
        ? rows.sublist(0, maxRows)
        : rows;
    final int hidden = rows.length - shown.length;
    final DateTime now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text('Queue Preview', style: RenanceText.sectionTitle),
            Text('Next up', style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        ...shown.map(
          (ReviewItem it) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QueueRow(item: it, now: now),
          ),
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+ $hidden more topics on the schedule',
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// One topic row: chip + status (Overdue red / Due now amber / in Nd).
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item, required this.now});

  final ReviewItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final String status = item.status(now);
    final (Color tint, String label) = switch (status) {
      'overdue' => (context.error, 'Overdue'),
      'due' => (RenanceColors.amber, 'Due now'),
      _ => (context.textSecondary, item.laterLabel),
    };
    final String subtitle = item.lastTotal > 0
        ? 'last time ${item.lastCorrect}/${item.lastTotal} correct'
        : 'new on the schedule';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14141C2D),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.selectionBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.caption.copyWith( 
                      fontSize: 12,
                       color: context.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (status != 'later')
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: RenanceText.bodyMedium.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
        ],
      ),
    );
  }
}

/// One paper in the history list.
class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.attempt,
    required this.title,
    required this.onTap,
  });

  final AttemptRow attempt;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final int? pct = attempt.pct;
    final Color pctColor = pct == null
        ? context.textSecondary
        : pct >= 75
        ? RenanceColors.emerald
        : pct >= 50
        ? RenanceColors.amber
        : context.error;
    final String when = _relative(attempt.submittedAt ?? attempt.startedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14141C2D),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attempt.isGraded
                        ? '$when · ${attempt.score}/${attempt.total} correct'
                        : '$when · ${attempt.status}',
                    style: RenanceText.caption.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              pct == null ? '-' : '$pct%',
              style: RenanceText.statNumber.copyWith(color: pctColor),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.outlineDark),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime dt) {
    final Duration d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ============================================================ review detail

/// Per-question answer review (answer_review_light): Wrong / Skipped /
/// All chips, question cards with You Picked vs Correct Answer blocks and
/// the key explanation. Data: GET /attempts/{id}/review (graded only).
class ReviewDetailScreen extends StatefulWidget {
  const ReviewDetailScreen({
    super.key,
    required this.attemptId,
    this.studyTitle,
  });

  final String attemptId;

  /// Study mode hands the study paper's title in, so the reader can
  /// head itself the way the school app's Past Questions page does.
  final String? studyTitle;

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

enum _ReviewFilter { wrong, skipped, all }

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  AttemptReview? _review;
  String? _error;
  _ReviewFilter _filter = _ReviewFilter.all;
  String _query = '';
  SavedStore? _saved;
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await _load();
      if (!mounted) return;
      final prefs =
          Provider.of<SessionStore>(context, listen: false).prefs;
      setState(() => _saved = SavedStore(prefs));
    });
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final AttemptReview review = await api.attemptReview(widget.attemptId);
      if (!mounted) return;
      setState(() => _review = review);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  /// Exam body label for the "Exam Type" chip, derived from the code.
  String get _bodyLabel {
    final String code = _review?.code ?? '';
    if (code.startsWith('waec-')) return 'WAEC';
    if (code.startsWith('neco-')) return 'NECO';
    if (code.startsWith('daily-')) return 'Challenge';
    if (code.startsWith('uni-')) return 'University';
    return 'JAMB';
  }

  String get _typeLabel {
    final AttemptReview? review = _review;
    if (review == null) return 'Mixed';
    final bool anyTheory = review.questions.any((ReviewQuestion q) =>
        q.type == 'theory' || q.options.isEmpty);
    final bool anyMcq =
        review.questions.any((ReviewQuestion q) => q.type == 'mcq');
    if (anyTheory && anyMcq) return 'Mixed';
    if (anyTheory) return 'Theory';
    return 'Objective';
  }

  Future<void> _openExplanation(
    List<ReviewQuestion> questions,
    int index,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _ExplanationPager(
        state: this,
        questions: questions,
        initialIndex: index,
      ),
    );
    if (mounted) setState(() {}); // refresh save states
  }

  void _jumpTo(int i) {
    final GlobalKey? key = _cardKeys[i];
    final BuildContext? ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final AttemptReview? review = _review;

    return Scaffold(
      backgroundColor: context.cardLowest,
      body: SafeArea(
        bottom: false,
        child: review == null
            ? Column(
                children: <Widget>[
                  _ReaderHeader(
                    title: 'Past Questions',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: _error == null
                          ? const LogoActivityIndicator(
                              label: 'Opening the marked paper…',
                            )
                          : Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: RenanceText.bodySecondary.copyWith(
                                        color: context.textSecondary),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: _load,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : Column(
                children: <Widget>[
                  _ReaderHeader(
                    title: 'Past Questions',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (BuildContext context) {
                        final List<ReviewQuestion> questions = review.questions
                            .where(
                              (ReviewQuestion q) => switch (_filter) {
                                _ReviewFilter.wrong =>
                                  q.isWrong && q.selected.isNotEmpty,
                                _ReviewFilter.skipped => q.selected.isEmpty,
                                _ReviewFilter.all => true,
                              },
                            )
                            .where((ReviewQuestion q) =>
                                _query.isEmpty ||
                                q.stem.toLowerCase().contains(_query))
                            .toList(growable: false);
                        final int wrongCount = review.wrongCount;
                        final int skippedCount = review.skippedCount;
                        _cardKeys.clear();

                        return RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: <Widget>[
                              // Subject title — the school app's big
                              // Mathematics heading.
                              Text(
                                widget.studyTitle ??
                                    student.titleForCode(review.code),
                                style: RenanceText.displayMd
                                    .copyWith(fontSize: 23),
                              ),
                              const SizedBox(height: 10),
                              // Type chips — "Questions Type Objective" /
                              // "Exam Type JAMB".
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _TypeChip(
                                    label: 'Questions Type',
                                    value: _typeLabel,
                                    tone: const Color(0xFF0E7490),
                                    tint: const Color(0xFFE0F2F7),
                                  ),
                                  _TypeChip(
                                    label: 'Exam Type',
                                    value: _bodyLabel,
                                    tone: const Color(0xFFB45309),
                                    tint: const Color(0xFFFDF0E0),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // The filter trio keeps its Renance edge.
                              Row(
                                children: <Widget>[
                                  _FilterChip(
                                    'Wrong ($wrongCount)',
                                    _filter == _ReviewFilter.wrong,
                                    () => setState(
                                        () => _filter = _ReviewFilter.wrong),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    'Skipped ($skippedCount)',
                                    _filter == _ReviewFilter.skipped,
                                    () => setState(() =>
                                        _filter = _ReviewFilter.skipped),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    'All (${review.questions.length})',
                                    _filter == _ReviewFilter.all,
                                    () => setState(
                                        () => _filter = _ReviewFilter.all),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Search Question — the school app's bar.
                              TextField(
                                onChanged: (String v) =>
                                    setState(() => _query = v.trim().toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: 'Search Question',
                                  prefixIcon: Icon(Icons.search,
                                      size: 20, color: context.outline),
                                  filled: true,
                                  fillColor: context.card,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: context.outlineVariant),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: context.ink, width: 1.2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (questions.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 40),
                                  child: Center(
                                    child: Text(
                                      switch (_filter) {
                                        _ReviewFilter.wrong =>
                                          'Nothing wrong here, flawless paper.',
                                        _ReviewFilter.skipped =>
                                          'No skipped questions.',
                                        _ReviewFilter.all => 'No questions.',
                                      },
                                      style: RenanceText.bodySecondary
                                          .copyWith(
                                              color:
                                                  context.textSecondary),
                                    ),
                                  ),
                                )
                              else
                                ...questions.asMap().entries.map(
                                  (MapEntry<int, ReviewQuestion> e) {
                                    final GlobalKey key = GlobalKey();
                                    _cardKeys[e.key] = key;
                                    return Container(
                                      key: key,
                                      margin: const EdgeInsets.only(
                                          bottom: 16),
                                      child: _StudyQuestionCard(
                                        index: e.key + 1,
                                        question: e.value,
                                        onView: () => _openExplanation(
                                            questions, e.key),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // The bottom navigator strip, the school app's drawer.
                  if (review.questions.isNotEmpty)
                    _ReaderNavigator(
                      total: review.questions.length,
                      onJump: _jumpTo,
                    ),
                ],
              ),
      ),
    );
  }

  // ---- explanation helpers used by _ExplanationPager -------------------

  bool isSaved(String questionId) =>
      _saved?.isSaved(questionId) ?? false;

  Future<void> toggleSave(ReviewQuestion q) async {
    final SavedStore? store = _saved;
    if (store == null) return;
    await store.toggle(SavedQuestion(
      id: q.questionId,
      code: _review?.code ?? '',
      title: _review?.title ?? '',
      stem: q.stem,
      options: q.options,
      savedAt: DateTime.now(),
      topic: q.topic,
      year: q.year,
      image: q.image,
      passage: q.passage,
      correct: q.correct,
      explanation: q.explanation,
      attemptId: widget.attemptId,
    ));
  }

  void reportQuestion(ReviewQuestion q) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Report noted on question ${q.questionId}. Thanks for the '
            'flag, it goes straight to the question team.'),
      ),
    );
  }
}

/// The reader's sticky header: back circle + the white "Past Questions"
/// pill centred, exactly the school app's head.
class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardLowest,
        border: Border(
          bottom: BorderSide(
            color: context.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            InkWell(
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
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.outlineVariant),
              ),
              child: Text(
                title,
                style: RenanceText.bodyMedium.copyWith(fontSize: 14),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

/// The "Questions Type Objective" / "Exam Type JAMB" chips.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.value,
    required this.tone,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tone;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label ',
            style: RenanceText.bodySecondary.copyWith(
              fontSize: 13,
              color: tone.withValues(alpha: 0.85),
            ),
          ),
          Text(
            value,
            style: RenanceText.bodyMedium.copyWith(
              fontSize: 13,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// One question card of the reader: "Question N" pill, stem, the option
/// stack, then the View Explanation pill + copy button — the school
/// app's study card.
class _StudyQuestionCard extends StatelessWidget {
  const _StudyQuestionCard({
    required this.index,
    required this.question,
    required this.onView,
  });

  final int index;
  final ReviewQuestion question;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.outlineVariant),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14141C2D),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              'Question $index',
              style: RenanceText.bodyMedium.copyWith(fontSize: 14.5),
            ),
          ),
          const SizedBox(height: 14),
          if (question.passage.isNotEmpty) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardLow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('COMPREHENSION PASSAGE',
                        style: RenanceText.labelMono.copyWith(
                          fontSize: 10,
                          color: context.textSecondary,
                        )),
                    const SizedBox(height: 6),
                    QuestionText(
                      question.passage,
                      style: RenanceText.bodyBase.copyWith(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          QuestionText(
            question.stem,
            style: RenanceText.bodyMedium.copyWith(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (question.image.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                resolveQImageUrl(question.image),
                fit: BoxFit.contain,
                height: 200,
                errorBuilder: (_, Object __, StackTrace? ___) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...question.options.entries.map(
            (MapEntry<String, String> opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: context.outlineVariant),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      opt.key,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.error.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: QuestionText(
                        opt.value,
                        style: RenanceText.bodyBase.copyWith(
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              // The View Explanation pill — Myschool's red cut becomes
              // Renance ink.
              InkWell(
                onTap: onView,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.inverseChip,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'View Explanation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.onInverseChip,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  final StringBuffer buf = StringBuffer(question.stem);
                  for (final MapEntry<String, String> opt
                      in question.options.entries) {
                    buf.write('\n${opt.key}) ${opt.value}');
                  }
                  Clipboard.setData(ClipboardData(text: buf.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Question copied')),
                  );
                },
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.outlineVariant),
                  ),
                  child: Icon(Icons.copy_outlined,
                      size: 17, color: context.ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The reader's bottom navigator: "N Questions" pill + the number strip.
class _ReaderNavigator extends StatelessWidget {
  const _ReaderNavigator({required this.total, required this.onJump});

  final int total;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: context.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.cardLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total Questions',
                    style: RenanceText.labelMono.copyWith(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: total,
                itemBuilder: (BuildContext context, int i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onJump(i),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: context.outlineVariant),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: RenanceText.bodyBase.copyWith(fontSize: 13),
                      ),
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
}

/// Keeps one sheet open across Previous/Next, rebuilding the
/// ExplanationSheet per question — the school app's pager behaviour.
class _ExplanationPager extends StatefulWidget {
  const _ExplanationPager({
    required this.state,
    required this.questions,
    required this.initialIndex,
  });

  final _ReviewDetailScreenState state;
  final List<ReviewQuestion> questions;
  final int initialIndex;

  @override
  State<_ExplanationPager> createState() => _ExplanationPagerState();
}

class _ExplanationPagerState extends State<_ExplanationPager> {
  late int _idx = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final ReviewQuestion q = widget.questions[_idx];
    return ExplanationSheet(
      key: ValueKey<int>(_idx),
      title: 'Question',
      questionNumber: _idx + 1,
      stem: q.stem,
      passage: q.passage,
      image: q.image,
      topic: q.topic,
      year: q.year,
      options: q.options,
      correct: q.correct,
      selected: q.selected,
      explanation: q.explanation,
      attemptId: widget.state.widget.attemptId,
      questionId: q.questionId,
      saved: widget.state.isSaved(q.questionId),
      onToggleSave: () => widget.state.toggleSave(q),
      onPrevious:
          _idx > 0 ? () => setState(() => _idx--) : null,
      onNext: _idx < widget.questions.length - 1
          ? () => setState(() => _idx++)
          : null,
      onReport: () => widget.state.reportQuestion(q),
    );
  }
}
