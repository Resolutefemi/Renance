/// Leaderboard — the app mirror of the website's /leaderboard boards:
/// the all-time XP standings and the Arena rankings (weekly or forever).
///
/// Both boards are auth-gated server-side; the caller's own row rides
/// along as "me" even outside the top 25, so a student always learns
/// exactly where they stand. Bots never rank.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import 'theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _tab = 'xp'; // xp | arena-week | arena-all
  bool _loading = true;
  String? _error;
  LeaderboardData? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final ApiClient api = context.read<ApiClient>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LeaderboardData data = switch (_tab) {
        'arena-week' => await api.leaderboardArena(period: 'week'),
        'arena-all' => await api.leaderboardArena(period: 'all'),
        _ => await api.leaderboardXp(),
      };
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _metricOf(BoardEntry e) => switch (_tab) {
        'arena-week' || 'arena-all' => '${e.points} pts',
        _ => '${e.xp} XP',
      };

  String _subOf(BoardEntry e) => switch (_tab) {
        'arena-week' || 'arena-all' =>
          '${e.matches} matches · ${e.correct} correct',
        _ => '${e.attempts} papers · best streak ${e.bestStreak}',
      };

  @override
  Widget build(BuildContext context) {
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Leaderboard', style: RenanceText.displayLg),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: <Widget>[
                      for (final (String id, String label) in const <(String, String)>[
                        ('xp', 'XP · All Time'),
                        ('arena-week', 'Arena · Week'),
                        ('arena-all', 'Arena · All Time'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _TabChip(
                            label: label,
                            selected: _tab == id,
                            onTap: () {
                              if (_tab == id) return;
                              _tab = id;
                              _fetch();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.wifi_off, size: 36, color: context.textSecondary),
            const SizedBox(height: 12),
            Text('Could not load the board',
                style: RenanceText.bodyMedium),
            const SizedBox(height: 4),
            Text('Check your connection and try again.',
                style: RenanceText.caption
                    .copyWith(color: context.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    final List<BoardEntry> entries = _data?.entries ?? <BoardEntry>[];
    final BoardEntry? me = _data?.me;
    if (entries.isEmpty) {
      return Center(
        child: Text('No one is ranked yet — be the first.',
            style: RenanceText.bodySecondary
                .copyWith(color: context.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        for (final BoardEntry e in entries)
          _BoardRow(
            entry: e,
            metric: _metricOf(e),
            sub: _subOf(e),
            mine: me != null && e.username == me.username,
          ),
        if (me != null && !entries.any((BoardEntry e) => e.username == me.username)) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: Text('⋯')),
          ),
          _BoardRow(
            entry: me,
            metric: _metricOf(me),
            sub: _subOf(me),
            mine: true,
          ),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.selectionBlue.withValues(alpha: 0.25) : context.cardLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? context.selectionBlue : Colors.transparent),
        ),
        child: Text(label,
            style: RenanceText.labelMono.copyWith(
                fontSize: 12,
                color: selected ? context.ink : context.textSecondary)),
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.entry,
    required this.metric,
    required this.sub,
    required this.mine,
  });

  final BoardEntry entry;
  final String metric;
  final String sub;
  final bool mine;

  Color _rankColor(BuildContext context) => switch (entry.rank) {
        1 => const Color(0xFFD4AF37), // gold
        2 => const Color(0xFF9FA8B5), // silver
        3 => const Color(0xFFB07B4F), // bronze
        _ => context.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? context.selectionBlue.withValues(alpha: 0.2) : context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: mine ? context.selectionBlue : Colors.transparent),
        boxShadow: mine
            ? null
            : const <BoxShadow>[
                BoxShadow(
                    color: Color(0x14141C2D),
                    blurRadius: 3,
                    offset: Offset(0, 1)),
              ],
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text('#${entry.rank}',
                style: RenanceText.labelMono.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _rankColor(context))),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        entry.username.isEmpty ? 'Scholar' : entry.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.bodyMedium,
                      ),
                    ),
                    if (mine) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.selectionBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('YOU',
                            style: RenanceText.labelMono.copyWith(
                                fontSize: 9, color: context.ink)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(sub,
                    style: RenanceText.caption
                        .copyWith(color: context.textSecondary)),
              ],
            ),
          ),
          Text(metric,
              style: RenanceText.labelMono.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
