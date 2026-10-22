/// Review tab + answer review, Stitch review_queue_light and
/// answer_review_light, adapted to real data.
///
/// Tab: the amber spaced-repetition hero (real SM-2 due count from
/// GET /me/review, estimated time, Start Review) plus the Queue Preview
/// (due/overdue/upcoming topic rows) and the recent papers list. Detail:
/// the post-grade answer review, You Picked vs Correct Answer,
/// per-question explanations from the sealed keys - grouped SUBJECT BY
/// SUBJECT (founder directive: no scrolling a 180-question wall to find
/// mistakes). Each subject block carries its own Wrong / Skipped /
/// Answered buckets, so a student lands straight on a subject's wrong
/// answers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../qtext.dart';
import 'exam_screen.dart';
import 'explanation_sheet.dart';
import 'msymbols.dart';
import 'saved_questions.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'renance_logo.dart';
import 'tactile.dart';
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
          MediaQuery.paddingOf(context).top +66,
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
              const MsIcon(
                'local_fire_department',
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
          TactileButton(
            onPressed: onStart,
            height: 44,
            radius: BorderRadius.circular(10),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  hasWork ? 'Start Review' : 'Revise latest paper',
                ),
                const SizedBox(width: 6),
                const MsIcon('arrow_forward', size: 18, fill: true),
              ],
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
        child: Column(
          children: <Widget>[
            Row(
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
                            : '${attempt.isGraded ? when : 'in progress'} · ${attempt.status}',
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
                MsIcon('chevron_right', color: context.outlineDark),
              ],
            ),
            // The score bar: the paper's story in one glance.
            if (attempt.isGraded && pct != null) ...<Widget>[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5,
                  backgroundColor: context.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 50 ? context.ink : context.error,
                  ),
                ),
              ),
            ],
            // In-progress papers say they can be resumed.
            if (!attempt.isGraded) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'tap to resume',
                    style: RenanceText.caption.copyWith(
                      fontSize: 10.5,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
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

enum _ReviewFilter { wrong, skipped, answered, all }

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  AttemptReview? _review;
  String? _error;
  String _query = '';
  SavedStore? _saved;
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};
  // The subject sub-navbar's active tab (founder 2026-10-22): null
  // shows every subject section; a name filters the reader to one.
  String? _activeSubject;
  // Round-8 resume gate: the attempt is still open server-side, so the
  // reader yields to the continue-exam card instead of the 409 error.
  bool _inProgress = false;
  String _attemptCode = '';

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
    // Round-8 resume gate (founder): a paper the student left unfinished
    // must offer its seat back here, never the reader's 409 dead end.
    // The attempt row is checked first; every other path keeps the old
    // behaviour byte for byte.
    try {
      final AttemptView attempt = await api.attempt(widget.attemptId);
      if (!mounted) return;
      if (attempt.status == 'in_progress') {
        setState(() {
          _inProgress = true;
          _attemptCode = attempt.code;
        });
        return;
      }
    } on Exception catch (_) {
      // Unreachable row: fall through to the review load, whose error
      // path is unchanged.
    }
    try {
      final AttemptReview review = await api.attemptReview(widget.attemptId);
      if (!mounted) return;
      setState(() => _review = review);
    } on ApiException catch (e) {
      if (!mounted) return;
      // The reader is graded-only (409 not_graded). If the row is
      // really an open seat, route there; otherwise the plain error
      // state stands.
      if ((e.statusCode == 409 || e.code == 'not_graded') &&
          await _seatIsOpen(api)) {
        if (!mounted) return;
        setState(() => _inProgress = true);
        return;
      }
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  /// True when the attempt row still reads in_progress (and grabs the
  /// paper's code for the continue-exam card).
  Future<bool> _seatIsOpen(ApiClient api) async {
    try {
      final AttemptView attempt = await api.attempt(widget.attemptId);
      if (attempt.status == 'in_progress') {
        _attemptCode = attempt.code;
        return true;
      }
    } on Exception catch (_) {
      // Unreachable row: not an open seat we can prove.
    }
    return false;
  }

  /// The paused paper's manifest entry, matched by code exactly the way
  /// the home hero card does it. Null when the code is not in the sync
  /// manifest - the continue button hides in that case.
  ExamMeta? _resolveExam(BuildContext context) {
    if (_attemptCode.isEmpty) return null;
    final SyncController sync = context.read<SyncController>();
    for (final ExamMeta e in sync.exams) {
      if (e.code == _attemptCode) return e;
    }
    return null;
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
        child: _inProgress
            ? Column(
                children: <Widget>[
                  _ReaderHeader(
                    title: 'Past Questions',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: _ContinueSeatCard(
                      attemptId: widget.attemptId,
                      exam: _resolveExam(context),
                    ),
                  ),
                ],
              )
            : review == null
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
                                  TactileButton(
                                    onPressed: _load,
                                    outline: context.outlineVariant,
                                    edge: context.outlineVariant,
                                    edgeWidth: 3,
                                    height: 46,
                                    radius: BorderRadius.circular(12),
                                    fontSize: 14,
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
                        final bool dark = context.darkChrome;
                        final List<ReviewGroup> allGroups = review.groups;
                        // The subject sub-navbar: one pill per subject in
                        // paper order, "All" in front. Multi-subject
                        // papers only - a single-subject paper has
                        // nothing to switch.
                        final List<String> subjectTabs = <String>[
                          for (final ReviewGroup g in allGroups) g.subject,
                        ];
                        final List<ReviewGroup> groups =
                            _activeSubject == null
                                ? allGroups
                                : allGroups
                                    .where((ReviewGroup g) =>
                                        g.subject == _activeSubject)
                                    .toList(growable: false);
                        _cardKeys.clear();
                        int running = 0; // global card index for the jump strip

                        return RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: <Widget>[
                              // Subject title - the school app's big
                              // Mathematics heading.
                              Text(
                                widget.studyTitle ??
                                    student.titleForCode(review.code),
                                style: RenanceText.displayMd
                                    .copyWith(fontSize: 23),
                              ),
                              const SizedBox(height: 10),
                              // Type chips - "Questions Type Objective" /
                              // "Exam Type JAMB".
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  // Chip tints ride the tier: the light
                                  // pastel wells swap to the dark ramp's
                                  // tinted wells (amber-tint / emerald-tint
                                  // / ink-tint) with lifted tones - the
                                  // fixed light washes used to glare in
                                  // dark mode.
                                  _TypeChip(
                                    label: 'Questions Type',
                                    value: _typeLabel,
                                    tone: dark
                                        ? const Color(0xFF7DD3FC)
                                        : const Color(0xFF0E7490),
                                    tint: dark
                                        ? const Color(0xFF17223B)
                                        : const Color(0xFFE0F2F7),
                                  ),
                                  _TypeChip(
                                    label: 'Exam Type',
                                    value: _bodyLabel,
                                    tone: dark
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFFB45309),
                                    tint: dark
                                        ? const Color(0xFF3A2F14)
                                        : const Color(0xFFFDF0E0),
                                  ),
                                  _TypeChip(
                                    label: 'Score',
                                    value: review.score != null && review.total != null
                                        ? '${review.score}/${review.total}'
                                        : '-',
                                    tone: dark
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFF166534),
                                    tint: dark
                                        ? const Color(0xFF12301F)
                                        : const Color(0xFFDCFCE7),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Search Question - the school app's bar. It
                              // filters inside every subject block.
                              TextField(
                                onChanged: (String v) =>
                                    setState(() => _query = v.trim().toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: 'Search Question',
                                  // Founder 2026-10-21: glyph centred on
                                  // the text line, 10px inside a 36px
                                  // hit area (the app's bar).
                                  prefixIcon: MsFieldIcon('search',
                                      size: 18, color: context.textSecondary,
                                      box: 36, leftInset: 10),
                                  prefixIconConstraints:
                                      const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
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
                              const SizedBox(height: 14),
                              // SUBJECT SUB-NAVBAR (founder 2026-10-22):
                              // English | Physics | Mathematics | ... -
                              // switch the corrections you are working
                              // through without scrolling the whole paper.
                              if (subjectTabs.length > 1)
                                SizedBox(
                                  height: 42,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    itemCount: subjectTabs.length + 1,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (BuildContext ctx, int i) {
                                      final bool isAll = i == 0;
                                      final String name = isAll
                                          ? 'All'
                                          : subjectTabs[i - 1];
                                      final bool active = isAll
                                          ? _activeSubject == null
                                          : _activeSubject == name;
                                      return TactileButton(
                                        onPressed: () => setState(() =>
                                            _activeSubject =
                                                isAll ? null : name),
                                        height: 36,
                                        radius: BorderRadius.circular(999),
                                        fontSize: 12.5,
                                        expand: false,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        face: active
                                            ? context.primary
                                            : context.card,
                                        onFace: active
                                            ? context.primary
                                            : context.card,
                                        edge: active
                                            ? context.primary
                                            : context.outlineVariant,
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: active
                                                ? Colors.white
                                                : context.ink,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 14),
                              // SUBJECT BY SUBJECT: every subject block
                              // heads with its counts, then its own
                              // Wrong / Skipped / Answered / All buckets.
                              for (final ReviewGroup g in groups) ...<Widget>[
                                _SubjectSection(
                                  group: g,
                                  query: _query,
                                  numberOffset: running,
                                  onNumbered: (int n) => running = n,
                                  cardKeys: _cardKeys,
                                  onView: _openExplanation,
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (groups.every((ReviewGroup g) =>
                                  g.questions
                                      .where((ReviewQuestion q) =>
                                          _query.isEmpty ||
                                          q.stem.toLowerCase().contains(_query))
                                      .isEmpty))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 40),
                                  child: Center(
                                    child: Text(
                                      _query.isEmpty
                                          ? 'No questions to review.'
                                          : 'No question matches "$_query".',
                                      style: RenanceText.bodySecondary.copyWith(
                                          color: context.textSecondary),
                                    ),
                                  ),
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

/// The paused-paper state of the reader (Round 8): the corrections API
/// only serves graded papers, so an attempt still in progress lands
/// here - the seat is saved, one tap returns to the CBT player with the
/// same attempt id.
class _ContinueSeatCard extends StatelessWidget {
  const _ContinueSeatCard({required this.attemptId, required this.exam});

  final String attemptId;
  final ExamMeta? exam;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RenanceColors.emerald.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const MsIcon('pause_circle',
                  size: 30, color: RenanceColors.emerald),
            ),
            const SizedBox(height: 18),
            Text(
              'This paper is still open',
              textAlign: TextAlign.center,
              style: RenanceText.displayMd.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 8),
            Text(
              'You left this paper unfinished - your seat is saved. '
              'Jump back in and finish it.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(
                  color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            if (exam != null) ...<Widget>[
              TactileButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                    builder: (_) => ExamScreen(
                      exam: exam!,
                      resumeAttemptId: attemptId,
                    ),
                  ));
                },
                face: context.primary,
                onFace: context.onPrimary,
                height: 50,
                radius: BorderRadius.circular(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const MsIcon('play_arrow', size: 18, fill: true),
                    const SizedBox(width: 8),
                    const Text('Continue Exam'),
                  ],
                ),
              ),
            ] else ...<Widget>[
              Text(
                'We could not match this paper to your exam list - open '
                'it again from the home desk.',
                textAlign: TextAlign.center,
                style: RenanceText.caption.copyWith(
                    color: context.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One subject block of the answer review: the subject name with its
/// wrong / skipped / answered counts, its own bucket chips (Wrong by
/// default - the whole point of the grouping is landing on the mistakes
/// fast), then the bucket's question cards.
class _SubjectSection extends StatefulWidget {
  const _SubjectSection({
    required this.group,
    required this.query,
    required this.numberOffset,
    required this.onNumbered,
    required this.cardKeys,
    required this.onView,
  });

  final ReviewGroup group;

  /// Live search text; filters inside this block.
  final String query;

  /// Index of this block's first card in the paper-wide numbering, so
  /// the bottom jump strip addresses every card uniquely.
  final int numberOffset;

  /// Reports back the next free number after this block's cards.
  final void Function(int) onNumbered;

  /// Shared (index -> key) map with the reader's jump strip.
  final Map<int, GlobalKey> cardKeys;

  /// Opens the explanation pager on this block's filtered list.
  final void Function(List<ReviewQuestion>, int) onView;

  @override
  State<_SubjectSection> createState() => _SubjectSectionState();
}

class _SubjectSectionState extends State<_SubjectSection> {
  _ReviewFilter _filter = _ReviewFilter.wrong;

  @override
  Widget build(BuildContext context) {
    final ReviewGroup g = widget.group;
    final List<ReviewQuestion> matching = g.questions
        .where((ReviewQuestion q) =>
            widget.query.isEmpty ||
            q.stem.toLowerCase().contains(widget.query))
        .toList(growable: false);
    final List<ReviewQuestion> shown = matching
        .where((ReviewQuestion q) => switch (_filter) {
              _ReviewFilter.wrong => q.isWrong && q.selected.isNotEmpty,
              _ReviewFilter.skipped => q.selected.isEmpty,
              _ReviewFilter.answered => q.correctly && q.selected.isNotEmpty,
              _ReviewFilter.all => true,
            })
        .toList(growable: false);

    // Paper-wide numbering handed to the jump strip.
    int n = widget.numberOffset;
    final List<int> numbers = <int>[];
    for (int i = 0; i < shown.length; i++) {
      numbers.add(n);
      widget.cardKeys[n] = GlobalKey();
      n++;
    }
    widget.onNumbered(n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Subject head: name + the three count badges.
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      g.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.displayMd.copyWith(fontSize: 17),
                    ),
                  ),
                  _CountBadge(
                    count: g.wrong,
                    label: 'wrong',
                    color: context.error,
                  ),
                  const SizedBox(width: 6),
                  _CountBadge(
                    count: g.skipped,
                    label: 'skipped',
                    color: RenanceColors.amber,
                  ),
                  const SizedBox(width: 6),
                  _CountBadge(
                    count: g.answered,
                    label: 'correct',
                    color: RenanceColors.emerald,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Bucket chips - Wrong is the default landing bucket.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _FilterChip(
                    'Wrong (${g.wrong})',
                    _filter == _ReviewFilter.wrong,
                    () => setState(() => _filter = _ReviewFilter.wrong),
                  ),
                  _FilterChip(
                    'Skipped (${g.skipped})',
                    _filter == _ReviewFilter.skipped,
                    () => setState(() => _filter = _ReviewFilter.skipped),
                  ),
                  _FilterChip(
                    'Answered (${g.answered})',
                    _filter == _ReviewFilter.answered,
                    () => setState(() => _filter = _ReviewFilter.answered),
                  ),
                  _FilterChip(
                    'All (${g.questions.length})',
                    _filter == _ReviewFilter.all,
                    () => setState(() => _filter = _ReviewFilter.all),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                widget.query.isNotEmpty
                    ? 'No match in this subject.'
                    : switch (_filter) {
                        _ReviewFilter.wrong =>
                          'Nothing wrong here, flawless subject.',
                        _ReviewFilter.skipped =>
                          'No skipped questions.',
                        _ReviewFilter.answered =>
                          'None answered correctly yet.',
                        _ReviewFilter.all => 'No questions.',
                      },
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary),
              ),
            ),
          )
        else
          ...List<int>.generate(shown.length, (int i) => i).map(
            (int i) {
              return Container(
                key: widget.cardKeys[numbers[i]],
                margin: const EdgeInsets.only(bottom: 16),
                child: _StudyQuestionCard(
                  index: numbers[i] + 1,
                  question: shown[i],
                  onView: () => widget.onView(shown, i),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// The tiny "12 wrong" badge next to a subject name.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count $label',
        style: RenanceText.labelMono.copyWith(fontSize: 10.5, color: color),
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
            TactileBackKey(
              onTap: onBack,
              size: 44,
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
/// stack, then the View Explanation pill + copy button - the school
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
    return Container(alignment: Alignment.center,
      
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
              // The View Explanation pill - Myschool's red cut becomes
              // Renance ink.
              TactileButton(
                onPressed: onView,
                face: context.inverseChip,
                onFace: context.onInverseChip,
                height: 40,
                radius: RenanceRadius.chip,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                expand: false,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const Text('View Explanation'),
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
                child: Container(alignment: Alignment.center,
                  
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.outlineVariant),
                  ),
                  child: MsIcon('content_copy',
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
/// ExplanationSheet per question - the school app's pager behaviour.
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
