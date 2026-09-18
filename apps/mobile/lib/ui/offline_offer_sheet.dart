/// The offline offer — "Make Renance offline" (the founder's cut).
///
/// Shown once after signing up, and to any student who opens the app
/// with the shelf not fully on the device yet: one sheet that explains
/// the offline pack (every question pack for your exams, ~120 MB today)
/// and boots the real download through the SyncController — the same
/// bootstrap the shelf runs, with live progress and a dismiss that
/// never nags again.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../storage.dart';
import 'theme.dart';

/// The prefs key remembering the student answered the offer. One ask:
/// a dismissed offer never nags again (the Downloads screen stays the
/// always-available manual path).
const String kOfflineOfferSeen = 'offline_offer_seen_v1';

/// Whether the offer should surface right now: the student has not
/// answered it and the shelf is not fully on the device yet.
Future<bool> shouldOfferOffline(
  SessionStore session,
  StudentController student,
  SyncController sync,
) async {
  if (session.prefs.getBool(kOfflineOfferSeen) ?? false) return false;
  if (sync.exams.isEmpty) return false;
  return student.downloaded.length < sync.exams.length;
}

class OfflineOfferSheet extends StatelessWidget {
  const OfflineOfferSheet({super.key, required this.onDone});

  /// Called after the sheet closes either way (offer answered).
  final VoidCallback onDone;

  Future<void> _accept(BuildContext context) async {
    final SyncController sync = context.read<SyncController>();
    final SessionStore session = context.read<SessionStore>();
    await session.prefs.setBool(kOfflineOfferSeen, true);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    // The real download: every pack the student's exams need, live
    // progress on the shelf's sync card. Downloads continues in the
    // background even if the student navigates away.
    await sync.bootstrap(profileExams: <String>[]);
    onDone();
  }

  Future<void> _decline(BuildContext context) async {
    final SessionStore session = context.read<SessionStore>();
    await session.prefs.setBool(kOfflineOfferSeen, true);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.offline_bolt_rounded, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Make Renance offline',
                    style: RenanceText.sectionTitle.copyWith(fontSize: 19),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Download every question pack for your exams once — questions, '
              'answers and explanations — and Renance works with no data at '
              'all. The pack is about 120 MB today and updates in the '
              'background when you open the app on Wi-Fi.',
              style: RenanceText.bodyMedium.copyWith(
                color: Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can always manage or delete packs from Downloads.',
              style: RenanceText.bodyMedium.copyWith(
                color: Colors.black38,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decline(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _accept(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Download all',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
