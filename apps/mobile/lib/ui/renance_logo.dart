/// The Renance logomark — the ONLY progress visual in the product.
/// Founder rule: standard circular progress indicators are replaced by a
/// custom vectorized animation of the logomark, pulsing and shifting
/// opacities during fetching/processing (Bybit-style brand transition).
///
/// Drawn natively with CustomPainter so it stays crisp on every density.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class RenanceMark extends StatefulWidget {
  const RenanceMark({super.key, this.size = 44, this.busy = false});

  final double size;
  final bool busy;

  @override
  State<RenanceMark> createState() => _RenanceMarkState();
}

class _RenanceMarkState extends State<RenanceMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        final double amplitude = widget.busy ? 0.06 : 0.03;
        final double scale = 1 - amplitude * math.sin(t * 2 * math.pi);
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _MarkPainter(t: t, busy: widget.busy),
          ),
        );
      },
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.t, required this.busy});

  final double t;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);

    if (busy) {
      // three orbit arcs chasing each other, opacity phase-shifted
      final Rect orbit = Rect.fromCircle(
        center: const Offset(32, 32),
        radius: 30,
      );
      for (var i = 0; i < 3; i++) {
        final double phase = (t - i / 3.0) % 1.0;
        final double opacity = 0.15 + 0.85 * math.sin(phase * 2 * math.pi).abs();
        final Paint arcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = RenanceColors.emerald.withValues(alpha: opacity);
        canvas.drawArc(orbit, i * 2 * math.pi / 3 - math.pi / 2, 0.9, false, arcPaint);
      }
    }

    // gradient tile
    final Rect tile = Rect.fromLTWH(2, 2, 60, 60);
    final Paint tilePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF8B5CF6), Color(0xFF10B981)],
      ).createShader(tile);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile, const Radius.circular(16)),
      tilePaint,
    );

    // the R (matches the web SVG geometry: M22 47 V17 H34 a9.5 0 0 1 0 19 H22 M35 36 L47 47)
    final Path rPath = Path()
      ..moveTo(22, 47)
      ..lineTo(22, 17)
      ..lineTo(34, 17)
      ..arcToPoint(
        const Offset(34, 36),
        radius: const Radius.circular(9.5),
        clockwise: true,
      )
      ..lineTo(22, 36);
    final Path legPath = Path()
      ..moveTo(35, 36)
      ..lineTo(47, 47);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    canvas.drawPath(rPath, stroke);
    canvas.drawPath(legPath, stroke);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.busy != busy;
}

/// Mark + label row used wherever a spinner would have gone.
class LogoActivityIndicator extends StatelessWidget {
  const LogoActivityIndicator({
    super.key,
    this.label,
    this.size = 40,
    this.busy = true,
  });

  final String? label;
  final double size;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RenanceMark(size: size, busy: busy),
        if (label != null) ...<Widget>[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label!,
              style: const TextStyle(
                color: RenanceColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
