/// Leaderboard, the web /leaderboard boards on the app: XP (all-time)
/// and Arena (weekly) tabs, real server data, the caller's own row rides
/// along as "You" even outside the top 25. Same rank-row language as the
/// Arena lobby's Global Rank board.
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
      // Sticky back bar — same fixed header language as the Arena lobby.
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
                height: 52,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    const Text('Leaderboard', style: RenanceText.sectionTitle),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: <Widget>[
                  for (final (int i, String label) in const <(int, String)>[
                    (0, 'XP'),
                    (1, 'Arena'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _arena == (i == 1),
                        onSelected: (_) {
                          setState(() => _arena = i == 1);
                        },
                        labelStyle: RenanceText.bodyMedium.copyWith(
                          color: _arena == (i == 1)
                              ? context.ink
                              : context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
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
                          fmt: _fmt,
                          valueFor: (BoardEntry e) => _arena
                              ? _fmt(e.points)
                              : _fmt(e.xp),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rank rows. "You" gets the ink bar + highlighted row, same as the
/// Arena lobby's board.
class _BoardList extends StatelessWidget {
  const _BoardList({
    required this.board,
    required this.fmt,
    required this.valueFor,
  });

  final LeaderboardData? board;
  final String Function(int) fmt;
  final String Function(BoardEntry) valueFor;

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Container(
          clipBehavior: Clip.antiAlias,
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
            children: <Widget>[
              for (var i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: context.outlineLight),
                _RankRow(
                  entry: rows[i],
                  value: valueFor(rows[i]),
                  you: meRank != null && rows[i].rank == meRank,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.value, this.you = false});

  final BoardEntry entry;
  final String value;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final String initial = entry.username.isEmpty
        ? 'R'
        : entry.username[0].toUpperCase();
    return Container(
      color: you
          ? (context.isDarkTier
              ? RenanceColors.darkSurfaceLow
              : const Color(0xFFEEF1FB))
          : null,
      child: Row(
        children: <Widget>[
          if (you)
            Container(width: 4, height: 64, color: context.ink),
          SizedBox(
            width: you ? 44 : 48,
            child: Text('${entry.rank}',
                textAlign: TextAlign.center,
                style: RenanceText.bodyBase.copyWith(fontSize: 16)),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: you ? Colors.white : context.cardHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: you
                ? Image.asset('assets/brand/renance_mark.png')
                : Text(initial,
                    style: RenanceText.bodyMedium.copyWith(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              you ? 'You' : entry.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyMedium.copyWith(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: you ? context.ink : RenanceColors.emerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
