/// Certificate wallet, the Stitch certificate_wallet_light screen.
///
/// The featured card is derived from the scholar's real level and name;
/// the archive grid is the milestone catalogue (static until the exam
/// board ships verified credentials, per the founder: static is fine).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import 'theme.dart';

class CertificateWalletScreen extends StatelessWidget {
  const CertificateWalletScreen({super.key});

  String _certId(String uid, int level) {
    final src = uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    String take(int from, int n) {
      final s = src.length <= from
          ? 'RNC'
          : src.substring(from, (from + n).clamp(0, src.length));
      return s.padRight(n, 'X');
    }

    return 'RNC-${take(0, 3)}-${take(3, 3)}-L$level';
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final String name =
        student.me?.profile?.fullName.isNotEmpty == true
            ? student.me!.profile!.fullName
            : (student.me?.user.username ?? 'Renance scholar');
    final int level = student.gamification?.state.level ?? 1;
    final String uid = student.me?.user.id ?? '';
    final String id = _certId(uid, level);
    final DateTime now = DateTime.now();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String date =
        '${months[now.month - 1]} ${now.day}, ${now.year}';

    return Scaffold(
      backgroundColor: RenanceColors.background,
      appBar: AppBar(
        backgroundColor: RenanceColors.background,
        elevation: 0,
        title: Text('Digital Wallet',
            style: RenanceText.sectionTitle.copyWith(fontSize: 18)),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Digital Wallet', style: RenanceText.sectionTitle),
                  const SizedBox(width: 6),
                  Text('· 1 of 4 certificates',
                      style: RenanceText.caption),
                ],
              ),
              const SizedBox(height: 12),
              // Featured certificate card ---------------------------------
              Container(
                decoration: BoxDecoration(
                  color: RenanceColors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14141C2D),
                      blurRadius: 24,
                      offset: Offset(0, 4),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: <Widget>[
                      // Guilloche-style ambient pattern (Stitch detail).
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.03,
                          child: CustomPaint(
                            painter: _GuillochePainter(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('CONSISTENCY 100',
                                          style: RenanceText.labelMono
                                              .copyWith(
                                                  color:
                                                      RenanceColors.amber,
                                                  letterSpacing: 2)),
                                      const SizedBox(height: 4),
                                      Text('Level $level',
                                          style: RenanceText.displayLg
                                              .copyWith(
                                                  color:
                                                      RenanceColors.ink)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: RenanceColors.emerald
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text('Verified',
                                          style: RenanceText.labelMono
                                              .copyWith(
                                                  color: RenanceColors
                                                      .emerald)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified,
                                          size: 16,
                                          color: RenanceColors.emerald),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _CertRow(label: 'Issued to', value: name),
                            _CertRow(label: 'Date', value: date),
                            _CertRow(
                                label: 'ID',
                                value: id,
                                mono: true,
                                last: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Actions -----------------------------------------------------
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Sharing arrives with public profiles: your certificate will get a shareable link.')),
                          );
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.ios_share, size: 20),
                        label: const Text('Share'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (BuildContext ctx) => AlertDialog(
                              backgroundColor: RenanceColors.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              title: Row(
                                children: <Widget>[
                                  const Icon(Icons.verified,
                                      color: RenanceColors.emerald),
                                  const SizedBox(width: 8),
                                  Text('Verified',
                                      style: RenanceText.sectionTitle),
                                ],
                              ),
                              content: Text(
                                'Level $level certificate for $name.\nID: $id',
                                style: RenanceText.bodySecondary,
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: RenanceColors.outlineLight),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text('Verify'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Archive -----------------------------------------------------
              Text('Archive', style: RenanceText.sectionTitle),
              const SizedBox(height: 12),
              Row(
                children: const <Widget>[
                  Expanded(
                    child: _ArchiveCard(
                      eyebrow: 'Level 6',
                      title: 'Consistency 50',
                      icon: Icons.shield_outlined,
                      colors: <Color>[Color(0xFFE7EEFF), Color(0xFFF0F3FF)],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _ArchiveCard(
                      eyebrow: 'Milestone',
                      title: '10k Mastery',
                      icon: Icons.diamond_outlined,
                      colors: <Color>[Color(0xFFE9DDFF), Color(0xFFF3EEFF)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const <Widget>[
                  Expanded(
                    child: _ArchiveCard(
                      eyebrow: 'Foundation',
                      title: 'First 100 XP',
                      icon: Icons.menu_book_outlined,
                      colors: <Color>[Color(0xFFDAE2FC), Color(0xFFEEF2FF)],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _ArchiveCard(
                      eyebrow: 'Exam board',
                      title: 'Distinction',
                      icon: Icons.workspace_premium_outlined,
                      colors: <Color>[Color(0xFFD0E1FB), Color(0xFFEDF3FF)],
                      locked: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Distinction certificates are issued when your exam board '
                'results are verified on Renance.',
                style: RenanceText.caption.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertRow extends StatelessWidget {
  const _CertRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.last = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: EdgeInsets.only(bottom: last ? 0 : 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: RenanceColors.surfaceContainerHigh)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(label, style: RenanceText.caption),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? RenanceText.labelMono.copyWith(color: RenanceColors.ink)
                  : RenanceText.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.colors,
    this.locked = false,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final List<Color> colors;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: RenanceColors.card,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x33141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Center(
              child: Icon(icon,
                  size: 40,
                  color: locked
                      ? RenanceColors.textSecondary
                      : RenanceColors.ink),
            ),
          ),
          const SizedBox(height: 10),
          Text(eyebrow,
              style: RenanceText.labelMono.copyWith(
                fontSize: 11,
                color: RenanceColors.textSecondary,
              )),
          const SizedBox(height: 2),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyMedium.copyWith(fontSize: 14)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Repeating circle-and-diamond lattice, the ambient guilloche texture
/// from the Stitch certificate card, drawn cheaply.
class _GuillochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF263143);
    const double step = 60;
    double y = 0;
    while (y < size.height + step) {
      double x = 0;
      while (x < size.width + step) {
        canvas.drawCircle(Offset(x, y), 15, paint);
        canvas.drawCircle(Offset(x, y), 30, paint);
        x += step;
      }
      y += step;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
