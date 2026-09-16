/// The CBT player, Stitch exam_player_light + score_report_light.
///
/// Playing: dark header card (Q counter, pulsing timer pill, 4px progress
/// rail), white question card with display-md stem, the letter-box option
/// stack, and the Flag / Skip / Next bottom bar. Results: the dark
/// DIAGNOSTIC COMPLETE hero with drifting confetti, the XP + streak card,
/// time/correct stats and the topic breakdown with real thresholds.
/// All state lives in ExamController, this file is presentation only.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../papers.dart';
import '../qtext.dart';
import 'fatigue_nudge.dart';
import 'review_screen.dart' show ReviewDetailScreen;
import 'renance_logo.dart';
import 'syllabus_screen.dart';
import 'theme.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    required this.exam,
    this.durationOverrideMinutes,
    this.untimed = false,
    this.shuffleQuestions = false,
    this.studyMode = false,
  });

  final ExamMeta exam;

  /// Practice Settings overrides (Stitch practice_mode_setup): a chosen
  /// timer replaces the pack duration; untimed runs a count-up clock.
  final int? durationOverrideMinutes;
  final bool untimed;

  /// Practice Settings' shuffle toggle: re-orders the loaded questions
  /// on-device. Grading is per-question-id, so order is free.
  final bool shuffleQuestions;

  /// Study Past Questions mode (the school app's study cut): the paper
  /// plays untimed and, once graded, lands straight in the Past
  /// Questions reader with the explanations unlocked.
  final bool studyMode;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      context.read<ExamController>().load(
            widget.exam,
            durationOverrideMinutes: widget.durationOverrideMinutes,
            untimed: widget.untimed || widget.studyMode,
            shuffleQuestions: widget.shuffleQuestions,
          );
    });
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _hhmmss(int s) =>
      '${(s ~/ 3600).toString().padLeft(2, '0')} : '
      '${((s % 3600) ~/ 60).toString().padLeft(2, '0')} : '
      '${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ExamController c = context.watch<ExamController>();
    // Study mode: the graded paper lands in the Past Questions reader.
    if (widget.studyMode && c.phase == ExamPhase.graded) {
      final String? attemptId = c.attemptId;
      if (attemptId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) => ReviewDetailScreen(
              attemptId: attemptId,
              studyTitle: widget.exam.title,
            ),
          ));
        });
      }
    }
    // Playing phase owns its chrome: the Myschool-cut CBT header
    // (title · copy · calculator / big clock · Quit · Submit) replaces
    // the default AppBar.
    final bool inPlay = c.phase == ExamPhase.playing;
    return Scaffold(
      backgroundColor: context.cardLowest,
      appBar: inPlay
          ? null
          : AppBar(
              backgroundColor: context.cardLowest,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                  widget.studyMode ? 'Study Past Questions' : 'Active Quiz',
                  style: RenanceText.sectionTitle),
              titleSpacing: 0,
            ),
      body: switch (c.phase) {
        ExamPhase.loading => const Center(
            child: LogoActivityIndicator(label: 'Opening pack…'),
          ),
        ExamPhase.intro => _Intro(controller: c, studyMode: widget.studyMode),
        ExamPhase.playing => FatigueNudgeOverlay(
            visible: c.nudgeVisible,
            reasons: c.signal.reasons,
            onTakeBreak: c.takeBreak,
            onKeepGoing: c.keepGoing,
            child: SafeArea(
              bottom: false,
              child: _Player(
                controller: c,
                mmss: _mmss,
                hhmmss: _hhmmss,
                studyMode: widget.studyMode,
              ),
            ),
          ),
        ExamPhase.grading => Center(
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
                      fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ExamPhase.queued => _Queued(),
        ExamPhase.graded => widget.studyMode && c.attemptId != null
            ? const SizedBox.shrink() // redirecting to the reader
            : _Result(controller: c),
        ExamPhase.error => _ErrorView(controller: c),
      },
    );
  }
}

// ------------------------------------------------------------------- intro

/// The exam instructions page — the school app's "CBT Exam
/// Instructions" cut: the dark simulator banner, the instruction list,
/// then the Summary block (Subjects / Test Mode / Exam Year cards) and
/// the Proceed-to-Test action with the Edit Selections link.
class _Intro extends StatelessWidget {
  const _Intro({required this.controller, required this.studyMode});

  final ExamController controller;
  final bool studyMode;

  /// Per-subject counts for the standard UTME mock — English 60 and 40
  /// per elective, the canonical compose the server also uses. Custom
  /// papers show the honest "≈ split across N subjects" instead.
  List<(String, int)> _subjectRows(Bundle bundle) {
    final String code = bundle.code;
    if (code.startsWith('jamb-mock-')) {
      final String body = code.substring('jamb-mock-'.length);
      final int tilde = body.indexOf('~');
      final String subjectPart =
          tilde > 0 ? body.substring(0, tilde) : body;
      final List<String> slugs = subjectPart.split('-');
      final int? enOverride = _intParam(code, 'enN');
      final int? totalOverride = _intParam(code, 'n');
      if (totalOverride == null) {
        return <(String, int)>[
          (
            slugs.first,
            enOverride ?? 60,
          ),
          for (final String s in slugs.skip(1)) (s, 40),
        ];
      }
    }
    // Custom/pick: split the total evenly across the code's subjects.
    final String prefix = code.startsWith('jamb-custom-')
        ? 'jamb-custom-'
        : code.startsWith('waec-custom-')
            ? 'waec-custom-'
            : code.startsWith('neco-custom-')
                ? 'neco-custom-'
                : code.startsWith('jamb-pick-')
                    ? 'jamb-pick-'
                    : '';
    if (prefix.isEmpty) return <(String, int)>[];
    final String body = code.substring(prefix.length);
    final int tilde = body.indexOf('~');
    final String subjectPart = tilde > 0 ? body.substring(0, tilde) : body;
    final List<String> slugs = subjectPart.split('-');
    final int? n = _intParam(code, 'n');
    final int total = n ?? bundle.questionCount;
    final int each = slugs.isEmpty ? total : total ~/ slugs.length;
    return <(String, int)>[for (final String s in slugs) (s, each)];
  }

  int? _intParam(String code, String key) {
    final RegExp re = RegExp('$key=(\\d+)');
    return int.tryParse(re.firstMatch(code)?.group(1) ?? '');
  }

  String? _yearParam(String code) {
    final RegExp re = RegExp('(?:^|[~.])y=([\\d;r]+)');
    return re.firstMatch(code)?.group(1);
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Leave the paper?'),
        content: const Text(
            'Leave now and nothing is submitted — you keep your seat in '
            'the paper list.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) {
      return const Center(child: LogoActivityIndicator(label: 'Loading…'));
    }
    final List<(String, int)> subjectRows = _subjectRows(bundle);
    final bool untimed = controller.untimed;
    final int minutes = controller.durationOverrideMinutes ??
        bundle.durationMinutes ??
        30;
    final String? yearsRaw = _yearParam(bundle.code);

    return Column(
      children: <Widget>[
        // Back bar — every page gets a back button (founder rule).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: () => _confirmLeave(context),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.outlineVariant),
                    color: context.card,
                  ),
                  child:
                      Icon(Icons.arrow_back, size: 20, color: context.ink),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              // Simulator banner — the school app's cream banner with
              // the abstract shapes, Renance's ink ground.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: context.inverseChip,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        studyMode
                            ? 'Past Questions Study'
                            : 'JAMB CBT  Simulator',
                        style: RenanceText.sectionTitle.copyWith(
                          fontSize: 19,
                          color: context.onInverseChip,
                        ),
                      ),
                    ),
                    // The abstract corner shapes, quiet white.
                    SizedBox(
                      width: 74,
                      height: 40,
                      child: CustomPaint(
                        painter: _BannerShapes(
                          color: context.onInverseChip
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // CBT Exam Instructions ------------------------------
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.inverseChip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fact_check,
                        size: 18, color: context.onInverseChip),
                  ),
                  const SizedBox(width: 10),
                  Text('CBT Exam Instructions',
                      style: RenanceText.displayMd.copyWith(fontSize: 21)),
                ],
              ),
              const SizedBox(height: 12),
              _Instruction(
                  'Questions will appear one at a time.'),
              _Instruction(
                  "You're free to move to any question using the "
                  'question navigation at the bottom of your exam '
                  'environment.'),
              _Instruction(
                  "After answering a question, click 'Next' to proceed "
                  'to the next one.'),
              _Instruction(
                  "When you finish all the questions, click 'Submit'."),
              _Instruction(
                  'If you wish to exit before completing the test, click '
                  '"Quit" to exit the test environment and forfeit your '
                  'exam progress.'),
              _Instruction(
                  'A simple calculator has also been provided at the top '
                  'of your screen so feel free to use it as applicable.'),
              _Instruction(
                  'Keep an eye on your countdown time. If you run out of '
                  'time, your answers will be automatically submitted, '
                  'and your performance summary will be displayed.'),
              const SizedBox(height: 20),
              // Summary ----------------------------------------------
              Text('Summary', style: RenanceText.displayMd.copyWith(fontSize: 21)),
              const SizedBox(height: 12),
              if (subjectRows.isNotEmpty)
                _SummaryCard(
                  icon: Icons.menu_book,
                  iconBg: RenanceColors.emerald,
                  title: 'Subjects',
                  caption:
                      'You have selected, and will be examined on the '
                      'following subjects.',
                  child: Column(
                    children: <Widget>[
                      for (final (String slug, int count) in subjectRows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  subjectName(slug),
                                  style: RenanceText.bodyMedium
                                      .copyWith(fontSize: 15.5),
                                ),
                              ),
                              Text(
                                '$count Questions',
                                style: RenanceText.bodyBase.copyWith(
                                  fontSize: 14.5,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              else
                _SummaryCard(
                  icon: Icons.menu_book,
                  iconBg: RenanceColors.emerald,
                  title: 'Subjects',
                  caption: null,
                  child: Text(
                    '${bundle.title} · ${bundle.questionCount} questions',
                    style: RenanceText.bodyMedium.copyWith(fontSize: 15.5),
                  ),
                ),
              const SizedBox(height: 12),
              _SummaryCard(
                icon: Icons.access_time_filled,
                iconBg: const Color(0xFF2563EB),
                title: 'Test Mode',
                caption: null,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        untimed
                            ? 'Study Mode — Untimed'
                            : 'Full Test Mode',
                        style: RenanceText.bodyMedium.copyWith(
                            fontSize: 15.5),
                      ),
                    ),
                    if (!untimed) ...<Widget>[
                      Text(
                        '$minutes',
                        style: RenanceText.statNumber.copyWith(
                            fontSize: 24),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Minutes',
                        style: RenanceText.caption.copyWith(
                            color: context.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                icon: Icons.calendar_month,
                iconBg: RenanceColors.amber,
                title: 'Exam Year',
                caption: null,
                child: Text(
                  yearsRaw == null
                      ? 'All years'
                      : yearsRaw.replaceAll(';', ', '),
                  style: RenanceText.bodyMedium.copyWith(fontSize: 15.5),
                ),
              ),
              const SizedBox(height: 16),
              // Smart order keeps its Renance edge, quietly.
              _SmartOrderToggle(controller: controller),
              const SizedBox(height: 16),
              // Proceed to Test ------------------------------------
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => controller.begin(),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: context.inverseChip,
                    foregroundColor: context.onInverseChip,
                  ),
                  child: Text(
                    studyMode ? 'Start Study' : 'Proceed to Test',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Edit Selections',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: context.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One numbered-free instruction line, the school app's plain list.
class _Instruction extends StatelessWidget {
  const _Instruction(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: RenanceText.bodyBase.copyWith(
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

/// The Summary block card: coloured icon bubble + title (+ caption) +
/// the child rows, the light tint the school app uses.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.child,
    this.caption,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: RenanceText.bodyMedium.copyWith(fontSize: 16)),
            ],
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              caption!,
              style: RenanceText.bodySecondary.copyWith(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// The banner's abstract corner shapes.
class _BannerShapes extends CustomPainter {
  const _BannerShapes({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path tri = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.25)
      ..lineTo(size.width * 0.68, size.height)
      ..close();
    canvas.drawPath(tri, paint);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.28), 9, paint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.02, size.height * 0.1, 14, 14), paint);
  }

  @override
  bool shouldRepaint(_BannerShapes oldDelegate) =>
      oldDelegate.color != color;
}

/// Smart Order (ROADMAP #5): begin the paper weak-topic-first, ranked
/// from this student's own review state. Default on for practice, flip
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
        color: context.cardLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.outlineLight),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome,
              size: 18, color: on ? context.ink : context.outlineDark),
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
                  style: RenanceText.caption.copyWith(color: context.textSecondary)
                      .copyWith(fontSize: 11, color: context.textSecondary),
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

/// The Myschool-cut CBT chrome: title + copy + calculator circles on
/// the first row, the big tri-part clock with the Quit / Submit pair on
/// the second, then the subject strip for multi-subject papers. Every
/// colour stays in the founder's white & black defaults; the clock
/// leans emerald → amber → red purely as the honest urgency code.
class _ExamHeader extends StatelessWidget {
  const _ExamHeader({
    required this.controller,
    required this.mmss,
    required this.hhmmss,
    required this.onOpenCalculator,
    required this.studyMode,
  });

  final ExamController controller;
  final String Function(int) mmss;
  final String Function(int) hhmmss;
  final VoidCallback onOpenCalculator;
  final bool studyMode;

  Future<void> _confirmQuit(BuildContext context) async {
    final bool? quit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Quit the paper?'),
        content: const Text(
            'Quitting exits the test environment and forfeits your exam '
            'progress.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _copyQuestion(BuildContext context) {
    final BundleQuestion? q = controller.current;
    if (q == null) return;
    final StringBuffer buf = StringBuffer(q.stem);
    for (final MapEntry<String, String> opt in q.options.entries) {
      buf.write('\n${opt.key}) ${opt.value}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) return const SizedBox.shrink();
    final bool breaking = controller.breakSecondsLeft > 0;
    final int? remaining =
        controller.untimed ? null : controller.secondsRemaining;

    final Color clockColor;
    if (breaking) {
      clockColor = context.ink;
    } else if (remaining != null && remaining < 60) {
      clockColor = context.error;
    } else if (remaining != null && remaining < 300) {
      clockColor = RenanceColors.amber;
    } else {
      clockColor = const Color(0xFF0E9F6E); // the school app's clock green
    }

    return Container(
      decoration: BoxDecoration(
        color: context.cardLowest,
        border: Border(
          bottom: BorderSide(
            color: context.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${bundle.title}'
                    '${controller.untimed ? ' (Study Mode)' : ' (Full Test Mode)'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyMedium.copyWith(
                      fontSize: 15.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // copy circle
                _RoundIcon(
                  icon: Icons.copy_outlined,
                  onTap: () => _copyQuestion(context),
                ),
                const SizedBox(width: 8),
                // calculator circle
                _RoundIcon(
                  icon: Icons.calculate_outlined,
                  onTap: onOpenCalculator,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: <Widget>[
                // the big tri-part clock
                Expanded(
                  child: Text(
                    breaking
                        ? 'BREAK ${mmss(controller.breakSecondsLeft)}'
                        : controller.untimed
                            ? mmss(controller.elapsedSeconds)
                            : hhmmss(remaining ?? 0),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: clockColor,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                // Quit
                InkWell(
                  onTap: () => _confirmQuit(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.error),
                    ),
                    child: Text(
                      'Quit',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Submit
                InkWell(
                  onTap: () => _Player.maybeSubmit(context, controller),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: context.inverseChip,
                    ),
                    child: Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.onInverseChip,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One outlined circle icon button of the CBT header row.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.outlineVariant),
          color: context.card,
        ),
        child: Icon(icon, size: 19, color: context.ink),
      ),
    );
  }
}

/// The subject strip: for the standard UTME mock the canonical sections
/// (Use of English first, 40-question electives after) become tappable
/// chips that jump to each subject's first question — the school app's
/// subject navigation, honestly derived from the paper code. Custom
/// multi-subject papers list their subjects read-only, because their
/// per-subject boundaries are not derivable.
class _SubjectStrip extends StatelessWidget {
  const _SubjectStrip({required this.controller});

  final ExamController controller;

  List<(String, int)> _sections(Bundle bundle) {
    final String code = bundle.code;
    if (!code.startsWith('jamb-mock-')) return const <(String, int)>[];
    final String body = code.substring('jamb-mock-'.length);
    final int tilde = body.indexOf('~');
    final String subjectPart = tilde > 0 ? body.substring(0, tilde) : body;
    final List<String> slugs = subjectPart.split('-');
    final RegExp enRe = RegExp('enN=(\\d+)');
    final int english =
        int.tryParse(enRe.firstMatch(code)?.group(1) ?? '') ?? 60;
    final List<(String, int)> out = <(String, int)>[];
    int at = 0;
    for (var i = 0; i < slugs.length; i++) {
      out.add((slugs[i], at));
      at += i == 0 ? english : 40;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) return const SizedBox.shrink();
    final List<(String, int)> sections = _sections(bundle);
    if (sections.length < 2) return const SizedBox.shrink();

    int activeIdx = 0;
    for (var i = 0; i < sections.length; i++) {
      if (controller.index >= sections[i].$2) activeIdx = i;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < sections.length; i++) ...<Widget>[
              GestureDetector(
                onTap: () => controller.goTo(sections[i].$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: i == activeIdx
                        ? context.isDarkTier
                            ? context.cardHigh
                            : const Color(0xFFFDEBE7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subjectName(sections[i].$1),
                    style: RenanceText.bodyMedium.copyWith(
                      fontSize: 14.5,
                      color:
                          i == activeIdx ? context.ink : context.textSecondary,
                    ),
                  ),
                ),
              ),
              if (i < sections.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

/// The playing state — the school app's CBT body: the white question
/// card with the "Question N" pill, the radio-circle option stack, the
/// Previous | Next bar, and the persistent bottom navigator
/// ("N Questions" pill + the jump strip) that expands into the full
/// question grid.
class _Player extends StatelessWidget {
  const _Player({
    required this.controller,
    required this.mmss,
    required this.hhmmss,
    required this.studyMode,
  });

  final ExamController controller;
  final String Function(int) mmss;
  final String Function(int) hhmmss;
  final bool studyMode;

  /// The Submit affordance shared by the header pill and the bottom
  /// bar: confirm when anything is unanswered, then grade.
  static void maybeSubmit(BuildContext context, ExamController controller) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) return;
    final int unanswered = bundle.questionCount - controller.answeredCount;
    if (unanswered > 0) {
      _confirmSubmit(context, controller, unanswered);
    } else {
      controller.submit();
    }
  }

  static void _confirmSubmit(
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
              : '$unanswered question(s) unanswered, they will be marked wrong.',
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
      backgroundColor: context.pageBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) => _NavigatorSheet(
        controller: controller,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  void _openCalculator(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => const RenanceCalculatorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ExamController controller = this.controller;
    final Bundle? bundle = controller.bundle;
    final BundleQuestion? question = controller.current;
    if (bundle == null || question == null) {
      return const Center(child: LogoActivityIndicator(label: 'Loading…'));
    }
    final bool flagged = controller.flags.contains(question.id);
    final bool last = controller.index == bundle.questionCount - 1;

    return Column(
      children: <Widget>[
        _ExamHeader(
          controller: controller,
          mmss: mmss,
          hhmmss: hhmmss,
          onOpenCalculator: () => _openCalculator(context),
          studyMode: studyMode,
        ),
        _SubjectStrip(controller: controller),
        // Scrollable question area ---------------------------------------
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Question card --------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // "Question N" pill — the school app's badge, ink cut.
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: context.outlineVariant),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x14141C2D),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'Question ${controller.index + 1}',
                            style: RenanceText.bodyMedium.copyWith(
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // flag pill keeps its Renance place.
                        InkWell(
                          onTap: () => controller.toggleFlag(question.id),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: flagged
                                    ? RenanceColors.amber
                                    : context.outlineVariant,
                              ),
                              color: flagged
                                  ? RenanceColors.amber
                                      .withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  flagged
                                      ? Icons.flag
                                      : Icons.flag_outlined,
                                  size: 14,
                                  color: flagged
                                      ? RenanceColors.amber
                                      : context.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  flagged ? 'flagged' : 'flag',
                                  style: RenanceText.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: flagged
                                        ? context.ink
                                        : context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (question.passage.isNotEmpty) ...<Widget>[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardLow.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                context.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
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
                                  fontSize: 14,
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
                        fontSize: 16.5,
                        height: 26 / 16.5,
                      ),
                    ),
                    if (question.image.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          resolveQImageUrl(question.image),
                          fit: BoxFit.contain,
                          height: 220,
                          errorBuilder: (_, Object __, StackTrace? ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Options stack — radio-circle grammar.
              ...question.options.entries.map(
                (MapEntry<String, String> opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    letter: opt.key,
                    text: opt.value,
                    selected: controller.answers[question.id] == opt.key,
                    onTap: () => controller.select(question.id, opt.key),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // Sticky action bar -------------------------------------------------
        Container(
          decoration: BoxDecoration(
            color: context.cardLowest,
            border: Border(
              top: BorderSide(
                color: context.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: <Widget>[
                // ← Previous -------------------------------------------
                OutlinedButton(
                  onPressed:
                      controller.index == 0 ? null : () => controller.previous(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.outlineVariant),
                    backgroundColor: context.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.chevron_left,
                          size: 18,
                          color: controller.index == 0
                              ? context.outlineLight
                              : context.ink),
                      const SizedBox(width: 4),
                      Text('Previous',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: controller.index == 0
                                  ? context.outlineLight
                                  : context.ink)),
                    ],
                  ),
                ),
                const Spacer(),
                // Next → / Submit ---------------------------------------
                if (!last)
                  OutlinedButton(
                    onPressed: () => controller.next(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.outlineVariant),
                      backgroundColor: context.card,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Next',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: context.error)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18, color: context.error),
                      ],
                    ),
                  )
                else
                  FilledButton(
                    onPressed: () =>
                        _Player.maybeSubmit(context, controller),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      backgroundColor: context.inverseChip,
                      foregroundColor: context.onInverseChip,
                    ),
                    child: const Text('Submit',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
        // Persistent bottom navigator — the school app's drawer strip.
        _BottomNavigator(
          controller: controller,
          onExpand: () => _openNavigator(context, controller),
        ),
      ],
    );
  }
}

/// The persistent bottom navigator: "N Questions" pill + the jump strip
/// + the expand chevron, Myschool's collapsed drawer.
class _BottomNavigator extends StatelessWidget {
  const _BottomNavigator({required this.controller, required this.onExpand});

  final ExamController controller;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final Bundle? bundle = controller.bundle;
    if (bundle == null) return const SizedBox.shrink();
    final int n = bundle.questionCount;

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.cardLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$n Questions',
                    style: RenanceText.labelMono.copyWith(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onExpand,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.keyboard_arrow_up,
                        size: 22, color: context.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: n,
                itemBuilder: (BuildContext context, int i) {
                  final String id = bundle.questions[i].id;
                  final bool answered = controller.answers.containsKey(id);
                  final bool current = controller.index == i;
                  final bool flaggedNow = controller.flags.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _MiniNumber(
                      n: i + 1,
                      answered: answered,
                      current: current,
                      flagged: flaggedNow,
                      onTap: () => controller.goTo(i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One mini number tile of the strip: ink fill when answered, ring when
/// current, amber dot when flagged.
class _MiniNumber extends StatelessWidget {
  const _MiniNumber({
    required this.n,
    required this.answered,
    required this.current,
    required this.flagged,
    required this.onTap,
  });

  final int n;
  final bool answered;
  final bool current;
  final bool flagged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: answered ? context.inverseChip : context.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: current
                ? context.ink
                : answered
                    ? context.inverseChip
                    : context.outlineVariant,
            width: current ? 2 : 1,
          ),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: answered ? context.onInverseChip : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Option row: letter chip + stem; selected = selection-blue card with
/// the primary ring and the primary letter chip (Stitch selectOption
/// state machine, the student's colour when a seed is live).
/// Option row — the school app's radio-circle grammar: the circle
/// radio (hollow → ink-filled when picked), the letter, the text. The
/// student's colour rides the ring whenever a seed is live.
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? context.selectionBlue.withValues(alpha: 0.45)
              : context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? context.primary : context.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            // The radio circle.
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? context.primary : context.card,
                border: Border.all(
                  color: selected ? context.primary : context.outlineDark,
                  width: selected ? 7 : 1.6,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              letter,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: context.error.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: QuestionText(
                text,
                style: RenanceText.bodyBase.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15,
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
// ------------------------------------------------------------- navigator

/// Filter chips of the Stitch question_navigator_light sheet.
enum _NavFilter { all, flagged, skipped, unseen }

/// The full question_navigator_light bottom sheet: title + circular close,
/// count chips (All / Flagged / Skipped / Unseen), a 5-column tile grid with
/// the four paper states, the legend row and the black Resume Exam button.
class _NavigatorSheet extends StatefulWidget {
  const _NavigatorSheet({required this.controller, required this.onClose});

  final ExamController controller;
  final VoidCallback onClose;

  @override
  State<_NavigatorSheet> createState() => _NavigatorSheetState();
}

class _NavigatorSheetState extends State<_NavigatorSheet> {
  _NavFilter _filter = _NavFilter.all;

  @override
  Widget build(BuildContext context) {
    final ExamController controller = widget.controller;
    final Bundle? bundle = controller.bundle;
    if (bundle == null) return const SizedBox.shrink();

    bool answered(int i) =>
        controller.answers.containsKey(bundle.questions[i].id);
    bool flagged(int i) => controller.flags.contains(bundle.questions[i].id);
    bool skipped(int i) =>
        controller.visited.contains(bundle.questions[i].id) && !answered(i);
    bool unseen(int i) => !controller.visited.contains(bundle.questions[i].id);

    final int flaggedCount = flaggedIndices(bundle, controller).length;
    final int skippedCount = <int>[
      for (var i = 0; i < bundle.questionCount; i++)
        if (skipped(i)) i,
    ].length;
    final int unseenCount = <int>[
      for (var i = 0; i < bundle.questionCount; i++)
        if (unseen(i)) i,
    ].length;

    final Map<_NavFilter, List<int>> lists = <_NavFilter, List<int>>{
      _NavFilter.all: <int>[
        for (var i = 0; i < bundle.questionCount; i++) i,
      ],
      _NavFilter.flagged: flaggedIndices(bundle, controller),
      _NavFilter.skipped: <int>[
        for (var i = 0; i < bundle.questionCount; i++)
          if (skipped(i)) i,
      ],
      _NavFilter.unseen: <int>[
        for (var i = 0; i < bundle.questionCount; i++)
          if (unseen(i)) i,
      ],
    };
    final Map<_NavFilter, String> labels = <_NavFilter, String>{
      _NavFilter.all: 'All (${bundle.questionCount})',
      _NavFilter.flagged: 'Flagged ($flaggedCount)',
      _NavFilter.skipped: 'Skipped ($skippedCount)',
      _NavFilter.unseen: 'Unseen ($unseenCount)',
    };
    final List<int> shown = lists[_filter]!;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // title + circular close -------------------------------------
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Question Navigator',
                      style: RenanceText.sectionTitle),
                ),
                InkWell(
                  onTap: widget.onClose,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.cardLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        size: 20, color: context.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // count chips ------------------------------------------------
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: <Widget>[
                  for (final _NavFilter f in _NavFilter.values) ...<Widget>[
                    if (f != _NavFilter.values.first) const SizedBox(width: 8),
                    _NavChip(
                      label: labels[f]!,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // state grid -------------------------------------------------
            Flexible(
              child: shown.isEmpty
                  ? Center(
                      child: Text('Nothing here yet.',
                          style: RenanceText.caption.copyWith(color: context.textSecondary)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.98,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (BuildContext context, int k) =>
                          _NavTile(
                        index: shown[k],
                        answered: answered(shown[k]),
                        flagged: flagged(shown[k]),
                        skipped: skipped(shown[k]),
                        unseen: unseen(shown[k]),
                        onTap: () {
                          controller.goTo(shown[k]);
                          widget.onClose();
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            // legend -----------------------------------------------------
            const Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                _NavLegendItem(state: _NavLegendState.answered),
                _NavLegendItem(state: _NavLegendState.flagged),
                _NavLegendItem(state: _NavLegendState.skipped),
                _NavLegendItem(state: _NavLegendState.unseen),
              ],
            ),
            const SizedBox(height: 16),
            // Resume Exam ------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: widget.onClose,
                child: const Text('Resume Exam',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<int> flaggedIndices(Bundle bundle, ExamController controller) => <int>[
      for (var i = 0; i < bundle.questionCount; i++)
        if (controller.flags.contains(bundle.questions[i].id)) i,
    ];

class _NavChip extends StatelessWidget {
  const _NavChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? context.selectionBlue
              : context.cardLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? context.ink : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One grid tile: black answered, amber-ringed + dotted flagged, gray
/// skipped, hairline unseen.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.index,
    required this.answered,
    required this.flagged,
    required this.skipped,
    required this.unseen,
    required this.onTap,
  });

  final int index;
  final bool answered;
  final bool flagged;
  final bool skipped;
  final bool unseen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color fill = Colors.white;
    Color fg = context.textSecondary;
    Border border = Border.all(color: context.outlineVariant, width: 1);
    if (skipped) {
      fill = context.cardLow;
      border = Border.all(color: context.cardLow, width: 1);
    }
    if (answered) {
      fill = Colors.black;
      fg = Colors.white;
      border = Border.all(color: Colors.black, width: 1);
    }
    if (flagged) {
      border = Border.all(color: RenanceColors.amber, width: 2);
      if (!answered) fg = context.ink;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Stack(
          children: <Widget>[
            Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (flagged)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: RenanceColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _NavLegendState { answered, flagged, skipped, unseen }

class _NavLegendItem extends StatelessWidget {
  const _NavLegendItem({required this.state});

  final _NavLegendState state;

  @override
  Widget build(BuildContext context) {
    final Widget swatch;
    switch (state) {
      case _NavLegendState.answered:
        swatch = Container(
            decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(3),
        ));
      case _NavLegendState.flagged:
        swatch = Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: RenanceColors.amber, width: 1.5),
              ),
            ),
            Positioned(top: -2, right: -2, child: _amberDot()),
          ],
        );
      case _NavLegendState.skipped:
        swatch = Container(
            decoration: BoxDecoration(
          color: context.cardLow,
          borderRadius: BorderRadius.circular(3),
        ));
      case _NavLegendState.unseen:
        swatch = Container(
            decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: context.outlineVariant),
        ));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(width: 13, height: 13, child: swatch),
        SizedBox(width: 6),
        Text(
          switch (state) {
            _NavLegendState.answered => 'Answered',
            _NavLegendState.flagged => 'Flagged',
            _NavLegendState.skipped => 'Skipped',
            _NavLegendState.unseen => 'Unseen',
          },
          style: TextStyle(
              fontSize: 13, color: context.textSecondary),
        ),
      ],
    );
  }
}

Widget _amberDot() => Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: RenanceColors.amber,
        shape: BoxShape.circle,
      ),
    );

// ---------------------------------------------------- recovery (results)

/// The Stitch results_recovery_light screen: the score report's low-score
/// variant (pct below 50). Rose hero with the red progress ring, the
/// "focus on the gaps" copy, the XP pill, the Topics to Review card and
/// the Review answers / Retry weak topics actions.
class _RecoveryView extends StatelessWidget {
  const _RecoveryView({
    required this.controller,
    required this.result,
    required this.pct,
    required this.xpEarned,
  });

  final ExamController controller;
  final ExamResult result;
  final int pct;
  final int xpEarned;

  @override
  Widget build(BuildContext context) {
    final List<TopicRow> weak = result.breakdown
        .where((TopicRow r) => r.total > 0 && r.correct / r.total < 0.8)
        .toList()
      ..sort((TopicRow a, TopicRow b) =>
          (a.correct / a.total).compareTo(b.correct / b.total));

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              // rose hero -------------------------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: 128,
                      height: 128,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          CustomPaint(
                            size: const Size(128, 128),
                            painter: _RecoveryRing(
                              pct: pct,
                              trackColor: context.surfaceContainer,
                              valueColor: context.error),
                          ),
                          Text(
                            '$pct%',
                            style: RenanceText.statNumber.copyWith(
                              fontSize: 26,
                              color: context.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'The review list below is where the points are.',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodyMedium.copyWith(
                        fontSize: 19,
                        height: 27 / 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Don't sweat it. Focus on the gaps.",
                      textAlign: TextAlign.center,
                      style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    // XP pill -------------------------------------------------
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.stars,
                              size: 18, color: context.ink),
                          const SizedBox(width: 8),
                          Text('+$xpEarned',
                              style: RenanceText.bodyMedium.copyWith(
                                color: context.ink,
                              )),
                          const SizedBox(width: 8),
                          Text('XP Earned',
                              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Topics to Review ------------------------------------------
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Topics to Review',
                    style: RenanceText.sectionTitle),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                        color: Color(0x33141C2D),
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    if (weak.isEmpty)
                      Text(
                        'Nothing critical here, the review list has every '
                        'question from this paper.',
                        style: RenanceText.caption.copyWith(color: context.textSecondary),
                      )
                    else
                      ...List<Widget>.generate(weak.length, (int i) {
                        final TopicRow row = weak[i];
                        final double frac =
                            row.total == 0 ? 0 : row.correct / row.total;
                        final Color bar = frac < 0.5
                            ? context.error
                            : RenanceColors.amber;
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: i == weak.length - 1 ? 0 : 20),
                          child: Column(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(row.topic,
                                        style: RenanceText.bodyMedium),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('${row.correct}/${row.total} pts',
                                      style: RenanceText.bodyMedium.copyWith(
                                        fontSize: 14,
                                        color: bar,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  minHeight: 6,
                                  backgroundColor:
                                      context.surfaceContainer,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(bar),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
        // actions --------------------------------------------------------
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
                    onPressed: controller.attemptId == null
                        ? null
                        : () {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => ReviewDetailScreen(
                                  attemptId: controller.attemptId!),
                            ));
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        Text('Review answers',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
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
                    onPressed: () => controller.load(controller.meta!),
                    child: const Text('Retry weak topics',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
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

/// Ring of the recovery hero: light-blue track, red arc from the top.
class _RecoveryRing extends CustomPainter {
  const _RecoveryRing({required this.pct, required this.trackColor, required this.valueColor});

  final int pct;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 6;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(c, r, track);

    final Rect arc = Rect.fromCircle(center: c, radius: r);
    final Paint value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = valueColor;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      2 * math.pi * (pct / 100),
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(_RecoveryRing oldDelegate) => oldDelegate.pct != pct;
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
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, height: 1.5),
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

/// The graded state, score_report_light: dark hero with drifting
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

    // results_recovery_light: the low-score variant of the score report.
    if (pct < 50) {
      return _RecoveryView(
        controller: widget.controller,
        result: result,
        pct: pct,
        xpEarned: xpEarned,
      );
    }

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
                        color: context.card,
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
                                    style: RenanceText.caption.copyWith(color: context.textSecondary)),
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
                        color: context.card,
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
                              'No topic data on this paper, every question '
                              'counted toward the overall score.',
                              style: RenanceText.caption.copyWith(color: context.textSecondary, height: 1.4),
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
                                      : context.error;
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
                    painter: _ConfettiPainter(t: _drift.value, baseColor: context.ink),
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
                                  : context.error,
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
                                    : context.error,
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

/// Six tiny particles drifting upward, ink, emerald, amber.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.baseColor});

  final double t;
  final Color baseColor;

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
      baseColor,
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
/// Weak topics from the graded paper, tap opens the syllabus map on
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x33141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 22, color: context.textSecondary),
          const SizedBox(height: 4),
          Text(value,
              style: RenanceText.statNumber.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: RenanceText.caption.copyWith(color: context.textSecondary)),
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
            Icon(Icons.error_outline,
                size: 40, color: context.error),
            const SizedBox(height: 12),
            Text(
              controller.error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(
                  color: context.error, height: 1.5),
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

// ------------------------------------------------------------- calculator

/// The on-screen calculator every JAMB CBT hall puts next to the clock —
/// the Flutter port of the web's calculator.tsx: immediate-execution
/// arithmetic with one memory register, digits, the four operations,
/// percent, square root, sign flip and the MRC / M+ / M- row. Never eval:
/// the chain is a tiny accumulator state machine.
class RenanceCalculatorSheet extends StatefulWidget {
  const RenanceCalculatorSheet({super.key});

  @override
  State<RenanceCalculatorSheet> createState() => _RenanceCalculatorSheetState();
}

class _RenanceCalculatorSheetState extends State<RenanceCalculatorSheet> {
  String _display = '0';
  double _mem = 0;
  double? _acc; // accumulator (lhs)
  String? _op; // pending operation: + - × ÷
  bool _fresh = true; // next digit starts a new entry
  String? _lastOp; // for repeated "="
  double? _lastArg;

  double get _current => double.tryParse(_display) ?? 0;

  double _tidy(double n) => n.isFinite ? double.parse(n.toStringAsPrecision(12)) : n;

  String _format(double n) {
    if (n.isNaN || n.isInfinite) return 'Error';
    if (n != 0 && n.abs() < 1e-9) return n.toStringAsExponential(4);
    if (n.abs() >= 1e12) return n.toStringAsExponential(6);
    final String s = _tidy(n).toString();
    return s.length > 14 ? _tidy(n).toStringAsPrecision(10) : s;
  }

  void _show(double n) {
    setState(() {
      _display = _format(n);
      _fresh = false;
    });
  }

  void _digit(String d) {
    setState(() {
      if (_fresh || _display == '0') {
        _display = d == '.' ? '0.' : d;
        _fresh = false;
        return;
      }
      if (d == '.' && _display.contains('.')) return;
      if (_display.length >= 14) return;
      _display += d;
    });
  }

  void _applyOp(String op, double lhs, double rhs) {
    switch (op) {
      case '+':
        return _show(_tidy(lhs + rhs));
      case '-':
        return _show(_tidy(lhs - rhs));
      case '×':
        return _show(_tidy(lhs * rhs));
      case '÷':
        if (rhs == 0) {
          setState(() {
            _display = 'Error';
            _fresh = true;
            _acc = null;
            _op = null;
          });
          return;
        }
        return _show(_tidy(lhs / rhs));
    }
  }

  void _setOp(String op) {
    setState(() {
      if (_op != null && !_fresh) {
        _applyOp(_op!, _acc ?? 0, _current);
        _acc = double.tryParse(_display) ?? 0;
      } else {
        _acc = _current;
      }
      _op = op;
      _fresh = true;
    });
  }

  void _equals() {
    setState(() {
      if (_op != null && !_fresh) {
        _lastOp = _op;
        _lastArg = _current;
        _applyOp(_op!, _acc ?? 0, _current);
        _op = null;
        _acc = null;
        _fresh = true;
      } else if (_lastOp != null && _lastArg != null) {
        _applyOp(_lastOp!, _current, _lastArg!);
      }
    });
  }

  void _percent() {
    final double v = _current;
    _show(_op == null || _acc == null ? v / 100 : (_acc ?? 0) * v / 100);
    setState(() => _fresh = true);
  }

  void _sqrt() {
    final double v = _current;
    if (v < 0) {
      setState(() {
        _display = 'Error';
        _fresh = true;
      });
      return;
    }
    _show(_tidy(math.sqrt(v)));
  }

  void _sign() {
    if (_display == '0' || _display == 'Error') return;
    _show(-_current);
  }

  void _clear() {
    setState(() {
      _display = '0';
      _acc = null;
      _op = null;
      _fresh = true;
      _lastOp = null;
      _lastArg = null;
    });
  }

  void _mPlus() {
    setState(() {
      _mem += _current;
      _fresh = true;
    });
  }

  void _mMinus() {
    setState(() {
      _mem -= _current;
      _fresh = true;
    });
  }

  void _mrc() {
    setState(() {
      if (_fresh) {
        _mem = 0;
      } else {
        _display = _format(_mem);
        _fresh = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const List<List<String>> rows = <List<String>>[
      <String>['MRC', 'M+', 'M-', '÷'],
      <String>['7', '8', '9', '×'],
      <String>['4', '5', '6', '-'],
      <String>['1', '2', '3', '+'],
      <String>['0', '.', '%', '='],
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Calculator',
                        style: RenanceText.sectionTitle),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: context.textSecondary,
                    tooltip: 'Close',
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _display,
                  textAlign: TextAlign.right,
                  style: RenanceText.labelMono.copyWith(
                    fontSize: 28,
                    color: context.ink,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final List<String> row in rows) ...<Widget>[
                Row(
                  children: <Widget>[
                    for (final String key in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _CalcKey(
                            label: key,
                            filled: key == '=' ||
                                key == '+' ||
                                key == '-' ||
                                key == '×' ||
                                key == '÷',
                            onTap: () => _press(key),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CalcKey(
                        label: '√', onTap: _sqrt),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CalcKey(
                        label: '±', onTap: _sign),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CalcKey(
                        label: 'C',
                        onTap: _clear),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _press(String key) {
    switch (key) {
      case 'MRC':
        return _mrc();
      case 'M+':
        return _mPlus();
      case 'M-':
        return _mMinus();
      case '+':
      case '-':
      case '×':
      case '÷':
        return _setOp(key);
      case '=':
        return _equals();
      case '%':
        return _percent();
      case 'C':
        return _clear();
      case '√':
        return _sqrt();
      case '±':
        return _sign();
      default:
        if (key == '.' || int.tryParse(key) != null) return _digit(key);
    }
  }
}

/// One calculator key: ink-filled for operators, card for digits.
class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? context.inverseChip : context.cardLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: RenanceText.bodyMedium.copyWith(
                fontSize: 17,
                color: filled ? context.onInverseChip : context.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
