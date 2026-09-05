/// Study plan, the Stitch study_plan_light screen, 1:1.
///
/// "TODAY'S PLAN" card with the three focus blocks, the Current Energy
/// Level selector and the Fatigue Insight card. The layout, spacing and
/// copy style stay the Stitch design; the VALUES go live when the student
/// is signed in:
///
///   Practice block   weakest topic's subject from GET /syllabus/{body} (#4)
///   Review block     SM-2 due count from the cached /me/review (#3), the
///                    same 2 min per topic the review tab estimates
///   Voice block      Leitner cards due today from /me/cards/progress (#7)
///   Fatigue Insight  the /me/fatigue advisory (#6), cached in the
///                    StudentController like the home banner
///
/// Signed out, or when a call fails, the screen quietly falls back to the
/// exact Stitch copy, so the design never shows a hole. The energy chips
/// stay a local self-report; telemetry has no field for mood and we do
/// not shoehorn one in.
///
/// Wide windows (desktop, >= 560 px) keep the column centered.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'flashcards_screen.dart';
import 'theme.dart';

/// Study plan screen entry.
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key, this.onGoTab});

  /// Jumps into a home shell tab: 1 = Library (practice shelf),
  /// 2 = Review queue. Null when pushed from somewhere without the shell.
  final ValueChanged<int>? onGoTab;

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  int _energy = 0; // 0 Sharp, 1 Normal, 2 Tired

  static const List<String> _kEnergies = <String>['Sharp', 'Normal', 'Tired'];
  static const List<IconData> _kEnergyIcons = <IconData>[
    Icons.bolt,
    Icons.battery_charging_full,
    Icons.battery_1_bar,
  ];

  // Live slices loaded once; null = unknown, fall back to Stitch copy.
  String? _weakestSubject;
  int? _cardsDue;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final StudentController student = context.read<StudentController>();
    if (student.me == null) return; // signed out: pure design copy
    if (!mounted) return;
    setState(() => _signedIn = true);
    final ApiClient? api = student.api;
    if (api == null) return;

    // Weakest subject for the practice block. Any failure just leaves
    // the Stitch title on screen.
    try {
      final SyllabusTree tree = await api.syllabus(_bodySlugFor(student));
      final String topic =
          tree.weakest.isEmpty ? '' : tree.weakest.first.topic;
      final String? subject = _subjectOf(tree, topic);
      if (!mounted) return;
      setState(() => _weakestSubject = subject);
    } on ApiException catch (_) {
      // design fallback
    } on NetworkException catch (_) {
      // design fallback
    }

    // Flashcards due today for the voice block.
    try {
      final List<CardProgress> rows = await api.cardProgress();
      if (!mounted) return;
      setState(
        () => _cardsDue =
            rows.where((CardProgress r) => r.isDue).length,
      );
    } on ApiException catch (_) {
      // design fallback
    } on NetworkException catch (_) {
      // design fallback
    }
  }

  String _bodySlugFor(StudentController student) {
    final List<String> exams = student.me?.profile?.exams ?? const <String>[];
    final String exam = exams.isEmpty ? '' : exams.first;
    if (exam.contains('WAEC')) return 'waec';
    if (exam.contains('University')) return 'university-modules';
    return 'jamb';
  }

  /// The subject that owns a topic, walking the syllabus tree. Null when
  /// the topic maps to nothing (then the design title stays).
  String? _subjectOf(SyllabusTree tree, String topic) {
    if (topic.isEmpty) return null;
    for (final SyllabusSubject s in tree.subjects) {
      for (final SyllabusSection section in s.sections) {
        for (final SyllabusTopic t in section.topics) {
          if (t.topic == topic) return s.subject;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Live review + fatigue come from the controller cache, the same
    // single refresh() the launcher and review tab read.
    final StudentController student = context.watch<StudentController>();
    final StudyPlanValues plan = deriveStudyPlanValues(
      signedIn: _signedIn,
      dueTopics: student.review?.stats.due,
      cardsDue: _cardsDue,
      weakestSubject: _weakestSubject,
      fatigue: student.fatigue,
    );

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                // back bar ------------------------------------------------
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                    ),
                    const SizedBox(width: 4),
                    const Text('Study Plan', style: RenanceText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                // TODAY'S PLAN card --------------------------------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                          color: Color(0x14141C2D),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text("TODAY'S PLAN",
                                style: RenanceText.overline.copyWith(color: context.textSecondary)),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.cardLow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_outlined,
                                size: 20, color: context.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${plan.totalMinutes} min remaining',
                          style: RenanceText.displayMd),
                      const SizedBox(height: 16),
                      _PlanRow(
                        icon: Icons.science_outlined,
                        iconBg: const Color(0xFFE8F5E9),
                        iconColor: RenanceColors.emerald,
                        title: plan.practiceTitle,
                        meta: '${plan.practiceMinutes} min',
                        focus: 'High focus',
                        onTap: () => widget.onGoTab?.call(1),
                      ),
                      const SizedBox(height: 10),
                      _PlanRow(
                        icon: Icons.style_outlined,
                        iconBg: const Color(0xFFE7EEFF),
                        iconColor: context.ink,
                        title: 'Review Cards',
                        meta: '${plan.reviewMinutes} min',
                        focus: 'Medium focus',
                        onTap: () => widget.onGoTab?.call(2),
                      ),
                      const SizedBox(height: 10),
                      _PlanRow(
                        icon: Icons.mic_outlined,
                        iconBg: const Color(0xFFFFF3D6),
                        iconColor: RenanceColors.amber,
                        title: 'Voice Flashcards',
                        meta: '${plan.cardsMinutes} min',
                        focus: 'Low focus',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FlashcardsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Current Energy Level ------------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Current Energy Level',
                      style: RenanceText.sectionTitle),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    for (var i = 0; i < _kEnergies.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 10),
                      _EnergyChip(
                        label: _kEnergies[i],
                        icon: _kEnergyIcons[i],
                        selected: _energy == i,
                        onTap: () => setState(() => _energy = i),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 28),
                // Fatigue Insight -----------------------------------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.isDarkTier
                        ? RenanceColors.darkSurface
                        : const Color(0xFFE4EAFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lightbulb_outlined,
                            size: 22, color: context.ink),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Fatigue Insight',
                                style: RenanceText.bodyMedium
                                    .copyWith(color: context.ink)),
                            SizedBox(height: 8),
                            Text(
                              plan.insight,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                height: 24 / 15,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

// ------------------------------------------------------------ derivation

/// The plan block values, derived from live backend state. Pure, so the
/// tests (and the web mirror in apps/web/lib/study-plan.ts) can hold the
/// exact same numbers: unknown inputs collapse to the Stitch defaults and
/// the design copy never shows a hole.
@immutable
class StudyPlanValues {
  const StudyPlanValues({
    required this.practiceTitle,
    required this.practiceMinutes,
    required this.reviewMinutes,
    required this.cardsMinutes,
    required this.totalMinutes,
    required this.insight,
  });

  final String practiceTitle;
  final int practiceMinutes; // a focused practice block, 15 min
  final int reviewMinutes;
  final int cardsMinutes;
  final int totalMinutes;
  final String insight;
}

/// Stitch fallbacks, the numbers the design mock carries.
const int kPlanPracticeMinutes = 15;
const int kPlanReviewMinutes = 12;
const int kPlanCardsMinutes = 15;

/// The derivation. [dueTopics] is the SM-2 queue's stats.due (null while
/// loading), [cardsDue] the Leitner rows due today, [weakestSubject] the
/// subject of the syllabus map's weakest topic, [fatigue] the cached
/// /me/fatigue advisory.
StudyPlanValues deriveStudyPlanValues({
  required bool signedIn,
  int? dueTopics,
  int? cardsDue,
  String? weakestSubject,
  FatigueState? fatigue,
}) {
  // Review block: the review tab estimates 2 min per due topic; a clean
  // queue still gets a 5 min warm-up block, an unknown queue the mock 12.
  final int reviewMinutes;
  if (dueTopics == null) {
    reviewMinutes = kPlanReviewMinutes;
  } else if (dueTopics <= 0) {
    reviewMinutes = 5;
  } else {
    reviewMinutes = (dueTopics * 2).clamp(6, 40);
  }

  // Voice block: about 45 seconds per due card, 5 to 20 min window.
  final int cardsMinutes;
  if (cardsDue == null) {
    cardsMinutes = kPlanCardsMinutes;
  } else if (cardsDue <= 0) {
    cardsMinutes = 5;
  } else {
    cardsMinutes = (cardsDue * 0.75).round().clamp(5, 20);
  }

  final String practiceTitle =
      weakestSubject == null ? 'Biology Practice' : '$weakestSubject Practice';

  return StudyPlanValues(
    practiceTitle: practiceTitle,
    practiceMinutes: kPlanPracticeMinutes,
    reviewMinutes: reviewMinutes,
    cardsMinutes: cardsMinutes,
    totalMinutes: kPlanPracticeMinutes + reviewMinutes + cardsMinutes,
    insight: _insight(signedIn, fatigue, weakestSubject),
  );
}

String _insight(bool signedIn, FatigueState? fatigue, String? weakestSubject) {
  final String topicsPart = weakestSubject == null
      ? 'your heaviest topics'
      : 'your heaviest topics ($weakestSubject)';

  // Signed out: the design mock copy, exactly as Stitch wrote it.
  if (!signedIn) {
    return "You usually fade after ~25 min in the evening. We've placed "
        'your heaviest topics (Biology) first to maximize retention.';
  }
  // Signed in, no sittings yet: the honest zero state.
  if (fatigue == null || fatigue.sessionsToday == 0) {
    return 'No sittings logged today yet. We\'ve placed $topicsPart first '
        'to maximize retention.';
  }

  final int mins = fatigue.minutesToday.round();
  final String studied =
      mins >= 1 ? "You've studied $mins min today" : 'Welcome back';
  switch (fatigue.level) {
    case 'high':
      return '$studied and your pace is dipping. Take five before the '
          'next block to maximize retention.';
    case 'mild':
      return '$studied and your pace is easing. The heavier topics go '
          'first while your focus holds.';
    default:
      return "$studied. We've placed $topicsPart first to maximize "
          'retention.';
  }
}

/// One plan block row: drag-handle dots, tinted icon circle, title +
/// "15 min • High focus" meta and the play affordance.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.meta,
    required this.focus,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String meta;
  final String focus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.isDarkTier
              ? RenanceColors.darkSurfaceLow
              : const Color(0xFFEEF1FB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var r = 0; r < 2; r++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        for (var c = 0; c < 2; c++)
                          Container(
                            width: 3.5,
                            height: 3.5,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: context.outlineLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: RenanceText.bodyMedium
                          .copyWith(fontSize: 17, color: context.ink)),
                  const SizedBox(height: 2),
                  Text('$meta • $focus',
                      style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 15)),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded,
                size: 26, color: context.ink),
          ],
        ),
      ),
    );
  }
}

/// Energy chip: selection-blue when active, plain container otherwise.
class _EnergyChip extends StatelessWidget {
  const _EnergyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? context.selectionBlue
                : context.cardLow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon,
                  size: 18,
                  color: selected ? context.ink : context.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? context.ink : context.textSecondary,
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
