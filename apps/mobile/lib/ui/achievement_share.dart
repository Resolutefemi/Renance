/// The feed achievement share offers (founder pass VIII): after a big
/// moment (exam headline, every 3 units of a course) the app OFFERS to
/// post the achievement to the feed - one beautiful popup, confetti on
/// open, a green Share key that runs POST /social/feed, and a Maybe
/// later that stays polite.
///
/// Nag doctrine (founder call): each offer asks ONCE. The milestone
/// marks itself done when the popup closes - after a successful share
/// or a clean dismiss - while a FAILED post leaves it unmarked so the
/// student can retry later. Everything network-side is guarded: a
/// share failure can never crash the caller's flow.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import 'celebrations.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

/// Offer to share an EXAM achievement. [dedupKey] is the caller's
/// milestone handle; the storage flag lives at
/// 'renance.shared.{dedupKey}' and is set on dismiss. A null key skips
/// the gate (the popup shows every time the caller asks).
Future<void> maybeOfferExamShare(
  BuildContext context, {
  required String headline,
  required String subtitle,
  required String postText,
  String? dedupKey,
}) {
  return _offer(
    context,
    icon: 'star',
    headline: headline,
    subtitle: subtitle,
    postText: postText,
    dedupStoreKey: dedupKey == null ? null : 'renance.shared.$dedupKey',
  );
}

/// Offer to share a UNIT milestone (every 3 fully-completed units of a
/// course). Gated at 'renance.unitShare.{courseId}.{unitCount}' so each
/// milestone asks exactly once.
Future<void> maybeOfferUnitShare(
  BuildContext context, {
  required String courseTitle,
  required int unitCount,
  required String courseId,
}) {
  return _offer(
    context,
    icon: 'emoji_events',
    headline: '$unitCount units done in $courseTitle!',
    subtitle: 'Tell the feed about it - your streak crew is watching.',
    postText: 'Just finished $unitCount units in $courseTitle on Renance - '
        'the grind continues on renance.app',
    dedupStoreKey: 'renance.unitShare.$courseId.$unitCount',
  );
}

/// The streak lengths that earn a feed-share offer (founder pass IX:
/// 'also streak like 7 days streak, 14 days streak, and more').
const List<int> kStreakShareMilestones = <int>[
  7, 14, 21, 30, 50, 100, 200, 365,
];

/// Offer to share a STREAK milestone - fires the moment the streak
/// lands exactly on one of [kStreakShareMilestones] (7, 14, 21, 30,
/// 50, 100, 200, 365 days), right after the streak celebration pops.
/// Gated at 'renance.streakShare.{n}' so each milestone asks once;
/// any other streak value returns silently.
Future<void> maybeOfferStreakShare(
  BuildContext context, {
  required int streak,
}) {
  if (!kStreakShareMilestones.contains(streak)) {
    return Future<void>.value();
  }
  return _offer(
    context,
    icon: 'local_fire_department',
    headline: '$streak-day streak!',
    subtitle:
        'Consistency builds mastery - your crew should see this one.',
    postText: 'Just hit a $streak-day streak on Renance 🔥 consistency '
        'builds mastery - renance.app',
    dedupStoreKey: 'renance.streakShare.$streak',
  );
}

/// The shared gate + popup plumbing. The dialog pops with true after a
/// successful share and false on a clean dismiss; either way the
/// milestone marks done. A network failure keeps the dialog open with
/// an inline error and marks nothing.
Future<void> _offer(
  BuildContext context, {
  required String icon,
  required String headline,
  required String subtitle,
  required String postText,
  required String? dedupStoreKey,
}) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (dedupStoreKey != null &&
        (prefs.getBool(dedupStoreKey) ?? false)) {
      return;
    }
    if (!context.mounted) return;
    final Object? closed = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AchievementShareDialog(
        icon: icon,
        headline: headline,
        subtitle: subtitle,
        postText: postText,
      ),
    );
    if (closed != null) {
      // Shared OR dismissed - the ask happened, mark the milestone.
      if (dedupStoreKey != null) {
        await prefs.setBool(dedupStoreKey, true);
      }
    }
    if ((closed == true) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted to the feed 🎉')),
      );
    }
  } catch (_) {
    // The offer is sugar, never a gate.
  }
}

class _AchievementShareDialog extends StatefulWidget {
  const _AchievementShareDialog({
    required this.icon,
    required this.headline,
    required this.subtitle,
    required this.postText,
  });

  final String icon;
  final String headline;
  final String subtitle;
  final String postText;

  @override
  State<_AchievementShareDialog> createState() =>
      _AchievementShareDialogState();
}

class _AchievementShareDialogState extends State<_AchievementShareDialog> {
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The celebration pattern: confetti bursts over the popup on open.
    // Post-frame so the OverlayEntry insert never lands mid-build (an
    // in-build insert throws markNeedsBuild-during-build and would
    // kill the share offer outright).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showConfetti(context);
    });
  }

  Future<void> _share() async {
    if (_posting) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.socialCreatePost(widget.postText);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = 'Could not post right now.';
      });
    }
  }

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
          border: Border.all(
            color: context.primary.withValues(alpha: 0.5),
            width: 2,
          ),
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
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MsIcon(
                  widget.icon,
                  size: 38,
                  color: context.primary,
                  fill: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TactileButton(
              onPressed: _posting ? null : _share,
              height: 46,
              fontSize: 14,
              child: Text(_posting ? 'Posting…' : 'Share to feed'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _posting ? null : () => Navigator.of(context).pop(false),
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
            if (_error != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
