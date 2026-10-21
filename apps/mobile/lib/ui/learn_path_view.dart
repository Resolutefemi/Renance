/// The course PATH view - the Duolingo-style zig-zag unit ladder, the
/// Flutter twin of the web's CoursePathView + PathNode
/// (apps/web/app/courses/page.tsx): 76px circular nodes offset
/// 0/56/112/56px per index, 15 rotating unit colour themes, and the
/// PINNED gradient unit banners - every unit header stays cleanly at
/// the top of the screen like a structural sub-navbar while its topics
/// scroll under it (the web's `sticky top-12 z-10` banners, here via
/// consecutive pinned SliverPersistentHeaders) - plus the unit-1
/// treasure chest, the unit review trophy, the "Start" speech bubble on
/// the current node, the unit revision card and the generating
/// placeholder.
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

/// The pinned unit-banner height - founder 2026-10-21: the old 50px
/// extent (38px of visible banner after the bottom margin) squeezed the
/// bar into a cramped one-line strip with an ellipsized name. 68px
/// carries the web banner's presence: py-2.5 padding, up to TWO name
/// lines (long unit names like "Unit 1 · Matter, Atomic Structure and
/// Equations" now show in full instead of truncating), badge and the
/// extruded ledge included.
const double kUnitBannerExtent = 68;

/// Founder report 2026-10-21 ("the unit bar is still not okay"): a
/// phone running a LARGE system font scale renders the 13px name at
/// ~17px, so the two name lines no longer fit the fixed 68px header and
/// the second line painted half-swallowed by the banner's bottom edge.
/// A pinned SliverPersistentHeader can't grow on its own, so the extent
/// is COMPUTED from the live TextScaler: two scaled name lines + the
/// py-2.5 padding (20) + the 2px border ring (4) + the bottom margin
/// (12) + a small breathing tail - never shorter than the 68px base.
double unitBannerExtentFor(TextScaler scaler) {
  final double twoLines = scaler.scale(13.0) * 1.2 * 2;
  final double extent = 12 + 4 + 20 + twoLines + 4;
  return extent < kUnitBannerExtent ? kUnitBannerExtent : extent.ceilToDouble();
}

/// The whole PATH ladder for one course - a sliver list so every unit
/// banner can PIN at the top of the viewport (the web's sticky
/// sub-navbar) while its ladder scrolls underneath.
class LearnPathView extends StatelessWidget {
  const LearnPathView({
    super.key,
    required this.path,
    required this.onOpenTopic,
    required this.onOpenChest,
    required this.onOpenRevision,
  });

  final CoursePathModel path;
  final void Function(TopicNode topic) onOpenTopic;
  final void Function(UnitNode unit) onOpenChest;
  final void Function(UnitNode unit) onOpenRevision;

  @override
  Widget build(BuildContext context) {
    // The pinned unit-banner height for THIS device's font scale -
    // resolved per build (unitBannerExtentFor).
    final double bannerExtent =
        unitBannerExtentFor(MediaQuery.textScalerOf(context));
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        // the gradient course header scrolls away normally
        SliverToBoxAdapter(child: _CourseBanner(path: path)),
        // The founder's 2026-10-22 pass: the unit banner rides right
        // under the hero card (was a 20px float that read as a gap).
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
        for (final UnitNode unit in path.units)
          // THE PINNED UNIT BANNER - the structural sub-navbar. Founder
          // bug report 2026-10-20: bare sibling SliverPersistentHeaders
          // ALL pin at the viewport top forever (each is its own sliver
          // whose 50px scroll extent never scrolls past), so every unit
          // bar piled up under the header and squeezed together.
          // SliverMainAxisGroup scopes each pinned header to its OWN
          // unit's extent: the banner pins while its ladder scrolls
          // under it, and the NEXT unit's banner slides up and pushes it
          // away - the exact CSS `position: sticky; top-12` push the
          // website plays.
          SliverMainAxisGroup(
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: _UnitBannerDelegate(
                  unit: unit,
                  extent: bannerExtent,
                  onChest: () => onOpenChest(unit),
                  onReview: () => onOpenRevision(unit),
                ),
              ),
              SliverToBoxAdapter(
                child: _UnitLadder(
                  path: path,
                  unit: unit,
                  onOpenTopic: onOpenTopic,
                  onOpenRevision: () => onOpenRevision(unit),
                ),
              ),
            ],
          ),
        if (path.generating)
          const SliverToBoxAdapter(child: _GeneratingNode()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// The gradient course header: body · department, title, gold progress.
class _CourseBanner extends StatelessWidget {
  const _CourseBanner({required this.path});

  final CoursePathModel path;

  @override
  Widget build(BuildContext context) {
    final Color cta = context.primary;
    final Color deep = mixTowardBlack(cta, 0.72);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[cta, deep],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.outlineVariant, width: 2),
        boxShadow: <BoxShadow>[
          // learn-tile: the hard 4px extruded ledge + inner top gloss
          BoxShadow(
            color: context.outlineVariant.withValues(alpha: 0.55),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // Web: text-[11px] font-black UPPERCASE tracking-wide white/85
            // (CSS `uppercase` - the old build leaked the raw lowercase
            // body label "jamb · jamb subjects").
            (path.body.isEmpty
                    ? 'Course path'
                    : '${path.body} · ${path.department}')
                .toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RenanceText.labelMono.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            path.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LearnProgressBar(
                  value: path.completedPercent / 100,
                  gold: true,
                  // Web hero rail h-3.5 = 14px (founder 2026-10-21:
                  // the default 12px read squeezed next to the web).
                  height: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${path.completedPercent}%',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          // The "Add / remove courses" pill is gone (founder
          // 2026-10-22): course management lives in the Courses tab,
          // the map page is a pure learning path.
        ],
      ),
    );
  }
}

/// The pinned sliver delegate wrapping the unit banner content at a
/// fixed extent - the sticky sub-navbar itself.
class _UnitBannerDelegate extends SliverPersistentHeaderDelegate {
  _UnitBannerDelegate({
    required this.unit,
    required this.extent,
    required this.onChest,
    required this.onReview,
  });

  final UnitNode unit;

  /// The text-scale-aware header height (unitBannerExtentFor) - fixed
  /// per delegate instance so pin/scroll math stays stable.
  final double extent;
  final VoidCallback onChest;
  final VoidCallback onReview;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _UnitBanner(
      unit: unit,
      onChest: onChest,
      onReview: onReview,
    );
  }

  @override
  bool shouldRebuild(_UnitBannerDelegate oldDelegate) =>
      oldDelegate.unit != unit || oldDelegate.extent != extent;
}

/// Sticky gradient unit banner: "Unit n · Name" + the chest (unit 1)
/// or the review trophy (later units). The exact web recipe: rounded-xl
/// border-2 theme.deep, 135deg solid->deep gradient, the learn-tile
/// extruded ledge, px-3.5 py-2.5, 13px font-black name and the
/// border-white/50 bg-white/20 badge key.
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // Web banner recipe px-3.5 py-2.5 - the roomy 10px vertical padding
      // (founder 2026-10-21: the squeezed 8px strip is out).
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[solid, deep],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: deep, width: 2),
        boxShadow: <BoxShadow>[
          // learn-tile: the hard extruded ledge + the soft float bloom
          BoxShadow(
            color: context.outlineVariant.withValues(alpha: 0.55),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          const BoxShadow(
            color: Color(0x26111C2D),
            offset: Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              // Web parity: the banner prints `u.name` RAW - the API name
              // already carries the "Unit n · " prefix. Prefixing it again
              // produced "Unit 1 · Unit 1 · Matter, Atomic Structure…".
              // Two lines (web wraps naturally): long unit names show in
              // full instead of dying in an ellipsis.
              unit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.2,
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

class _BannerKey extends StatefulWidget {
  const _BannerKey({required this.onTap, required this.label, required this.icon});

  final VoidCallback? onTap;
  final String label;
  final String icon;

  @override
  State<_BannerKey> createState() => _BannerKeyState();
}

class _BannerKeyState extends State<_BannerKey> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressing = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressing = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressing = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _pressing ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // the web's badge: rounded-lg border-2 border-white/50
          // bg-white/20 text-[11px] font-extrabold
          color: Colors.white.withValues(alpha: enabled ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.50 : 0.30),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MsIcon(
              widget.icon,
              size: 15,
              color: Colors.white,
              fill: enabled,
            ),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : Colors.white60,
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
    required this.onOpenRevision,
  });

  final CoursePathModel path;
  final UnitNode unit;
  final void Function(TopicNode topic) onOpenTopic;
  final VoidCallback onOpenRevision;

  @override
  Widget build(BuildContext context) {
    final List<TopicNode> topics = path.topics
        .where((TopicNode t) => t.unit == unit.index)
        .toList();
    // Web: "mt-3 flex flex-col items-center gap-1" - the ladder column
    // is CENTRED and each node translates around the centre line.
    return Column(
      children: <Widget>[
        for (var i = 0; i < topics.length; i++)
          Padding(
            // the web ladder's gap-1: 4px between node cards.
            padding: const EdgeInsets.only(bottom: 4),
            child: Transform.translate(
              offset: Offset(_zigzagOffset(i), 0),
              child: _PathNode(
                topic: topics[i],
                unit: unit,
                zigzag: 0,
                onTap: () => onOpenTopic(topics[i]),
              ),
            ),
          ),
        _RevisionCard(
          unit: unit,
          topics: topics.length,
          onTap: onOpenRevision,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// The web's ZIGZAG cycle relative to the CENTRE line: ml-0 / ml-14 /
  /// ml-28 / ml-14 (0/56/112/56) on an items-centred column, i.e. the
  /// node offsets swing -56 / 0 / +56 / 0 around the centre line - the
  /// exact Duolingo zig-zag the website plays (the old left-anchored
  /// 40+zigzag rail leaned the whole ladder to one side).
  static double _zigzagOffset(int i) => <double>[-56, 0, 56, 0][i % 4];
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

    // Web parity (PathNode): locked nodes wear opacity-70.
    final double nodeOpacity = t.status == 'locked' ? 0.70 : 1.0;
    return GestureDetector(
      onTapDown: t.isCompleted || t.isCurrent
          ? (_) => setState(() => _pressing = true)
          : null,
      onTapCancel: () => setState(() => _pressing = false),
      onTapUp: (_) => setState(() => _pressing = false),
      onTap: t.isCompleted || t.isCurrent ? widget.onTap : null,
      child: Opacity(
        opacity: nodeOpacity,
        child: Column(
          // Web PathNode: `flex flex-col items-center` - node, then the
          // CENTERED title, then Perfect!, then the Start bubble. The
          // old build floated the bubble over the label (screenshot bug).
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    border: Border.all(color: ring, width: 2),
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
                    // the web's node glyph: text-[30px]
                    child: MsIcon(icon, size: 30, color: iconColor, fill: done || current),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 190,
              child: Text(
                t.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: t.status == 'locked' ? context.textSecondary : context.ink,
                ),
              ),
            ),
            if (done && t.bestScore >= 100) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                'Perfect!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: deep,
                ),
              ),
            ],
            // the "Start" speech bubble rides UNDER the label, centred
            // on the node (web: <p class="learn-bubble mt-0.5">Start</p>)
            if (current) ...<Widget>[
              const SizedBox(height: 2),
              _StartBubble(onTap: widget.onTap),
            ],
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

/// The "Start" speech bubble (learn-bubble): the web paints it dark -
/// on-surface #3c3c46 face, white 10.5px w900 uppercase ink, with the
/// little pointer triangle on top.
class _StartBubble extends StatelessWidget {
  const _StartBubble({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BubbleTailPainter(color: context.ink),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Text(
            'START',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: context.card,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(size.width / 2 - 5, 1)
      ..lineTo(size.width / 2, -5 + 1)
      ..lineTo(size.width / 2 + 5, 1)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.width, size.height - 1),
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) => oldDelegate.color != color;
}

/// The unit revision card at the end of every unit ladder - the web's
/// exact recipe: learn-tile rounded-2xl border-2 theme.solid with the
/// 135deg wash->transparent gradient face, the SOLID 44px icon key and
/// the theme-ink title.
class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.unit,
    required this.topics,
    required this.onTap,
  });

  final UnitNode unit;
  final int topics;
  final VoidCallback onTap;

  bool get unlocked => unit.reviewReady;

  @override
  Widget build(BuildContext context) {
    final (Color solid, Color deep) = unitTheme(unit.index);
    final Color ink = mixTowardBlack(solid, 0.82);
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(alignment: Alignment.center,
        
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const <double>[0, 0.72],
            colors: <Color>[
              solid.withValues(alpha: 0.12),
              solid.withValues(alpha: 0.0),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: solid, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.outlineVariant.withValues(alpha: 0.55),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(alignment: Alignment.center,
              
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: unlocked ? solid : context.cardHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unlocked ? mixTowardBlack(solid, 0.72) : context.outlineVariant,
                  width: 2,
                ),
                boxShadow: unlocked
                    ? <BoxShadow>[
                        BoxShadow(
                          color: mixTowardBlack(solid, 0.68),
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: MsIcon(
                'fact_check',
                size: 22,
                color: unlocked ? Colors.white : context.textSecondary,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unlocked
                        ? '50 questions from all $topics topics of this unit'
                        : 'Finish a topic in this unit to unlock the revision paper',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            MsIcon(
              unlocked ? 'chevron_right' : 'lock',
              size: 20,
              color: ink,
            ),
          ],
        ),
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
