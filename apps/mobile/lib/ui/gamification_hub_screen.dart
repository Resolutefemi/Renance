/// Gamification hub, the Stitch gamification_hub_light screen, 1:1.
///
/// The streak hero card (Current Streak, best streak, the 7-day dot row
/// with the pulsing today-flame), the Level card ("Level 7 · Exam Ready"
/// with the XP rail into the next level), the Badges grid with earned
/// check-circles and grayscale locks, and the Recent Awards ledger, all
/// fed by the real GET /me/gamification payload.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'badge_detail_screen.dart';
import 'leaderboard_screen.dart';
import 'msymbols.dart';
import 'notifications_screen.dart';
import 'theme.dart';
import 'tactile.dart';

/// Badge chip catalog for the grid, keyed to the server's badge codes.
const List<(String, String, String)> _kHubBadges = <(String, String, String)>[
  ('first_blood', 'First Blood', 'flag'),
  ('xp_500', 'Scholar', 'school'),
  ('streak_3', 'Warming Up', 'local_fire_department'),
  ('century', 'Century', 'emoji_events'),
  ('perfect_paper', 'Flawless', 'workspace_premium'),
  ('streak_7', 'On Fire', 'local_fire_department'),
  ('xp_2000', 'Champion', 'military_tech'),
  ('streak_30', 'Unstoppable', 'rocket_launch'),
];

const List<String> _kAwardHints = <String>[
  'Completed your first exam',
  'Completed foundational modules',
  'Kept a 3-day streak running',
  'Answered 100 questions correctly',
  'Scored 100% on a full exam',
  'Kept a 7-day streak running',
  'Top 10% in weekly practice',
  'Kept a 30-day streak running',
];

class GamificationHubScreen extends StatelessWidget {
  const GamificationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final GamificationSummary? g = student.gamification;
    final StreakState state = g?.state ??
        StreakState(
          currentStreak: 0,
          bestStreak: 0,
          totalXp: 0,
          totalCorrect: 0,
          attempts: 0,
          level: 1,
        );
    final Set<String> earned = g?.awards.map((Award a) => a.code).toSet() ??
        const <String>{};

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            // Header: back, flame pill, bell ------------------------------
            Row(
              children: <Widget>[
                _RoundBack(onBack: () => Navigator.of(context).maybePop()),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const MsIcon('local_fire_department',
                          size: 20, color: RenanceColors.amber),
                      const SizedBox(width: 4),
                      Text('${state.currentStreak}',
                          style: RenanceText.labelMono),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => NotificationsScreen()),
                  ),
                  icon: const MsIcon('notifications_none', size: 24),
                  color: context.textSecondary,
                ),
              ],
            ),
            // Streak hero card ---------------------------------------------
            const SizedBox(height: 8),
            _StreakHero(state: state),
            // Leaderboard entry ---------------------------------------------
            const SizedBox(height: 16),
            Material(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const LeaderboardScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.selectionBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const MsIcon('emoji_events', size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Leaderboard', style: RenanceText.bodyMedium),
                            Text('XP and diamond standings - see where you rank',
                                style: RenanceText.caption.copyWith(
                                    fontSize: 12,
                                    color: context.textSecondary)),
                          ],
                        ),
                      ),
                      const MsIcon('chevron_right', size: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Level card ----------------------------------------------------
            const SizedBox(height: 16),
            _LevelCard(state: state),
            // Badges grid ---------------------------------------------------
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Badges', style: RenanceText.sectionTitle),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.98,
              children: <Widget>[
                for (final (String code, String label, String icon)
                    in _kHubBadges)
                  _BadgeCell(
                    code: code,
                    label: label,
                    icon: icon,
                    earned: earned.contains(code),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BadgeDetailScreen(
                          spec: BadgeSpec(
                            code: code,
                            label: label,
                            icon: icon,
                            bg: context.selectionBlue,
                            fg: context.ink,
                            hint: () {
                              final int i = _kHubBadges.indexWhere(
                                  ((String, String, String) b) =>
                                      b.$1 == code);
                              return i >= 0
                                  ? _kAwardHints[i]
                                  : 'Keep the grind going';
                            }(),
                            earned: earned.contains(code),
                          ),
                          related: const <BadgeSpec>[],
                          currentStreak: state.currentStreak,
                          totalXp: state.totalXp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Recent awards ---------------------------------------------------
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Recent Awards', style: RenanceText.sectionTitle),
            ),
            const SizedBox(height: 10),
            if (g == null || g.awards.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No awards yet. Run a paper and the badges start landing.',
                  style: RenanceText.bodySecondary
                      .copyWith(color: context.textSecondary),
                ),
              )
            else
              ...g.awards.reversed.take(4).map<Widget>((Award a) {
                final int idx = _kHubBadges
                    .indexWhere(((String, String, String) b) =>
                        b.$1 == a.code);
                final String title = idx >= 0
                    ? '${_kHubBadges[idx].$2} Badge Earned'
                    : '${a.code} Badge Earned';
                final String hint =
                    idx >= 0 ? _kAwardHints[idx] : 'Keep the grind going';
                final String icon =
                    idx >= 0 ? _kHubBadges[idx].$3 : 'emoji_events';
                return Container(alignment: Alignment.center,
                  
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(alignment: Alignment.center,
                        
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.selectionBlue,
                        ),
                        child: MsIcon(icon,
                            size: 22, color: context.ink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(title,
                                style: RenanceText.bodyMedium
                                    .copyWith(fontSize: 14)),
                            Text(hint,
                                style: RenanceText.caption.copyWith(
                                    fontSize: 12,
                                    color: context.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- widgets

class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.cardLow,
      ),
      child: SheetBackKey(icon: 'arrow_back', onTap: onBack),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.state});

  final StreakState state;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now().toUtc();
    final int todayIdx = now.weekday - 1; // Monday = 0
    final List<String> dots = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const MsIcon('local_fire_department',
                  size: 24, color: RenanceColors.amber),
              const SizedBox(width: 8),
              Text('Current Streak', style: RenanceText.sectionTitle),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('${state.currentStreak}',
                  style: RenanceText.displayLg.copyWith(fontSize: 40)),
              const SizedBox(width: 4),
              Text('Days',
                  style: RenanceText.bodyMedium.copyWith(
                      color: context.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Best Streak: ${state.bestStreak}',
            style: RenanceText.bodySecondary
                .copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                _DayDot(
                  label: dots[i],
                  isToday: i == todayIdx,
                  isDone: i < todayIdx && (todayIdx - i) < state.currentStreak,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.isToday,
    required this.isDone,
  });

  final String label;
  final bool isToday;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final Color circle = isToday
        ? RenanceColors.amber
        : isDone
            ? RenanceColors.amber.withValues(alpha: 0.2)
            : context.cardHigh;
    final Color fg = isToday
        ? Colors.white
        : isDone
            ? RenanceColors.amber
            : context.textSecondary;

    return Column(
      children: <Widget>[
        Text(
          label,
          style: isToday
              ? RenanceText.caption
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w700)
              : RenanceText.caption.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circle),
          child: isToday || isDone
              ? MsIcon(
                  isToday ? 'local_fire_department' : 'check',
                  size: 16,
                  color: fg,
                )
              : null,
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});

  final StreakState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('Level ${state.level}',
                            style: RenanceText.sectionTitle),
                        const SizedBox(width: 8),
                        const MsIcon('verified',
                            size: 20, fill: true, color: RenanceColors.emerald),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.level >= 5 ? 'Exam Ready' : 'Keep climbing',
                      style: RenanceText.bodySecondary.copyWith(
                          color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.inverseChip,
                ),
                child: Text('${state.level}',
                    style: RenanceText.statNumber.copyWith(
                        color: context.onInverseChip, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('${state.xpIntoLevel} XP',
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary)),
              Text('${(state.level) * 500} XP',
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: state.levelProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.cardHigh,
              valueColor: AlwaysStoppedAnimation<Color>(context.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({
    required this.code,
    required this.label,
    required this.icon,
    required this.earned,
    required this.onTap,
  });

  final String code;
  final String label;
  final String icon;
  final bool earned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? context.selectionBlue : context.surfaceVariant,
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: MsIcon(icon,
                size: 32,
                color: earned ? context.ink : context.textSecondary),
          ),
          if (earned)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(alignment: Alignment.center,
                
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.card,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x14141C2D), blurRadius: 2),
                  ],
                ),
                child: const MsIcon('check_circle',
                    size: 14, fill: true, color: RenanceColors.emerald),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.pageBg.withValues(alpha: 0.5),
                ),
                child: MsIcon('lock',
                    size: 16, color: context.textSecondary),
              ),
            ),
        ],
      ),
    );

    return Opacity(
      opacity: earned ? 1.0 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              circle,
              const SizedBox(height: 8),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RenanceText.labelMono.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: context.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
