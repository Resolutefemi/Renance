/// Renance splash — the cinematic brand opening, "Your Guide to Academic
/// Success" edition.
///
/// Two cuts of one timeline:
///  * FIRST OPEN  (introSeen == false): the full sequence — ink canvas
///    blooms, aurora glows drift, particles burst, three orbit rings
///    converge while the mark lands with an elastic overshoot, the
///    wordmark cascades letter-by-letter, the tagline fades up with a
///    tracking tween, and the LEARN · PRACTICE · RISE chips pop in.
///  * SECOND OPEN (introSeen == true): the snappy cut — the same beats
///    compressed to ~2.2 s, no particle field, straight to business.
///
/// A glass SKIP pill surfaces after a beat (2.5 s first run, 1.4 s after)
/// and jumps straight to the route decision. Nothing here is scrollable:
/// one fixed full-bleed LayoutBuilder canvas, exactly like a native
/// launch screen.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ---- master timeline --------------------------------------------------
  // First run: 5.4 s showtime. Second run: 2.3 s.
  late final bool _firstRun = !context.read<SessionStore>().introSeen;
  late final Duration _showtime = _firstRun
      ? const Duration(milliseconds: 5400)
      : const Duration(milliseconds: 2300);

  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: _showtime,
  );

  // infinite ambience
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  Timer? _routeTimer;
  bool _leaving = false;
  bool _skipVisible = false;

  // ---- staggered intervals ----------------------------------------------
  // [first run, second run] share the same fractions of their own clock.
  CurvedAnimation _anim(double from, double to,
          {Curve curve = Curves.easeOutCubic}) =>
      CurvedAnimation(parent: _master, curve: Interval(from, to, curve: curve));

  late final Animation<double> _glow = Tween(begin: 0.0, end: 1.0)
      .animate(_anim(0.00, _firstRun ? 0.22 : 0.30, curve: Curves.easeOut));

  late final Animation<double> _ringsIn = Tween(begin: 1.9, end: 1.0).animate(
    _anim(_firstRun ? 0.10 : 0.06, _firstRun ? 0.46 : 0.42,
        curve: Curves.easeOutBack),
  );

  late final Animation<double> _markIn = Tween(begin: 0.0, end: 1.0).animate(
    _anim(_firstRun ? 0.26 : 0.20, _firstRun ? 0.58 : 0.55,
        curve: Curves.elasticOut),
  );

  late final Animation<double> _glowPuff = Tween(begin: 0.6, end: 1.6).animate(
    _anim(_firstRun ? 0.26 : 0.20, _firstRun ? 0.62 : 0.60,
        curve: Curves.easeOut),
  );

  late final Animation<double> _wordmark = Tween(begin: 0.0, end: 1.0).animate(
    _anim(_firstRun ? 0.40 : 0.34, _firstRun ? 0.68 : 0.70,
        curve: Curves.easeOutCubic),
  );

  late final Animation<double> _tagline = Tween(begin: 0.0, end: 1.0).animate(
    _anim(_firstRun ? 0.58 : 0.62, _firstRun ? 0.84 : 0.88,
        curve: Curves.easeOutCubic),
  );

  late final Animation<double> _chips = Tween(begin: 0.0, end: 1.0).animate(
    _anim(_firstRun ? 0.66 : 0.72, _firstRun ? 0.92 : 0.97,
        curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _master.forward();
    // Skip appears "after some time", as the founder asked: 2.5 s on the
    // full cut, 1.4 s on the snappy one.
    Timer(Duration(milliseconds: _firstRun ? 2500 : 1400), () {
      if (mounted) setState(() => _skipVisible = true);
    });
    _routeTimer =
        Timer(_showtime + const Duration(milliseconds: 350), _advance);
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _master.dispose();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _advance() {
    if (_leaving || !mounted) return;
    _leaving = true;
    final session = context.read<SessionStore>();
    // Remember the cinematic played; next launch takes the snappy cut.
    if (!session.introSeen) unawaited(session.markIntroSeen());
    final hasToken = (session.token ?? '').isNotEmpty;
    Navigator.of(context).pushReplacementNamed(hasToken ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C1424), // ink-deep brand canvas
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Size size = c.biggest;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // aurora glows, always drifting
                AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_glow, _spin]),
                  builder: (_, __) => CustomPaint(
                    painter: _AuroraPainter(
                      intensity: _glow.value,
                      t: _spin.value,
                      size: size,
                    ),
                  ),
                ),

                // particle burst (first run only)
                if (_firstRun)
                  AnimatedBuilder(
                    animation: _master,
                    builder: (_, __) => CustomPaint(
                      painter: _ParticlePainter(t: _master.value, size: size),
                    ),
                  ),

                // the stage
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // rings + mark
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            <Listenable>[_master, _spin, _pulse]),
                        builder: (_, __) {
                          final double breathe = _markIn.value >= 1
                              ? 1 + 0.05 * _pulse.value
                              : 1.0;
                          return SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                Transform.scale(
                                  scale: _ringsIn.value,
                                  child: const _ConvergingRings(),
                                ),
                                // landing glow puff
                                Transform.scale(
                                  scale: _glowPuff.value,
                                  child: Opacity(
                                    opacity: (0.55 * _markIn.value).clamp(0, 1),
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: <Color>[
                                            const Color(0xFF60A5FA)
                                                .withValues(alpha: 0.35),
                                            const Color(0xFF34D399)
                                                .withValues(alpha: 0.12),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // the mark itself
                                if (_markIn.value > 0)
                                  Opacity(
                                    opacity: _markIn.value.clamp(0, 1),
                                    child: Transform.scale(
                                      scale:
                                          (0.4 + 0.6 * _markIn.value) * breathe,
                                      child: Image.asset(
                                        'assets/brand/renance_mark_white.png',
                                        width: 96,
                                        height: 96,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // cascading wordmark
                      AnimatedBuilder(
                        animation: _master,
                        builder: (_, __) => Opacity(
                          opacity: _wordmark.value.clamp(0, 1),
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - _wordmark.value)),
                            child: const _CascadingWordmark(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // tagline with tracking tween
                      AnimatedBuilder(
                        animation: _tagline,
                        builder: (_, __) => Opacity(
                          opacity: _tagline.value.clamp(0, 1),
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - _tagline.value)),
                            child: Text(
                              'Your Guide to Academic Success',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing:
                                    0.02 + 0.06 * (1 - _tagline.value),
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // bottom chips + skip
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedBuilder(
                            animation: _chips,
                            builder: (_, __) => Opacity(
                              opacity: _chips.value.clamp(0, 1),
                              child: Transform.scale(
                                scale: 0.85 + 0.15 * _chips.value,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    _Chip('LEARN', const Color(0xFF60A5FA)),
                                    const SizedBox(width: 8),
                                    _Chip('PRACTICE', const Color(0xFF34D399)),
                                    const SizedBox(width: 8),
                                    _Chip('RISE', const Color(0xFFF59E0B)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // skip pill, pops after a beat
                Align(
                  alignment: Alignment.bottomRight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, bottom: 24),
                      child: AnimatedOpacity(
                        opacity: _skipVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: _skipVisible ? 1 : 0.7,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutBack,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _advance,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Skip',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded,
                                        size: 15, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// converging orbit rings
// ---------------------------------------------------------------------------

class _ConvergingRings extends StatefulWidget {
  const _ConvergingRings();
  @override
  State<_ConvergingRings> createState() => _ConvergingRingsState();
}

class _ConvergingRingsState extends State<_ConvergingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 7000))
    ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, __) => CustomPaint(
        size: const Size(200, 200),
        painter: _RingPainter(t: _spin.value),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.t});
  final double t;

  static const List<
      ({
        double radius,
        Color color,
        double width,
        double sweep,
        double speed,
        bool reverse
      })> _rings = <({
    double radius,
    Color color,
    double width,
    double sweep,
    double speed,
    bool reverse
  })>[
    (
      radius: 0.92,
      color: Color(0xFF60A5FA),
      width: 2.0,
      sweep: 0.34,
      speed: 1.0,
      reverse: false,
    ),
    (
      radius: 0.74,
      color: Color(0xFFF0F3FF),
      width: 1.2,
      sweep: 0.22,
      speed: 1.0,
      reverse: true,
    ),
    (
      radius: 0.56,
      color: Color(0xFF34D399),
      width: 2.0,
      sweep: 0.26,
      speed: 1.0,
      reverse: false,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < _rings.length; i++) {
      final ring = _rings[i];
      final double phase = ring.speed * (ring.reverse ? -t : t) + i * 0.33;
      final Rect orbit = Rect.fromCircle(
        center: center,
        radius: ring.radius * size.width / 2,
      );
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.width
        ..strokeCap = StrokeCap.round
        ..color = ring.color.withValues(alpha: 0.75);
      canvas.drawArc(
          orbit, phase * 2 * math.pi, ring.sweep * 2 * math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// aurora backdrop
// ---------------------------------------------------------------------------

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.intensity,
    required this.t,
    required this.size,
  });
  final double intensity;
  final double t;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (intensity <= 0.01) return;
    final double w = canvasSize.width;
    final double h = canvasSize.height;
    final double drift = math.sin(t * 2 * math.pi) * 0.06;

    void blob(Offset c, double r, Color color) {
      final Rect rect = Rect.fromCircle(center: c, radius: r);
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ).createShader(rect)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(c, r, paint);
    }

    blob(
      Offset(w * (0.18 + drift), h * (0.16 + drift * 0.5)),
      math.min(w, h) * 0.55,
      const Color(0xFF2563EB).withValues(alpha: 0.30 * intensity),
    );
    blob(
      Offset(w * (0.88 - drift), h * (0.24 - drift * 0.4)),
      math.min(w, h) * 0.48,
      const Color(0xFF0D9488).withValues(alpha: 0.26 * intensity),
    );
    blob(
      Offset(w * (0.5 + drift * 0.6), h * 0.52),
      math.min(w, h) * 0.62,
      const Color(0xFF4F46E5).withValues(alpha: 0.20 * intensity),
    );
    blob(
      Offset(w * 0.5, h * 0.46),
      math.min(w, h) * 0.30,
      const Color(0xFF60A5FA).withValues(alpha: 0.14 * intensity),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.intensity != intensity ||
      oldDelegate.size != size;
}

// ---------------------------------------------------------------------------
// particle burst — one-shot on the first-run cut
// ---------------------------------------------------------------------------

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.t, required this.size});
  final double t;
  final Size size;

  static const int _count = 26;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (t <= 0 || t >= 1) return;
    final Offset center =
        Offset(canvasSize.width / 2, canvasSize.height / 2 - 40);
    // The burst fires as the mark lands (~0.45 of the timeline) and is done
    // by ~0.95; progress inside that window drives radius + fade.
    final double p = ((t - 0.42) / 0.5).clamp(0.0, 1.0);
    if (p <= 0) return;

    final Paint paint = Paint();
    final math.Random rng = math.Random(7); // deterministic burst
    for (int i = 0; i < _count; i++) {
      final double angle = (i / _count) * 2 * math.pi + rng.nextDouble() * 0.4;
      final double dist =
          (40 + rng.nextDouble() * 130) * Curves.easeOut.transform(p);
      final double r = 1.0 + rng.nextDouble() * 2.2;
      final double fade = (1 - p) * 0.8;
      final List<Color> palette = <Color>[
        const Color(0xFF60A5FA),
        const Color(0xFF34D399),
        const Color(0xFFF59E0B),
        const Color(0xFFF0F3FF),
      ];
      paint.color = palette[i % palette.length].withValues(alpha: fade);
      canvas.drawCircle(
        center + Offset(math.cos(angle) * dist, math.sin(angle) * dist),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// cascading wordmark — R E N A N C E lands letter by letter
// ---------------------------------------------------------------------------

class _CascadingWordmark extends StatelessWidget {
  const _CascadingWordmark();

  @override
  Widget build(BuildContext context) {
    const String word = 'RENANCE';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < word.length; i++) _Letter(ch: word[i], index: i),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.ch, required this.index});
  final String ch;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 55),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double v, Widget? child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
        ),
      ),
      child: Text(
        ch,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 6,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LEARN · PRACTICE · RISE glass chips
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
