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
    // The seal: a 12-point burst approximated with a rotated star path.
    final Path seal = Path();
    const int points = 8;
    final double cx = s / 2, cy = s / 2;
    final double outer = s / 2;
    final double inner = s * 0.40;
    for (int i = 0; i < points * 2; i++) {
      final double angle = (i * 3.14159265) / points;
      final double r = i.isEven ? outer : inner;
      final double x = cx + r * _cos(angle);
      final double y = cy + r * _sin(angle);
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
      ..color = Color(0xFFFFFFFF)
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

double _cos(double x) => _sin(x + 3.1415926535 / 2);
double _sin(double x) {
  // Taylor is enough for 8 anchor points at this size.
  x = x % (2 * 3.14159265);
  double term = x, sum = x;
  for (int i = 1; i < 5; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    sum += term;
  }
  return sum;
}
