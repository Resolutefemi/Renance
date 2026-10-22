/// The mobile FAQ (founder pass VIII): a simple Material list of
/// expandable Q&A tiles carrying the CURRENT Renance facts - the
/// diamond economy, referrals, streak freezes, the exam surface, the
/// course desk, performance and corrections, the feed, quests, offline
/// packs, school workspaces and how to reach management. Reached from
/// Profile -> Help & Support (and the More sheet's Help & FAQ tile
/// stays the license page until its owner rewires it). The footer keeps
/// the old 'Open-source licenses' showLicensePage behavior the profile
/// row used to open.
library;

import 'package:flutter/material.dart';

import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

class _FaqEntry {
  const _FaqEntry(this.question, this.answer);
  final String question;
  final String answer;
}

/// The 12 founder-approved facts, kept current with pass VII/VIII.
const List<_FaqEntry> _kFaq = <_FaqEntry>[
  _FaqEntry(
    'What are diamonds and how do I earn them?',
    'Diamonds are the Renance currency. You earn them from daily and '
    'weekly quests, chest drops on the course path, and first-time '
    'clears of topics and papers. Spend them in the Shop.',
  ),
  _FaqEntry(
    'How does the referral bonus work?',
    'Share your referral code from Profile. Each friend who joins '
    'Renance with your code earns you 100 diamonds - no cap on how '
    'many friends you bring.',
  ),
  _FaqEntry(
    'What are Streak Freezes?',
    'A Streak Freeze auto-saves a day you miss, so your streak survives '
    'life happening. They cost 200 diamonds each and you can hold up to '
    '2 at a time; one is spent automatically the day you skip.',
  ),
  _FaqEntry(
    'Which exams does Renance cover?',
    'JAMB UTME plus the full JAMB MOCK, WAEC/WASSCE, NECO, and '
    'Post-UTME by school - with dedicated university desks once you '
    'pick your department.',
  ),
  _FaqEntry(
    'What is the course desk?',
    'Your department\'s courses, curated with syllabus-aligned lessons '
    'and question banks - plus courses from OTHER departments you can '
    'borrow any time from the "Other departments" shelf.',
  ),
  _FaqEntry(
    'How does performance analysis work?',
    'Every graded paper feeds your subject mastery - accuracy, pace '
    'and topic-by-topic strength - so you always know what to drill '
    'next.',
  ),
  _FaqEntry(
    'What are corrections?',
    'After every graded paper you get per-subject correction pills: '
    'each wrong or skipped question comes back with the right answer '
    'and a worked explanation, and feeds your review queue.',
  ),
  _FaqEntry(
    'What can I share on the feed?',
    'Your achievements post themselves - streaks, big scores, league '
    'promotions - and you can share your own wins, follow friends and '
    'cheer their milestones.',
  ),
  _FaqEntry(
    'What are quests?',
    'Daily and weekly missions - finish topics, keep the streak, win '
    'papers - each paying out diamonds you can spend on freezes, '
    'hearts and boosts.',
  ),
  _FaqEntry(
    'Do Renance packs work offline?',
    'Yes. Download a pack once and its questions, lessons and review '
    'work with no data at all; submissions made offline queue and sync '
    'when you are back.',
  ),
  _FaqEntry(
    'What do schools get?',
    'Free school workspaces: managers set up the school, then teachers '
    'run syllabi, schemes of work, notes and results from their own '
    'sign-in.',
  ),
  _FaqEntry(
    'How do I reach Renance management?',
    'Join our WhatsApp channel from the app for news and study packs, '
    'or message management directly on +234 916 763 6685.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: <Widget>[
            // The page bar: the flat back key + the 15px w800 title
            // (the About screen's exact header recipe).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    TactileBackKey(
                      onTap: () => Navigator.of(context).pop(),
                      size: 42,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Help & FAQ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.15,
                          color: context.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                'Everything students ask, answered.',
                style: RenanceText.bodySecondary.copyWith(
                  color: context.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final _FaqEntry entry in _kFaq)
              _FaqTile(entry: entry),
            const SizedBox(height: 18),
            // The footer row keeps the old licenses behavior the profile
            // row used to open.
            Center(
              child: TextButton(
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Renance',
                    applicationLegalese: 'Learn. Practice. Rise.',
                  );
                },
                child: Text(
                  'Open-source licenses',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textSecondary,
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

/// One expandable Q&A tile: card container, question row with the
/// rotating chevron, and an AnimatedCrossFade for the answer.
class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.entry});

  final _FaqEntry entry;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.entry.question,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: MsIcon(
                        'expand_more',
                        size: 20,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 160),
                  sizeCurve: Curves.easeOut,
                  crossFadeState: _open
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.entry.answer,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                        color: context.textSecondary,
                      ),
                    ),
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
