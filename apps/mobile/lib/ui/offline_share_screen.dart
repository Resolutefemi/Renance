/// Offline share, the Stitch offline_share_light screen, 1:1.
///
/// Send Pack / Receive cards, the nearby-phone radar (the R mark at the
/// center with sweeping rings) and the Devices Found sheet row.
///
/// The FILE slice of ROADMAP #16 is real: a downloaded pack is a sealed
/// questions-only bundle, so Send Pack writes it to a .renance-pack.json
/// file and hands it to the OS share sheet (Bluetooth, Xender, ShareIT,
/// Nearby, any offline pipe students already use), and Receive imports a
/// picked file through the same strict validation the API boot applies.
/// The radar and the peer sheet stay the Stitch design; a true
/// phone-to-phone channel is the later slice.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers.dart';
import '../models.dart';
import '../pack_share.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

class OfflineShareScreen extends StatefulWidget {
  const OfflineShareScreen({super.key});

  @override
  State<OfflineShareScreen> createState() => _OfflineShareScreenState();
}

class _OfflineShareScreenState extends State<OfflineShareScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      TactileBackKey(icon: 'arrow_back', onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 4),
                      const Text('Offline Share',
                          style: RenanceText.sectionTitle),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Share study packs without an internet connection.',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _ActionCard(
                          icon: 'arrow_upward',
                          label: 'Send Pack',
                          onTap: () => _sendFlow(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: 'arrow_downward',
                          label: 'Receive',
                          onTap: () => _receiveFlow(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // radar ------------------------------------------------------
                Expanded(
                  child: AnimatedBuilder(
                    animation: _radar,
                    builder: (BuildContext context, Widget? _) {
                      return CustomPaint(
                        size: Size.infinite,
                        painter: _RadarPainter(
                          t: _radar.value,
                          dotColor: context.ink,
                          // outline-light token - the fixed #EBEBEF rings
                          // vanished on the dark canvas.
                          ringColor: context.outlineLight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 84,
                                height: 84,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: context.card,
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                        color: Color(0x1A111C2D),
                                        blurRadius: 18,
                                        offset: Offset(0, 8)),
                                  ],
                                ),
                                child: Image.asset(
                                    // Tier-correct mark: the dark navy
                                    // modular R on the light card, the
                                    // white variant on the dark card -
                                    // the dark mark on darkCard is
                                    // invisible (night-bug fix
                                    // 2026-10-19).
                                    context.darkChrome
                                        ? 'assets/brand/renance_mark_white.png'
                                        : 'assets/brand/renance_mark.png'),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'Looking for nearby Renance phones...',
                                style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // devices sheet ---------------------------------------------
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: context.cardHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text('Devices Found',
                          style: RenanceText.sectionTitle),
                      SizedBox(height: 12),
                      Container(alignment: Alignment.center,
                        
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(alignment: Alignment.center,
                              
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: context.cardHigh,
                                shape: BoxShape.circle,
                              ),
                              child: MsIcon('smartphone',
                                  size: 22, color: context.ink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text("Alex's iPhone",
                                      style: RenanceText.bodyMedium),
                                  SizedBox(height: 2),
                                  Text('Ready to connect',
                                      style: RenanceText.caption.copyWith(color: context.textSecondary)),
                                ],
                              ),
                            ),
                            TactileButton(
                              height: 44,
                              radius: BorderRadius.circular(12),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              expand: false,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              onPressed: () => _snack(
                                  'Peer transfer ships in an upcoming release.'),
                              child: const Text('Connect'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ------------------------------------------------------- file slice (16)

  /// Send Pack: pick one of the packs on this phone, write it to a
  /// .renance-pack.json file and open the OS share sheet. The sheet is
  /// the transport; Bluetooth, Xender, ShareIT and Nearby all appear.
  Future<void> _sendFlow(BuildContext context) async {
    final StudentController student = context.read<StudentController>();
    final SyncController sync = context.read<SyncController>();
    final List<ExamMeta> onDevice = <ExamMeta>[
      for (final ExamMeta e in sync.exams)
        if (student.downloaded.contains(e.code)) e,
    ];
    if (onDevice.isEmpty) {
      _snack(
          'Download a pack in your Library first, then send it from here.');
      return;
    }
    final ExamMeta? picked = await showModalBottomSheet<ExamMeta>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Container(
        decoration: BoxDecoration(
          color: sheetContext.pageBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sheetContext.cardHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Send a pack', style: RenanceText.sectionTitle),
              const SizedBox(height: 4),
              Text(
                'They receive every question, offline, no data needed.',
                style: RenanceText.bodySecondary
                    .copyWith(color: sheetContext.textSecondary),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: onDevice.length,
                  itemBuilder: (BuildContext _, int i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(alignment: Alignment.center,
                      
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sheetContext.cardHigh,
                        shape: BoxShape.circle,
                      ),
                      child: MsIcon('folder',
                          size: 22, color: sheetContext.ink),
                    ),
                    title: Text(
                      student.titleForCode(onDevice[i].code),
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.bodyMedium,
                    ),
                    subtitle: Text(
                      '${onDevice[i].questionCount} questions',
                      style: RenanceText.caption
                          .copyWith(color: sheetContext.textSecondary),
                    ),
                    trailing: MsIcon('chevron_right',
                        size: 24, color: sheetContext.textSecondary),
                    onTap: () => Navigator.of(sheetContext).pop(onDevice[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    try {
      final Bundle? bundle =
          await student.store.loadPackByCode(picked.code);
      if (!mounted) return;
      if (bundle == null) {
        _snack( 'That pack is no longer on this device.');
        return;
      }
      final File file = File(
        '${Directory.systemTemp.path}/${sharedPackFileName(bundle)}',
      );
      await file.writeAsString(encodeSharedPack(bundle), flush: true);
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'Renance pack: ${bundle.title}',
        subject: bundle.title,
      );
    } on IOException {
      if (mounted) _snack( 'Could not write the pack file.');
    }
  }

  /// Receive: pick a shared pack file, run it through the strict
  /// validation, store it, refresh the Library badge.
  Future<void> _receiveFlow(BuildContext context) async {
    final StudentController student = context.read<StudentController>();
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(label: 'Renance pack', extensions: <String>['json']),
      ],
    );
    if (file == null || !mounted) return;

    try {
      final Bundle bundle = decodeSharedPack(await file.readAsString());
      await student.store.savePack(bundle, packSha(bundle));
      await student.refreshDownloaded();
      _snack('${bundle.title} imported. It is in your Library.');
    } on PackShareException catch (e) {
      _snack(e.message);
    } on FormatException {
      _snack('That file is not valid JSON.');
    } on FileSystemException {
      _snack('Could not store the pack on this device.');
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TactileCard(
      onTap: onTap,
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          Container(alignment: Alignment.center,
            
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.cardLow,
              shape: BoxShape.circle,
            ),
            child: MsIcon(icon, size: 26, color: context.ink),
          ),
          const SizedBox(height: 14),
          Text(label, style: RenanceText.bodyMedium.copyWith(fontSize: 17)),
        ],
      ),
    );
  }
}

/// Concentric rings + one orbiting ink dot (the design's dot, re-toned).
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t, required this.dotColor, required this.ringColor});

  final double t;
  final Color dotColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = ringColor;
    for (final double r in <double>[0.16, 0.30, 0.44]) {
      canvas.drawCircle(c, size.shortestSide * r, ring);
    }
    final double angle = t * 2 * math.pi;
    final double rr = size.shortestSide * 0.30;
    final Paint dot = Paint()..color = dotColor;
    canvas.drawCircle(
      c + Offset(math.cos(angle) * rr, math.sin(angle) * rr),
      7,
      dot,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.t != t;
}
