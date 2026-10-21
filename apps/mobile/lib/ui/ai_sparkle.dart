import 'package:flutter/material.dart';

import 'tactile.dart' show mixTowardBlack;
import 'theme.dart';

/// AiSparkleIcon: the house AI glyph - the curved four-point sparkle
/// the flagship AI products use (Gemini, Copilot), drawn with quads so
/// the star's sides are concave, plus a small companion star at the
/// top-right. Same geometry as the web's components/ai-sparkle.tsx so
/// app and site speak one icon language (founder directive: "a very
/// good AI icon, not one that looks vibe coded").
class AiSparkleIcon extends StatelessWidget {
  const AiSparkleIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AiSparklePainter(color ?? Colors.white),
    );
  }
}

class _AiSparklePainter extends CustomPainter {
  _AiSparklePainter(this.color);

  final Color color;

  /// One curved four-point star centred on [c] with radius [r]. Each
  /// side is a quadratic whose control point sits 0.143r off the
  /// centre toward the side - the concavity that makes it read as a
  /// sparkle instead of a diamond.
  static Path _star(Path path, Offset c, double r) {
    final double k = 0.143 * r;
    path
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final double s = size.width;
    // Main sparkle fills the box; companion sits at the top-right.
    canvas.drawPath(
      _star(Path(), Offset(0.46 * s, 0.52 * s), 0.44 * s),
      paint,
    );
    canvas.drawPath(
      _star(Path(), Offset(0.80 * s, 0.20 * s), 0.175 * s),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AiSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The floating Renance AI entry (founder directive): bottom-right of
/// the HOME tab only. The founder's 2026-10-20 3D pass, colour-corrected
/// the same day ("change the colour back to the Renance default green
/// colour and other buttons that you changed their colour to the glassy
/// top gloss too") - still a RICH physical keycap, never a flat sticker:
///
///   * a FLAT primary face (the vivid #10da11, seed when live) - no
///     lighting gradient, no glassy top lip, exactly like the desk CTA,
///   * a hard 4px extruded bottom edge (color-mix(primary 68%, #000))
///     that collapses to 2px on press while the face sinks 2px,
///   * a 1px black/10 ring + the web's soft 0 6px 20px shadow AND a
///     wide green bloom - three stacked shadow layers.
class AiFloatingButton extends StatefulWidget {
  const AiFloatingButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends State<AiFloatingButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final Color face = context.primary;
    final Color edge = mixTowardBlack(face, 0.68);
    const double size = 56; // web h-14 w-14
    final double lift = _pressing ? 2.0 : 4.0;

    return Semantics(
      button: true,
      label: 'Renance AI Studio',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapCancel: () => setState(() => _pressing = false),
        onTapUp: (_) => setState(() => _pressing = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: size,
          height: size - lift,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              // 1. the hard extruded keycap edge
              BoxShadow(
                color: edge,
                offset: Offset(0, lift),
                blurRadius: 0,
              ),
              // 2. the web's soft drop: 0 6px 20px rgba(16,20,24,0.35)
              const BoxShadow(
                color: Color(0x59101418),
                offset: Offset(0, 6),
                blurRadius: 20,
              ),
              // 3. the green depth bloom lifting it off the page
              BoxShadow(
                color: face.withValues(alpha: 0.35),
                offset: const Offset(0, 10),
                blurRadius: 28,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // the 1px black/10 ring (web ring-1 ring-black/10)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // the FLAT primary face (gloss removed with the founder's
              // 2026-10-20 colour fix - the lighting gradient + top lip
              // read as a lighter glassy green instead of the brand
              // green; the ring below is the only overlay left)
              Positioned.fill(
                child: ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: face),
                  ),
                ),
              ),
              // the sparkle rides centered above the paint
              Center(
                child: AiSparkleIcon(size: 28, color: context.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
