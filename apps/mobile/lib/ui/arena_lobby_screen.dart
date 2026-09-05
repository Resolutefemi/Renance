/// Arena lobby, the Stitch arena_lobby_light screen, 1:1.
///
/// Dark hero with the Find a Match CTA, the two game mode cards
/// (Rapid / Blitz), the Daily Tournament row and the Global Rank board.
/// Static-friendly: matchmaking is simulated locally, the rank board is
/// the Stitch copy. Founder rule: no purple anywhere, accents are ink.
///
/// Wide windows (desktop, >= 560 px) keep the column centered.
library;

import 'package:flutter/material.dart';

import 'arena_match_screen.dart';
import 'theme.dart';

class ArenaLobbyScreen extends StatelessWidget {
  const ArenaLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                // back bar ------------------------------------------------
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                    ),
                    const SizedBox(width: 4),
                    const Text('Arena', style: RenanceText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                // dark hero -----------------------------------------------
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: <Color>[Color(0xFF131B2E), Color(0xFF0E2230)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Arena',
                          style: RenanceText.sectionTitle.copyWith(
                              color: RenanceColors.darkTextPrimary,
                              fontSize: 20)),
                      const SizedBox(height: 10),
                      const Text(
                        'Head-to-head quizzes · 5 questions · 60 seconds',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          height: 24 / 16,
                          color: Color(0xB3F0F3FF),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            // The hero card is dark in every tier, so the
                            // on-color stays the fixed ink (context.ink
                            // would turn white in the dark tier).
                            foregroundColor: RenanceColors.ink,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => const ArenaMatchScreen(),
                            ));
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const <Widget>[
                              Icon(Icons.shuffle, size: 20),
                              SizedBox(width: 8),
                              Text('Find a Match',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                // Game Modes ----------------------------------------------
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Game Modes', style: RenanceText.sectionTitle),
                ),
                SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ModeCard(
                        icon: Icons.timer_outlined,
                        iconBg: Color(0xFFFFF3D6),
                        iconColor: RenanceColors.amber,
                        deco: Color(0xFFFFF3D6),
                        title: 'Rapid',
                        subtitle: '3 mins',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        icon: Icons.bolt,
                        iconBg: Color(0xFFE7EEFF),
                        iconColor: context.ink,
                        deco: Color(0xFFE7EEFF),
                        title: 'Blitz',
                        subtitle: '60 secs',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Daily Tournament ----------------------------------------
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events_outlined,
                              size: 26, color: RenanceColors.emerald),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Daily Tournament',
                                  style: RenanceText.bodyMedium),
                              SizedBox(height: 2),
                              Text('Ends in 4h 12m',
                                  style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 24, color: context.textSecondary),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 28),
                // Global Rank ---------------------------------------------
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Global Rank', style: RenanceText.sectionTitle),
                    ),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('View All',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.ink,
                            )),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: Color(0x14141C2D),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      _RankRow(rank: '1', name: 'Alex Chen', points: '2,450'),
                      Divider(height: 1, color: context.outlineLight),
                      _RankRow(rank: '2', name: 'Sam Rivera', points: '2,390'),
                      Divider(height: 1, color: context.outlineLight),
                      _RankRow(
                          rank: '214',
                          name: 'You',
                          points: '1,820',
                          you: true),
                    ],
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

/// One game-mode card with the quarter-circle decoration.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.deco,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color deco;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -28,
            right: -28,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: deco, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, size: 24, color: iconColor),
                ),
                const Spacer(),
                Text(title,
                    style: RenanceText.bodyMedium.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(subtitle, style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One Global Rank row; the "You" row is highlighted with the ink bar.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.points,
    this.you = false,
  });

  final String rank;
  final String name;
  final String points;
  final bool you;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: you
          ? (context.isDarkTier
              ? RenanceColors.darkSurfaceLow
              : const Color(0xFFEEF1FB))
          : null,
      child: Row(
        children: <Widget>[
          if (you)
            Container(
              width: 4,
              height: 64,
              color: context.ink,
            ),
          SizedBox(
            width: you ? 44 : 48,
            child: Text(rank,
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
            padding: const EdgeInsets.all(6),
            child: you
                ? Image.asset('assets/brand/renance_mark.png')
                : Icon(Icons.person_outline,
                    size: 22, color: context.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: RenanceText.bodyMedium.copyWith(fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              points,
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
