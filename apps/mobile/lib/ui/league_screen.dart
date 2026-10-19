/// The League page - the Flutter twin of the web's app/league: the
/// 20-tier switcher with shield badges, the weekly XP board with the
/// Lagos-Monday reset countdown, the promotion/demotion zones, the
/// last-week pills, browse-any-tier boards and profile links.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../learn_models.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'social_screens.dart';
import 'tactile.dart';
import 'theme.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  bool _loading = true;
  String? _error;
  LeagueBoard? _board;
  int? _viewing;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({int? league}) async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final LeagueBoard board = await api.learnLeague(league: league);
      if (!mounted) return;
      setState(() {
        _board = board;
        _viewing = league;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(height: MediaQuery.paddingOf(context).top + 72),
        // The 20-tier pill scroller.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              for (var i = 0; i < kLeagueNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TierPill(
                    name: kLeagueNames[i],
                    active: (_viewing ?? _board?.leagueIndex ?? 0) == i,
                    onTap: () => _load(league: i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: RenanceMark(size: 40, busy: true))
              : _error != null
                  ? _LeagueSyncing(message: _error!)
                  : RefreshIndicator(
                      onRefresh: () => _load(league: _viewing),
                      child: _boardView(context),
                    ),
        ),
      ],
    );
  }

  Widget _boardView(BuildContext context) {
    final LeagueBoard b = _board!;
    final bool browsing = b.viewing;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        if (browsing) ...<Widget>[
          Center(
            child: TactileButton(
              onPressed: () => _load(),
              expand: false,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              fontSize: 13,
              face: context.card,
              onFace: context.ink,
              edge: mixTowardBlack(context.outlineVariant, 0.62),
              child: const Text('← Back to my league'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Header: badge + name + countdown.
        Row(
          children: <Widget>[
            LeagueBadge(league: b.league, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${b.league} League',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Resets in ${formatCountdown(b.endsInMs)}',
                    style: RenanceText.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (b.promotedLastWeek || b.demotedLastWeek) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: b.promotedLastWeek
                  ? context.primary.withValues(alpha: 0.1)
                  : context.errorContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              b.promotedLastWeek
                  ? 'Promoted last week - +50 gems!'
                  : 'Demoted last week',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: b.promotedLastWeek
                    ? mixTowardBlack(context.primary, 0.6)
                    : context.onErrorContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Zones legend.
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF10DA11),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'promotion zone (top ${b.promotedCut})',
              style: RenanceText.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(width: 14),
            if (b.entries.length >= b.demotedFrom) ...<Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF4B4B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'demotion (rank ${b.demotedFrom}+)',
                style: RenanceText.caption.copyWith(fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        // The board.
        for (var i = 0; i < b.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LeagueRow(
              entry: b.entries[i],
              rank: i + 1,
              promoteCut: b.promotedCut,
              demoteFrom: b.demotedFrom,
              you: b.entries[i].isYou,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Only lessons, reviews and practice earn league XP - win streaks do '
          'not count.',
          style: RenanceText.caption.copyWith(
            color: context.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _LeagueSyncing extends StatelessWidget {
  const _LeagueSyncing({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const RenanceMark(size: 40, busy: true),
            const SizedBox(height: 14),
            Text('Your league is syncing…', style: RenanceText.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.name, required this.active, required this.onTap});

  final String name;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? context.primary.withValues(alpha: 0.1) : context.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? context.primary : context.outlineVariant,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            LeagueBadge(league: name, size: 16),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active
                    ? mixTowardBlack(context.primary, 0.6)
                    : context.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.entry,
    required this.rank,
    required this.promoteCut,
    required this.demoteFrom,
    required this.you,
  });

  final LeagueEntry entry;
  final int rank;
  final int promoteCut;
  final int demoteFrom;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final Color zone = rank <= promoteCut
        ? const Color(0xFF10DA11)
        : rank >= demoteFrom
            ? const Color(0xFFFF4B4B)
            : Colors.transparent;
    return GestureDetector(
      onTap: entry.username.isNotEmpty
          ? () => PublicProfileScreen.push(context, entry.username)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: you ? context.primary.withValues(alpha: 0.1) : context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: you ? context.primary : context.outlineVariant,
            width: you ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: zone,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                style: RenanceText.labelMono.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColorFor(entry.username.isNotEmpty
                    ? entry.username
                    : entry.name),
              ),
              child: Center(
                child: Text(
                  (entry.name.isNotEmpty ? entry.name : '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.isYou ? '${entry.name} (You)' : entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
            ),
            Text(
              '${entry.xp} XP',
              style: RenanceText.labelMono.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
