import 'dart:math' as math;

import 'package:flutter/material.dart';

/// BlueTickIcon: the premium verified badge, X-style. The ONE splash of
/// colour a monochrome product allows - a paid subscriber's name carries
/// the tick on leaderboards, the arena and the profile.
class BlueTickIcon extends StatelessWidget {
  const BlueTickIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BlueTickPainter()),
    );
  }
}

class _BlueTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Paint blue = Paint()..color = const Color(0xFF1D9BF0);
    // The seal: an 8-point burst.
    const int points = 8;
    final double cx = s / 2, cy = s / 2;
    final double outer = s / 2;
    final double inner = s * 0.40;
    final Path seal = Path();
    for (int i = 0; i < points * 2; i++) {
      final double angle = (i * math.pi) / points;
      final double r = i.isEven ? outer : inner;
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        seal.moveTo(x, y);
      } else {
        seal.lineTo(x, y);
      }
    }
    seal.close();
    canvas.drawPath(seal, blue);

    // The white check.
    final Paint check = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = s * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final Path c = Path()
      ..moveTo(s * 0.28, cy + s * 0.02)
      ..lineTo(s * 0.43, cy + s * 0.17)
      ..lineTo(s * 0.73, cy - s * 0.15);
    canvas.drawPath(c, check);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
