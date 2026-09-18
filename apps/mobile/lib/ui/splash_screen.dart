/// Renance splash — the initialization loading screen, the Myschool cut.
///
/// Like the school app the founder asked us to mirror: one solid brand
/// ground (Myschool paints theirs red, Renance paints it BLACK — the
/// founder's first default), the wordmark sitting large in the middle,
/// the version stencilled at the bottom. RENANCE is written in WHITE
/// with a RAINBOW outline riding every letter — the rainbow slowly
/// sweeps around the stroke while the mark breathes, then the app
/// opens. Two cuts: the first open holds a beat longer than later
/// launches, and a skip pill surfaces after a moment either way.
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
  // First open holds the stage a beat longer than later launches (the
  // entrance animations only; the floor itself lasts twenty seconds).
  late final bool _firstRun = !context.read<SessionStore>().introSeen;
  late final Duration _showtime = _firstRun
      ? const Duration(milliseconds: 3400)
      : const Duration(milliseconds: 1800);

  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: _showtime,
  );

  // The rainbow stroke sweep + the gentle breathe, both infinite.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  Timer? _routeTimer;
  bool _leaving = false;
  bool _skipVisible = false;

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
    Timer(
      Duration(milliseconds: _firstRun ? 1200 : 700),
      () => mounted ? setState(() => _skipVisible = true) : null,
    );
    // The founder rule: the initialization page lasts UP TO twenty
    // seconds before automatically skipping. The entrance animations
    // finish in a few seconds, the wordmark keeps breathing after, and
    // the Skip pill is available the whole wait for anyone in a hurry.
    _routeTimer = Timer(const Duration(seconds: 20), _advance);
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _master.dispose();
    _sweep.dispose();
    _breathe.dispose();
    super.dispose();
  }

  void _advance() {
    if (_leaving || !mounted) return;
    _leaving = true;
    final session = context.read<SessionStore>();
    if (!session.introSeen) session.markIntroSeen();
    final hasToken = (session.token ?? '').isNotEmpty;
    Navigator.of(context).pushReplacementNamed(hasToken ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The mark: RENANCE in white, rainbow riding the stroke.
            Center(
              child: AnimatedBuilder(
                animation:
                    Listenable.merge(<Listenable>[_master, _sweep, _breathe]),
                builder: (_, __) {
                  final double breathe =
                      1 + 0.018 * math.sin(_breathe.value * math.pi);
                  return Opacity(
                    opacity: _markIn.value.clamp(0, 1),
                    child: Transform.scale(
                      scale: (0.92 + 0.08 * _markIn.value) * breathe,
                      child: RainbowWordmark(t: _sweep.value),
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
                      child: const Text(
                        '2.5.0 v',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Skip pill, pops after a beat.
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, bottom: 24),
                  child: AnimatedOpacity(
                    opacity: _skipVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: _skipVisible ? 1 : 0.7,
                      duration: const Duration(milliseconds: 400),
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
                              color: Colors.white.withValues(alpha: 0.08),
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
        ),
      ),
    );
  }
}

/// RENANCE — white letters with a rainbow outline, the Myschool-logo
/// treatment in Renance colours: the school app paints its wordmark
/// white-on-red, Renance paints it white-on-black with the full rainbow
/// riding the stroke. Each letter carries its own hue slice so the
/// spectrum reads left-to-right, and the highlight sweeps around the
/// stroke forever.
class RainbowWordmark extends StatelessWidget {
  const RainbowWordmark({super.key, this.fontSize = 40, required this.t});

  final double fontSize;

  /// The sweep phase (0..1), driven by the splash's infinite controller.
  final double t;

  static const String _word = 'RENANCE';
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < _word.length; i++)
          _RainbowLetter(
            ch: _word[i],
            hueBase: i / _word.length,
            fontSize: fontSize,
            t: t,
          ),
      ],
    );
  }
}

class _RainbowLetter extends StatelessWidget {
  const _RainbowLetter({
    required this.ch,
    required this.hueBase,
    required this.fontSize,
    required this.t,
  });

  final String ch;
  final double hueBase;
  final double fontSize;
  final double t;

  @override
  Widget build(BuildContext context) {
    // The stroke: a sweep-animated rainbow gradient clipped to the
    // letter's outline via ShaderMask; the white fill layer above paints
    // the body, so every letter reads WHITE with a rainbow edge.
    final double shift = (hueBase + t) % 1.0;
    return Stack(
      children: <Widget>[
        ShaderMask(
          shaderCallback: (Rect bounds) => LinearGradient(
            colors: <Color>[
              ...RainbowWordmark._rainbow,
              RainbowWordmark._rainbow[0],
              RainbowWordmark._rainbow[2],
              RainbowWordmark._rainbow[4],
              RainbowWordmark._rainbow[6],
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
            color: Colors.white,
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
