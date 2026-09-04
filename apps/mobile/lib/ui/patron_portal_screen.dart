/// Patron portal, the Stitch patron_portal_light screen, 1:1.
///
/// The dark PATRON STATUS hero (Add Funds / Share Impact), Student
/// Stories, the Needs Funding cards with raised rails and Fund this CTAs,
/// and the Transparency Ledger with the Verified chip. Static friendly:
/// funding actions show a snackbar until the payments rail ships.
/// Founder rule: the raised rail is ink, not purple.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

class PatronPortalScreen extends StatelessWidget {
  const PatronPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                    ),
                    const SizedBox(width: 4),
                    const Text('Patron Portal',
                        style: RenanceText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                // dark hero -------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: <Color>[Color(0xFF131B2E), Color(0xFF0E2420)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: const <Widget>[
                          Icon(Icons.push_pin_outlined,
                              size: 16, color: RenanceColors.amber),
                          SizedBox(width: 8),
                          Expanded(child: Text('PATRON STATUS',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  height: 16 / 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w500,
                                  color: RenanceColors.amber))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('₦184,000',
                          style: RenanceText.displayLg
                              .copyWith(color: RenanceColors.darkTextPrimary)),
                      const SizedBox(height: 6),
                      const Text('unlocked · 46 students supported',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: Color(0xB3F0F3FF),
                          )),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: context.ink,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                onPressed: () => _snack(context,
                                    'Payments ship with the funding rail.'),
                                child: const Text('+ Add Funds',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      RenanceColors.darkTextPrimary,
                                  side: const BorderSide(
                                      color: Color(0x40F0F3FF)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                onPressed: () => _snack(context,
                                    'Impact story copied for sharing.'),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.share_outlined, size: 16),
                                    SizedBox(width: 6),
                                    Text('Share Impact',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                // Student Stories -------------------------------------------
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Student Stories',
                          style: RenanceText.sectionTitle),
                    ),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Row(
                          children: <Widget>[
                            Text('View all',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.ink)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                                size: 15, color: context.ink),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 250,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: const <Widget>[
                      _StoryCard(
                        name: 'Oluwaseun A.',
                        quote:
                            '"Thanks to the WAEC fee support, I can finally take my final exams this..."',
                        status: 'Funded',
                        gradient: <Color>[
                          Color(0xFFD8E3FB),
                          Color(0xFFB9CFF4),
                        ],
                      ),
                      SizedBox(width: 12),
                      _StoryCard(
                        name: 'Chidi N.',
                        quote:
                            '"The monthly data grant keeps my access online..."',
                        status: 'In Progress',
                        gradient: <Color>[
                          Color(0xFFE7EEFF),
                          Color(0xFFCBD9F6),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Needs Funding ---------------------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Needs Funding',
                      style: RenanceText.sectionTitle),
                ),
                const SizedBox(height: 14),
                _NeedCard(
                  tag: 'Exam Fee',
                  amount: '₦21,500',
                  title: 'WAEC Registration',
                  subtitle: 'For 5 students in Lagos',
                  raised: '₦8,500 raised',
                  progress: 0.40,
                  progressColor: context.ink,
                ),
                const SizedBox(height: 12),
                const _NeedCard(
                  tag: 'Study Material',
                  amount: '₦15,000',
                  title: 'Physics Textbooks',
                  subtitle: 'Rural library restock',
                  raised: '₦12,000 raised',
                  progress: 0.80,
                  progressColor: RenanceColors.emerald,
                ),
                SizedBox(height: 28),
                // Transparency Ledger --------------------------------------
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Transparency Ledger',
                          style: RenanceText.sectionTitle),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.selectionBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Verified',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.ink)),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: Color(0x14141C2D),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      _LedgerRow(
                        icon: Icons.account_balance_outlined,
                        title: 'Disbursed to JAMB Board',
                        date: 'Oct 12, 2023',
                        amount: '-₦14,200',
                      ),
                      Divider(height: 1, color: context.outlineLight),
                      _LedgerRow(
                        icon: Icons.savings_outlined,
                        title: 'Your Contribution',
                        date: 'Oct 10, 2023',
                        amount: '+₦50,000',
                        positive: true,
                      ),
                      Divider(height: 1, color: context.outlineLight),
                      _LedgerRow(
                        icon: Icons.menu_book_outlined,
                        title: 'Textbook Supplier Payment',
                        date: 'Sep 28, 2023',
                        amount: '-₦8,500',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: () => _snack(context,
                        'The PDF ledger export ships with the funding rail.'),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.download_outlined,
                              size: 18, color: context.ink),
                          SizedBox(width: 8),
                          Text('Download Full Ledger (PDF)',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.ink)),
                        ],
                      ),
                    ),
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

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.name,
    required this.quote,
    required this.status,
    required this.gradient,
  });

  final String name;
  final String quote;
  final String status;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final bool funded = status == 'Funded';
    return Container(
      width: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // photo tile stand-in -------------------------------------------
          Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: funded
                                ? RenanceColors.emerald
                                : RenanceColors.amber,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(status,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.ink,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: RenanceText.bodyMedium),
                const SizedBox(height: 6),
                Text(quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, 
                        fontSize: 13, height: 19 / 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedCard extends StatelessWidget {
  const _NeedCard({
    required this.tag,
    required this.amount,
    required this.title,
    required this.subtitle,
    required this.raised,
    required this.progress,
    required this.progressColor,
  });

  final String tag;
  final String amount;
  final String title;
  final String subtitle;
  final String raised;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tag, style: RenanceText.caption.copyWith(color: context.textSecondary)),
              ),
              const Spacer(),
              Text(amount,
                  style: RenanceText.statNumber.copyWith(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: RenanceText.bodyMedium.copyWith(fontSize: 17)),
          const SizedBox(height: 2),
          Text(subtitle, style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: context.cardHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(progress * 100).round()}%',
                  style: RenanceText.labelMono.copyWith(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(raised, style: RenanceText.labelMono.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Payments ship with the funding rail.')),
              ),
              child: const Text('Fund this',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.icon,
    required this.title,
    required this.date,
    required this.amount,
    this.positive = false,
  });

  final IconData icon;
  final String title;
  final String date;
  final String amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.cardLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: context.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: RenanceText.bodyMedium),
                const SizedBox(height: 2),
                Text(date, style: RenanceText.caption.copyWith(color: context.textSecondary)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: positive ? RenanceColors.emerald : context.ink,
            ),
          ),
        ],
      ),
    );
  }
}
