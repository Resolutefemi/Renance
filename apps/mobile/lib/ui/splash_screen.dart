/// Splash, the Stitch splash_screen_light screen, 1:1.
///
/// Three orbiting rings (#D0E1FB 3s, ink 4s reverse, emerald 5s) chase
/// each other around the pulsing Renance mark; the wordmark sits below and
/// the LEARN. PRACTICE. RISE. tagline anchors the bottom. The route fires
/// as soon as a short brand beat has elapsed: no work is done here, so the
/// app reaches the home screen in well under a second on a warm start.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../storage.dart';
import 'renance_logo.dart';
import 'theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Minimum brand beat. Deliberately short: the splash is a signature, not
  /// a loading screen, and every real initialization happens after the
  /// first home frame (silent sync runs in the background).
  static const Duration _brandBeat = Duration(milliseconds: 650);

  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  Future<void> _decide() async {
    final Stopwatch elapsed = Stopwatch()..start();
    if (!mounted) return;
    final SessionStore session = context.read<SessionStore>();
    final bool hasToken = (session.token ?? '').isNotEmpty;
    final int remaining =
        _brandBeat.inMilliseconds - elapsed.elapsedMilliseconds;
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacementNamed(hasToken ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RenanceColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _OrbitRings(),
                    const SizedBox(height: 24),
                    const Text('Renance', style: RenanceText.displayLg),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Text(
                'LEARN. PRACTICE. RISE.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2 * 12,
                  color: RenanceColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three concentric arc rings from the Stitch splash, each spinning at
/// its own speed/direction, with the mark pulsing in the middle.
class _OrbitRings extends StatefulWidget {
  const _OrbitRings();

  @override
  State<_OrbitRings> createState() => _OrbitRingsState();
}

class _OrbitRingsState extends State<_OrbitRings>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> get _pulseView =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (BuildContext context, Widget? _) {
        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: const Size(96, 96),
                painter: _RingPainter(
                  t: _spin.value,
                  radius: 0.92,
                  color: const Color(0xFFD0E1FB),
                  strokeWidth: 1.5,
                  sweep: 80 / 200,
                  speed: 3 / 4,
                  reverse: false,
                ),
              ),
              CustomPaint(
                size: const Size(96, 96),
                painter: _RingPainter(
                  t: _spin.value,
                  radius: 0.76,
                  color: RenanceColors.ink,
                  strokeWidth: 1,
                  sweep: 60 / 200,
                  speed: 1,
                  reverse: true,
                ),
              ),
              CustomPaint(
                size: const Size(96, 96),
                painter: _RingPainter(
                  t: _spin.value,
                  radius: 0.60,
                  color: RenanceColors.emerald,
                  strokeWidth: 1.5,
                  sweep: 40 / 200,
                  speed: 4 / 5,
                  reverse: false,
                ),
              ),
              AnimatedBuilder(
                animation: _pulseView,
                builder: (_, __) => Transform.scale(
                  scale: 1 + 0.10 * _pulseView.value,
                  child: const RenanceMark(size: 48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One dashed arc on a circular orbit.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.t,
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.sweep,
    required this.speed,
    required this.reverse,
  });

  final double t;
  final double radius; // fraction of half the tile
  final Color color;
  final double strokeWidth;
  final double sweep; // radians fraction of a full turn
  final double speed; // rotations per controller cycle
  final bool reverse;

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = speed * (reverse ? -t : t);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect orbit = Rect.fromCircle(
      center: center,
      radius: radius * size.width / 2,
    );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Full circle track is invisible; only the moving arc paints.
    canvas.drawArc(orbit, phase * 2 * math.pi, sweep * 2 * math.pi, false,
        paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.t != t;
}
