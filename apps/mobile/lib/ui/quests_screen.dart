/// The Quests page - the Flutter twin of the web's app/quests:
/// daily/weekly/monthly challenge cards with live progress bars, the
/// amber Claim key, gem payouts with confetti + toast, and the quiet
/// offline poll (no retry buttons, founder rule).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../learn_controller.dart';
import '../learn_models.dart';
import 'celebrations.dart';
import 'courses_screen.dart' show LearnPageBar;
import 'learn_bits.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

class QuestsScreen extends StatefulWidget {
  /// [standalone] renders the page bar with a back key (pushed from the
  /// library's Daily Quest card); the tab body runs under the home
  /// header instead.
  const QuestsScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  bool get _standalone => widget.standalone;
  bool _loading = true;
  String? _error;
  QuestsResponse? _quests;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final QuestsResponse quests = await api.learnQuests();
      if (!mounted) return;
      setState(() {
        _quests = quests;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      // Quiet poll every 8s while offline.
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _claim(QuestOut quest) async {
    final LearnController learn = context.read<LearnController>();
    try {
      final int gems = await learn.claimQuest(quest.key);
      if (!mounted) return;
      showConfetti(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+$gems gems claimed!')),
      );
      await _load();
      learn.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Claim failed - ${e.message}')),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Claim failed - ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget top = _standalone
        ? LearnPageBar(title: 'Quests')
        : SizedBox(height: MediaQuery.paddingOf(context).top +66);
    return Column(
      children: <Widget>[
        top,
        Expanded(
          child: _loading
              ? const Center(child: RenanceMark(size: 40, busy: true))
              : _error != null
                  ? _QuestsSyncing(message: _error!)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                        children: <Widget>[
                          _QuestSectionHeader('Daily quests · reset at midnight'),
                          const SizedBox(height: 10),
                          for (final QuestOut q in _quests?.daily ?? <QuestOut>[])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _QuestCard(
                                quest: q,
                                big: false,
                                onClaim: () => _claim(q),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _QuestSectionHeader('Weekly challenge'),
                          const SizedBox(height: 10),
                          if (_quests != null)
                            _QuestCard(
                              quest: _quests!.weekly,
                              big: true,
                              onClaim: () => _claim(_quests!.weekly),
                            ),
                          const SizedBox(height: 12),
                          _QuestSectionHeader('Monthly challenge'),
                          const SizedBox(height: 10),
                          if (_quests != null)
                            _QuestCard(
                              quest: _quests!.monthly,
                              big: true,
                              onClaim: () => _claim(_quests!.monthly),
                            ),
                          const SizedBox(height: 18),
                          Text(
                            'Everything you do on Renance counts: lessons, '
                            'past-question quizzes, practice and reviews all '
                            'feed your quests.',
                            style: RenanceText.caption.copyWith(
                              color: context.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _QuestsSyncing extends StatelessWidget {
  const _QuestsSyncing({required this.message});

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
            Text('Your quests are syncing…', style: RenanceText.bodyMedium),
            const SizedBox(height: 4),
            Text(
              "Today's challenges appear the moment the connection is back.",
              textAlign: TextAlign.center,
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The web's section header: 13px font-black uppercase tracking-wide
/// on-surface-variant (quests/page.tsx).
class _QuestSectionHeader extends StatelessWidget {
  const _QuestSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.onClaim,
    this.big = false,
  });

  final QuestOut quest;
  final VoidCallback onClaim;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final double pct =
        quest.target == 0 ? 0 : (quest.progress / quest.target).clamp(0.0, 1.0);
    final bool complete = quest.complete || pct >= 1;
    // The web's card states: claimed -> surface-container + strikethrough,
    // complete -> amber border + amber/10 wash, else the plain card.
    final Color outline = quest.claimed || complete
        ? (complete && !quest.claimed ? RenanceColors.bee : context.outlineVariant)
        : context.outlineVariant;
    final Color face = quest.claimed
        ? context.surfaceContainer
        : complete
            ? RenanceColors.bee.withValues(alpha: 0.10)
            : context.card;
    return TactileCard(
      padding: const EdgeInsets.all(14),
      outline: outline,
      color: face,
      child: Row(
        children: <Widget>[
          // the web's icon well: rounded-xl bg-primary/15, 24px glyph
          Container(
            width: big ? 48 : 44,
            height: big ? 48 : 44,
            // Web: flex items-center justify-center - the glyph centers.
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: MsIcon(
              quest.icon.isEmpty ? 'bolt' : quest.icon,
              size: big ? 24 : 22,
              color: mixTowardBlack(context.primary, 0.6),
              fill: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: quest.claimed ? context.textSecondary : context.ink,
                    decoration:
                        quest.claimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      // Web ProgressBar: h-3.5 = 14px tall.
                      child: LearnProgressBar(value: pct, height: 14, gold: complete),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${quest.progress.clamp(0, quest.target)}/${quest.target}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (quest.claimed)
            // the web's claimed mark: the green check bubble
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: MsIcon(
                'check_circle',
                size: 20,
                color: mixTowardBlack(context.primary, 0.6),
                fill: true,
              ),
            )
          else if (complete)
            TactileButton(
              onPressed: onClaim,
              expand: false,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              fontSize: 12.5,
              face: RenanceColors.bee,
              onFace: Colors.white,
              edge: RenanceColors.beeDark,
              child: const Text('Claim'),
            )
          else
            // the web's gem pill: rounded-full border-2
            // border-outline-light bg-surface-container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: context.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.outlineLight, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const GemIcon(size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${quest.gems}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: context.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
