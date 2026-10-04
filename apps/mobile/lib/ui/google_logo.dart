/// The official four-colour Google "G", drawn natively.
///
/// Drawn with a CustomPainter from the standard 48x48 brand geometry so the
/// auth screens show the real Google mark - no SVG dependency, no asset file,
/// no network fetch. Colours are Google's official brand palette:
/// blue #4285F4, green #34A853, yellow #FBBC05, red #EA4335.
library;

import 'package:flutter/material.dart';

/// The multicolour Google "G" logo at any size.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  /// Square edge length in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The brand geometry lives on a 48x48 grid; scale it to the widget.
    final double s = size.shortestSide / 48;

    Path path(List<PathCommand> commands) {
      final Path p = Path();
      for (final PathCommand c in commands) {
        switch (c) {
          case final MoveTo m:
            p.moveTo(m.x * s, m.y * s);
          case final LineTo l:
            p.lineTo(l.x * s, l.y * s);
          case final CubicTo cu:
            p.cubicTo(cu.x1 * s, cu.y1 * s, cu.x2 * s, cu.y2 * s, cu.x * s, cu.y * s);
          case CloseTo():
            p.close();
        }
      }
      return p;
    }

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Blue - the G crossbar and right stem.
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(path(const <PathCommand>[
      MoveTo(46.98, 24.55),
      CubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20),
      LineTo(24, 20),
      LineTo(24, 29.02),
      LineTo(36.94, 29.02),
      CubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2),
      LineTo(39.89, 42.2),
      CubicTo(44.4, 38.02, 46.98, 31.91, 46.98, 24.55),
      CloseTo(),
    ]), paint);

    // Green - the top arc of the G.
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(path(const <PathCommand>[
      MoveTo(24, 9.5),
      CubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1),
      LineTo(40.06, 6.25),
      CubicTo(35.9, 2.38, 30.47, 0, 24, 0),
      CubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22),
      LineTo(10.54, 19.41),
      CubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5),
      CloseTo(),
    ]), paint);

    // Yellow - the left stem of the G.
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(path(const <PathCommand>[
      MoveTo(10.53, 28.59),
      CubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24),
      CubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41),
      LineTo(2.55, 13.22),
      CubicTo(0.92, 16.46, 0, 20.12, 0, 24),
      CubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78),
      LineTo(10.53, 28.59),
      CloseTo(),
    ]), paint);

    // Red - the bottom arc of the G.
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(path(const <PathCommand>[
      MoveTo(24, 48),
      CubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19),
      LineTo(32.16, 36.19),
      CubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49),
      CubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58),
      LineTo(2.55, 34.77),
      CubicTo(6.51, 42.62, 14.62, 48, 24, 48),
      CloseTo(),
    ]), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sealed command set covering the subset of SVG path syntax the G uses.
sealed class PathCommand {
  const PathCommand();
}

final class MoveTo extends PathCommand {
  const MoveTo(this.x, this.y);
  final double x;
  final double y;
}

final class LineTo extends PathCommand {
  const LineTo(this.x, this.y);
  final double x;
  final double y;
}

final class CubicTo extends PathCommand {
  const CubicTo(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x;
  final double y;
}

final class CloseTo extends PathCommand {
  const CloseTo();
}
