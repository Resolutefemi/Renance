/// Review tab + answer review — Stitch review_queue_light and
/// answer_review_light, adapted to real data.
///
/// Tab: the amber "questions to retake" hero card (the student's real
/// missed-question backlog) plus the recent papers list. Detail: the
/// post-grade answer review — You Picked vs Correct Answer, per-question
/// explanations from the sealed keys, Wrong / Skipped / All filters.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'renance_logo.dart';
import 'theme.dart';

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
            16, MediaQuery.paddingOf(context).top + 64 + 8, 16, 24),
        children: <Widget>[
          _BacklogCard(
            student: student,
            onStart: () {
              final graded = papers.where((AttemptRow a) => a.isGraded);
              if (graded.isEmpty) return;
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) =>
                    ReviewDetailScreen(attemptId: graded.first.attemptId),
              ));
            },
          ),
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
                    'No papers yet — every paper you finish lands here '
                    'with its wrong answers for review.',
                    textAlign: TextAlign.center,
                    style: RenanceText.bodySecondary,
                  ),
                ],
              ),
            )
          else
            ...papers.map((AttemptRow a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PaperCard(
                    attempt: a,
                    title: student.titleForCode(a.code),
                    onTap: a.isGraded
                        ? () {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReviewDetailScreen(attemptId: a.attemptId),
                            ));
                          }
                        : null,
                  ),
                )),
        ],
      ),
    );
  }
}

/// "N questions to retake" — the real backlog across graded papers.
class _BacklogCard extends StatelessWidget {
  const _BacklogCard({required this.student, required this.onStart});

  final StudentController student;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final int backlog = student.questionsToReview;
    final bool hasWork = backlog > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RenanceColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_fire_department,
                  size: 18, color: RenanceColors.amber),
              const SizedBox(width: 6),
              Text('REVIEW QUEUE',
                  style: RenanceText.labelMono.copyWith(
                      color: RenanceColors.amber,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('$backlog',
                  style: RenanceText.displayLg.copyWith(
                      color: RenanceColors.amber, letterSpacing: -1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  hasWork ? 'questions to retake' : 'questions to retake — all clear',
                  style: RenanceText.bodyMedium
                      .copyWith(color: RenanceColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: hasWork ? onStart : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Start Review',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
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
        ? RenanceColors.textSecondary
        : pct >= 75
            ? RenanceColors.emerald
            : pct >= 50
                ? RenanceColors.amber
                : RenanceColors.error;
    final String when = _relative(attempt.submittedAt ?? attempt.startedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RenanceColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    attempt.isGraded
                        ? '$when · ${attempt.score}/${attempt.total} correct'
                        : '$when · ${attempt.status}',
                    style: RenanceText.caption,
                  ),
                ],
              ),
            ),
            Text(
              pct == null ? '—' : '$pct%',
              style: RenanceText.statNumber.copyWith(color: pctColor),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: RenanceColors.outlineDark),
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
  const ReviewDetailScreen({super.key, required this.attemptId});

  final String attemptId;

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

enum _ReviewFilter { wrong, skipped, all }

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  AttemptReview? _review;
  String? _error;
  _ReviewFilter _filter = _ReviewFilter.wrong;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
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

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final AttemptReview? review = _review;

    return Scaffold(
      backgroundColor: RenanceColors.card,
      appBar: AppBar(
        backgroundColor: RenanceColors.card,
        titleSpacing: 0,
        title: review == null
            ? const Text('Review')
            : Text('Review · ${review.wrongCount} wrong',
                style: RenanceText.sectionTitle),
      ),
      body: review == null
          ? Center(
              child: _error == null
                  ? const LogoActivityIndicator(label: 'Opening the marked paper…')
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: RenanceText.bodySecondary),
                          const SizedBox(height: 16),
                          OutlinedButton(
                              onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
            )
          : Builder(builder: (BuildContext context) {
              final List<ReviewQuestion> questions = review.questions
                  .where((ReviewQuestion q) => switch (_filter) {
                        _ReviewFilter.wrong => q.isWrong && q.selected.isNotEmpty,
                        _ReviewFilter.skipped => q.selected.isEmpty,
                        _ReviewFilter.all => true,
                      })
                  .toList(growable: false);
              final int wrongCount = review.wrongCount;
              final int skippedCount = review.skippedCount;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: <Widget>[
                  Text(student.titleForCode(review.code),
                      style: RenanceText.bodySecondary),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      _FilterChip('Wrong ($wrongCount)',
                          _filter == _ReviewFilter.wrong, () {
                        setState(() => _filter = _ReviewFilter.wrong);
                      }),
                      const SizedBox(width: 8),
                      _FilterChip('Skipped ($skippedCount)',
                          _filter == _ReviewFilter.skipped, () {
                        setState(() => _filter = _ReviewFilter.skipped);
                      }),
                      const SizedBox(width: 8),
                      _FilterChip('All (${review.questions.length})',
                          _filter == _ReviewFilter.all, () {
                        setState(() => _filter = _ReviewFilter.all);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (questions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          switch (_filter) {
                            _ReviewFilter.wrong =>
                              'Nothing wrong here — flawless paper.',
                            _ReviewFilter.skipped => 'No skipped questions.',
                            _ReviewFilter.all => 'No questions.',
                          },
                          style: RenanceText.bodySecondary,
                        ),
                      ),
                    )
                  else
                    ...questions.asMap().entries.map(
                          (MapEntry<int, ReviewQuestion> e) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ReviewCard(
                              index: review.questions.indexOf(e.value) + 1,
                              question: e.value,
                              onAskTutor: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'The AI tutor joins when the model key lands.')),
                                );
                              },
                            ),
                          ),
                        ),
                ],
              );
            }),
    );
  }
}

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
          color: selected
              ? RenanceColors.selectionBlue
              : RenanceColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: RenanceText.labelMono.copyWith(
            fontSize: 12,
            color: selected ? RenanceColors.ink : RenanceColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One reviewed question: stem, You Picked block, Correct Answer block,
/// explanation strip, Ask-AI row.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.index,
    required this.question,
    required this.onAskTutor,
  });

  final int index;
  final ReviewQuestion question;
  final VoidCallback onAskTutor;

  @override
  Widget build(BuildContext context) {
    final bool pickedWrong =
        question.selected.isNotEmpty && !question.correctly;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RenanceColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x33141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Q. $index', style: RenanceText.labelMono),
              if (question.topic.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: RenanceColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      question.topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.caption.copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(question.stem,
              style: RenanceText.bodyBase.copyWith(height: 1.45)),
          const SizedBox(height: 14),
          if (pickedWrong) ...<Widget>[
            _AnswerBlock(
              letter: question.selected,
              text: question.options[question.selected] ?? '',
              label: 'You Picked',
              correct: false,
            ),
            const SizedBox(height: 10),
          ],
          if (question.selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Skipped — you left this one blank.',
                  style: RenanceText.caption
                      .copyWith(color: RenanceColors.amber)),
            ),
          _AnswerBlock(
            letter: question.correct,
            text: question.options[question.correct] ?? '',
            label: 'Correct Answer',
            correct: true,
          ),
          if (question.explanation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RenanceColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                question.explanation,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: RenanceText.caption.copyWith(height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: onAskTutor,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.smart_toy,
                      size: 16, color: RenanceColors.violet),
                  const SizedBox(width: 6),
                  Text(
                    'Ask AI Tutor why ${question.correct} is right',
                    style: RenanceText.labelMono
                        .copyWith(fontSize: 12, color: RenanceColors.violet),
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

/// The letter-box + option text row (You Picked red / Correct emerald).
class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({
    required this.letter,
    required this.text,
    required this.label,
    required this.correct,
  });

  final String letter;
  final String text;
  final String label;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final Color tone = correct ? RenanceColors.emerald : RenanceColors.error;
    final Color toneBg =
        correct ? const Color(0xFFE7F8F1) : RenanceColors.errorContainer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: toneBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(letter,
              style: RenanceText.labelMono
                  .copyWith(fontSize: 15, color: tone, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label,
                  style: RenanceText.labelMono
                      .copyWith(fontSize: 11, color: tone)),
              const SizedBox(height: 2),
              Text(text,
                  style: RenanceText.bodyBase.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
