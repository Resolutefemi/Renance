/// The notification onboarding nag (founder pass VIII): every app open
/// until the student accepts notifications, the shell asks ONCE per
/// launch - first the quiet OS prompt, then this Renance-styled dialog
/// explaining WHY (the daily streak reminder). The founder directive is
/// explicit: NO prefs gate, the ask pops every open until accepted -
/// one nudge a day is the whole product promise and notifications are
/// how it lands. Everything downstream stays best-effort: a student who
/// never accepts simply never sees the reminders.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../notifications.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

/// Android-only gate called from the post-splash bootstrap: ensures the
/// permission, nags with the explanation dialog while it is still
/// denied, and then re-arms today's streak reminder in every path
/// (including the non-Android no-op, which just touches the reminder).
Future<void> ensureNotificationOnboarding(BuildContext context) async {
  if (!Platform.isAndroid) {
    await RenanceNotifications.dailyStreakTouch();
    return;
  }
  bool granted = await RenanceNotifications.isPermissionGranted();
  if (!granted) {
    // The quiet OS prompt first; the dialog is only for the "no".
    granted = await RenanceNotifications.ensurePermission();
    if (!granted && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _StreakNagDialog(),
      );
    }
  }
  await RenanceNotifications.dailyStreakTouch();
}

class _StreakNagDialog extends StatelessWidget {
  const _StreakNagDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.outlineVariant),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33111C2D),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.primary,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: mixTowardBlack(context.primary, 0.68),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const MsIcon(
                  'notifications_active',
                  size: 32,
                  color: Colors.white,
                  fill: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Never miss your streak',
              textAlign: TextAlign.center,
              style: RenanceText.sectionTitle.copyWith(
                fontSize: 19,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow notifications so Renance can remind you to keep your '
              'streak alive - one nudge a day, that\'s all.',
              textAlign: TextAlign.center,
              style: RenanceText.bodyBase.copyWith(
                fontSize: 13.5,
                height: 1.5,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TactileButton(
              onPressed: () async {
                await RenanceNotifications.ensurePermission();
                if (context.mounted) Navigator.of(context).pop();
              },
              height: 46,
              fontSize: 14,
              child: const Text('Allow notifications'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not now',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
