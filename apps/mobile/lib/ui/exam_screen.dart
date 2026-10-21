/// The CBT player, Stitch exam_player_light + score_report_light.
///
/// Playing: dark header card (Q counter, pulsing timer pill, 4px progress
/// rail), white question card with display-md stem, the letter-box option
/// stack, and the Flag / Skip / Next bottom bar. Results: the Examination
/// Performance report (exam_report_screen.dart) - cream banner, big score,
/// the timing cards, the score breakdown and the black action row.
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
import 'exam_report_screen.dart';
import 'fatigue_nudge.dart';
import 'review_screen.dart' show ReviewDetailScreen;
import 'renance_logo.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';
import 'pacing_ui.dart';
import 'premium_screen.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    required this.exam,
    this.durationOverrideMinutes,
    this.untimed = false,
    this.shuffleQuestions = false,
    this.studyMode = false,
    this.daily = false,
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

  /// The Daily Challenge sprint: every head reads "Daily Quiz" - the
  /// composed paper's plumbing label never leaks into the chrome.
  final bool daily;

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
    // EVERY graded paper lands straight in the corrections reader
    // (founder 2026-10-22: "after exam submission, it's that correction
    // page for the exam the user just did that should be opened" - the
    // report detour and the old tutor hop both die here; the reader's
    // Score chip carries the result the report used to show).
    if (c.phase == ExamPhase.graded) {
      final String? attemptId = c.attemptId;
      if (attemptId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) => ReviewDetailScreen(
              attemptId: attemptId,
              studyTitle: widget.studyMode ? widget.exam.title : null,
            ),
          ));
        });
      }
    }
    // Playing phase owns its chrome: the Myschool-cut CBT header
    // (title · copy · calculator / big clock · Quit · Submit) replaces
    // the default AppBar. The instructions page does the same: its own
    // back bar rides inside the intro body, so the scaffold AppBar stays
    // hidden there too (two stacked bars read as a bug on the intro).
    final bool inPlay = c.phase == ExamPhase.playing;
    final bool inIntro = c.phase == ExamPhase.intro;
    return Scaffold(
      backgroundColor: context.cardLowest,
      appBar: (inPlay || inIntro)
          ? null
          : AppBar(
              backgroundColor: context.cardLowest,
              leading: SheetBackKey(icon: 'arrow_back', onTap: () => Navigator.of(context).maybePop()),
              title: Text(
                  widget.studyMode ? 'Study Past Questions' : 'Active Quiz',
                  style: RenanceText.sectionTitle),
              titleSpacing: 0,
            ),
      body: switch (c.phase) {
        ExamPhase.loading => const Center(
            child: LogoActivityIndicator(label: 'Opening pack…'),
          ),
        // No scaffold AppBar on the intro: SafeArea keeps the back bar
        // clear of the status bar instead.
        ExamPhase.intro =>
          SafeArea(child: _Intro(controller: c, studyMode: widget.studyMode, daily: widget.daily)),
        ExamPhase.playing => _CapPromptGate(
            controller: c,
            child: FatigueNudgeOverlay(
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
                  daily: widget.daily,
                ),
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
        ExamPhase.graded => c.attemptId != null
            ? const SizedBox.shrink() // redirecting to the corrections reader
            : _Result(controller: c),
        ExamPhase.error => _ErrorView(controller: c),
      },
    );
  }
}

// ------------------------------------------------------------------- intro

/// The exam instructions page - the school app's "CBT Exam
/// Instructions" cut: the dark simulator banner, the instruction list,
/// then the Summary block (Subjects / Test Mode / Exam Year cards) and
/// the Proceed-to-Test action with the Edit Selections link.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.controller,
    required this.studyMode,
    this.daily = false,
  });

  final ExamController controller;
  final bool studyMode;

  /// The Daily Challenge sprint: the intro's subject card reads
  /// "Daily Quiz", never the composed paper's plumbing label.
  final bool daily;

  /// Per-subject rows for the Summary's Subjects card. The server's
  /// composition carries the CANONICAL grouping (bundle.sections:
  /// subject display names + real per-subject counts) for every
  /// composed paper except picks; picks and static packs answer with
  /// the one honest row - the pack the student actually opened
  /// (founder bug 2026-10-05: the old '-' split of a pick base like
  /// uni-futa-cos101-bank printed four fake subjects - "Uni / Futa /
  /// Cos101 / Bank - 10 Questions" each).
  List<(String, int)> _subjectRows(Bundle bundle) {
    if (bundle.sections.isNotEmpty) {
      return <(String, int)>[
        for (final BundleSection s in bundle.sections)
          (s.subject, s.questionIds.length),
      ];
    }
    // Stale cached mock bundles (pre-sections): parse the canonical
    // code - English 60, 40 per elective - with the multi-word-safe
    // splitter ("agricultural-science" is one subject, never two).
    final String code = bundle.code;
    if (code.startsWith('jamb-mock-')) {
      final String body = code.substring('jamb-mock-'.length);
      final int tilde = body.indexOf('~');
      final String subjectPart =
          tilde > 0 ? body.substring(0, tilde) : body;
      final List<String> slugs = _splitSubjectChain(subjectPart);
      final int? totalOverride = _intParam(code, 'n');
      if (slugs.isNotEmpty && totalOverride == null) {
        final int? enOverride = _intParam(code, 'enN');
        return <(String, int)>[
          (subjectName(slugs.first), enOverride ?? 60),
          for (final String s in slugs.skip(1)) (subjectName(s), 40),
        ];
      }
    }
    return const <(String, int)>[];
  }

  /// Splits a hyphen-joined subject chain into known bank slugs,
  /// longest match first ("agricultural-science-biology" ->
  /// [agricultural-science, biology]). Returns [] when a fragment
  /// matches nothing - the caller falls back to the pack title row
  /// instead of printing a fake subject.
  List<String> _splitSubjectChain(String chain) {
    final List<String> known = <String>[
      'english',
      for (final (String s, String _) in kUtmeElectives) s,
    ]..sort((String a, String b) => b.length.compareTo(a.length));
    final List<String> out = <String>[];
    String rest = chain;
    while (rest.isNotEmpty) {
      String match = '';
      for (final String s in known) {
        if (rest == s || rest.startsWith('$s-')) {
          match = s;
          break;
        }
      }
      if (match.isEmpty) return const <String>[];
      out.add(match);
      rest = rest.length == match.length
          ? ''
          : rest.substring(match.length + 1);
    }
    return out;
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
            'Leave now and nothing is submitted - you keep your seat in '
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
        // Top bar: the Renance round back (Stitch top bar) + the quiz
        // name - not the old outlined circle that read as a foreign
        // element (founder rule: every page gets a back button).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: <Widget>[
              Material(
                color: context.surfaceContainer,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _confirmLeave(context),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: MsIcon('arrow_back',
                        size: 20, color: context.ink),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  daily ? 'Daily Quiz' : bundle.title,
                  style: RenanceText.sectionTitle.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              // Simulator banner - the school app's cream banner with
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
                        // The simulator banner speaks the student's exam
                        // body - a UNI paper never opens as "JAMB CBT
                        // Simulator" (founder bug 2026-10-05).
                        studyMode
                            ? 'Past Questions Study'
                            : switch (bundle.body) {
                                'WAEC' => 'WASSCE CBT Simulator',
                                'NECO' => 'NECO CBT Simulator',
                                'University Modules' =>
                                  'University CBT Simulator',
                                'POST-UTME' => 'Post-UTME CBT Simulator',
                                _ => 'JAMB CBT Simulator',
                              },
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
                  Container(alignment: Alignment.center,
                    
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.inverseChip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: MsIcon('fact_check',
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
                  icon: 'menu_book',
                  iconBg: RenanceColors.emerald,
                  title: 'Subjects',
                  caption:
                      'You have selected, and will be examined on the '
                      'following subjects.',
                  child: Column(
                    children: <Widget>[
                      for (final (String name, int count) in subjectRows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  name,
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
                  icon: 'menu_book',
                  iconBg: RenanceColors.emerald,
                  title: 'Subjects',
                  caption: null,
                  child: Text(
                    '${daily ? 'Daily Quiz' : bundle.title} · ${bundle.questionCount} questions',
                    style: RenanceText.bodyMedium.copyWith(fontSize: 15.5),
                  ),
                ),
              const SizedBox(height: 12),
              _SummaryCard(
                icon: 'access_time_filled',
                iconBg: const Color(0xFF2563EB),
                title: 'Test Mode',
                caption: null,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        untimed
                            ? 'Study Mode - Untimed'
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
                icon: 'calendar_month',
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
              TactileButton(
                onPressed: () => controller.begin(),
                height: 54,
                radius: BorderRadius.circular(12),
                face: context.inverseChip,
                onFace: context.onInverseChip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const MsIcon('play_arrow', size: 20, fill: true),
                    const SizedBox(width: 8),
                    Text(
                      studyMode ? 'Start Study' : 'Proceed to Test',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Edit Selections'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One instruction line: a quiet emerald check bubble + the text - the
/// Renance list grammar, not the school app's bare paragraphs.
class _Instruction extends StatelessWidget {
  const _Instruction(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(alignment: Alignment.center,
            
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: RenanceColors.emerald.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: MsIcon('check',
                size: 13, color: RenanceColors.emerald),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: RenanceText.bodyBase.copyWith(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
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

  final String icon;
  final Color iconBg;
  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center,
      
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
              Container(alignment: Alignment.center,
                
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: MsIcon(icon, size: 17, color: Colors.white),
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
          MsIcon('auto_awesome',
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

/// The CBT command bar - ONE row: the quiz name on the left, the clock
/// with Quit / Submit riding right behind it on the right. Copy +
/// calculator live on the question card, beside the question they act
/// on; multi-subject papers keep the slim subject strip beneath. The
/// clock leans emerald → amber → red as the honest urgency code.
class _ExamHeader extends StatelessWidget {
  const _ExamHeader({
    required this.controller,
    required this.mmss,
    required this.hhmmss,
    this.daily = false,
  });

  final ExamController controller;
  final String Function(int) mmss;
  final String Function(int) hhmmss;

  /// The Daily Challenge sprint: the chrome head reads "Daily Quiz",
  /// never the composed paper's plumbing label.
  final bool daily;

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
            style: FilledButton.styleFrom(
              backgroundColor: context.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true && context.mounted) {
      Navigator.of(context).pop();
    }
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

    return Container(alignment: Alignment.center,
      
      decoration: BoxDecoration(
        color: context.cardLowest,
        border: Border(
          bottom: BorderSide(
            color: context.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          // LHS - the quiz name, never the subject receipt.
          Expanded(
            child: Text(
              daily ? 'Daily Quiz' : bundle.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyMedium.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // the clock, first citizen of the RHS
          Text(
            breaking
                ? 'BREAK ${mmss(controller.breakSecondsLeft)}'
                : controller.untimed
                    ? mmss(controller.elapsedSeconds)
                    : hhmmss(remaining ?? 0),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: clockColor,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Quit - a compact outlined circle; the dialog keeps the
          // accident away.
          InkWell(
            onTap: () => _confirmQuit(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(alignment: Alignment.center,
              
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.error),
              ),
              child: MsIcon('logout', size: 17, color: context.error),
            ),
          ),
          const SizedBox(width: 8),
          // Submit - right behind the clock, where the thumb lands.
          _SubmitKey(onTap: () => _Player.maybeSubmit(context, controller)),
        ],
      ),
    );
  }
}

/// The Submit key - the brand pill with the 3px extruded edge that
/// sinks on press (the tactile push-button physics).
class _SubmitKey extends StatefulWidget {
  const _SubmitKey({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SubmitKey> createState() => _SubmitKeyState();
}

class _SubmitKeyState extends State<_SubmitKey> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapCancel: () => setState(() => _pressing = false),
      onTapUp: (_) => setState(() => _pressing = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: context.inverseChip,
          boxShadow: [
            BoxShadow(
              color: mixTowardBlack(context.inverseChip, 0.68),
              offset: Offset(0, _pressing ? 1 : 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          'Submit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.onInverseChip,
          ),
        ),
      ),
    );
  }
}

/// One small circle icon button of the question card row (copy /
/// calculator): they act on the current question, so they live on the
/// card instead of crowding the command bar.
class _CardRoundIcon extends StatelessWidget {
  const _CardRoundIcon({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(alignment: Alignment.center,
        
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.outlineVariant),
          color: context.card,
        ),
        child: MsIcon(icon, size: 16, color: context.textSecondary),
      ),
    );
  }
}

/// The subject strip: for the standard UTME mock the canonical sections
/// (Use of English first, 40-question electives after) - one slim row
/// under the command bar. The current subject's name sits in the
/// middle with its answered count, progress bar and in-subject
/// question position; round < > chevrons at the row's two ends jump
/// straight to the previous / next subject's first question, so a
/// student can start the paper with any subject they like. Custom
/// multi-subject papers keep no strip, because their per-subject
/// boundaries are not derivable.
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
    final int total = bundle.questionCount;

    int activeIdx = 0;
    for (var i = 0; i < sections.length; i++) {
      if (controller.index >= sections[i].$2) activeIdx = i;
    }
    final int start = sections[activeIdx].$2;
    final int end = activeIdx + 1 < sections.length
        ? sections[activeIdx + 1].$2
        : total;
    final int secTotal = end - start;
    int answered = 0;
    for (var i = start; i < end; i++) {
      if (controller.answers.containsKey(bundle.questions[i].id)) answered++;
    }
    final double pct = secTotal > 0 ? answered / secTotal : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: <Widget>[
          // < - jump to the previous subject (dim on the first one).
          _SubjectChevron(
            icon: 'chevron_left',
            onTap: activeIdx > 0
                ? () => controller.goTo(sections[activeIdx - 1].$2)
                : null,
          ),
          const SizedBox(width: 8),
          MsIcon('subject', size: 15, color: context.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              subjectName(sections[activeIdx].$1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyMedium.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$answered/$secTotal',
            style: RenanceText.labelMono.copyWith(
              fontSize: 10.5,
              color: context.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 3,
                backgroundColor: context.cardHigh,
                valueColor: AlwaysStoppedAnimation<Color>(context.primary),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Q${controller.index - start + 1}/$secTotal',
            style: RenanceText.labelMono.copyWith(
              fontSize: 10.5,
              color: context.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          // > - jump to the next subject (dim on the last one).
          _SubjectChevron(
            icon: 'chevron_right',
            onTap: activeIdx < sections.length - 1
                ? () => controller.goTo(sections[activeIdx + 1].$2)
                : null,
          ),
        ],
      ),
    );
  }
}

/// One round < / > switcher of the subject strip: jumps to the
/// previous / next subject's first question; dimmed at the row's ends.
class _SubjectChevron extends StatelessWidget {
  const _SubjectChevron({required this.icon, this.onTap});

  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(alignment: Alignment.center,
        
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.card,
          border: Border.all(color: context.outlineVariant),
        ),
        child: MsIcon(
          icon,
          size: 17,
          color: enabled ? context.ink : context.outlineLight,
        ),
      ),
    );
  }
}

/// The playing state - the school app's CBT body: the white question
/// card with the "Question N" pill, the radio-circle option stack, the
/// Previous | Next bar, and the persistent bottom navigator
/// ("N Questions" pill + the jump strip) that expands into the full
/// question grid.
class _Player extends StatelessWidget {
  const _Player({
    required this.controller,
    required this.mmss,
    required this.hhmmss,
    this.daily = false,
  });

  final ExamController controller;
  final String Function(int) mmss;
  final String Function(int) hhmmss;

  /// Threads the Daily Challenge sprint flag down to the exam header.
  final bool daily;

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

  /// Device clipboard copy of the current question (stem + options),
  /// the study-flow hand-off to an AI chat or a note.
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
          daily: daily,
        ),
        _SubjectStrip(controller: controller),
        // Pacing runs in the background only: the per-question clock keeps
        // recording silently while the paper plays, and the forensics
        // report is the single place the student meets it (after submit).
        // Scrollable question area ---------------------------------------
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Question card --------------------------------------------
              Container(alignment: Alignment.center,
                
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
                    // "Question N" pill - the school app's badge, ink cut.
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
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
                        // copy + calculator + flag: they act on THIS
                        // question, so they ride the card - three equal
                        // round icons that always fit the row, never
                        // shoved out of the card edge on small phones.
                        _CardRoundIcon(
                          icon: 'content_copy',
                          onTap: () => _copyQuestion(context),
                        ),
                        const SizedBox(width: 6),
                        _CardRoundIcon(
                          icon: 'calculate',
                          onTap: () => _openCalculator(context),
                        ),
                        const SizedBox(width: 6),
                        // flag round icon: amber fill ring when flagged.
                        InkWell(
                          onTap: () => controller.toggleFlag(question.id),
                          customBorder: const CircleBorder(),
                          child: Container(alignment: Alignment.center,
                            
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: flagged
                                    ? RenanceColors.amber
                                    : context.outlineVariant,
                              ),
                              color: flagged
                                  ? RenanceColors.amber
                                      .withValues(alpha: 0.15)
                                  : context.card,
                            ),
                            child: MsIcon(
                              'flag',
                              size: 16,
                              fill: flagged,
                              color: flagged
                                  ? RenanceColors.amber
                                  : context.textSecondary,
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
              // Options stack - radio-circle grammar.
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
                TactileButton(
                  onPressed: controller.index == 0
                      ? null
                      : () => controller.previous(),
                  height: 44,
                  radius: RenanceRadius.chip,
                  outline: context.outlineVariant,
                  edge: context.outlineVariant,
                  edgeWidth: 3,
                  fontSize: 14,
                  expand: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const <Widget>[
                      MsIcon('chevron_left', size: 18),
                      SizedBox(width: 4),
                      Text('Previous'),
                    ],
                  ),
                ),
                const Spacer(),
                // Next → / Submit ---------------------------------------
                if (!last)
                  TactileButton(
                    onPressed: () => controller.next(),
                    height: 44,
                    radius: RenanceRadius.chip,
                    outline: context.outlineVariant,
                    edge: context.outlineVariant,
                    edgeWidth: 3,
                    fontSize: 14,
                    onFace: context.error,
                    expand: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Text('Next'),
                        SizedBox(width: 4),
                        MsIcon('chevron_right', size: 18),
                      ],
                    ),
                  )
                else
                  TactileButton(
                    onPressed: () =>
                        _Player.maybeSubmit(context, controller),
                    height: 44,
                    radius: RenanceRadius.chip,
                    outline: context.outlineVariant,
                    edge: context.outlineVariant,
                    edgeWidth: 3,
                    fontSize: 14,
                    onFace: context.error,
                    expand: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Text('Submit'),
                        SizedBox(width: 4),
                        MsIcon('chevron_right', size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Persistent bottom navigator - the school app's drawer strip.
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
                    child: MsIcon('keyboard_arrow_up',
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
                ? context.inverseChip
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
/// Option row - the web's CBT key-card grammar (3D tactile pass): the
/// squircle letter badge, the 2px border, the 3px extruded ledge and the
/// macaw wash when picked (the Supreme option-selected recipe). Pressing
/// sinks the card like a physical key.
class _OptionTile extends StatefulWidget {
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
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.darkChrome;
    final Color face = widget.selected
        ? context.selectionBlue
        : context.card;
    final Color outline = widget.selected
        ? RenanceColors.macaw
        : (dark ? RenanceColors.darkOutline : RenanceColors.swan);
    final Color ledge = mixTowardBlack(outline, dark ? 0.48 : 0.62);
    final double sink = _pressing ? 1 : 3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressing = true),
      onTapCancel: () => setState(() => _pressing = false),
      onTapUp: (_) => setState(() => _pressing = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: face,
          borderRadius: RenanceRadius.field,
          border: Border.all(color: outline, width: 2),
          boxShadow: [
            BoxShadow(color: ledge, offset: Offset(0, sink), blurRadius: 0),
          ],
        ),
        child: Row(
          children: <Widget>[
            // The squircle letter badge.
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.selected
                    ? RenanceColors.macaw
                    : context.inverseChip,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                widget.letter,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: widget.selected
                      ? Colors.white
                      : context.onInverseChip,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: QuestionText(
                widget.text,
                style: RenanceText.bodyBase.copyWith(
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
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
                  child: Container(alignment: Alignment.center,
                    
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.cardLow,
                      shape: BoxShape.circle,
                    ),
                    child: MsIcon('close',
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
            TactileButton(
              onPressed: widget.onClose,
              face: context.inverseChip,
              onFace: context.onInverseChip,
              child: const Text('Resume Exam',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
    // Dark-mode fix (2026-10-11): the unseen tile used to hardcode
    // Colors.white - in the dark tier the whole grid lit up as a
    // wall of white cells. The paper-white only belongs to the light
    // tier; dark resolves through cardLowest like every other surface.
    Color fill = context.cardLowest;
    Color fg = context.textSecondary;
    Border border = Border.all(color: context.outlineVariant, width: 1);
    if (skipped) {
      fill = context.cardLow;
      border = Border.all(color: context.cardLow, width: 1);
    }
    if (answered) {
      fill = context.primary;
      fg = context.onPrimary;
      border = Border.all(color: context.primary, width: 1);
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
          color: context.primary,
          borderRadius: BorderRadius.circular(3),
        ));
      case _NavLegendState.flagged:
        swatch = Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: context.cardLowest,
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
          color: context.cardLowest,
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
            TactileButton(
              onPressed: () => Navigator.of(context).pop(),
              face: context.inverseChip,
              onFace: context.onInverseChip,
              child: const Text('Back to library'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ result

/// The graded state: the Examination Performance report - the founder's
/// reference screenshots rebuilt with black actions. All layout lives in
/// exam_report_screen.dart so the Exam History page can replay the same
/// report from a stored attempt.
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

    return ExamReportView(
      result: result,
      title: widget.controller.meta?.title ?? code,
      code: code,
      body: widget.controller.bundle?.body ?? '',
      startedAt: widget.controller.startedAt,
      durationMs: widget.controller.durationMsUsed,
      attemptId: widget.controller.attemptId,
      delta: delta,
      xpEarned: result.score * 10, // XPPerCorrect = 10 (server rule)
      streak: student.gamification?.state.currentStreak ?? 0,
      onRetry: widget.controller.meta == null
          ? null
          : () => widget.controller.load(widget.controller.meta!),
      onGoBack: () => Navigator.of(context).pop(),
      extra: PacingForensicsSection(controller: widget.controller),
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
            MsIcon('error',
                size: 40, color: context.error),
            const SizedBox(height: 12),
            Text(
              controller.error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(
                  color: context.error, height: 1.5),
            ),
            const SizedBox(height: 20),
            TactileButton(
              onPressed: () => Navigator.of(context).pop(),
              outline: context.outlineVariant,
              fontSize: 14,
              height: 44,
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- calculator

/// The on-screen calculator every JAMB CBT hall puts next to the clock -
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
                    icon: MsIcon('close', size: 20),
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

/// The free-tier cap gate: when the controller raises the subscribe
/// prompt (the 20th answer on a capped paper, or a 402 from a capped
/// submit), the premium sheet opens once. Progress stays saved; after
/// subscribing the student continues the same paper.
/// The free-tier cap gate: when the controller raises the subscribe
/// prompt (the 20th answer on a capped paper, or a 402 from a capped
/// submit), the premium sheet opens once. Progress stays saved; after
/// subscribing the student continues the same paper.
class _CapPromptGate extends StatefulWidget {
  const _CapPromptGate({required this.controller, required this.child});

  final ExamController controller;
  final Widget child;

  @override
  State<_CapPromptGate> createState() => _CapPromptGateState();
}

class _CapPromptGateState extends State<_CapPromptGate> {
  @override
  Widget build(BuildContext context) {
    if (widget.controller.capPromptVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.dismissCapPrompt();
        // Full-screen push (not a sheet): the paywall owns the focus, and
        // back returns to the paper with every answer still in place.
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PremiumScreen(capNotice: true),
          ),
        );
      });
    }
    return widget.child;
  }
}
