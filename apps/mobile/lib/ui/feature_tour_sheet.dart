/// The new-student feature tour (founder directive, 2026-09-30;
/// expanded 2026-10-11): a one-time card stack that makes every
/// Renance surface discoverable right after signup - with a Skip
/// button always in reach. Persisted via SharedPreferences so it shows
/// exactly once.
///
/// Founder directive (2026-10-11): the tour teaches WHERE TO CLICK for
/// every feature (bottom tabs, the header search, the AI sparkle), and
/// the Appearance step is INTERACTIVE - a "Try it now" button opens the
/// real appearance sheet from inside the tour so new students meet the
/// theme/seed controls before their first paper, and know it lives
/// under Profile for later.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_sheet.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

const String _kTourKey = 'renance.tour.v1';

class _TourStep {
  const _TourStep({
    required this.icon,
    required this.title,
    required this.body,
    this.whereToTap,
    this.actionLabel,
  });
  final String icon;
  final String title;
  final String body;

  /// The "where to click" hint - the concrete finger target.
  final String? whereToTap;

  /// Optional live action button (e.g. open the appearance sheet).
  final String? actionLabel;
}

const List<_TourStep> _steps = <_TourStep>[
  _TourStep(
    icon: 'school',
    title: 'Welcome to Renance',
    body: 'Your study OS for JAMB, WAEC, NECO, Post-UTME and university - '
        '235,110+ real past questions, spaced review, and an AI raised on all of it. '
        'Here is the full tour.',
  ),
  _TourStep(
    icon: 'apps',
    title: 'The five tabs at the bottom',
    body: 'Everything in Renance lives behind five tabs: HOME (your desk), '
        'PRACTICE (question packs and papers), REVIEW (spaced repetition), '
        'PROGRESS (reports and streaks) and PROFILE (account, focus, settings). '
        'Tap a tab any time to jump there.',
    whereToTap: 'Bottom bar - Home, Practice, Review, Progress, Profile',
  ),
  _TourStep(
    icon: 'edit_note',
    title: 'Practice with real past questions',
    body: 'Pick your exam body and subject, then drill actual past papers year by '
        'year. Every question carries a worked explanation on the review screen. '
        'University students: the Practice tab is also where your school\'s course '
        'banks live.',
    whereToTap: 'Practice tab, or the Exams tile on Home',
  ),
  _TourStep(
    icon: 'search',
    title: 'Search anything, instantly',
    body: 'Looking for a topic, a course code or a past paper? The magnifier at '
        'the top of Home searches the whole corpus - subjects, courses and '
        'questions - in one field.',
    whereToTap: 'Magnifier icon - top right of the Home header',
  ),
  _TourStep(
    icon: 'auto_awesome',
    title: 'Renance AI Studio',
    body: 'Chat with an AI grounded on the full past-question corpus, generate playable '
        'quizzes, study notes, notebooks and lesson notes - all exportable as PDF, with '
        'folders, history and memories that follow your account.',
    whereToTap: 'The sparkle button - bottom right of Home',
  ),
  _TourStep(
    icon: 'history_edu',
    title: 'Review that never forgets',
    body: 'Wrong answers come back on a spaced-repetition schedule, and every paper you sit '
        'lands in your history with a full report - pace, accuracy, topics. When the badge '
        'shows a number, that is how many topics are due right now.',
    whereToTap: 'Review tab - watch for the green badge count',
  ),
  _TourStep(
    icon: 'emoji_events',
    title: 'Duel and climb',
    body: 'Challenge friends to live 1v1 arena duels, take the daily quiz, and climb the '
        'leaderboards - Arena, JAMB, WAEC, NECO, streaks and the daily board. '
        'Wins earn REN you can redeem for premium.',
    whereToTap: 'Compete row on Home - Arena, Daily Quiz, Leaderboard',
  ),
  _TourStep(
    icon: 'offline_bolt',
    title: 'Make Renance work offline',
    body: 'Download your question packs once and Renance works with no data at all - '
        'on a bus, in a hall, anywhere. Manage or delete packs any time from the '
        'Downloads screen.',
    whereToTap: 'The offline offer after signup, or the Downloads tile',
  ),
  _TourStep(
    icon: 'school',
    title: 'Your focus shapes the app',
    body: 'Set your learning focus - JAMB, WAEC, NECO, Post-UTME or University - and the '
        'whole app reshapes around it: the home desk, the packs, the leaderboards. '
        'Change it whenever your target changes.',
    whereToTap: 'Profile tab - Learning focus card',
  ),
  _TourStep(
    icon: 'palette',
    title: 'Make it yours - Appearance',
    body: 'Light, dark or mixed mode, plus a seed colour that re-tints the whole app. '
        'Open it right now and see every surface change - you can always find it '
        'again under Profile.',
    whereToTap: 'Profile tab - Appearance card',
    actionLabel: 'Try appearance settings now',
  ),
  _TourStep(
    icon: 'rocket_launch',
    title: 'You are all set',
    body: 'Set your learning focus in Profile whenever your target changes - the whole app '
        'reshapes around it. Happy studying, scholar.',
  ),
];

/// Shows the tour once; callers await it before other first-run offers.
Future<void> maybeShowFeatureTour(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kTourKey) ?? false) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FeatureTourDialog(),
  );
  await prefs.setBool(_kTourKey, true);
}

class _FeatureTourDialog extends StatefulWidget {
  const _FeatureTourDialog();

  @override
  State<_FeatureTourDialog> createState() => _FeatureTourDialogState();
}

class _FeatureTourDialogState extends State<_FeatureTourDialog> {
  int _step = 0;

  Future<void> _runAction() async {
    // The interactive step (founder directive 2026-10-11): open the REAL
    // appearance sheet from inside the tour so the new student touches
    // the light/dark/seed controls before their first paper. The tour
    // dialog stays mounted underneath; when the sheet closes the walk
    // continues exactly where it left off.
    final _TourStep s = _steps[_step];
    if (s.actionLabel == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppearanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _TourStep s = _steps[_step];
    final bool last = _step == _steps.length - 1;
    return Dialog(
      backgroundColor: context.pageBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(alignment: Alignment.center,
                  
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: MsIcon(s.icon, color: context.onPrimary, size: 24),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'SKIP',
                    style: RenanceText.labelMono
                        .copyWith(fontSize: 11, color: context.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                for (int i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _step ? 22 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == _step ? context.ink : context.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const Spacer(),
                Text('${_step + 1}/${_steps.length}',
                    style: RenanceText.labelMono.copyWith(fontSize: 10)),
              ],
            ),
            const SizedBox(height: 10),
            Text(s.title,
                style: RenanceText.sectionTitle.copyWith(fontSize: 19)),
            const SizedBox(height: 8),
            Text(
              s.body,
              style: RenanceText.bodyBase
                  .copyWith(fontSize: 13.5, height: 1.5, color: context.textSecondary),
            ),
            // The "where to click" hint: the concrete finger target for
            // this feature, styled as a pointer chip so it reads as a
            // direction, not more copy.
            if (s.whereToTap != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MsIcon('touch_app',
                        size: 16, color: context.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.whereToTap!,
                        style: RenanceText.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // The live action: opens the real appearance sheet.
            if (s.actionLabel != null) ...<Widget>[
              const SizedBox(height: 12),
              TactileButton(
                onPressed: _runAction,
                outline: context.outlineVariant,
                edge: context.outlineVariant,
                edgeWidth: 3,
                height: 46,
                fontSize: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const MsIcon('open_in_new', size: 16),
                    const SizedBox(width: 8),
                    Text(s.actionLabel!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                if (_step > 0) ...<Widget>[
                  TactileButton(
                    onPressed: () => setState(() => _step--),
                    outline: context.outlineVariant,
                    edge: context.outlineVariant,
                    edgeWidth: 3,
                    height: 46,
                    fontSize: 14,
                    expand: false,
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TactileButton(
                    onPressed: () {
                      if (last) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _step++);
                      }
                    },
                    height: 46,
                    fontSize: 14,
                    child: Text(last ? 'Start studying' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
