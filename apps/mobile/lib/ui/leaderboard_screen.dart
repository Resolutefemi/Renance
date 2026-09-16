/// Leaderboard — the Myschool ranking cut the founder asked to copy.
///
/// Sticky back bar with the centred title, the board tabs as a white
/// pill riding a track (Myschool's Challenge/JAMB/WAEC/NECO/CBT row —
/// Renance's real boards are XP and Arena), and the ranking as cards:
/// #1 rides a gold gradient, #2 silver, #3 bronze, the rest plain white
/// cards. Each card: medal, avatar, username, the big score at the
/// right and the honest stat chips (streaks, correct, papers) beneath —
/// Renance's answer to "Myschool Point 76.67 from 1 CBT".
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
  bool _arena = false;
  bool _loading = true;
  String? _error;
  LeaderboardData? _xp;
  LeaderboardData? _arenaBoard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _xp ??= await api.leaderboardXp();
      _arenaBoard ??= await api.leaderboardArena();
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final String s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final LeaderboardData? board = _arena ? _arenaBoard : _xp;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Sticky back bar, centred title — the school app's header.
            Container(
              decoration: BoxDecoration(
                color: context.pageBg,
                border: Border(
                  bottom: BorderSide(
                    color: context.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.outlineVariant),
                          color: context.card,
                        ),
                        child:
                            Icon(Icons.arrow_back, size: 19, color: context.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Leaderboard',
                        textAlign: TextAlign.center,
                        style: RenanceText.sectionTitle,
                      ),
                    ),
                    const SizedBox(width: 92),
                  ],
                ),
              ),
            ),
            // Board tabs: white pill on a track, Myschool's segmented row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (int i, String label) in const <(int, String)>[
                      (0, 'XP'),
                      (1, 'Arena'),
                    ])
                      GestureDetector(
                        onTap: () => setState(() => _arena = i == 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 9),
                          decoration: BoxDecoration(
                            color: _arena == (i == 1)
                                ? context.cardLowest
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: _arena == (i == 1)
                                ? const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x14141C2D),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            style: RenanceText.bodyMedium.copyWith(
                              fontSize: 14,
                              color: _arena == (i == 1)
                                  ? context.ink
                                  : context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(height: 12),
                          Text('Loading the board…',
                              style: RenanceText.caption
                                  .copyWith(color: context.textSecondary)),
                        ],
                      ),
                    )
                  : _error != null
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: <Widget>[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: RenanceText.bodySecondary
                                  .copyWith(color: context.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        )
                      : _BoardList(
                          board: board,
                          arena: _arena,
                          fmt: _fmt,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ranking cards: gold / silver / bronze for the podium, white
/// cards below, the caller's own row ringed in ink when it rides along.
class _BoardList extends StatelessWidget {
  const _BoardList({
    required this.board,
    required this.arena,
    required this.fmt,
  });

  final LeaderboardData? board;
  final bool arena;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    final LeaderboardData? data = board;
    if (data == null) return const SizedBox.shrink();
    final List<BoardEntry> rows = <BoardEntry>[...data.entries];
    final BoardEntry? me = data.me;
    if (me != null && !rows.any((BoardEntry e) => e.username == me.username)) {
      rows.add(me);
    }
    final int? meRank = me?.rank;

    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: <Widget>[
          Text(
            'No scores yet, be the first on the board.',
            textAlign: TextAlign.center,
            style: RenanceText.bodySecondary
                .copyWith(color: context.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: <Widget>[
        Text(
          arena ? 'Arena Ranking' : 'XP Ranking',
          style: RenanceText.displayMd.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RankCard(
              entry: rows[i],
              value: arena ? fmt(rows[i].points) : fmt(rows[i].xp),
              arena: arena,
              you: meRank != null && rows[i].rank == meRank,
            ),
          ),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.entry,
    required this.value,
    required this.arena,
    required this.you,
  });

  final BoardEntry entry;
  final String value;
  final bool arena;
  final bool you;

  static const Color _gold = Color(0xFFF7CE55);
  static const Color _silver = Color(0xFFD9DEE7);
  static const Color _bronze = Color(0xFFE4C3A0);

  @override
  Widget build(BuildContext context) {
    final int rank = entry.rank;
    final Color tint = rank == 1
        ? _gold
        : rank == 2
            ? _silver
            : rank == 3
                ? _bronze
                : Colors.transparent;
    final Color valueColor = rank == 1
        ? const Color(0xFF8A6A00)
        : rank == 2
            ? const Color(0xFF4A5568)
            : rank == 3
                ? const Color(0xFF7A5230)
                : context.ink;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rank <= 3 ? tint.withValues(alpha: 0.34) : context.card,
        borderRadius: BorderRadius.circular(16),
        border: you
            ? Border.all(color: context.ink, width: 1.6)
            : Border.all(
                color: context.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F141C2D),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Medal / rank badge.
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rank <= 3 ? Colors.white : context.cardLow,
                  border: rank <= 3
                      ? null
                      : Border.all(color: context.outlineVariant),
                  boxShadow: rank <= 3
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x22141C2D),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: rank == 1
                    ? const Icon(Icons.emoji_events, size: 20, color: Color(0xFFB7791F))
                    : Text(
                        '$rank',
                        style: RenanceText.bodyMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: rank <= 3 ? valueColor : context.ink,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              // Avatar initial.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: you ? context.inverseChip : context.cardLow,
                ),
                child: you
                    ? Text(
                        'R',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: context.onInverseChip,
                        ),
                      )
                    : Text(
                        (entry.username.isEmpty
                                ? 'R'
                                : entry.username[0])
                            .toUpperCase(),
                        style: RenanceText.bodyMedium.copyWith(
                          fontSize: 15,
                          color: context.ink,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  you ? 'You' : entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.bodyMedium.copyWith(fontSize: 16),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Renance ${arena ? 'Points' : 'XP'}',
                    style: RenanceText.caption.copyWith(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: RenanceText.statNumber.copyWith(
                      fontSize: 22,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The honest stat chips, Myschool's "Best Score / Time Adv" row.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _StatChip(
                icon: Icons.local_fire_department,
                label: 'Best Streak',
                value: '${entry.bestStreak}',
              ),
              _StatChip(
                icon: Icons.check_circle_outline,
                label: 'Correct',
                value: '${entry.correct}',
              ),
              _StatChip(
                icon: Icons.history_edu,
                label: arena ? 'Matches' : 'Papers',
                value: '${arena ? entry.matches : entry.attempts}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.cardLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: context.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: RenanceText.caption.copyWith(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: RenanceText.labelMono.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
