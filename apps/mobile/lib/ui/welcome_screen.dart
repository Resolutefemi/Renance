/// The Duolingo-style welcome (founder pass VIII, the founder
/// screenshots): post-splash landing for logged-out NEW students -
/// the big keycap brand mark, the lowercase wordmark, the tagline and
/// two chunky doors: GET STARTED (register) and I ALREADY HAVE AN
/// ACCOUNT (login). Returning students (and every token-holding
/// device) keep the old straight-to-login cut; this screen marks the
/// intro flag the splash used to burn silently, so it shows exactly
/// once per device. Theme-aware like the splash: white ground in
/// light, black in dark, seed-aware keycap + accents everywhere.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../storage.dart';
import 'tactile.dart';
import 'theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// Marks the intro flag and pushes through the chosen door. The flag
  /// is marked on BOTH paths so this screen is a one-time cut per
  /// device (the splash's old no-op markIntroSeen moved here).
  Future<void> _enter(BuildContext context, String route) async {
    await context.read<SessionStore>().markIntroSeen();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    // The splash's ground rule: white in light, black in dark, with the
    // RenanceModeScope (mounted above every route) feeding the keycap
    // and accents the live seed.
    final RenanceThemeMode mode = context.renanceMode;
    final bool dark = mode == RenanceThemeMode.dark;
    final Color ground = dark ? Colors.black : Colors.white;
    final Color ink =
        dark ? RenanceColors.darkTextPrimary : RenanceColors.ink;
    final Color muted =
        dark ? RenanceColors.darkTextSecondary : RenanceColors.wolf;
    final Color brand = context.primary;

    return Scaffold(
      backgroundColor: ground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // The generous top air the founder's screenshots carry.
            const Spacer(flex: 3),
            // The big keycap brand mark - the same physics as the
            // splash's 3D R, reading the live seed.
            const RenanceKeycap(size: 112),
            const SizedBox(height: 24),
            Text(
              'renance',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: brand,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Learn. Practice. Rise.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'JAMB · WAEC · NECO · Post-UTME - your guide to academic '
                'success, free forever.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: muted,
                ),
              ),
            ),
            const Spacer(flex: 4),
            // The two doors: full-width, chunky, max 420px, centred -
            // the web hero-cta recipe through the tactile key system.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TactileButton(
                        onPressed: () => _enter(context, '/register'),
                        height: 56,
                        fontSize: 15.5,
                        child: const Text('GET STARTED'),
                      ),
                      const SizedBox(height: 14),
                      TactileButton(
                        onPressed: () => _enter(context, '/login'),
                        height: 56,
                        fontSize: 15.5,
                        // The white-key variant: card face, 2px brand
                        // border, brand label - the outlined door.
                        outline: brand,
                        onFace: brand,
                        child: const Text('I ALREADY HAVE AN ACCOUNT'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 28),
          ],
        ),
      ),
    );
  }
}
