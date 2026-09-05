/// Progress, the gamification hub (design: gamification_hub_light).
/// Streak hero with a live 7-day dot row, level card with XP progress,
/// the 8-badge grid (earned vs locked) and the recent-awards ledger.
/// Data: GET /me/gamification; RenanceMark is the only loader.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import 'badge_detail_screen.dart';
import 'gamification_hub_screen.dart';
import 'progress_dashboard_screen.dart';
import 'renance_logo.dart';
import 'theme.dart';

// Pastel badge tints from the design library (badge_detail_light).
const Color _kBlueTint = Color(0xFFD0E1FB); // selection-blue
const Color _kEmeraldTint = Color(0xFFE8F5E9);
const Color _kBadgeTint = Color(0xFFE7EEFF); // surface-container
const Color _kAmberTint = Color(0xFFFFF3D6); // amber/20 on white

/// One row of the badge catalog. Colors: circle background / foreground.
class _BadgeSpec {
  _BadgeSpec(this.code, this.label, this.icon, this.bg, this.fg, this.hint);
  final String code;
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String hint;
}

/// Mirrors the server's BadgesFor codes, keep in sync with
/// apps/study-api/internal/store/gamification.go.
List<_BadgeSpec> _kBadgeCatalog = <_BadgeSpec>[
  _BadgeSpec('first_blood', 'First Blood', Icons.flag, _kBlueTint,
      RenanceColors.ink, 'Complete your first exam'),
  _BadgeSpec('xp_500', 'Scholar', Icons.school, _kBlueTint,
      RenanceColors.ink,
      'Earn 500 XP'),
  _BadgeSpec('streak_3', 'Warming Up', Icons.local_fire_department,
      _kAmberTint, RenanceColors.amber, 'Keep a 3-day streak'),
  _BadgeSpec('century', 'Century', Icons.emoji_events, _kEmeraldTint,
      RenanceColors.emerald, 'Answer 100 questions correctly'),
  _BadgeSpec('perfect_paper', 'Flawless', Icons.workspace_premium,
      _kBadgeTint, RenanceColors.ink, 'Score 100% on a full exam'),
  _BadgeSpec('streak_7', 'On Fire', Icons.local_fire_department, _kAmberTint,
      RenanceColors.amber, 'Keep a 7-day streak'),
  _BadgeSpec('xp_2000', 'Champion', Icons.military_tech, _kAmberTint,
      RenanceColors.amber, 'Earn 2,000 XP'),
  _BadgeSpec('streak_30', 'Unstoppable', Icons.rocket_launch, _kBadgeTint,
      RenanceColors.ink, 'Keep a 30-day streak'),
];

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  GamificationSummary? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await context.read<ApiClient>().gamification();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const RenanceMark(size: 34),
            const SizedBox(width: 10),
            Text('Progress', style: TextStyle(fontWeight: FontWeight.w600)),
            if (data != null && data.state.currentStreak > 0) ...<Widget>[
              SizedBox(width: 12),
              _StreakPill(count: data.state.currentStreak),
            ],
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Progress report',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ProgressDashboardScreen()),
            ),
            icon: const Icon(Icons.insights),
          ),
          IconButton(
            tooltip: 'Awards hub',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const GamificationHubScreen()),
            ),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
      body: switch ((data, _error)) {
        (null, null) => const Center(
            child: LogoActivityIndicator(label: 'Loading your progress…'),
          ),
        (_, final String err) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.cloud_off_outlined,
                      size: 36, color: context.error),
                  SizedBox(height: 12),
                  Text(err,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.textSecondary)),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        (final GamificationSummary d, _) => RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                _StreakHero(state: d.state),
                const SizedBox(height: 16),
                _LevelCard(state: d.state),
                const SizedBox(height: 24),
                Text('BADGES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: context.textSecondary,
                    )),
                const SizedBox(height: 12),
                _BadgesGrid(summary: d),
                const SizedBox(height: 24),
                if (d.awards.isNotEmpty) ...<Widget>[
                  Text('RECENT AWARDS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: context.textSecondary,
                      )),
                  const SizedBox(height: 12),
                  ...d.awards.take(5).map(
                        (Award a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AwardRow(award: a),
                        ),
                      ),
                ],
              ],
            ),
          ),
      },
    );
  }
}

// ------------------------------------------------------------- streak hero

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.local_fire_department,
              size: 16, color: RenanceColors.amber),
          SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: context.ink)),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.state});
  final StreakState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.local_fire_department,
                    size: 22, color: RenanceColors.amber),
                SizedBox(width: 6),
                Text('Current Streak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.ink.withValues(alpha: 0.9),
                    )),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text('${state.currentStreak}',
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: context.ink)),
                SizedBox(width: 6),
                Text('Days',
                    style: TextStyle(
                        fontSize: 14, color: context.textSecondary)),
              ],
            ),
            SizedBox(height: 2),
            Text('Best Streak: ${state.bestStreak}',
                style: TextStyle(
                    fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 20),
            _WeekDots(state: state, now: DateTime.now()),
          ],
        ),
      ),
    );
  }
}

class _DayDot {
  const _DayDot(this.label, this.practiced, this.isToday);
  final String label;
  final bool practiced;
  final bool isToday;
}

const List<String> _kWeekdayLabels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.state, required this.now});
  final StreakState state;
  final DateTime now;

  List<_DayDot> _compute() {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final last = state.lastActive == null
        ? null
        : _dateOnly(DateTime.parse(state.lastActive!));
    return List<_DayDot>.generate(7, (int i) {
      final day = monday.add(Duration(days: i));
      final bool practiced;
      if (last == null) {
        practiced = false;
      } else {
        final diff = last.difference(day).inDays;
        practiced = diff >= 0 && diff < state.currentStreak;
      }
      return _DayDot(_kWeekdayLabels[i], practiced, _sameDay(day, today));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dots = _compute();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final _DayDot d in dots)
          Column(
            children: <Widget>[
              Text(d.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: d.isToday ? FontWeight.w700 : FontWeight.w400,
                    color: d.isToday
                        ? context.ink
                        : context.textSecondary,
                  )),
              const SizedBox(height: 6),
              _Dot(d: d),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.d});
  final _DayDot d;

  @override
  Widget build(BuildContext context) {
    // Pending: today not yet practiced → amber outline ring.
    if (d.isToday && !d.practiced) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: RenanceColors.amber, width: 1.6),
        ),
      );
    }
    final bool solidToday = d.isToday && d.practiced;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: d.practiced
            ? (solidToday ? RenanceColors.amber : _kAmberTint)
            : context.cardHigh,
      ),
      child: Icon(
        solidToday ? Icons.local_fire_department : Icons.check,
        size: 16,
        color: solidToday
            ? Colors.white
            : d.practiced
                ? RenanceColors.amber
                : context.textSecondary,
      ),
    );
  }
}

// -------------------------------------------------------------- level card

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});
  final StreakState state;

  @override
  Widget build(BuildContext context) {
    final int next = (state.level * 500);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.ink)),
                          SizedBox(width: 6),
                          Icon(Icons.verified,
                              size: 18, color: RenanceColors.emerald),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${state.totalCorrect} correct · ${state.attempts} papers',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.inverseChip,
                  ),
                  alignment: Alignment.center,
                  child: Text('${state.level}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.onInverseChip)),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('${_comma(state.totalXp)} XP',
                    style: TextStyle(
                        fontSize: 11, color: context.textSecondary)),
                Text('${_comma(next)} XP',
                    style: TextStyle(
                        fontSize: 11, color: context.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: state.levelProgress, // always 0..1 by construction (xpIntoLevel/500)
                minHeight: 8,
                backgroundColor: context.cardHigh,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- badge grid

class _BadgesGrid extends StatelessWidget {
  const _BadgesGrid({required this.summary});
  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    // Earned first (newest first), then locked in catalog order.
    final List<_BadgeSpec> earned = _kBadgeCatalog
        .where((_BadgeSpec s) => summary.holds(s.code))
        .toList();
    final List<_BadgeSpec> locked =
        _kBadgeCatalog.where((_BadgeSpec s) => !summary.holds(s.code)).toList();
    final List<_BadgeSpec> ordered = <_BadgeSpec>[...earned, ...locked];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.92,
      children: <Widget>[
        for (final _BadgeSpec s in ordered)
          _BadgeTile(
            spec: s,
            earned: summary.holds(s.code),
            onTap: () => _showDetail(context, s, summary.holds(s.code),
                summary.awards.where((Award a) => a.code == s.code).toList()),
          ),
      ],
    );
  }

  void _showDetail(
      BuildContext sheetCtx, _BadgeSpec s, bool earned, List<Award> awards) {
    // Full Stitch badge_detail_light screen (replaces the old sheet).
    Navigator.of(sheetCtx).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BadgeDetailScreen(
          spec: BadgeSpec(
            code: s.code,
            label: s.label,
            icon: s.icon,
            bg: s.bg,
            fg: s.fg,
            hint: earned && awards.isNotEmpty
                ? 'Earned ${_relativeAgo(awards.first.earnedAt, DateTime.now())}'
                : s.hint,
            earned: earned,
          ),
          related: <BadgeSpec>[
            for (final _BadgeSpec r in _kBadgeCatalog)
              if (r.code != s.code)
                BadgeSpec(
                  code: r.code,
                  label: r.label,
                  icon: r.icon,
                  bg: r.bg,
                  fg: r.fg,
                  hint: r.hint,
                  earned: summary.holds(r.code),
                ),
          ].take(3).toList(),
          currentStreak: summary.state.currentStreak,
          totalXp: summary.state.totalXp,
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.spec,
    required this.earned,
    required this.onTap,
  });

  final _BadgeSpec spec;
  final bool earned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: earned
                          ? spec.bg
                          : context.cardHigh,
                    ),
                    child: Icon(spec.icon,
                        size: 30,
                        color: earned
                            ? spec.fg
                            : context.textSecondary),
                  ),
                  if (!earned)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.card.withValues(alpha: 0.55),
                        ),
                        child: Icon(Icons.lock,
                            size: 18, color: context.textSecondary),
                      ),
                    ),
                  if (earned)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.card,
                        ),
                        child: const Icon(Icons.check_circle,
                            size: 16, color: RenanceColors.emerald),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: earned
                        ? context.ink
                        : context.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ recent awards

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award});
  final Award award;

  @override
  Widget build(BuildContext context) {
    final _BadgeSpec spec = _kBadgeCatalog.firstWhere(
      (_BadgeSpec s) => s.code == award.code,
      orElse: () => _BadgeSpec('unknown', 'Badge', Icons.emoji_events,
          _kBlueTint, context.ink, 'A Renance badge'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: spec.bg),
              child: Icon(spec.icon, size: 20, color: spec.fg),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${spec.label} Badge Earned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.ink)),
                  SizedBox(height: 2),
                  Text(spec.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary)),
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(_relativeAgo(award.earnedAt, DateTime.now()),
                style: TextStyle(
                    fontSize: 11, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _comma(int n) {
  final String s = '$n';
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final int remaining = s.length - i;
    out.write(s[i]);
    if (remaining > 1 && remaining % 3 == 1) out.write(',');
  }
  return out.toString();
}

String _relativeAgo(DateTime t, DateTime now) {
  final Duration d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
