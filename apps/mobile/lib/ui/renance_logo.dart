/// The Renance logomark, the ONLY progress visual in the product.
/// Founder rule: standard circular progress indicators are replaced by a
/// custom animation of the logomark, pulsing and shifting opacities during
/// fetching/processing (Bybit-style brand transition).
///
/// The mark itself is the 3D FLAT keycap (founder 2026-10-18 parity
/// pass, the web's renance-mark-svg): solid brand face, extruded darker
/// bottom edge, glassy inner top highlight. It reads the LIVE seed so a
/// student's appearance colour re-tints it, exactly like the website's
/// favicon; dark containers keep the white cut (`onDark: true`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tactile.dart';
import 'theme.dart';

class RenanceMark extends StatefulWidget {
  const RenanceMark({
    super.key,
    this.size = 44,
    this.busy = false,
    this.onDark,
  });

  final double size;
  final bool busy;

  /// Set when the mark sits on a known container color so the white cut
  /// is used. Left null it resolves from the active Appearance tier, so
  /// dark pages automatically get the light mark.
  final bool? onDark;

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
    // Explicit wins; otherwise the tier decides (dark pages need the
    // white cut, light pages the ink mark).
    final bool onDarkSurface =
        widget.onDark ?? Theme.of(context).colorScheme.brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        final double amplitude = widget.busy ? 0.06 : 0.03;
        final double scale = 1 - amplitude * math.sin(t * 2 * math.pi);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (widget.busy)
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _OrbitPainter(t: t),
                ),
              Transform.scale(
                scale: scale,
                child: RenanceKeycap(
                  size: widget.size * 0.86,
                  // The white cut on dark surfaces keeps the old
                  // contract; otherwise the keycap reads the live seed
                  // (the web's appearance-adaptive mark).
                  face: onDarkSurface ? Colors.white : null,
                  onPrimary: onDarkSurface ? RenanceColors.mixedHero : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Three emerald orbit arcs chasing each other, opacity phase-shifted.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    const Color emerald = Color(0xFF00CD9C);
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
        ..color = emerald.withValues(alpha: opacity);
      canvas.drawArc(
          orbit, i * 2 * math.pi / 3 - math.pi / 2, 0.9, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => oldDelegate.t != t;
}

/// Mark + label row used wherever a spinner would have gone.
class LogoActivityIndicator extends StatelessWidget {
  const LogoActivityIndicator({
    super.key,
    this.label,
    this.size = 40,
    this.busy = true,
    this.onDark = false,
  });

  final String? label;
  final double size;
  final bool busy;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RenanceMark(size: size, busy: busy, onDark: onDark),
        if (label != null) ...<Widget>[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label!,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
