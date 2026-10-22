/// Renance splash - the Supreme cut, the Flutter twin of the web's
/// loading screen (commit 5682eb87 "Supreme splash loading (3D R
/// keycap)").
///
/// Founder directive 2026-10-18: the old rainbow-dancing-letters cut
/// retires. The splash is now the website's own: the 3D R keycap floats
/// above the page with the "Renance" wordmark under it (the Duolingo
/// recipe), eight seconds, no skip. The keycap is painted by the same
/// physics as the web's inline SVG - face, extruded edge, glassy lip -
/// and reads the LIVE seed, so it follows the student's appearance
/// colour exactly like the website's favicon does. The ground follows
/// the appearance tier: white in light, black in dark.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../storage.dart';
import 'tactile.dart';
import 'theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Founder rule (2026-10-18): the splash holds its full eight seconds -
  // no skip pill, no early exit. The sequence is part of the brand.
  static const _hold = Duration(seconds: 8);

  // The float: the keycap rides a slow sine above the wordmark - the
  // Supreme splash motion (the web's renance-float).
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  // The entrance: keycap pops in, then the wordmark settles under it.
  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _markIn = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
  );

  late final Animation<double> _wordIn = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
  );

  Timer? _routeTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _routeTimer = Timer(_hold, _advance);
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _master.dispose();
    _float.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    final session = context.read<SessionStore>();
    final hasToken = (session.token ?? '').isNotEmpty;
    if (!hasToken) {
      // Founder pass VIII: a logged-out FIRST run meets the
      // Duolingo-style welcome instead of the bare login form. The old
      // code burned the introSeen flag right here without anything
      // ever rendering from it; now the flag gates the welcome and the
      // welcome's two doors mark it, so returning students keep the
      // straight-to-login cut.
      if (!session.introSeen) {
        Navigator.of(context).pushReplacementNamed('/welcome');
        return;
      }
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    session.markIntroSeen();
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
    // Founder directive (2026-10-18): the splash ground follows the
    // appearance setting - white in light, black in dark - and the
    // keycap + wordmark follow the live seed (the appearance-adaptive
    // favicon behaviour, brought to the launch screen).
    final mode = context.renanceMode;
    final bool dark = mode == RenanceThemeMode.dark;
    final Color ground = dark ? Colors.black : Colors.white;
    final Color onGround =
        dark ? RenanceColors.darkTextPrimary : RenanceColors.ink;
    final Color muted =
        dark ? RenanceColors.darkTextSecondary : RenanceColors.wolf;

    // The RenanceModeScope is mounted above every route (MaterialApp
    // builder), so the keycap reads the live seed + tier itself - the
    // appearance-adaptive favicon behaviour, brought to the launch
    // screen. Nothing to resolve here beyond the ground.

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: ground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The 3D keycap, floating (Supreme splash motion).
              AnimatedBuilder(
                animation: Listenable.merge([_float, _master]),
                builder: (context, child) {
                  final lift = _float.value;
                  return Transform.translate(
                    offset: Offset(0, -10 * lift),
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * _markIn.value,
                      child: Opacity(
                        opacity: _markIn.value.clamp(0, 1),
                        child: child,
                      ),
                    ),
                  );
                },
                child: const RenanceKeycap(size: 108),
              ),
              const SizedBox(height: 26),
              // The wordmark, Duolingo-style: bold rounded letters under
              // the mark, in the tier's ink (seed-aware like the web).
              FadeTransition(
                opacity: _wordIn,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_wordIn),
                  child: Text(
                    'Renance',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: onGround,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _wordIn,
                child: Text(
                  'Your Guide to Academic Success',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
