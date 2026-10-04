import 'package:flutter/material.dart';

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

/// The floating Renance AI entry (founder directive): the theme-colour
/// circle with the contrasting sparkle, bottom-right of the HOME tab
/// only. Used by the student launcher and the tertiary (university)
/// home. Founder directive (2026-10-02): the old ink circle follows the
/// seed - black in stock light, the student's colour when one is live.
class AiFloatingButton extends StatelessWidget {
  const AiFloatingButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.primary,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: const Color(0x42141C2D),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Center(
            child: AiSparkleIcon(size: 27, color: context.onPrimary),
          ),
        ),
      ),
    );
  }
}
