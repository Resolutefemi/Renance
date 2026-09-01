/// The CBT player: intro → playing (timer, palette, flags) → grading →
/// graded | queued (offline) | error. Watches ExamController.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'renance_logo.dart';
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          c.bundle?.title ?? widget.exam.title,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch (c.phase) {
        ExamPhase.loading => const Center(
            child: LogoActivityIndicator(label: 'Opening pack…'),
          ),
        ExamPhase.intro => _Intro(controller: c),
        ExamPhase.playing => _Player(controller: c, mmss: _mmss),
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
                  'the goroutine engine is comparing your picks '
                  'against the sealed key',
                  style: TextStyle(
                      fontSize: 12, color: RenanceColors.onSurfaceVariant),
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: RenanceColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${bundle.questionCount} questions · '
              '${bundle.durationMinutes ?? 30} minutes · '
              '${bundle.totalMarks} marks',
              style: const TextStyle(
                color: RenanceColors.onSurfaceVariant,
                fontSize: 14,
              ),
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
            const SizedBox(height: 24),
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
              style: const TextStyle(
                fontSize: 13,
                color: RenanceColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({required this.controller, required this.mmss});
  final ExamController controller;
  final String Function(int) mmss;

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    final BundleQuestion? question = controller.current;
    if (bundle == null || question == null) {
      return const Center(child: LogoActivityIndicator(label: 'Loading…'));
    }
    final bool urgent = controller.secondsRemaining < 60;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Question ${controller.index + 1} of ${bundle.questionCount}',
                style: const TextStyle(
                  fontSize: 13,
                  color: RenanceColors.onSurfaceVariant,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgent
                      ? RenanceColors.errorContainer
                      : RenanceColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mmss(controller.secondsRemaining),
                  style: TextStyle(
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: urgent ? RenanceColors.error : RenanceColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        // palette
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (var i = 0; i < bundle.questions.length; i++)
                _PaletteDot(
                  index: i,
                  controller: controller,
                  question: bundle.questions[i],
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            question.topic.isNotEmpty
                                ? question.topic.toUpperCase()
                                : 'QUESTION',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: RenanceColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => controller.toggleFlag(question.id),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              controller.flags.contains(question.id)
                                  ? Icons.flag
                                  : Icons.flag_outlined,
                              size: 18,
                              color: controller.flags.contains(question.id)
                                  ? RenanceColors.amber
                                  : RenanceColors.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question.stem,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: RenanceColors.ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...question.options.entries.map(
                      (MapEntry<String, String> opt) => _OptionTile(
                        letter: opt.key,
                        text: opt.value,
                        selected:
                            controller.answers[question.id] == opt.key,
                        onTap: () => controller.select(question.id, opt.key),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              if (controller.index > 0)
                OutlinedButton(
                  onPressed: controller.previous,
                  child: const Text('Prev'),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 48),
                ),
                onPressed: () {
                  final int unanswered =
                      bundle.questionCount - controller.answeredCount;
                  final bool last = controller.index ==
                      bundle.questionCount - 1;
                  if (last || unanswered == 0) {
                    _confirmSubmit(context, controller, unanswered);
                  } else {
                    controller.next();
                  }
                },
                child: Text(
                  controller.index == bundle.questionCount - 1
                      ? 'Submit paper'
                      : 'Next',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
}

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
    Color fg = RenanceColors.onSurfaceVariant;
    if (current) {
      side = const BorderSide(color: RenanceColors.ink, width: 1.6);
      fg = RenanceColors.ink;
    } else if (flagged) {
      side = const BorderSide(color: RenanceColors.amber, width: 1.4);
      fg = RenanceColors.amber;
    } else if (answered) {
      fill = RenanceColors.secondaryContainer;
      fg = RenanceColors.ink;
    }
    final Border dotBorder = Border.fromBorderSide(side);

    return InkWell(
      onTap: () => controller.goTo(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: dotBorder,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? RenanceColors.secondaryContainer
                : RenanceColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RenanceColors.ink : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: RenanceColors.outlineVariant),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RenanceColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: RenanceColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            const Text(
              'Saved on your device',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: RenanceColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You're offline. Your paper is stored locally and will be "
              'sent for marking automatically when you reconnect.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: RenanceColors.onSurfaceVariant,
                height: 1.5,
              ),
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

class _Result extends StatelessWidget {
  const _Result({required this.controller});
  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    final ExamResult? result = controller.result;
    if (result == null) {
      return const Center(child: LogoActivityIndicator(label: 'Loading result…'));
    }
    final int pct =
        result.total == 0 ? 0 : (result.score * 100 ~/ result.total);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: <Widget>[
                const RenanceMark(size: 48),
                const SizedBox(height: 12),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: RenanceColors.ink,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.score} of ${result.total} correct',
                  style: const TextStyle(
                    color: RenanceColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TOPIC BREAKDOWN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: RenanceColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...result.breakdown.map((TopicRow row) {
          final double frac = row.total == 0 ? 0 : row.correct / row.total;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        row.topic,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${row.correct}/${row.total}',
                        style: const TextStyle(
                          color: RenanceColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 6,
                      backgroundColor: RenanceColors.surfaceContainer,
                      color: frac >= 0.5
                          ? RenanceColors.emerald
                          : RenanceColors.amber,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Library'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => controller.load(controller.meta!),
                child: const Text('Retake'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
              style: const TextStyle(
                color: RenanceColors.error,
                fontSize: 14,
                height: 1.5,
              ),
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
