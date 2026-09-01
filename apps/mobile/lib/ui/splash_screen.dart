/// Splash: brand animation while the session is inspected, then route.
library;

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
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), _decide);
  }

  Future<void> _decide() async {
    if (!mounted) return;
    final SessionStore session = context.read<SessionStore>();
    final bool hasToken = (session.token ?? '').isNotEmpty;
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacementNamed(hasToken ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const RenanceMark(size: 84, busy: true),
            const SizedBox(height: 20),
            const Text(
              'Renance',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: RenanceColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'the global student study OS',
              style: TextStyle(
                color: RenanceColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
