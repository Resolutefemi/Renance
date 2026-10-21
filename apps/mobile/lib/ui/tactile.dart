/// The 3D FLAT / TACTILE system, the Flutter twin of the web's press
/// physics (apps/web/app/globals.css, commits 5d9d184a + 5682eb87).
///
/// Founder directive 2026-10-13: buttons stop being flat rectangles - a
/// solid darker bottom edge (4px) makes them read as physical keys, and
/// pressing sinks them 2px while the edge collapses (4 -> 2). Cards stand
/// on white faces with 2px swan outlines and hard 4px extruded ledges.
/// Edges derive from the live token so the Chrome-style seed palette
/// keeps working: the edge is always a darker tone of whatever the
/// primary currently is (the web's color-mix(bg 68%, black)).
library;

import 'package:flutter/material.dart';

import 'msymbols.dart';
import 'theme.dart';

/// `color-mix(in srgb, c <t>%, #000)` - the web's edge derivation.
Color mixTowardBlack(Color c, double t) {
  return Color.fromARGB(
    (c.a * 255.0).round().clamp(0, 255),
    ((c.r * 255.0) * t).round().clamp(0, 255),
    ((c.g * 255.0) * t).round().clamp(0, 255),
    ((c.b * 255.0) * t).round().clamp(0, 255),
  );
}

/// The tactile push-button. A hard 4px extruded bottom edge; pressing
/// sinks the face 2px and the edge collapses to 2px - a real key.
///
/// The web's variants, all through this one widget:
/// - filled keys (bg-primary / bg-hero-cta / bg-macaw / bg-error) -
///   pass [face]; the edge derives color-mix(face 68%, black).
/// - the WHITE key (.hero-cta-secondary / .key-btn.bg-card) - pass
///   [outline]; the face resolves to the card token, a 2px outline
///   draws and the ledge derives color-mix(outline 78%, black).
/// - slim chips (< 32px tall: the Ask-AI chip, mode tabs, jump pills)
///   get a 3px edge via [edgeWidth] so the extrusion never swallows
///   the label.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.face,
    this.onFace,
    this.edge,
    this.outline,
    this.edgeWidth = 4,
    this.height = 52,
    this.radius = RenanceRadius.button,
    // The web's key label: `.key-btn` is 13.5px w800, dashboard CTAs
    // 14px w700-800; 14 w800 carries both (2026-10-19 web parity).
    this.fontSize = 14,
    this.fontWeight = FontWeight.w800,
    this.expand = true,
    this.padding,
  });

  final VoidCallback? onPressed;
  final Widget child;

  /// Face colour. Null resolves to the seed/brand primary.
  final Color? face;
  final Color? onFace;

  /// Extruded edge colour. Null derives color-mix(face 68%, black).
  final Color? edge;

  /// The white-key variant: pass the outline token (web .hero-cta-
  /// secondary / .key-btn.bg-card) and the button draws a 2px outline
  /// on the card face with a deeper derived ledge.
  final Color? outline;

  /// Resting edge thickness - 4 (default) or 3 for slim chips.
  final double edgeWidth;
  final double height;
  final BorderRadius radius;
  final double fontSize;
  final FontWeight fontWeight;
  final bool expand;
  final EdgeInsetsGeometry? padding;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final white = widget.outline != null;
    final face = widget.face ??
        (white ? context.card : Theme.of(context).colorScheme.primary);
    final label = widget.onFace ??
        (white ? context.ink : Theme.of(context).colorScheme.onPrimary);
    final edge = widget.edge ??
        (white ? mixTowardBlack(widget.outline!, 0.78) : mixTowardBlack(face, 0.68));
    final enabled = widget.onPressed != null;
    final lift = _pressing && enabled ? 2.0 : widget.edgeWidth;

    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: widget.height - lift,
      decoration: BoxDecoration(
        color: face,
        borderRadius: widget.radius,
        // NO keycap gloss here (founder 2026-10-20: "change the colour
        // back to the Renance default green colour and other buttons
        // that you changed their colour to the glassy top gloss too"):
        // the white top-lip gradient read as a lighter, glassy face and
        // buried the default green. Keys are FLAT token colour with the
        // extruded edge - the gloss stays on RenanceKeycap (the logo)
        // only. The 3D press physics below are untouched.
        border: white ? Border.all(color: widget.outline!, width: 2) : null,
        boxShadow: enabled
            ? <BoxShadow>[
                // the hard extruded ledge - the key's visible side
                BoxShadow(
                    color: edge, offset: Offset(0, lift), blurRadius: 0),
                // the soft ambient depth UNDER the ledge - the key
                // visibly floats off the surface, Duolingo-style
                BoxShadow(
                  color: edge.withValues(alpha: 0.45),
                  offset: Offset(0, lift + 6),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      padding:
          widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight,
          color: label,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: widget.child,
      ),
    );

    final gesture = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressing = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressing = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressing = false) : null,
      onTap: widget.onPressed,
      child: btn,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        // the web's .key-btn:disabled { opacity: 0.55 }
        opacity: enabled ? 1 : 0.55,
        child: widget.expand
            ? SizedBox(width: double.infinity, child: gesture)
            : gesture,
      ),
    );
  }
}

/// The hero card - the Flutter twin of the web's `.hero-card`
/// (globals.css), the exact 3D recipe every dashboard hero band uses:
///
///   border-radius: 20px;
///   border: 2px solid color-mix(in srgb, var(--color-hero) 82%,
///                                var(--color-on-hero) 18%);
///   box-shadow: 0 4px 0 0 color-mix(in srgb, var(--color-hero) 76%, #000),
///               0 14px 28px -20px rgba(17, 28, 45, 0.45),
///               inset 0 2px 0 color-mix(in srgb,
///                            var(--color-on-hero) 12%, transparent);
///
/// The caller supplies [face] (the hero token) and [onFace]; the
/// outline, ledge and gloss all derive exactly like the stylesheet.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.face,
    this.onFace,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;

  /// Hero ground; null resolves the live token.
  final Color? face;

  /// Ink on the hero; null resolves the live token.
  final Color? onFace;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Color hero = face ?? context.heroCard;
    final Color onHero = onFace ?? context.onHeroCard;
    final Color outline = Color.lerp(onHero, hero, 0.82)!;
    final Color ledge = Color.lerp(const Color(0xFF000000), hero, 0.76)!;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: hero,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outline, width: 2),
        boxShadow: <BoxShadow>[
          // the hard 4px extruded ledge
          BoxShadow(color: ledge, offset: const Offset(0, 4), blurRadius: 0),
          // the soft depth bloom under the band
          const BoxShadow(
            color: Color(0x73111C2D), // rgba(17,28,45,0.45)
            offset: Offset(0, 14),
            blurRadius: 28,
            spreadRadius: -20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        // inset 0 2px 0 on-hero/12 - the glassy inner top lip.
        // Clip.none here + on every inner Stack: corner ornaments
        // overflow their Stacks on purpose and are clipped ONCE, here,
        // with anti-aliasing - a hard Stack edge would sawtooth them.
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, 0.18],
                    colors: <Color>[
                      onHero.withValues(alpha: 0.12),
                      onHero.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// The tactile card: white face, 2px swan outline, hard 4px extruded
/// ledge, glassy inner top highlight (the web's .glass / .glass-float).
/// [float] plays the hover lift (translateY -3px, deeper shadow) on
/// press instead of the sink - the floating hero cards.
class TactileCard extends StatefulWidget {
  const TactileCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.outline,
    this.ledge,
    this.radius = RenanceRadius.card,
    this.padding = const EdgeInsets.all(16),
    this.float = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color? color;
  final Color? outline;
  final Color? ledge;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final bool float;

  @override
  State<TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<TactileCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.darkChrome;
    final face = widget.color ?? context.card;
    final outline =
        widget.outline ?? context.outlineVariant;
    final ledge = widget.ledge ??
        mixTowardBlack(outline, dark ? 0.48 : 0.62);
    final lift = _active ? (widget.float ? 6.0 : 2.0) : 4.0;
    final offset = _active
        ? (widget.float ? const Offset(0, -3) : const Offset(0, 0))
        : const Offset(0, 0);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: face,
        borderRadius: widget.radius,
        border: Border.all(color: outline, width: 2),
        boxShadow: [
          // the hard extruded ledge
          BoxShadow(
            color: ledge,
            offset: widget.float && _active ? offset : Offset(0, lift),
            blurRadius: 0,
          ),
          // the soft float shadow, hover only
          if (widget.float && _active)
            BoxShadow(
              color: const Color(0x40111C2D),
              offset: const Offset(0, 22),
              blurRadius: 40,
              spreadRadius: -22,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: widget.radius,
        // the glassy inner top lip: white 70% -> 0 in light,
        // hero ink 8% -> 0 in dark (the web's inset highlight).
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.35],
                    colors: dark
                        ? [const Color(0x14F0F3FF), const Color(0x00F0F3FF)]
                        : [const Color(0xB3FFFFFF), const Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Padding(padding: widget.padding, child: widget.child),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return card;
    return GestureDetector(
      onTapDown: (_) => setState(() => _active = true),
      onTapCancel: () => setState(() => _active = false),
      onTapUp: (_) => setState(() => _active = false),
      onTap: widget.onTap,
      child: card,
    );
  }
}

/// The Renance 3D FLAT keycap logomark - the ONLY loading/progress
/// visual in the product, now in Flutter exactly as the web draws it:
/// solid brand face, extruded darker bottom edge, glassy inner top
/// highlight, Nunito-900 "R". Reads the LIVE seed: a student who picks
/// red in Settings -> Appearance gets a red keycap here, in the splash
/// and everywhere else (the web's appearance-adaptive favicon rule).
class RenanceKeycap extends StatelessWidget {
  const RenanceKeycap({super.key, this.size = 44, this.onPrimary, this.face});

  final double size;

  /// Letter colour override; null resolves white on the face.
  final Color? onPrimary;

  /// Face override; null resolves the live primary (seed-aware).
  final Color? face;

  @override
  Widget build(BuildContext context) {
    final f = face ?? context.primary;
    final letter = onPrimary ?? context.onPrimary;
    final edge = mixTowardBlack(f, 0.62);
    return CustomPaint(
      size: Size.square(size),
      painter: _KeycapPainter(face: f, edge: edge, letter: letter),
    );
  }
}

class _KeycapPainter extends CustomPainter {
  _KeycapPainter({required this.face, required this.edge, required this.letter});

  final Color face;
  final Color edge;
  final Color letter;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final edgePaint = Paint()..color = edge;
    final facePaint = Paint()..color = face;

    // extruded bottom edge (behind the face)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(3 * s, 3 * s, 58 * s, 58 * s), Radius.circular(15 * s)),
      edgePaint,
    );
    // face, lifted up to reveal the edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(3 * s, 3 * s, 58 * s, 50 * s), Radius.circular(15 * s)),
      facePaint,
    );
    // glassy top lip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(9 * s, 9 * s, 46 * s, 27 * s), Radius.circular(10 * s)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x4DFFFFFF), const Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(9 * s, 9 * s, 46 * s, 27 * s)),
    );

    // the letter
    final tp = TextPainter(
      text: TextSpan(
        text: 'R',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 38 * s,
          fontWeight: FontWeight.w900,
          color: letter,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Founder bug report 2026-10-18 (the R sat too low in every in-app
    // keycap): the web SVG's y="42.5" is the glyph's BASELINE, but the
    // old port subtracted half the line-box height - landing the R ~19
    // units lower than the web inside the 64-unit keycap. Paint so the
    // alphabetic baseline itself sits at 42.5*s and the glyph optically
    // centres on the face (face spans y 3..53, centre y=28), exactly
    // the geometry icon.svg draws.
    final double baseline =
        tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(
      canvas,
      Offset(32 * s - tp.width / 2, 42.5 * s - baseline),
    );
  }

  @override
  bool shouldRepaint(_KeycapPainter old) =>
      old.face != face || old.edge != edge || old.letter != letter;
}

/// The web's PageBar back key (components/page-bar.tsx): the flat 36px
/// rounded-xl square with the bare arrow_back glyph - NO circle, NO
/// border, NO ledge. Founder directive 2026-10-20 (repeated twice):
/// "change all those previous buttons design at the top LHS on the
/// mobile app to match the website own in all pages" - every PAGE now
/// wears exactly this key. The 3D circle stays where the website itself
/// still plays it (overlay/sheet top bars) - see [SheetBackKey].
class TactileBackKey extends StatefulWidget {
  const TactileBackKey({
    super.key,
    this.onTap,
    this.icon = 'arrow_back',
    this.size = 36,
    this.semanticLabel,
  });

  final VoidCallback? onTap;

  /// Material Symbols ligature name ('arrow_back', 'close', ...).
  final String icon;
  final double size;
  final String? semanticLabel;

  @override
  State<TactileBackKey> createState() => _TactileBackKeyState();
}

class _TactileBackKeyState extends State<TactileBackKey> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    // the web: h-9 w-9 rounded-xl text-on-surface hover:bg-polar -
    // pressing paints the calm polar wash; nothing lifts or sinks.
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => setState(() => _pressing = true) : null,
        onTapCancel: widget.onTap != null ? () => setState(() => _pressing = false) : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _pressing = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressing
                ? (context.darkChrome
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF0F4F4)) // the polar wash
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: MsIcon(
            widget.icon,
            size: widget.size * 0.61,
            wght: 700,
            color: context.ink,
          ),
        ),
      ),
    );
  }
}

/// The web's .back-key (globals.css): the 3D circular back/close key
/// reserved for OVERLAY and SHEET top bars - "the back button should be
/// Duolingo's own, and 3D" (founder directive). 38px circle, 2px
/// outline, card face, a hard 3px ledge; pressing sinks 2px while the
/// ledge collapses to 1px. The lesson player's close key, the CBT
/// player's exit, the explanation sheet - the exact places the website
/// still paints the circle.
class SheetBackKey extends StatefulWidget {
  const SheetBackKey({
    super.key,
    this.onTap,
    this.icon = 'arrow_back',
    this.size = 38,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final String icon;
  final double size;
  final String? semanticLabel;

  @override
  State<SheetBackKey> createState() => _SheetBackKeyState();
}

class _SheetBackKeyState extends State<SheetBackKey> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final outline = context.outlineVariant;
    final ledge = mixTowardBlack(outline, 0.72);
    final lift = _pressing ? 1.0 : 3.0;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => setState(() => _pressing = true) : null,
        onTapCancel: widget.onTap != null ? () => setState(() => _pressing = false) : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _pressing = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size - lift,
          decoration: BoxDecoration(
            color: context.card,
            shape: BoxShape.circle,
            border: Border.all(color: outline, width: 2),
            boxShadow: [
              BoxShadow(color: ledge, offset: Offset(0, lift), blurRadius: 0),
            ],
          ),
          child: Center(
            child: MsIcon(
              widget.icon,
              size: widget.size * 0.58,
              wght: 700,
              color: context.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// The CBT player option row: a tactile key-card (2px border, 3px
/// extruded shadow, press physics) with a Duolingo squircle letter
/// badge; selection highlights in the macaw wash with the blue ring,
/// and the reveal paints check/cross (iguana / cardinal) - the exact
/// web recipe. [state]: rest, selected, correct, wrong.
enum KeyCardState { rest, selected, correct, wrong }

class TactileKeyCard extends StatefulWidget {
  const TactileKeyCard({
    super.key,
    required this.label,
    required this.badge,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String badge;
  final KeyCardState state;
  final VoidCallback onTap;

  @override
  State<TactileKeyCard> createState() => _TactileKeyCardState();
}

class _TactileKeyCardState extends State<TactileKeyCard> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.darkChrome;
    final Color face;
    final Color outline;
    switch (widget.state) {
      case KeyCardState.selected:
        face = context.selectionBlue;
        outline = RenanceColors.macaw;
        break;
      case KeyCardState.correct:
        face = dark ? const Color(0xFF12301F) : RenanceColors.iguana;
        outline = RenanceColors.treefrogDark;
        break;
      case KeyCardState.wrong:
        face = dark ? const Color(0xFF3A1214) : const Color(0xFFFFDFDF);
        outline = RenanceColors.cardinalDark;
        break;
      case KeyCardState.rest:
        face = context.card;
        outline = dark ? RenanceColors.darkOutline : RenanceColors.swan;
        break;
    }
    final ledge = mixTowardBlack(outline, dark ? 0.48 : 0.62);
    final sink = _pressing ? 1.0 : 3.0;

    final badgeBg = switch (widget.state) {
      KeyCardState.selected => RenanceColors.macaw,
      KeyCardState.correct => RenanceColors.treefrogDark,
      KeyCardState.wrong => RenanceColors.cardinalDark,
      KeyCardState.rest => context.inverseChip,
    };
    final badgeFg = switch (widget.state) {
      KeyCardState.selected => Colors.white,
      KeyCardState.correct => Colors.white,
      KeyCardState.wrong => Colors.white,
      KeyCardState.rest => context.onInverseChip,
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressing = true),
      onTapCancel: () => setState(() => _pressing = false),
      onTapUp: (_) => setState(() => _pressing = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: face,
          borderRadius: RenanceRadius.field,
          border: Border.all(color: outline, width: 2),
          boxShadow: [
            BoxShadow(
              color: ledge,
              offset: Offset(0, sink),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                widget.badge,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: badgeFg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
