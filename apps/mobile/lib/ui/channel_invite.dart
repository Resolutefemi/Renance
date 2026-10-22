/// The WhatsApp channel invite (founder pass VIII): a beautiful bottom
/// sheet that asks the student to join the official Renance WhatsApp
/// channel - new features, study packs and exam tips straight to their
/// WhatsApp.
///
/// Founder pass IX directive: the invite pops on EVERY app open until
/// the student actually taps Join - deferring (Maybe later, a drag, a
/// tap outside) is not a no, so the ask comes back next launch. Only
/// the joined flag (set when the channel link opens) retires it. The
/// sheet matches the app's 3D FLAT style (icon bubble on the seed
/// primary, extruded green key).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

/// The official WhatsApp channel (founder pass VIII).
const String kRenanceChannelUrl =
    'https://whatsapp.com/channel/0029VbDnzhVKAwEltcgbOZ3K';

const String _kJoined = 'renance.channel.joined';

/// Pops the invite on EVERY app open until the student joins (founder
/// pass IX: 'always pop up if the user doesn't click join'). Only the
/// joined flag - stamped when the WhatsApp link actually opens -
/// retires it. Safe to call on every launch; every failure is
/// swallowed - a prefs hiccup must not gate the app.
Future<void> maybeShowChannelInvite(BuildContext context) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kJoined) ?? false) return;
    if (!context.mounted) return;
    // Retire the old throttle stamp if a previous release left one.
    await prefs.remove('renance.channel.lastAsk');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChannelInviteSheet(),
    );
  } catch (_) {
    // The invite is sugar, never a gate.
  }
}

class _ChannelInviteSheet extends StatelessWidget {
  const _ChannelInviteSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
      ),
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
                // WhatsApp green - the one brand accent allowed to keep
                // its own colour here, because the destination IS it.
                color: const Color(0xFF25D366),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: mixTowardBlack(const Color(0xFF25D366), 0.68),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const MsIcon(
                'forum',
                size: 32,
                color: Colors.white,
                fill: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join our WhatsApp channel',
            textAlign: TextAlign.center,
            style: RenanceText.sectionTitle.copyWith(
              fontSize: 19,
              color: context.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay tuned for new features, study packs and exam tips - '
            'straight to your WhatsApp.',
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
              try {
                await launchUrl(
                  Uri.parse(kRenanceChannelUrl),
                  mode: LaunchMode.externalApplication,
                );
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                await prefs.setBool(_kJoined, true);
              } catch (_) {
                // A failed launch leaves the gate unmarked - the invite
                // simply comes back on the next open.
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            height: 46,
            fontSize: 14,
            child: const Text('Join the channel'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Maybe later',
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
    );
  }
}
