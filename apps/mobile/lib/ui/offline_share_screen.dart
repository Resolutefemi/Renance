/// Offline share, the Stitch offline_share_light screen, 1:1.
///
/// Send Pack / Receive cards, the nearby-phone radar (the R mark at the
/// center with sweeping rings) and the Devices Found sheet row. Static
/// friendly: discovery is simulated locally, Connect shows a snackbar
/// until the peer channel ships.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon:
                            const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: context.ink,
                      ),
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
                          icon: Icons.arrow_upward,
                          label: 'Send Pack',
                          onTap: () => _snack(context,
                              'Pick a pack to send when a device connects.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.arrow_downward,
                          label: 'Receive',
                          onTap: () => _snack(context,
                              'Stay on this screen to receive a pack.'),
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
                        painter: _RadarPainter(t: _radar.value, dotColor: context.ink),
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
                                    'assets/brand/renance_mark.png'),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: context.cardHigh,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.smartphone_outlined,
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
                            SizedBox(
                              height: 44,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  // The theme's minimum width is infinite
                                  // (full-width buttons); this Row measures
                                  // children unbounded, so pin a real min.
                                  minimumSize: const Size(96, 44),
                                ),
                                onPressed: () => _snack(context,
                                    'Peer transfer ships in an upcoming release.'),
                                child: const Text('Connect',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
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

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x14141C2D), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.cardLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: context.ink),
            ),
            const SizedBox(height: 14),
            Text(label, style: RenanceText.bodyMedium.copyWith(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}

/// Concentric rings + one orbiting ink dot (the design's dot, re-toned).
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t, required this.dotColor});

  final double t;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFD8E3FB);
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
