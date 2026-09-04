/// Notifications, the Stitch notifications_light screen, 1:1.
///
/// A derived feed, not an inbox: everything here is computed on-device
/// from data the app already fetched (review queue, awards, streak state,
/// fresh lessons), so there is no new server surface, nothing extra to
/// secure, and the screen works offline. Rows route into the shelf that
/// owns each item.
///
/// Wide windows (desktop, >= 560 px) keep the column centered.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'lessons_screen.dart' show LessonReaderScreen;
import 'theme.dart';

/// One feed row. `time` is a short relative label computed at build.
class FeedItem {
  FeedItem({
    required this.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.time,
    this.onOpen,
  });

  final String key;
  final IconData icon;
  final Color tint;
  final String title;
  final String body;
  final String time;
  final VoidCallback? onOpen;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onGoTab});

  /// Lets review/badge rows route back into the shell's tabs.
  final void Function(int tab)? onGoTab;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Lessons load lazily so the "fresh lessons" shelf has content even on
    // a first visit; failure is silent because the feed works without it.
    context.read<LessonsController>().load();
  }

  List<FeedItem> _buildFeed(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final LessonsController lessons = context.watch<LessonsController>();
    final DateTime now = DateTime.now();
    final List<FeedItem> feed = <FeedItem>[];

    // Review due, the highest-signal row a study app can show.
    final int due = student.review?.stats.due ?? 0;
    if (due > 0) {
      feed.add(FeedItem(
        key: 'review-due',
        icon: Icons.history_edu,
        tint: RenanceColors.emerald,
        title: '$due topic${due == 1 ? '' : 's'} due for review',
        body: 'Spaced repetition picked these from your weaker topics.',
        time: 'today',
        onOpen: widget.onGoTab == null
            ? null
            : () => widget.onGoTab!(2),
      ));
    }

    // Awards, freshest first. Badge names match the progress hub.
    final List<Award> awards = List<Award>.of(student.gamification?.awards ?? <Award>[])
      ..sort((Award a, Award b) => b.earnedAt.compareTo(a.earnedAt));
    for (final Award award in awards.take(5)) {
      final (String label, IconData icon, Color tint) = _awardLabel(award.code);
      feed.add(FeedItem(
        key: 'award-${award.code}-${award.earnedAt.millisecondsSinceEpoch}',
        icon: icon,
        tint: tint,
        title: 'Badge earned: $label',
        body: _awardHint(award.code),
        time: _relative(award.earnedAt, now),
      ));
    }

    // Streak state, only when it is alive or just at risk.
    final int streak = student.gamification?.state.currentStreak ?? 0;
    if (streak >= 2) {
      feed.add(FeedItem(
        key: 'streak',
        icon: Icons.local_fire_department,
        tint: RenanceColors.amber,
        title: '$streak-day streak running',
        body: 'Practice anything today to keep the flame alive.',
        time: 'today',
        onOpen: widget.onGoTab == null ? null : () => widget.onGoTab!(1),
      ));
    }

    // Fresh lessons, newest shelf additions first.
    for (final LessonMeta lesson in lessons.lessons.take(3)) {
      feed.add(FeedItem(
        key: 'lesson-${lesson.slug}',
        icon: Icons.menu_book,
        tint: context.ink,
        title: lesson.title,
        body: lesson.summary.isEmpty
            ? '${lesson.minutes} min read'
            : lesson.summary,
        time: lesson.minutes == 0 ? '' : '${lesson.minutes} min read',
        onOpen: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => LessonReaderScreen(
              slug: lesson.slug,
              title: lesson.title,
            ),
          ),
        ),
      ));
    }
    return feed;
  }

  (String, IconData, Color) _awardLabel(String code) => switch (code) {
        'first_blood' => ('First Blood', Icons.flag, context.ink),
        'xp_500' => ('Scholar', Icons.school, context.ink),
        'xp_2000' => ('Champion', Icons.military_tech, RenanceColors.amber),
        'century' => ('Century', Icons.emoji_events, RenanceColors.emerald),
        'perfect_paper' => (
            'Flawless',
            Icons.workspace_premium,
            context.ink
          ),
        'streak_3' => (
            'Warming Up',
            Icons.local_fire_department,
            RenanceColors.amber
          ),
        'streak_7' => (
            'On Fire',
            Icons.local_fire_department,
            RenanceColors.amber
          ),
        'streak_30' => (
            'Unstoppable',
            Icons.rocket_launch,
            context.ink
          ),
        _ => ('Badge', Icons.emoji_events, context.ink),
      };

  static String _awardHint(String code) => switch (code) {
        'first_blood' => 'You completed your first exam. The grind starts now.',
        'xp_500' => '500 XP earned across graded papers.',
        'xp_2000' => '2,000 XP earned. Champion form.',
        'century' => '100 questions answered correctly.',
        'perfect_paper' => 'A full paper at 100%. Flawless.',
        'streak_3' => 'Three days in a row. Warming up.',
        'streak_7' => 'Seven days in a row. On fire.',
        'streak_30' => 'Thirty days. Unstoppable.',
        _ => 'A Renance badge was added to your collection.',
      };

  static String _relative(DateTime atUtc, DateTime now) {
    final Duration diff = now.toUtc().difference(atUtc);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final int days = diff.inDays;
    if (days == 1) return 'yesterday';
    if (days < 30) return '${days}d ago';
    return '${(days / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final List<FeedItem> feed = _buildFeed(context);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: context.ink,
                      ),
                      const SizedBox(width: 4),
                      Text('Notifications', style: RenanceText.sectionTitle),
                    ],
                  ),
                ),
                Expanded(
                  child: feed.isEmpty
                      ? _AllCaughtUp()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: feed.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final FeedItem item = feed[i];
                            return _FeedRow(
                              item: item,
                              onTap: item.onOpen,
                            );
                          },
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

// ------------------------------------------------------------------ pieces

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.cardHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.done_all,
                color: RenanceColors.emerald, size: 26),
          ),
          const SizedBox(height: 14),
          Text("You're all caught up", style: RenanceText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Reviews, badges and fresh lessons will land here.',
            style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.cardLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 19, color: item.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: RenanceText.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.time.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            item.time,
                            style: RenanceText.caption.copyWith(color: context.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: RenanceText.caption.copyWith(color: context.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
