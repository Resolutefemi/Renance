/// The Learn module's shared atoms - the Flutter twins of the web's
/// components/learn/bits.tsx + learn-stats.tsx: the gem glyph, the
/// league shield badges, the goal ring, the gold/green progress bars,
/// the deterministic avatar colours, the header stat chips and the
/// combo toast.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../learn_controller.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

// ------------------------------------------------------------- constants

/// The confetti palette (bits.tsx ConfettiBurst).
const List<Color> kConfettiColors = <Color>[
  Color(0xFF10DA11),
  Color(0xFF1CB0F6),
  Color(0xFFFFC800),
  Color(0xFFFF9600),
  Color(0xFFFF4B4B),
  Color(0xFFCE82FF),
];

/// The 20 league tiers, in promotion order (economy.go Leagues).
const List<String> kLeagueNames = <String>[
  'Bronze', 'Copper', 'Silver', 'Gold', 'Sapphire', 'Ruby', 'Emerald',
  'Amethyst', 'Pearl', 'Obsidian', 'Jade', 'Topaz', 'Garnet', 'Quartz',
  'Tourmaline', 'Opal', 'Platinum', 'Titanium', 'Aurora', 'Diamond',
];

/// LeagueBadge shield colours (bits.tsx): the first nine tiers carry
/// explicit hues, everything after falls back to the brand green.
const Map<String, Color> kLeagueColors = <String, Color>{
  'Bronze': Color(0xFFD9A15B),
  'Copper': Color(0xFFC96F4A),
  'Silver': Color(0xFFB8C0CC),
  'Gold': Color(0xFFFFC800),
  'Sapphire': Color(0xFF1CB0F6),
  'Ruby': Color(0xFFFF4B4B),
  'Emerald': Color(0xFF2EC46E),
  'Amethyst': Color(0xFFCE82FF),
  'Pearl': Color(0xFFE8E6F2),
  'Diamond': Color(0xFF84D8FF),
};

Color leagueColor(String name) =>
    kLeagueColors[name] ?? const Color(0xFF10DA11);

/// The deterministic avatar palette (feed/profile rows): FNV-1a hash of
/// the username picks one of the eight house hues.
const List<Color> kAvatarColors = <Color>[
  Color(0xFF58CC02),
  Color(0xFF1CB0F6),
  Color(0xFFFFC800),
  Color(0xFFFF9600),
  Color(0xFFFF4B4B),
  Color(0xFFCE82FF),
  Color(0xFF2B70C9),
  Color(0xFF00CD9C),
];

Color avatarColorFor(String seed) {
  int h = 0x811c9dc5;
  for (final int c in seed.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7FFFFFFF;
  }
  return kAvatarColors[h % kAvatarColors.length];
}

/// The web's timeAgo: "just now", minutes, hours, days, weeks, then a
/// short date.
String timeAgo(int ms) {
  if (ms <= 0) return 'just now';
  final Duration d = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(ms),
  );
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${d.inDays ~/ 7}w';
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(ms);
  final String month = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][t.month - 1];
  return '$month ${t.day}';
}

/// The web's league countdown format: "2d 14h" / "5h 12m" / "45m".
String formatCountdown(int ms) {
  if (ms <= 0) return '0m';
  final Duration d = Duration(milliseconds: ms);
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

// ---------------------------------------------------------------- glyphs

/// The blue gem diamond (GemIcon SVG): fill #1cb0f6, stroke #1899d6,
/// facet lines #84d8ff.
class GemIcon extends StatelessWidget {
  const GemIcon({super.key, this.size = 17});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GemPainter(),
    );
  }
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Path body = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.38)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.38)
      ..close();
    final Paint fill = Paint()..color = const Color(0xFF1CB0F6);
    final Paint stroke = Paint()
      ..color = const Color(0xFF1899D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w / 17).clamp(1, 2);
    final Paint facet = Paint()
      ..color = const Color(0xFF84D8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w / 17).clamp(1, 2);
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);
    // facets: the kite cuts of the SVG
    canvas.drawLine(Offset(0, h * 0.38), Offset(w * 0.5, h * 0.38), facet);
    canvas.drawLine(Offset(w, h * 0.38), Offset(w * 0.5, h * 0.38), facet);
    canvas.drawLine(Offset(w * 0.25, h * 0.38), Offset(w * 0.5, h), facet);
    canvas.drawLine(Offset(w * 0.75, h * 0.38), Offset(w * 0.5, h), facet);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.25, h * 0.38), facet);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.75, h * 0.38), facet);
  }

  @override
  bool shouldRepaint(covariant _GemPainter old) => false;
}

/// The league shield with its two-letter monogram (LeagueBadge SVG):
/// a shield plate in the tier's hue, a darker rim, the initials in ink.
class LeagueBadge extends StatelessWidget {
  const LeagueBadge({super.key, required this.league, this.size = 24});

  final String league;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color c = leagueColor(league);
    final String mono = league.length >= 2
        ? league.substring(0, 2).toUpperCase()
        : league.toUpperCase();
    final bool dark = context.darkChrome;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LeagueShieldPainter(
          color: c,
          rim: mixTowardBlack(c, 0.68),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.06, bottom: size * 0.12),
            child: Text(
              mono,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: size * 0.34,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: dark ? const Color(0xFF131720) : const Color(0xFF131B2E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeagueShieldPainter extends CustomPainter {
  _LeagueShieldPainter({required this.color, required this.rim});

  final Color color;
  final Color rim;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Path shield = Path()
      ..moveTo(w * 0.5, h)
      ..lineTo(0, h * 0.78)
      ..lineTo(0, h * 0.1)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w, h * 0.1)
      ..lineTo(w, h * 0.78)
      ..close();
    canvas.drawPath(shield, Paint()..color = color);
    canvas.drawPath(
      shield,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.06).clamp(1, 2.5),
    );
    // the top banner band
    final Path band = Path()
      ..moveTo(0, h * 0.1)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w, h * 0.1)
      ..lineTo(w, h * 0.22)
      ..lineTo(w * 0.5, h * 0.12)
      ..lineTo(0, h * 0.22)
      ..close();
    canvas.drawPath(band, Paint()..color = rim);
  }

  @override
  bool shouldRepaint(_LeagueShieldPainter old) =>
      old.color != color || old.rim != rim;
}

/// The daily-goal ring (bits.tsx GoalRing): 30px SVG, r=10, 3.5 stroke,
/// track swan, fill primary, rotated -90 degrees, check at 100%.
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, this.size = 30, this.progress = 0});

  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double p = progress.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: p <= 0 ? 0.0001 : p,
              strokeWidth: size * 0.117,
              strokeAlign: BorderSide.strokeAlignInside,
              strokeCap: StrokeCap.round,
              backgroundColor: context.outlineLight,
              valueColor: AlwaysStoppedAnimation<Color>(context.primary),
            ),
          ),
          if (p >= 1.0)
            MsIcon('check', size: size * 0.45, color: context.primary)
          else
            Text(
              '${(p * 100).round()}',
              style: RenanceText.labelMono.copyWith(
                fontSize: size * 0.3,
                fontWeight: FontWeight.w700,
                color: context.ink,
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ progress

/// The learn progress bar: 12px pill track with the recessed inner
/// shadow, gloss line on the fill, gold when complete, green in flight
/// (the web's .hero-progress family at lesson scale).
class LearnProgressBar extends StatelessWidget {
  const LearnProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.gold = false,
    this.trackColor,
  });

  final double value;
  final double height;
  final bool gold;

  /// Overrides the swan track (e.g. the hero's hero-track token).
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    final Color fill = gold
        ? RenanceColors.bee
        : context.primary;
    return Container(
      height: height,
      // Track parity: the web rail is `w-full` - the GRAY TRACK always
      // spans the full row and the fill rides inside it. A bare Stack
      // hugs its FractionallySizedBox child, so a 0% fill collapsed the
      // whole rail into a 1px vertical line (founder screenshot bug).
      // `double.infinity` pins the track to the row width instead.
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor ?? context.outlineLight,
        borderRadius: BorderRadius.circular(999),
        // the web's recessed groove: inset 0 2px 3px rgba(0,0,0,.14),
        // inset 0 -1px 0 rgba(255,255,255,.08)
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x24000000),
            offset: const Offset(0, 2),
            blurRadius: 3,
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: const Color(0x14FFFFFF),
            offset: const Offset(0, -1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v <= 0 ? 0.0 : v,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            // the fill's own inset bottom shade (web .hero-progress-fill)
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0x1F000000),
                offset: const Offset(0, 2),
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
          height: height,
          // the Duolingo gloss line (web .hero-progress-gloss:
          // left/right 4px, top 2px, 3px tall, white 35%)
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- header chips

/// The header gems chip (LearnStatChips): the wallet counter that
/// links to the shop on the profile page. Owns a mini 2px press like
/// the web's active:translate-y-[2px].
class GemStatChip extends StatelessWidget {
  const GemStatChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final int gems = context.watch<LearnController>().gems;
    return _PressChip(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const GemIcon(size: 17),
          const SizedBox(width: 5),
          Text(
            '$gems',
            style: RenanceText.labelMono.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill container with the 2px tactile press.
class _PressChip extends StatefulWidget {
  const _PressChip({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressChip> createState() => _PressChipState();
}

class _PressChipState extends State<_PressChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: context.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.outlineLight, width: 2),
        ),
        child: DefaultTextStyle.merge(
          style: RenanceText.labelMono,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The streak pill (flame + mono count) - the header's live streak.
class StreakHeaderPill extends StatelessWidget {
  const StreakHeaderPill({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MsIcon(
            'local_fire_department',
            size: 19,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text('$streak', style: RenanceText.labelMono),
        ],
      ),
    );
  }
}

/// The freeze pill (snowflake + count), rendered only when the student
/// holds freezes - the dashboard header's rule.
class FreezeHeaderPill extends StatelessWidget {
  const FreezeHeaderPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MsIcon('ac_unit', size: 19, color: Color(0xFF1899D6)),
          const SizedBox(width: 4),
          Text('$count', style: RenanceText.labelMono),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- combo toast

/// The blue combo banner: "3 in a row! +XP combo" - flashes for 1.6s
/// on every third consecutive correct answer (the web's ToastBanner).
class ComboToast extends StatelessWidget {
  const ComboToast({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RenanceColors.macaw,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33111C2D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MsIcon('bolt', size: 18, color: Colors.white, fill: true),
          const SizedBox(width: 8),
          Text(
            '$count in a row! +XP combo',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
