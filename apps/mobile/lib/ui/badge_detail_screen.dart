/// Badge detail, the Stitch badge_detail_light screen, 1:1.
///
/// The orbiting dashed-circle hero with the badge medallion, the
/// "Rare · 4% of students" rarity pill, the title + how-to-earn
/// subtitle, the progress card (label, big current/target stat with
/// the amber shimmering rail, "Keep it up, you're closer than you
/// think!"), the Related Badges rail (unlocked coloured, locked dimmed
/// with the lock chip) and the black Share Achievement button.
/// Progress numbers are real: streak badges track the current streak,
/// XP badges track total XP, everything else is earned 1/1 or 0/1.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric, PathMetrics;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Plain data for one badge, decoupled from the progress screen's
/// private catalog so any caller can route here.
class BadgeSpec {
  const BadgeSpec({
    required this.code,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.hint,
    required this.earned,
  });

  final String code;
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String hint;
  final bool earned;
}

class BadgeDetailScreen extends StatefulWidget {
  const BadgeDetailScreen({
    super.key,
    required this.spec,
    required this.related,
    required this.currentStreak,
    required this.totalXp,
  });

  final BadgeSpec spec;

  /// Up to three sibling badges for the Related Badges rail.
  final List<BadgeSpec> related;
  final int currentStreak;
  final int totalXp;

  @override
  State<BadgeDetailScreen> createState() => _BadgeDetailScreenState();
}

class _BadgeDetailScreenState extends State<BadgeDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  /// (current, target) for the progress card, from the badge code.
  (int, int) get _progress {
    final String code = widget.spec.code;
    if (code.startsWith('streak_')) {
      final int? target = int.tryParse(code.split('_').last);
      if (target != null) {
        return (widget.currentStreak.clamp(0, target), target);
      }
    }
    if (code.startsWith('xp_')) {
      final int? target = int.tryParse(code.split('_').last);
      if (target != null) {
        return (widget.totalXp.clamp(0, target), target);
      }
    }
    return (widget.spec.earned ? 1 : 0, 1);
  }

  void _share() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing arrives with public profiles. Keep XP!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (int current, int target) = _progress;
    final double fill = target <= 0 ? 0 : current / target;

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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      // Hero -------------------------------------------------
                      SizedBox(
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            // Rotating dashed orbits, 30% opacity.
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.3,
                                child: RotationTransition(
                                  turns: _spin,
                                  child: CustomPaint(
                                    painter: _OrbitPainter(
                                      outerColor: context.surfaceVariant,
                                      innerColor: context.surfaceContainer),
                                    size: Size(240, 240),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 192,
                              height: 192,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.surfaceContainer,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x14111C2D),
                                    blurRadius: 24,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.surfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    widget.spec.icon,
                                    size: 96,
                                    color: widget.spec.earned
                                        ? widget.spec.fg
                                        : context.outlineLight,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        blurRadius: 24,
                                        color: Color(0x33000000),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Rarity pill + title + subtitle ----------------------
                      Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.star,
                                    size: 16, color: context.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  widget.spec.earned
                                      ? 'RARE · 4% OF STUDENTS'
                                      : 'LOCKED',
                                  style: RenanceText.labelMono.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: context.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(widget.spec.label,
                              style: RenanceText.displayMd),
                          const SizedBox(height: 4),
                          Text(
                            widget.spec.hint,
                            textAlign: TextAlign.center,
                            style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Progress card ---------------------------------------
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x141C2D34),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      widget.spec.code
                                              .startsWith('streak_')
                                          ? 'CURRENT STREAK'
                                          : widget.spec.code
                                                  .startsWith('xp_')
                                              ? 'TOTAL XP'
                                              : 'PROGRESS',
                                      style: RenanceText.labelMono.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text.rich(
                                      TextSpan(
                                        children: <InlineSpan>[
                                          TextSpan(
                                            text: '$current',
                                            style: RenanceText.statNumber,
                                          ),
                                          TextSpan(
                                            text: '/$target',
                                            style: RenanceText.statNumber
                                                .copyWith(
                                              fontSize: 18,
                                              color: RenanceColors
                                                  .textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 20,
                                  color: RenanceColors.amber,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                height: 12,
                                child: Stack(
                                  children: <Widget>[
                                    ColoredBox(
                                      color: RenanceColors
                                          .surfaceContainerLow,
                                      child: const SizedBox.expand(),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor:
                                          fill.clamp(0.0, 1.0),
                                      child: Stack(
                                        children: <Widget>[
                                          const ColoredBox(
                                            color: RenanceColors.amber,
                                            child: SizedBox.expand(),
                                          ),
                                          // Shimmer sweep.
                                          AnimatedBuilder(
                                            animation: _shimmer,
                                            builder: (BuildContext _,
                                                    Widget? __) =>
                                                Align(
                                              alignment: Alignment(
                                                  _shimmer.value * 3 - 2,
                                                  0),
                                              child: FractionallySizedBox(
                                                widthFactor: 0.4,
                                                child: Container(
                                                  color: Colors.white
                                                      .withValues(
                                                      alpha: 0.3),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Keep it up, you're closer than you think!",
                              textAlign: TextAlign.center,
                              style: RenanceText.caption.copyWith(color: context.textSecondary)
                                  .copyWith(color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Related Badges ---------------------------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('Related Badges',
                              style: RenanceText.sectionTitle),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text('View all',
                                  style: RenanceText.bodyMedium.copyWith(
                                      fontSize: 14,
                                      color: context.ink)),
                              Icon(Icons.chevron_right,
                                  size: 18, color: context.ink),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          itemCount: widget.related.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (BuildContext context, int i) {
                            final BadgeSpec r = widget.related[i];
                            return _RelatedBadgeCard(spec: r);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Share Achievement ------------------------------------
                      SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: _share,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Share Achievement',
                                style: RenanceText.bodyMedium
                                    .copyWith(color: Colors.white)),
                          ),
                        ),
                      ),
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

/// Two dashed orbit rings (r=118/90 of the 240 box), the Stitch SVG.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.outerColor, required this.innerColor});

  final Color outerColor;
  final Color innerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outerColor;
    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = innerColor;

    _dashedCircle(canvas, c, 118, outer, const [10, 15]);
    _dashedCircle(canvas, c, 90, inner, const [20, 10]);
  }

  void _dashedCircle(
      Canvas canvas, Offset c, double r, Paint paint, List<double> dash) {
    final Path path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r));
    final PathMetrics metrics = path.computeMetrics();
    for (final PathMetric m in metrics) {
      double dist = 0;
      bool draw = true;
      while (dist < m.length) {
        final double next = dist + dash[draw ? 0 : 1];
        final double end = math.min(next, m.length);
        if (draw) {
          canvas.drawPath(m.extractPath(dist, end), paint);
        }
        dist = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One card of the Related Badges rail: 144px wide, 64px medallion.
class _RelatedBadgeCard extends StatelessWidget {
  const _RelatedBadgeCard({required this.spec});

  final BadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    final bool earned = spec.earned;
    return Opacity(
      opacity: earned ? 1 : 0.6,
      child: Container(
        width: 144,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x141C2D34),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned
                        ? context.cardLow
                        : context.cardLowest,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    spec.icon,
                    size: 32,
                    color: earned ? spec.fg : context.outlineLight,
                  ),
                ),
                if (!earned)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Icon(Icons.lock,
                          size: 14, color: context.textSecondary),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyMedium.copyWith(
                color: earned
                    ? context.ink
                    : context.outlineDark,
              ),
            ),
            SizedBox(height: 2),
            Text(
              spec.hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RenanceText.caption.copyWith(
                fontSize: 11,
                color: earned
                    ? context.textSecondary
                    : context.outlineLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
