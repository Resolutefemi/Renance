import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../pacing.dart';
import 'theme.dart';

/// Live pacing coach for the question currently on screen. The monochrome
/// twin of the web's PacingGauge (contributor feature, PR #1): one quiet
/// line that turns louder as the clock burns, nudging before a question
/// becomes a time trap.
class PacingGaugeCard extends StatefulWidget {
  const PacingGaugeCard({super.key, required this.enabled});

  final bool enabled;

  @override
  State<PacingGaugeCard> createState() => _PacingGaugeCardState();
}

class _PacingGaugeCardState extends State<PacingGaugeCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One second cadence, matching the exam clock the student watches.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final ExamController exam = context.watch<ExamController>();
    if (exam.phase != ExamPhase.playing || exam.bundle == null) {
      return const SizedBox.shrink();
    }

    final int minutes =
        exam.durationOverrideMinutes ?? exam.bundle!.durationMinutes ?? 30;
    final LivePacingInfo info = assessLivePacing(
      exam.dwellMsOnCurrent(),
      minutes,
      exam.bundle!.questionCount,
    );

    // Quiet for on-track, a firm outline when lingering, filled ink at
    // trap risk. Strictly black and white like the rest of the exam.
    final Color fill = switch (info.state) {
      PacingState.onTrack => context.ink.withValues(alpha: 0.06),
      PacingState.lingering => context.ink.withValues(alpha: 0.12),
      PacingState.trapRisk => context.ink,
    };
    final Color text = info.state == PacingState.trapRisk
        ? context.pageBg
        : context.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.ink.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              switch (info.state) {
                PacingState.onTrack => Icons.schedule,
                PacingState.lingering => Icons.hourglass_top,
                PacingState.trapRisk => Icons.timer_off,
              },
              size: 18,
              color: text,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${info.label} · ${info.elapsedSec}s on this question '
                '(target ${info.targetSec}s). ${info.advice}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: info.state == PacingState.trapRisk
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-sitting pacing forensics: where the clock went, the time traps,
/// the end-of-paper panic zone and the marks worth recovering. The
/// monochrome twin of the web's PacingForensicsCard.
class PacingForensicsSection extends StatefulWidget {
  const PacingForensicsSection({super.key, required this.controller});

  final ExamController controller;

  @override
  State<PacingForensicsSection> createState() => _PacingForensicsSectionState();
}

class _PacingForensicsSectionState extends State<PacingForensicsSection> {
  PacingForensicsReport? _report;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  Future<void> _build() async {
    final ExamController exam = widget.controller;
    final Bundle? bundle = exam.bundle;
    if (bundle == null || !mounted) return;

    // Per-question correctness + topic come from the graded review; a
    // queued/offline sitting has none, so the report degrades to
    // timing-only (no correctness flags) instead of disappearing.
    Map<String, ReviewQuestion>? byId;
    final String? attemptId = exam.attemptId;
    if (attemptId != null && !attemptId.startsWith('offline-')) {
      try {
        final StudentController student = context.read<StudentController>();
        final AttemptReview review =
            await student.api!.attemptReview(attemptId);
        byId = <String, ReviewQuestion>{
          for (final ReviewQuestion q in review.questions) q.questionId: q,
        };
      } catch (_) {
        byId = null; // offline or gone: timing-only report
      }
    }

    final List<QuestionTimeRecord> records = <QuestionTimeRecord>[
      for (int i = 0; i < bundle.questions.length; i++)
        if ((exam.questionMs[bundle.questions[i].id] ?? 0) > 0)
          QuestionTimeRecord(
            questionId: bundle.questions[i].id,
            index: i,
            stem: bundle.questions[i].stem,
            topic: byId?[bundle.questions[i].id]?.topic ?? '',
            durationMs: exam.questionMs[bundle.questions[i].id] ?? 0,
            selected: exam.answers[bundle.questions[i].id] ?? '',
            correct: byId?[bundle.questions[i].id]?.correctly ?? false,
          ),
    ];

    final int minutes =
        exam.durationOverrideMinutes ?? bundle.durationMinutes ?? 30;
    if (!mounted) return;
    setState(() {
      _report = computePacingForensics(records, minutes, bundle.questionCount);
      _loaded = true;
    });
  }

  String _mmss(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final PacingForensicsReport? report = _report;
    if (report == null || report.timeTraps.isEmpty && !report.hasPanicZone) {
      // A clean paper needs no lecture: keep the screen tidy.
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ink.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ink.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.timer_outlined, size: 18, color: context.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pacing forensics',
                  style: RenanceText.sectionTitle.copyWith(color: context.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${report.pacingEfficiencyPct}% on pace',
                  style: TextStyle(
                    color: context.pageBg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.summaryFeedback,
            style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _StatBox(label: 'Target / Q', value: '${report.targetSecPerQuestion}s'),
              const SizedBox(width: 8),
              _StatBox(label: 'Your avg / Q', value: '${report.averageSecPerQuestion}s'),
              const SizedBox(width: 8),
              _StatBox(label: 'Time burned', value: _mmss(report.totalTimeTrapsDurationSec)),
              const SizedBox(width: 8),
              _StatBox(label: 'Recoverable', value: '~${report.estimatedRecoverableMarks} marks'),
            ],
          ),
          if (report.timeTraps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Time traps',
              style: RenanceText.labelMono.copyWith(color: context.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            for (final TimeTrap trap in report.timeTraps.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Icon(
                      trap.correct ? Icons.check_circle_outline : Icons.cancel_outlined,
                      size: 16,
                      color: context.ink.withValues(alpha: trap.correct ? 0.45 : 1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Q${trap.index + 1} · ${trap.topic}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.bodyBase.copyWith(color: context.ink, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${trap.durationSec}s (target ${trap.targetSec}s)',
                      style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
          if (report.hasPanicZone) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.directions_run, size: 16, color: context.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'End-of-paper panic: the last ${report.panicQuestionsCount} questions were rushed. '
                    'Flag earlier, return stronger.',
                    style: RenanceText.bodySecondary.copyWith(color: context.ink, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: context.pageBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.ink.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyBase.copyWith(
                color: context.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
