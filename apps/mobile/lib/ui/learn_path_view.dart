/// The course PATH view - the Duolingo-style zig-zag unit ladder, the
/// Flutter twin of the web's CoursePathView + PathNode
/// (apps/web/app/courses/page.tsx): 76px circular nodes offset
/// 0/56/112/56px per index, 15 rotating unit colour themes, sticky
/// gradient unit banners with the unit-1 treasure chest and the unit
/// review trophy, the "Start" speech bubble on the current node, the
/// unit revision card and the generating placeholder.
library;

import 'package:flutter/material.dart';

import '../learn_models.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

/// The 15 rotating unit themes (UNIT_COLORS): solid + deep pairs.
const List<(Color, Color)> kUnitThemes = <(Color, Color)>[
  (Color(0xFF16A34A), Color(0xFF15803D)),
  (Color(0xFF2563EB), Color(0xFF1D4ED8)),
  (Color(0xFF9333EA), Color(0xFF7E22CE)),
  (Color(0xFFEA580C), Color(0xFFC2410C)),
  (Color(0xFF0D9488), Color(0xFF0F766E)),
  (Color(0xFFE11D48), Color(0xFFBE123C)),
  (Color(0xFF4F46E5), Color(0xFF4338CA)),
  (Color(0xFF0891B2), Color(0xFF0E7490)),
  (Color(0xFFC026D3), Color(0xFFA21CAF)),
  (Color(0xFF65A30D), Color(0xFF4D7C0F)),
  (Color(0xFF0284C7), Color(0xFF0369A1)),
  (Color(0xFFD97706), Color(0xFFB45309)),
  (Color(0xFF059669), Color(0xFF047857)),
  (Color(0xFF7C3AED), Color(0xFF6D28D9)),
  (Color(0xFFDC2626), Color(0xFFB91C1C)),
];

(Color, Color) unitTheme(int unitIndex) =>
    kUnitThemes[(unitIndex - 1) % kUnitThemes.length];

/// The whole PATH ladder for one course.
class LearnPathView extends StatelessWidget {
  const LearnPathView({
    super.key,
    required this.path,
    required this.onOpenTopic,
    required this.onOpenChest,
    required this.onOpenRevision,
    required this.onManageCourses,
  });

  final CoursePathModel path;
  final void Function(TopicNode topic) onOpenTopic;
  final void Function(UnitNode unit) onOpenChest;
  final void Function(UnitNode unit) onOpenRevision;
  final VoidCallback onManageCourses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CourseBanner(path: path, onManage: onManageCourses),
        for (final UnitNode unit in path.units) ...<Widget>[
          _UnitBanner(
            unit: unit,
            onChest: () => onOpenChest(unit),
            onReview: () => onOpenRevision(unit),
          ),
          _UnitLadder(
            path: path,
            unit: unit,
            onOpenTopic: onOpenTopic,
          ),
        ],
        if (path.generating) const _GeneratingNode(),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// The gradient course header: body · department, title, gold progress.
class _CourseBanner extends StatelessWidget {
  const _CourseBanner({required this.path, required this.onManage});

  final CoursePathModel path;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final Color cta = context.primary;
    final Color deep = mixTowardBlack(cta, 0.72);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[cta, deep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            path.body.isEmpty ? 'Course path' : '${path.body} · ${path.department}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RenanceText.labelMono.copyWith(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            path.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          LearnProgressBar(
            value: path.completedPercent / 100,
            gold: path.completedPercent >= 100,
          ),
          const SizedBox(height: 6),
          Text(
            '${path.completedPercent}%',
            style: RenanceText.labelMono.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          TactileButton(
            onPressed: onManage,
            height: 40,
            radius: BorderRadius.circular(999),
            fontSize: 13,
            face: Colors.white,
            onFace: deep,
            edge: Colors.white.withValues(alpha: 0.45),
            child: const Text('Add / remove courses'),
          ),
        ],
      ),
    );
  }
}

/// Sticky gradient unit banner: "Unit n · Name" + the chest (unit 1)
/// or the review trophy (later units).
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({
    required this.unit,
    required this.onChest,
    required this.onReview,
  });

  final UnitNode unit;
  final VoidCallback onChest;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final (Color solid, Color deep) = unitTheme(unit.index);
    final bool first = unit.index == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[solid, deep],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: deep.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Unit ${unit.index} · ${unit.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (first)
            _BannerKey(
              onTap: unit.chestOpened ? null : onChest,
              label: unit.chestOpened ? 'Opened' : 'Open chest',
              icon: unit.chestOpened ? 'inventory_2' : 'redeem',
            )
          else
            _BannerKey(
              onTap: unit.reviewReady ? onReview : null,
              label: unit.reviewReady ? 'Review' : 'Locked',
              icon: 'trophy',
            ),
        ],
      ),
    );
  }
}

class _BannerKey extends StatelessWidget {
  const _BannerKey({required this.onTap, required this.label, required this.icon});

  final VoidCallback? onTap;
  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MsIcon(
              icon,
              size: 16,
              color: enabled ? const Color(0xFF131B2E) : Colors.white70,
              fill: enabled,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: enabled ? const Color(0xFF131B2E) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The zig-zag nodes of one unit + the revision card at its end.
class _UnitLadder extends StatelessWidget {
  const _UnitLadder({
    required this.path,
    required this.unit,
    required this.onOpenTopic,
  });

  final CoursePathModel path;
  final UnitNode unit;
  final void Function(TopicNode topic) onOpenTopic;

  @override
  Widget build(BuildContext context) {
    final List<TopicNode> topics = path.topics
        .where((TopicNode t) => t.unit == unit.index)
        .toList();
    return Column(
      children: <Widget>[
        for (var i = 0; i < topics.length; i++)
          _PathNode(
            topic: topics[i],
            unit: unit,
            zigzag: _zigzagOffset(i),
            onTap: () => onOpenTopic(topics[i]),
          ),
        _RevisionCard(unit: unit, topics: topics.length),
        const SizedBox(height: 20),
      ],
    );
  }

  /// The web's ZIGZAG cycle: ml-0 / ml-14 / ml-28 / ml-14 (0/56/112/56).
  double _zigzag(int i) => _zigzagOffset(i);

  static double _zigzagOffset(int i) => <double>[0, 56, 112, 56][i % 4];
}

/// One 76px circular node with the offset, bubble and caption.
class _PathNode extends StatefulWidget {
  const _PathNode({
    required this.topic,
    required this.unit,
    required this.zigzag,
    required this.onTap,
  });

  final TopicNode topic;
  final UnitNode unit;
  final double zigzag;
  final VoidCallback onTap;

  @override
  State<_PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<_PathNode> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final (Color solid, Color deep) = unitTheme(widget.unit.index);
    final TopicNode t = widget.topic;
    final bool done = t.isCompleted;
    final bool current = t.isCurrent;

    final Color face = done
        ? solid
        : current
            ? const Color(0xFFF59E0B)
            : context.cardHigh;
    final Color ring = done || current
        ? mixTowardBlack(face, 0.68)
        : context.outlineVariant;
    final String icon = done ? 'star' : current ? 'school' : 'lock';
    final Color iconColor = done || current
        ? Colors.white
        : context.textSecondary;

    return GestureDetector(
      onTapDown: t.isCompleted || t.isCurrent
          ? (_) => setState(() => _pressing = true)
          : null,
      onTapCancel: () => setState(() => _pressing = false),
      onTapUp: (_) => setState(() => _pressing = false),
      onTap: t.isCompleted || t.isCurrent ? widget.onTap : null,
      child: Padding(
        padding: EdgeInsets.only(left: 40 + widget.zigzag, bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // the pulsing ring on the current node
                if (current)
                  Positioned.fill(
                    child: _PulseRing(color: const Color(0xFFF59E0B)),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 76,
                  height: 76,
                  transform: Matrix4.translationValues(0, _pressing ? 2 : 0, 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: face,
                    border: Border.all(
                      color: done || current ? ring : context.outlineVariant,
                      width: 0,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: done || current
                            ? mixTowardBlack(face, 0.68)
                            : context.outlineVariant,
                        offset: Offset(0, _pressing ? 2 : 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: MsIcon(icon, size: 34, color: iconColor, fill: done || current),
                  ),
                ),
                // the "Start" speech bubble
                if (current)
                  Positioned(
                    top: -34,
                    left: 84,
                    child: _StartBubble(onTap: widget.onTap),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 190,
              child: Text(
                t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: context.ink,
                ),
              ),
            ),
            if (done && t.bestScore >= 100)
              Text(
                'Perfect!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: deep,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The amber pulsing ring around the current node (learn-node-pulse).
class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color});

  final Color color;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (BuildContext context, Widget? _) {
        final double t = _ctl.value;
        final double scale = 1.0 + 0.22 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.55 * (1 - t)),
                width: 3,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The "Start" speech bubble (learn-bubble).
class _StartBubble extends StatelessWidget {
  const _StartBubble({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.outlineVariant, width: 2),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1F111C2D), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          'Start',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.ink,
          ),
        ),
      ),
    );
  }
}

/// The unit revision card at the end of every unit ladder.
class _RevisionCard extends StatelessWidget {
  const _RevisionCard({required this.unit, required this.topics});

  final UnitNode unit;
  final int topics;

  bool get unlocked => unit.reviewReady;

  @override
  Widget build(BuildContext context) {
    final (Color solid, _) = unitTheme(unit.index);
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? solid.withValues(alpha: 0.15)
                  : context.cardHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unlocked ? solid : context.outlineVariant,
                width: 2,
              ),
            ),
            child: MsIcon(
              'fact_check',
              size: 22,
              color: unlocked ? solid : context.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Unit ${unit.index} Revision',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? '50 questions from all $topics topics of this unit'
                      : 'Finish a topic in this unit to unlock the revision paper',
                  style: RenanceText.caption.copyWith(
                    fontSize: 12,
                    color: context.textSecondary,
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

/// The "being prepared" node while the generator writes more topics.
class _GeneratingNode extends StatelessWidget {
  const _GeneratingNode();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.outlineVariant,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: <Widget>[
          const _PulseSpinner(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'More topics on the way',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The next 10 topics are quietly being written for this '
                  'course. Reopen it in a moment and they will be waiting '
                  'on the ladder.',
                  style: RenanceText.caption.copyWith(
                    fontSize: 12,
                    color: context.textSecondary,
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

class _PulseSpinner extends StatefulWidget {
  const _PulseSpinner();

  @override
  State<_PulseSpinner> createState() => _PulseSpinnerState();
}

class _PulseSpinnerState extends State<_PulseSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (BuildContext context, Widget? _) {
        final double t = _ctl.value;
        return Transform.scale(
          scale: 0.85 + 0.3 * (0.5 - 0.5 * (2 * t - 1).abs()),
          child: MsIcon(
            'progress_activity',
            size: 26,
            color: context.primary,
            fill: true,
          ),
        );
      },
    );
  }
}
