/// The new-student feature tour (founder directive, 2026-09-30): a
/// one-time card stack that makes every Renance surface discoverable
/// right after signup - with a Skip button always in reach. Persisted
/// via SharedPreferences so it shows exactly once.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

const String _kTourKey = 'renance.tour.v1';

class _TourStep {
  const _TourStep({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

const List<_TourStep> _steps = <_TourStep>[
  _TourStep(
    icon: Icons.school_outlined,
    title: 'Welcome to Renance',
    body: 'Your study OS for JAMB, WAEC, NECO, Post-UTME and university - '
        '235,110+ real past questions, spaced review, and an AI raised on all of it. '
        'Here is the tour.',
  ),
  _TourStep(
    icon: Icons.edit_note,
    title: 'Practice with real past questions',
    body: 'Pick your exam body and subject, then drill actual past papers year by year. '
        'Every question carries a worked explanation on the review screen.',
  ),
  _TourStep(
    icon: Icons.auto_awesome,
    title: 'Renance AI Studio',
    body: 'Chat with an AI grounded on the full past-question corpus, generate playable '
        'quizzes, study notes, notebooks and lesson notes - all exportable as PDF, with '
        'folders, history and memories that follow your account.',
  ),
  _TourStep(
    icon: Icons.auto_stories_outlined,
    title: 'Notes that write themselves',
    body: 'Every note, notebook and lesson note the AI generates is saved to your account, '
        'ready to download as PDF or share with classmates.',
  ),
  _TourStep(
    icon: Icons.history_edu_outlined,
    title: 'Review that never forgets',
    body: 'Wrong answers come back on a spaced-repetition schedule, and every paper you sit '
        'lands in your history with a full report - pace, accuracy, topics.',
  ),
  _TourStep(
    icon: Icons.emoji_events_outlined,
    title: 'Duel and climb',
    body: 'Challenge friends to live 1v1 arena duels, take the daily quiz, and climb the '
        'leaderboards. Wins earn REN you can redeem for premium.',
  ),
  _TourStep(
    icon: Icons.rocket_launch_outlined,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(s.icon, color: context.onPrimary, size: 24),
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
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                if (_step > 0) ...<Widget>[
                  OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (last) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _step++);
                      }
                    },
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
