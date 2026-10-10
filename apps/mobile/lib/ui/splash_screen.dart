/// Renance splash - the initialization loading screen, the cinematic cut.
///
/// Founder directive (2026-10-11): NO skip button - the brand sequence
/// plays its full ten seconds on every launch. The wordmark DANCES:
/// each RENANCE letter rides its own sine wave (the "dancing letters"
/// the founder asked for), enters with a staggered elastic pop, and the
/// rainbow stroke keeps sweeping the outlines. Around the letters a
/// MAGIC layer runs the whole time - golden sparkle particles drift up
/// from the wordmark like dust, twinkle, and fade, plus periodic
/// shooting-star comets that streak across the stage - the kind of
/// boot animation the big phone companies run when their logo lands.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../controllers.dart';
import '../storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Founder directive (2026-10-11): the splash ALWAYS stays ten seconds
  // - no skip pill, no early exit. First open vs later open only
  // changes how long the entrance stagger takes, never the hold.
  late final bool _firstRun = !context.read<SessionStore>().introSeen;

  late final AnimationController _master = AnimationController(
    vsync: this,
    // The entrance stagger (letters popping in one by one) runs a beat
    // longer on the very first install; later launches snap in faster.
    duration: _firstRun
        ? const Duration(milliseconds: 3200)
        : const Duration(milliseconds: 1800),
  );

  // The rainbow stroke sweep - infinite, the original cut.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  // The dance: one infinite controller drives every letter's sine wave,
  // each letter phase-shifted so the word ripples like a wave.
  late final AnimationController _dance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  // The magic layer: particles drifting + twinkling, forever.
  late final AnimationController _magic = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  )..repeat();

  // Periodic comet bursts: every ~2.6s a shooting star crosses.
  late final AnimationController _comet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  Timer? _cometTimer;

  Timer? _routeTimer;
  bool _leaving = false;

  late final Animation<double> _markIn = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _versionIn = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _master.forward();
    // Founder rule (2026-10-11): the initialization page holds its full
    // ten seconds, then the app opens. There is no skip - the sequence
    // is part of the brand, the way the phone companies cut theirs.
    _routeTimer = Timer(const Duration(seconds: 10), _advance);
    _cometTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && !_comet.isAnimating) {
        _comet.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _cometTimer?.cancel();
    _master.dispose();
    _sweep.dispose();
    _dance.dispose();
    _magic.dispose();
    _comet.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    final session = context.read<SessionStore>();
    if (!session.introSeen) session.markIntroSeen();
    final hasToken = (session.token ?? '').isNotEmpty;
    if (!hasToken) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    // School staff land straight back in their workspace (syllabus,
    // scheme of work, notes) when the device remembers a school session.
    try {
      final prefs = session.prefs;
      final schoolSession = SchoolController.rememberedSession(prefs);
      if (schoolSession != null &&
          (schoolSession['schoolId'] ?? '').isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/school');
        return;
      }
    } catch (_) {
      // fall through to the student home
    }
    if (!mounted) return;
    // Confirmation is signup-only by doctrine: a returning student goes
    // straight to the desk whether the address is confirmed yet or not.
    // The mailed link from signup completes it whenever they get to it.
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Founder directive (2026-10-05): the splash is ALWAYS black - white
    // letters, rainbow stroke - no matter what appearance seed the
    // student picked. The seed re-tints every other surface; the
    // initialization page keeps the brand's first colour.
    const Color ground = Colors.black;
    const Color onGround = Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ground,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The magic dust: sparkle particles rising around the mark.
            AnimatedBuilder(
              animation: _magic,
              builder: (_, __) => CustomPaint(
                painter: _MagicDustPainter(t: _magic.value, seed: 7),
              ),
            ),

            // The comets: shooting stars that streak the stage.
            AnimatedBuilder(
              animation: _comet,
              builder: (_, __) => CustomPaint(
                painter: _CometPainter(t: _comet.value),
              ),
            ),

            // The mark: RENANCE in white, rainbow riding the stroke,
            // every letter dancing its own wave.
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    <Listenable>[_master, _sweep, _dance]),
                builder: (_, __) {
                  return Opacity(
                    opacity: _markIn.value.clamp(0, 1),
                    child: DancingWordmark(
                      entrance: _markIn.value,
                      danceT: _dance.value,
                      sweepT: _sweep.value,
                      onColor: onGround,
                    ),
                  );
                },
              ),
            ),

            // Version stencil, the Myschool "8.1.0 v" position.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: AnimatedBuilder(
                    animation: _versionIn,
                    builder: (_, __) => Opacity(
                      opacity: _versionIn.value.clamp(0, 1),
                      child: Text(
                        '$appVersion v',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: onGround,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// RENANCE - white letters with a rainbow outline, every letter
/// dancing: the entrance staggers letter by letter (elastic pop, the
/// stage-direction the founder wanted - "letters dancing"), then the
/// word rides a travelling sine wave forever while the rainbow sweep
/// keeps circling the strokes.
class DancingWordmark extends StatelessWidget {
  const DancingWordmark({
    super.key,
    this.fontSize = 40,
    required this.entrance,
    required this.danceT,
    required this.sweepT,
    this.onColor = Colors.white,
  });

  final double fontSize;

  /// 0..1 - the master entrance progress driving the stagger.
  final double entrance;

  /// 0..1 - the infinite dance phase.
  final double danceT;

  /// 0..1 - the rainbow sweep phase.
  final double sweepT;

  /// The letter-body colour - white on the splash's fixed black ground.
  final Color onColor;

  static const String _word = 'RENANCE';

  @override
  Widget build(BuildContext context) {
    final int n = _word.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < n; i++)
          _DancingLetter(
            ch: _word[i],
            hueBase: i / n,
            fontSize: fontSize,
            entrance: entrance,
            danceT: danceT,
            sweepT: sweepT,
            index: i,
            count: n,
            onColor: onColor,
          ),
      ],
    );
  }
}

class _DancingLetter extends StatelessWidget {
  const _DancingLetter({
    required this.ch,
    required this.hueBase,
    required this.fontSize,
    required this.entrance,
    required this.danceT,
    required this.sweepT,
    required this.index,
    required this.count,
    required this.onColor,
  });

  final String ch;
  final double hueBase;
  final double fontSize;
  final double entrance;
  final double danceT;
  final double sweepT;
  final int index;
  final int count;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    // Entrance: each letter pops in staggered - the wave sweeps
    // left-to-right, letter i starts its window at i/count.
    final double start = index / count;
    final double local = ((entrance - start) * count).clamp(0.0, 1.0);
    // Elastic overshoot: 1.25 -> settle 1.0 (the "dancing" pop).
    final double pop = _elasticOut(local);
    final double scale = (0.3 + 0.7 * pop).clamp(0.0, 1.4);
    final double entranceOffset = (1 - pop) * fontSize * 0.9;

    // The dance: a travelling sine wave through the word. Each letter
    // bobs up and down and leans a touch, phase-shifted by position so
    // the whole word ripples - letters dancing, not just blinking.
    final double phase = danceT * 2 * math.pi + (index * 0.85);
    final double bob = math.sin(phase) * fontSize * 0.075;
    final double lean = math.sin(phase + 0.6) * 0.045; // radians
    // A little per-letter squash-and-stretch sells the bounce.
    final double squash = 1 + math.sin(phase) * 0.03;

    return Transform.translate(
      offset: Offset(0, entranceOffset - bob),
      child: Transform.rotate(
        angle: lean,
        child: Transform.scale(
          scale: scale / squash,
          child: _RainbowLetter(
            ch: ch,
            hueBase: hueBase,
            fontSize: fontSize,
            t: sweepT,
            onColor: onColor,
          ),
        ),
      ),
    );
  }

  static double _elasticOut(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    final double c = (2 * math.pi) / 3;
    return math.pow(2, -9 * x) * math.sin((x * 9 - 0.75) * c) + 1;
  }
}

/// One letter: white body, rainbow outline clipped through a
/// ShaderMask, the highlight sweeping the stroke forever.
class _RainbowLetter extends StatelessWidget {
  const _RainbowLetter({
    required this.ch,
    required this.hueBase,
    required this.fontSize,
    required this.t,
    required this.onColor,
  });

  final String ch;
  final double hueBase;
  final double fontSize;
  final double t;
  final Color onColor;

  static const List<Color> _rainbow = <Color>[
    Color(0xFFFF5A5F), // red
    Color(0xFFFF9F43), // orange
    Color(0xFFFCD34D), // yellow
    Color(0xFF34D399), // green
    Color(0xFF38BDF8), // blue
    Color(0xFF818CF8), // indigo
    Color(0xFFC084FC), // violet
  ];

  @override
  Widget build(BuildContext context) {
    final double shift = (hueBase + t) % 1.0;
    return Stack(
      children: <Widget>[
        ShaderMask(
          shaderCallback: (Rect bounds) => LinearGradient(
            colors: <Color>[
              ..._rainbow,
              _rainbow[0],
              _rainbow[2],
              _rainbow[4],
              _rainbow[6],
            ],
            transform: _SweepGradientTransform(shift),
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            ch,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              height: 1.1,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5.0
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white,
            ),
          ),
        ),
        Text(
          ch,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            height: 1.1,
            color: onColor,
          ),
        ),
      ],
    );
  }
}

/// Slides the gradient by [shift] so the rainbow sweeps.
class _SweepGradientTransform extends GradientTransform {
  const _SweepGradientTransform(this.shift);
  final double shift;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * shift, 0, 0);
  }
}

/// The magic layer: golden sparkle dust rising from the wordmark,
/// twinkling as it climbs, plus a soft ambient glow that breathes
/// behind the letters - the "magic effect" of a phone-company boot.
class _MagicDustPainter extends CustomPainter {
  _MagicDustPainter({required this.t, required this.seed});

  /// 0..1 - the infinite loop phase.
  final double t;
  final int seed;

  static const List<Color> _gold = <Color>[
    Color(0xFFFFD700),
    Color(0xFFFCD34D),
    Color(0xFFFFF3C4),
    Color(0xFF38BDF8),
    Color(0xFFC084FC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random rng = math.Random(seed);
    final Paint paint = Paint()..isAntiAlias = true;

    // Ambient glow behind the mark: a huge soft radial that breathes
    // with the loop (opacity 0.04..0.09) - the stage light.
    final double glowAlpha = 0.05 + 0.035 * math.sin(t * 2 * math.pi);
    paint.color = const Color(0xFF818CF8).withValues(alpha: glowAlpha);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.38 * (1 + 0.03 * math.sin(t * 2 * math.pi)),
      Paint()
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    );

    // The dust: 42 particles, each with its own random birth position
    // around the wordmark band, speed, twinkle phase and colour. The
    // loop wraps them - a particle that floats off the top is reborn
    // at the bottom.
    const int n = 42;
    for (int i = 0; i < n; i++) {
      final double rx = rng.nextDouble();
      final double speed = 0.10 + rng.nextDouble() * 0.22; // loops/min
      final double drift = (rng.nextDouble() - 0.5) * 0.14;
      final double twinklePhase = rng.nextDouble() * 2 * math.pi;
      final double baseSize = 1.2 + rng.nextDouble() * 2.4;

      // Particle's own loop progress.
      final double p = (t * (1 + speed * 3) + rx) % 1.0;
      // Rises from the wordmark band upward.
      final double bandTop = size.height * 0.40;
      final double bandH = size.height * 0.16;
      final double y = bandTop + bandH - p * bandH * 2.6;
      final double x =
          size.width * (0.14 + 0.72 * rx) + drift * size.width * p;

      // Only the particles near the stage width show.
      if (x < 0 || x > size.width) continue;

      // Twinkle: alpha pulses twice per loop, fade in at birth and out
      // at the top.
      final double twinkle =
          0.5 + 0.5 * math.sin(t * 4 * math.pi + twinklePhase);
      final double edgeFade = math.sin(p * math.pi);
      final double alpha = 0.85 * twinkle * edgeFade;
      if (alpha < 0.02) continue;

      // Four-point star sparkle for the bigger grains, dots for the rest.
      final Color c = _gold[i % _gold.length];
      paint.color = c.withValues(alpha: alpha);
      if (baseSize > 2.2) {
        _drawSparkle(
            canvas, paint, Offset(x, y), baseSize * (0.8 + 0.4 * twinkle));
      } else {
        canvas.drawCircle(Offset(x, y), baseSize * 0.5, paint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Paint paint, Offset c, double r) {
    final Path path = Path();
    final double k = r * 0.22;
    path
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MagicDustPainter oldDelegate) => oldDelegate.t != t;
}

/// The comets: a shooting star that streaks diagonally across the
/// stage with a fading tail - fires every few seconds while the splash
/// holds. The head is a warm white point; the tail is a gradient streak.
class _CometPainter extends CustomPainter {
  _CometPainter({required this.t});

  /// 0..1 - 0 before launch, climbs while flying.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final double ease = Curves.easeInQuad.transform(t);

    // The flight path: enters top-left-ish, exits bottom-right-ish,
    // skewed to cross behind the wordmark without covering it.
    final Offset start = Offset(-size.width * 0.10, size.height * 0.22);
    final Offset end = Offset(size.width * 1.10, size.height * 0.60);
    final Offset head = Offset.lerp(start, end, ease)!;

    // The tail: a streak back along the path.
    final Offset tailDelta = (end - start) * 0.16 * (1 - ease * 0.4);
    final Offset tail = head - tailDelta;

    final Paint tailPaint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: <Color>[
          const Color(0xFFFFFFFF).withValues(alpha: 0.75 * (1 - ease)),
          const Color(0xFF9BB8FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromPoints(head, tail))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    canvas.drawLine(head, tail, tailPaint);

    // The head: a bright core with a glow halo.
    final double headAlpha = (1 - ease * 0.9).clamp(0.0, 1.0);
    canvas.drawCircle(
      head,
      7,
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.28 * headAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      head,
      2.1,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: headAlpha),
    );

    // A few sparks shed off the head.
    final math.Random rng = math.Random(3);
    for (int i = 0; i < 5; i++) {
      final double sp = rng.nextDouble();
      final Offset jitter = Offset(
        (rng.nextDouble() - 0.5) * 18,
        (rng.nextDouble() - 0.5) * 10 + 6 * (1 - sp),
      );
      canvas.drawCircle(
        head - tailDelta * (0.3 + sp) + jitter,
        0.8 + rng.nextDouble() * 1.2,
        Paint()
          ..isAntiAlias = true
          ..color = const Color(0xFFFCD34D)
              .withValues(alpha: 0.5 * headAlpha * (1 - sp)),
      );
    }
  }

  @override
  bool shouldRepaint(_CometPainter oldDelegate) => oldDelegate.t != t;
}
