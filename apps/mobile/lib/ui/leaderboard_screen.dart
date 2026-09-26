/// Leaderboard - the focus standings: Arena, JAMB (official aggregate
/// out of 400), WAEC, NECO, Schools, Streak and the daily sprint.
///
/// Sticky back bar with the centred title, the board tabs as pills on a
/// scrollable track, and the ranking as cards: gold / silver / bronze
/// for the podium, white cards below, the caller's own row ringed in
/// ink when it rides along. The XP board is retired - these ladders
/// rank what students actually chase.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _Board _tab = _Board.arena;
  bool _loading = true;
  String? _error;
  final Map<_Board, LeaderboardData?> _boards = <_Board, LeaderboardData?>{};

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
      if (_boards[_tab] == null) {
        switch (_tab) {
          case _Board.arena:
            _boards[_tab] = await api.leaderboardArena();
          case _Board.jamb:
            _boards[_tab] = await api.leaderboardFocus(focus: 'jamb');
          case _Board.waec:
            _boards[_tab] = await api.leaderboardFocus(focus: 'waec');
          case _Board.neco:
            _boards[_tab] = await api.leaderboardFocus(focus: 'neco');
          case _Board.schools:
            _boards[_tab] = await api.leaderboardSchools();
          case _Board.streak:
            _boards[_tab] = await api.leaderboardStreak();
          case _Board.daily:
            _boards[_tab] = await api.dailyLeaderboard();
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Sticky back bar, centred title - the school app's header.
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
            // Board tabs: pills on a scrollable track, one per ladder.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 0, 0),
              child: SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final _Board b in _Board.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            if (_tab == b) return;
                            setState(() => _tab = b);
                            _load();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: _tab == b
                                  ? context.ink
                                  : context.cardLow,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(b.icon, size: 15,
                                    color: _tab == b
                                        ? context.onInverseChip
                                        : context.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  b.label,
                                  style: RenanceText.bodyMedium.copyWith(
                                    fontSize: 13.5,
                                    color: _tab == b
                                        ? context.onInverseChip
                                        : context.textSecondary,
                                  ),
                                ),
                              ],
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
                          board: _boards[_tab],
                          tab: _tab,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ladders the ranking page serves, each with its pill label and
/// the one-line explanation under the tabs.
enum _Board {
  arena('Arena', Icons.sports_esports,
      'Head-to-head duels, weekly and all time. A win is a point.'),
  jamb('JAMB', Icons.school,
      'Your best official UTME aggregate out of 400. The sealed subject ledger decides.'),
  waec('WAEC', Icons.menu_book,
      'Your best WAEC paper, graded on the server against the sealed keys.'),
  neco('NECO', Icons.history_edu,
      'Your best NECO paper, graded on the server against the sealed keys.'),
  schools('Schools', Icons.account_balance,
      'Every school ranked by the average its students hold on finalized results.'),
  streak('Streak', Icons.local_fire_department,
      'The students still showing up, day after day. Miss a day and it resets.'),
  daily('Daily', Icons.event_repeat,
      "Today's challenge, one sprint, everyone worldwide.");

  const _Board(this.label, this.icon, this.hint);
  final String label;
  final IconData icon;
  final String hint;
}

/// The ranking cards: gold / silver / bronze for the podium, white
/// cards below, the caller's own row ringed in ink when it rides along.
class _BoardList extends StatelessWidget {
  const _BoardList({
    required this.board,
    required this.tab,
  });

  final LeaderboardData? board;
  final _Board tab;

  String _fmtNum(double n) {
    if (n == n.roundToDouble()) {
      if (n >= 1000) {
        final String s = n.round().toString();
        return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
      }
      return n.round().toString();
    }
    return n.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final LeaderboardData? data = board;
    if (data == null) return const SizedBox.shrink();
    final List<BoardEntry> rows = <BoardEntry>[...data.entries];
    final BoardEntry? me = data.me;
    if (me != null &&
        tab != _Board.schools &&
        !rows.any((BoardEntry e) => e.username == me.username)) {
      rows.add(me);
    }
    final int? meRank = me?.rank;

    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: <Widget>[
          Text(
            tab == _Board.jamb
                ? 'No official UTME mock graded yet. Take one and claim the first seat.'
                : tab == _Board.schools
                    ? 'No school results finalized yet.'
                    : 'No scores yet, be the first on the board.',
            textAlign: TextAlign.center,
            style: RenanceText.bodySecondary
                .copyWith(color: context.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: <Widget>[
        Text(
          tab.hint,
          style: RenanceText.bodySecondary.copyWith(
            fontSize: 12.5,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RankCard(
              entry: rows[i],
              tab: tab,
              fmt: _fmtNum,
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
    required this.tab,
    required this.fmt,
    required this.you,
  });

  final BoardEntry entry;
  final _Board tab;
  final String Function(double) fmt;
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

    // The headline value each ladder ranks on.
    String headline = '';
    String headlineUnit = '';
    String headlineLabel = 'Renance Points';
    switch (tab) {
      case _Board.arena:
        headline = '${entry.points}';
        headlineLabel = 'Renance Points';
      case _Board.jamb:
        headline = fmt(entry.bestScore);
        headlineUnit = '/${fmt(entry.scoreOutOf)}';
        headlineLabel = 'Best UTME';
      case _Board.waec:
      case _Board.neco:
        headline = fmt(entry.bestScore);
        headlineUnit = '/${fmt(entry.scoreOutOf)}';
        headlineLabel = 'Best Paper';
      case _Board.schools:
        headline = fmt(entry.avgScore);
        headlineUnit = '%';
        headlineLabel = 'Average';
      case _Board.streak:
        headline = '${entry.currentStreak}';
        headlineUnit = ' days';
        headlineLabel = 'Current Streak';
      case _Board.daily:
        headline = '${entry.score}';
        headlineUnit = '/${entry.total}';
        headlineLabel = 'Score';
    }

    final List<Widget> chips = <Widget>[];
    switch (tab) {
      case _Board.arena:
        chips.addAll(<Widget>[
          _StatChip(
            icon: Icons.emoji_events_outlined,
            label: 'Wins',
            value: '${entry.wins}',
          ),
          _StatChip(
            icon: Icons.history_edu,
            label: 'Matches',
            value: '${entry.matches}',
          ),
          _StatChip(
            icon: Icons.check_circle_outline,
            label: 'Correct',
            value: '${entry.correct}',
          ),
        ]);
      case _Board.jamb:
      case _Board.waec:
      case _Board.neco:
        chips.add(_StatChip(
          icon: Icons.history_edu,
          label: 'Papers',
          value: '${entry.papers}',
        ));
      case _Board.schools:
        chips.addAll(<Widget>[
          _StatChip(
            icon: Icons.group_outlined,
            label: 'Students',
            value: '${entry.students}',
          ),
        ]);
      case _Board.streak:
        chips.addAll(<Widget>[
          _StatChip(
            icon: Icons.military_tech,
            label: 'Best',
            value: '${entry.bestStreak}d',
          ),
          _StatChip(
            icon: Icons.history_edu,
            label: 'Papers',
            value: '${entry.attempts}',
          ),
        ]);
      case _Board.daily:
        chips.add(_StatChip(
          icon: Icons.check_circle_outline,
          label: 'Score',
          value: '${entry.score}/${entry.total}',
        ));
    }

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
              // Avatar initial (the school crest chip on the schools board).
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: you ? context.inverseChip : context.cardLow,
                ),
                child: you && tab != _Board.schools
                    ? Text(
                        'R',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: context.onInverseChip,
                        ),
                      )
                    : tab == _Board.schools
                        ? Icon(Icons.account_balance,
                            size: 19, color: context.ink)
                        : Text(
                            ((tab == _Board.schools
                                            ? entry.school
                                            : entry.username)
                                        .isEmpty
                                    ? 'R'
                                    : (tab == _Board.schools
                                            ? entry.school
                                            : entry.username)[0])
                                .toUpperCase(),
                            style: RenanceText.bodyMedium.copyWith(
                              fontSize: 15,
                              color: context.ink,
                            ),
                          ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        you && tab != _Board.schools
                            ? 'You'
                            : tab == _Board.schools
                                ? entry.school
                                : entry.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.bodyMedium.copyWith(fontSize: 16),
                      ),
                    ),
                    // The premium verified tick, the one blue on the app.
                    if (entry.premium &&
                        tab != _Board.schools) ...<Widget>[
                      const SizedBox(width: 5),
                      const BlueTickIcon(size: 15),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    headlineLabel,
                    style: RenanceText.caption.copyWith(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    tab == _Board.streak ? '🔥 $headline' : '$headline$headlineUnit',
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
          // The honest stat chips under each row.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips,
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
