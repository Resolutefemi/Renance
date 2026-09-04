/// The CBT player — Stitch exam_player_light + score_report_light.
///
/// Playing: dark header card (Q counter, pulsing timer pill, 4px progress
/// rail), white question card with display-md stem, the letter-box option
/// stack, and the Flag / Skip / Next bottom bar. Results: the dark
/// DIAGNOSTIC COMPLETE hero with drifting confetti, the XP + streak card,
/// time/correct stats and the topic breakdown with real thresholds.
/// All state lives in ExamController — this file is presentation only.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'fatigue_nudge.dart';
import 'review_screen.dart' show ReviewDetailScreen;
import 'renance_logo.dart';
import 'syllabus_screen.dart';
import 'theme.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.exam});

  final ExamMeta exam;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      context.read<ExamController>().load(widget.exam);
    });
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ExamController c = context.watch<ExamController>();
    return Scaffold(
      backgroundColor: RenanceColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: RenanceColors.surfaceContainerLowest,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Active Quiz', style: RenanceText.sectionTitle),
        titleSpacing: 0,
      ),
      body: switch (c.phase) {
        ExamPhase.loading => const Center(
            child: LogoActivityIndicator(label: 'Opening pack…'),
          ),
        ExamPhase.intro => _Intro(controller: c),
        ExamPhase.playing => FatigueNudgeOverlay(
            visible: c.nudgeVisible,
            reasons: c.signal.reasons,
            onTakeBreak: c.takeBreak,
            onKeepGoing: c.keepGoing,
            child: _Player(controller: c, mmss: _mmss),
          ),
        ExamPhase.grading => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LogoActivityIndicator(
                  label: 'Marking your paper…',
                  size: 48,
                ),
                SizedBox(height: 10),
                Text(
                  'the engine is comparing your picks against the sealed key',
                  style: TextStyle(
                      fontSize: 12, color: RenanceColors.textSecondary),
                ),
              ],
            ),
          ),
        ExamPhase.queued => _Queued(),
        ExamPhase.graded => _Result(controller: c),
        ExamPhase.error => _ErrorView(controller: c),
      },
    );
  }
}

// ------------------------------------------------------------------- intro

class _Intro extends StatelessWidget {
  const _Intro({required this.controller});
  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) {
      return const Center(child: LogoActivityIndicator(label: 'Loading…'));
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const RenanceMark(size: 64),
            const SizedBox(height: 16),
            Text(
              bundle.title,
              textAlign: TextAlign.center,
              style: RenanceText.displayMd,
            ),
            const SizedBox(height: 8),
            Text(
              '${bundle.questionCount} questions · '
              '${bundle.durationMinutes ?? 30} minutes · '
              '${bundle.totalMarks} marks',
              style: RenanceText.bodySecondary,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    _Rule('Timer starts the moment you begin'),
                    _Rule('Auto-submits when time runs out'),
                    _Rule('Works offline — submissions sync when you reconnect'),
                    _Rule('Grading happens server-side, keys stay sealed'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SmartOrderToggle(controller: controller),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => controller.begin(),
              child: const Text('Begin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline,
              size: 15, color: RenanceColors.emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: RenanceText.caption.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Smart Order (ROADMAP #5): begin the paper weak-topic-first, ranked
/// from this student's own review state. Default on for practice — flip
/// off to answer in the pack's natural exam order.
class _SmartOrderToggle extends StatefulWidget {
  const _SmartOrderToggle({required this.controller});

  final ExamController controller;

  @override
  State<_SmartOrderToggle> createState() => _SmartOrderToggleState();
}

class _SmartOrderToggleState extends State<_SmartOrderToggle> {
  @override
  Widget build(BuildContext context) {
    final bool on = widget.controller.adaptive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: RenanceColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RenanceColors.outlineLight),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome,
              size: 18, color: on ? RenanceColors.violet : RenanceColors.outlineDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Smart order',
                    style: RenanceText.bodyMedium.copyWith(fontSize: 13)),
                Text(
                  on
                      ? 'Weak topics come first, easy before hard'
                      : 'The pack\'s natural exam order',
                  style: RenanceText.caption
                      .copyWith(fontSize: 11, color: RenanceColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: (bool v) => setState(() => widget.controller.adaptive = v),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ player

/// Dark exam header (Sticky): assignment icon + Q counter, the emerald
/// timer pill on the dark chip, and the 4px progress rail.
class _ExamHeader extends StatelessWidget {
  const _ExamHeader({
    required this.controller,
    required this.mmss,
    required this.onOpenNavigator,
  });

  final ExamController controller;
  final String Function(int) mmss;
  final VoidCallback onOpenNavigator;

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) return const SizedBox.shrink();
    final double progress =
        bundle.questionCount == 0 ? 0 : controller.index / bundle.questionCount;

    return Container(
      color: RenanceColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              InkWell(
                onTap: onOpenNavigator,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.grid_view_outlined,
                      size: 18,
                      color: RenanceColors.darkTextPrimary.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.assignment,
                  size: 18, color: RenanceColors.darkTextPrimary.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                'Q${controller.index + 1} / ${bundle.questionCount}',
                style: RenanceText.labelMono.copyWith(
                    fontSize: 14, color: RenanceColors.darkTextPrimary),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: RenanceColors.darkSurfaceLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Builder(
                  builder: (BuildContext pillContext) {
                    final bool breaking = controller.breakSecondsLeft > 0;
                    final Color pillColor = breaking
                        ? RenanceColors.violet
                        : RenanceColors.emerald;
                    return Row(
                      children: <Widget>[
                        Icon(
                          breaking
                              ? Icons.self_improvement
                              : Icons.timer,
                          size: 16,
                          color: pillColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          breaking
                              ? mmss(controller.breakSecondsLeft)
                              : mmss(controller.secondsRemaining),
                          style: RenanceText.labelMono.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: pillColor,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: RenanceColors.darkSurfaceLow,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  RenanceColors.darkTextPrimary),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// The playing state: dark header, white question card, option stack,
/// Flag | Skip | Next bottom bar.
class _Player extends StatelessWidget {
  const _Player({required this.controller, required this.mmss});

  final ExamController controller;
  final String Function(int) mmss;

  void _confirmSubmit(
    BuildContext context,
    ExamController controller,
    int unanswered,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Submit paper?'),
        content: Text(
          unanswered == 0
              ? 'All questions answered. Ready to send for marking?'
              : '$unanswered question(s) unanswered — they will be marked wrong.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep working'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.submit();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _openNavigator(BuildContext context, ExamController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RenanceColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Question Navigator', style: RenanceText.sectionTitle),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (var i = 0;
                          i < (controller.bundle?.questionCount ?? 0);
                          i++)
                        _PaletteDot(
                          index: i,
                          controller: controller,
                          question: controller.bundle!.questions[i],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    final BundleQuestion? question = controller.current;
    if (bundle == null || question == null) {
      return const Center(child: LogoActivityIndicator(label: 'Loading…'));
    }
    final bool flagged = controller.flags.contains(question.id);
    final bool last = controller.index == bundle.questionCount - 1;
    final int unanswered = bundle.questionCount - controller.answeredCount;

    return Column(
      children: <Widget>[
        _ExamHeader(
          controller: controller,
          mmss: mmss,
          onOpenNavigator: () => _openNavigator(context, controller),
        ),
        // Scrollable question area ----------------------------------------
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Question card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: RenanceColors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                        color: Color(0x33141C2D),
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (question.topic.isNotEmpty) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: RenanceColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          question.topic,
                          style: RenanceText.labelMono.copyWith(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      question.stem,
                      style: RenanceText.displayMd.copyWith(
                        fontSize: 20,
                        height: 28 / 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Options stack
              ...question.options.entries.map(
                (MapEntry<String, String> opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OptionTile(
                    letter: opt.key,
                    text: opt.value,
                    selected: controller.answers[question.id] == opt.key,
                    onTap: () => controller.select(question.id, opt.key),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom bar --------------------------------------------------------
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, -1)),
            ],
          ),
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => controller.toggleFlag(question.id),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: flagged
                              ? RenanceColors.amber
                              : RenanceColors.outlineLight,
                          width: flagged ? 1.6 : 1,
                        ),
                        backgroundColor: flagged
                            ? RenanceColors.surfaceContainerHigh
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            flagged ? Icons.flag : Icons.flag_outlined,
                            size: 20,
                            color: flagged
                                ? RenanceColors.amber
                                : RenanceColors.ink,
                          ),
                          const SizedBox(width: 8),
                          const Text('Flag',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: controller.next,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: RenanceColors.outlineLight),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Skip',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        if (last || unanswered == 0) {
                          _confirmSubmit(context, controller, unanswered);
                        } else {
                          controller.next();
                        }
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(last ? 'Submit paper' : 'Next',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          if (!last) ...<Widget>[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Option row: 40px letter box; selected = blue card + black ring + black
/// letter box + semibold text (Stitch selectOption state machine).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? RenanceColors.selectionBlue
              : RenanceColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? const <BoxShadow>[]
              : const <BoxShadow>[
                  BoxShadow(
                      color: Color(0x33141C2D),
                      blurRadius: 3,
                      offset: Offset(0, 1)),
                ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.black
                    : RenanceColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                letter,
                style: RenanceText.labelMono.copyWith(
                  fontSize: 16,
                  color: selected ? Colors.white : RenanceColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: RenanceText.bodyBase.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigator square: answered = blue fill, flagged = amber ring,
/// current = black ring.
class _PaletteDot extends StatelessWidget {
  const _PaletteDot({
    required this.index,
    required this.controller,
    required this.question,
  });

  final int index;
  final ExamController controller;
  final BundleQuestion question;

  @override
  Widget build(BuildContext context) {
    final bool answered = controller.answers.containsKey(question.id);
    final bool flagged = controller.flags.contains(question.id);
    final bool current = controller.index == index;

    BorderSide side = const BorderSide(color: RenanceColors.outlineVariant);
    Color? fill;
    Color fg = RenanceColors.textSecondary;
    if (current) {
      side = const BorderSide(color: Colors.black, width: 1.6);
      fg = Colors.black;
    } else if (flagged) {
      side = const BorderSide(color: RenanceColors.amber, width: 1.4);
      fg = RenanceColors.amber;
    } else if (answered) {
      fill = RenanceColors.selectionBlue;
      fg = RenanceColors.ink;
    }

    return InkWell(
      onTap: () {
        controller.goTo(index);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill ?? Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.fromBorderSide(side),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ queued

class _Queued extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const RenanceMark(size: 64),
            const SizedBox(height: 20),
            const Text('Saved on your device',
                style: RenanceText.displayMd),
            const SizedBox(height: 8),
            Text(
              "You're offline. Your paper is stored locally and will be "
              'sent for marking automatically when you reconnect.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to library'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ result

/// The graded state — score_report_light: dark hero with drifting
/// confetti, DIAGNOSTIC COMPLETE, the big stat, delta pill, XP card,
/// stats grid and topic breakdown.
class _Result extends StatefulWidget {
  const _Result({required this.controller});

  final ExamController controller;

  @override
  State<_Result> createState() => _ResultState();
}

class _ResultState extends State<_Result> {
  bool _refreshed = false;

  @override
  void initState() {
    super.initState();
    // Pull the fresh gamification state (XP/streak) + attempt history
    // (delta pill) exactly once when the graded screen mounts.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_refreshed || !mounted) return;
      _refreshed = true;
      context.read<StudentController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ExamResult? result = widget.controller.result;
    if (result == null) {
      return const Center(
          child: LogoActivityIndicator(label: 'Loading result…'));
    }
    final int pct =
        result.total == 0 ? 0 : (result.score * 100 ~/ result.total);

    // Delta vs the previous attempt on the same pack (real history).
    final StudentController student = context.watch<StudentController>();
    int? delta;
    final String code = widget.controller.meta?.code ?? '';
    final List<AttemptRow> samePack = student.attempts
        .where((AttemptRow a) => a.isGraded && a.code == code)
        .toList();
    if (samePack.length >= 2) {
      final int? prev = samePack[1].pct;
      if (prev != null) delta = pct - prev;
    }

    final int xpEarned = result.score * 10; // XPPerCorrect = 10 (server rule)
    final int streak = student.gamification?.state.currentStreak ?? 0;
    final int durationMs = widget.controller.durationMsUsed ?? 0;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: <Widget>[
              // Dark hero ------------------------------------------------
              _ScoreHero(pct: pct, delta: delta),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    // XP / streak card ---------------------------------
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RenanceColors.card,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                              color: Color(0x33141C2D),
                              blurRadius: 3,
                              offset: Offset(0, 1)),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RenanceColors.amber.withValues(alpha: 0.1),
                            ),
                            child: const Icon(Icons.stars,
                                color: RenanceColors.amber),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('Experience Gained',
                                    style: RenanceText.bodyMedium),
                                const SizedBox(height: 2),
                                Text('Keep the momentum going',
                                    style: RenanceText.caption),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text('+$xpEarned XP',
                                  style: RenanceText.statNumber.copyWith(
                                      fontSize: 18,
                                      color: RenanceColors.amber)),
                              const SizedBox(height: 2),
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.local_fire_department,
                                      size: 14, color: RenanceColors.amber),
                                  const SizedBox(width: 4),
                                  Text('Streak Day $streak',
                                      style: RenanceText.labelMono
                                          .copyWith(fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Stats grid -----------------------------------------
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatBox(
                            icon: Icons.timer,
                            value: _mmss(durationMs ~/ 1000),
                            label: 'Time Used',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBox(
                            icon: Icons.track_changes,
                            value: '${result.score}/${result.total}',
                            label: 'Correct Answers',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Topic breakdown --------------------------------------
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RenanceColors.card,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                              color: Color(0x33141C2D),
                              blurRadius: 3,
                              offset: Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Topic Breakdown',
                              style: RenanceText.sectionTitle),
                          const SizedBox(height: 12),
                          if (result.breakdown.isEmpty)
                            Text(
                              'No topic data on this paper — every question '
                              'counted toward the overall score.',
                              style: RenanceText.caption.copyWith(height: 1.4),
                            )
                          else
                            ...result.breakdown.map((TopicRow row) {
                              final double frac = row.total == 0
                                  ? 0
                                  : row.correct / row.total;
                              final int tpct = (frac * 100).round();
                              final Color bar = tpct >= 80
                                  ? RenanceColors.emerald
                                  : tpct >= 50
                                      ? RenanceColors.amber
                                      : RenanceColors.error;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(row.topic,
                                              style: RenanceText.bodyMedium
                                                  .copyWith(
                                                      fontSize: 13)),
                                        ),
                                        Text('$tpct%',
                                            style: RenanceText.labelMono
                                                .copyWith(
                                                    fontSize: 12,
                                                    color: RenanceColors
                                                        .textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: frac,
                                        minHeight: 8,
                                        backgroundColor: RenanceColors
                                            .surfaceContainer,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(bar),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          // Weak-topic recap (ROADMAP #4): every topic under
                          // 60% becomes a chip deep-linking the syllabus map.
                          if (result.weakTopics().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            _WeakTopicChips(
                              weak: result.weakTopics(),
                              body: widget.controller.bundle?.body ?? '',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Action buttons ---------------------------------------------------
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: widget.controller.attemptId == null
                        ? null
                        : () {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => ReviewDetailScreen(
                                  attemptId: widget.controller.attemptId!),
                            ));
                          },
                    child: const Text('Review Answers',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () =>
                        widget.controller.load(widget.controller.meta!),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        Text('Retry Weak Topics',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Dark DIAGNOSTIC COMPLETE hero with the drifting confetti particles.
class _ScoreHero extends StatefulWidget {
  const _ScoreHero({required this.pct, required this.delta});

  final int pct;
  final int? delta;

  @override
  State<_ScoreHero> createState() => _ScoreHeroState();
}

class _ScoreHeroState extends State<_ScoreHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (BuildContext context, Widget? _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        decoration: const BoxDecoration(color: RenanceColors.darkSurface),
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // confetti field
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(t: _drift.value),
                  ),
                ),
                Column(
                  children: <Widget>[
                    Text(
                      'DIAGNOSTIC COMPLETE',
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 12,
                        letterSpacing: 2.4,
                        color: RenanceColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          '${widget.pct}',
                          style: RenanceText.statNumber.copyWith(
                            fontSize: 60,
                            height: 1.0,
                            color: RenanceColors.darkTextPrimary,
                          ),
                        ),
                        Text(
                          ' %',
                          style: RenanceText.statNumber.copyWith(
                            fontSize: 24,
                            color: RenanceColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.delta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              widget.delta! >= 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 14,
                              color: widget.delta! >= 0
                                  ? RenanceColors.emerald
                                  : RenanceColors.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.delta! >= 0
                                  ? '+${widget.delta} vs last attempt'
                                  : '${widget.delta} vs last attempt',
                              style: RenanceText.labelMono.copyWith(
                                fontSize: 12,
                                color: widget.delta! >= 0
                                    ? RenanceColors.emerald
                                    : RenanceColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Six tiny particles drifting upward — violet, emerald, amber.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t});

  final double t;

  static const List<(double, double, int)> _seeds = <(double, double, int)>[
    (0.18, 0.78, 0), // x, y, color class
    (0.72, 0.88, 1),
    (0.42, 0.92, 2),
    (0.86, 0.70, 1),
    (0.13, 0.62, 2),
    (0.60, 0.60, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> colors = <Color>[
      RenanceColors.violet,
      RenanceColors.emerald,
      RenanceColors.amber,
    ];
    for (var i = 0; i < _seeds.length; i++) {
      final (double x, double y, int c) = _seeds[i];
      final double phase = (t + i / _seeds.length) % 1.0;
      final double dy = -0.30 * phase;
      final double opacity =
          (0.8 * (1 - phase) * math.sin(phase * math.pi * 2).abs())
              .clamp(0.0, 0.8);
      final Paint paint = Paint()
        ..color = colors[c].withValues(alpha: opacity);
      final Offset center =
          Offset(x * size.width, (y + dy) * size.height);
      if (i.isEven) {
        canvas.drawCircle(center, 2.2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 4, height: 4)
              .rotate(center, phase * math.pi),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

extension on Rect {
  Rect rotate(Offset center, double radians) {
    final List<Offset> corners = <Offset>[
      topLeft,
      topRight,
      bottomRight,
      bottomLeft,
    ].map((Offset c) {
      final double dx = c.dx - center.dx;
      final double dy = c.dy - center.dy;
      return Offset(
        center.dx + dx * math.cos(radians) - dy * math.sin(radians),
        center.dy + dx * math.sin(radians) + dy * math.cos(radians),
      );
    }).toList();
    return Rect.fromPoints(
      Offset(
        corners.map((Offset c) => c.dx).reduce(math.min),
        corners.map((Offset c) => c.dy).reduce(math.min),
      ),
      Offset(
        corners.map((Offset c) => c.dx).reduce(math.max),
        corners.map((Offset c) => c.dy).reduce(math.max),
      ),
    );
  }
}

/// Time Used / Correct Answers stat box.
/// Weak topics from the graded paper — tap opens the syllabus map on
/// this body (the mastery overlay shows exactly where the topic stands).
class _WeakTopicChips extends StatelessWidget {
  const _WeakTopicChips({required this.weak, required this.body});

  final List<TopicRow> weak;
  final String body;

  @override
  Widget build(BuildContext context) {
    final String slug = body.toLowerCase().replaceAll(' ', '-');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        Text('Focus next', style: RenanceText.sectionTitle.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final row in weak.take(4))
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SyllabusScreen(
                        initialBody:
                            slug.isEmpty ? 'jamb' : slug),
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: RenanceColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: RenanceColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.local_fire_department,
                          size: 14, color: RenanceColors.amber),
                      const SizedBox(width: 4),
                      Text('${row.topic} · ${row.correct}/${row.total}',
                          style:
                              RenanceText.labelMono.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
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
        children: <Widget>[
          Icon(icon, size: 22, color: RenanceColors.textSecondary),
          const SizedBox(height: 4),
          Text(value,
              style: RenanceText.statNumber.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: RenanceText.caption),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- error

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline,
                size: 40, color: RenanceColors.error),
            const SizedBox(height: 12),
            Text(
              controller.error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(
                  color: RenanceColors.error, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
