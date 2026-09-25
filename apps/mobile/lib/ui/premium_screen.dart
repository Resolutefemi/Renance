import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import 'renance_logo.dart';
import 'theme.dart';

/// PremiumScreen: the paywall and the plans desk. Founder pricing on
/// paper white: the four Paystack tiers (week, month, quarter, year),
/// the REN coin redemption table (arena wins pay 1, referrals pay 3),
/// and the WhatsApp line for bulk and school negotiation. One premium
/// covers JAMB, WAEC, NECO and Post-UTME. Paystack may still be
/// unconnected; the screen says so honestly and keeps the coins and the
/// WhatsApp line working.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.capNotice = false});

  /// True when opened from the 20-question cap: the headline tells the
  /// student their progress is saved and they continue after paying.
  final bool capNotice;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PlanCatalog? _catalog;
  Entitlement? _entitlement;
  String? _error;
  String? _busyPlan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final PlanCatalog catalog = await api.billingPlans();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on NetworkException {
      if (!mounted) return;
      setState(() => _error = 'No connection. Reconnect to load the plans.');
      return;
    }
    try {
      final Entitlement ent = await api.entitlement();
      if (!mounted) return;
      setState(() => _entitlement = ent);
    } catch (_) {
      // Signed-out or offline: the plans still show, coins just hide.
    }
  }

  Future<void> _subscribe(PremiumPlan plan) async {
    final ApiClient api = context.read<ApiClient>();
    setState(() => _busyPlan = plan.code);
    try {
      final String url = await api.initializePaystack(plan.code);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on NetworkException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No connection. Reconnect and try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  Future<void> _redeem(RenRedemption r) async {
    final ApiClient api = context.read<ApiClient>();
    setState(() => _busyPlan = r.code);
    try {
      final Entitlement ent = await api.redeemCoins(r.code);
      if (!mounted) return;
      setState(() => _entitlement = ent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r.label} applied from ${r.coins} REN coins. Continue your paper right where you stopped.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on NetworkException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No connection. Reconnect and try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlanCatalog? catalog = _catalog;
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(title: Text('Renance Premium', style: RenanceText.sectionTitle.copyWith(fontSize: 17))),
      body: catalog == null && _error == null
          ? const Center(child: LogoActivityIndicator(label: 'Loading plans…'))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center,
                        style: RenanceText.bodySecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: <Widget>[
                    if (widget.capNotice)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.ink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'You have reached the free limit of 20 questions. '
                          'Subscribe to continue, your progress is saved.',
                          style: RenanceText.bodyMedium.copyWith(
                            color: context.pageBg, fontSize: 13.5, height: 1.4,
                          ),
                        ),
                      ),
                    // Tiers ------------------------------------------------
                    ...List<Widget>.generate(catalog!.plans.length, (int i) {
                      final PremiumPlan p = catalog.plans[i];
                      final bool best = p.code == 'year';
                      return Container(
                        margin: EdgeInsets.only(bottom: i == catalog.plans.length - 1 ? 0 : 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: best ? context.ink : context.outlineVariant,
                            width: best ? 1.6 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(p.label, style: RenanceText.bodyMedium),
                                ),
                                if (best)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: context.ink,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'BEST VALUE',
                                      style: RenanceText.overline.copyWith(
                                        fontSize: 8.5, color: context.pageBg,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: <Widget>[
                                Text(
                                  '₦${_naira(p.amountNaira)}',
                                  style: RenanceText.statNumber.copyWith(fontSize: 24),
                                ),
                                const SizedBox(width: 4),
                                Text('${p.durationDays} days',
                                    style: RenanceText.caption.copyWith(color: context.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.perks,
                              style: RenanceText.caption.copyWith(
                                fontSize: 12, height: 1.4, color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 42,
                              child: _payButton(p, catalog),
                            ),
                          ],
                        ),
                      );
                    }),
                    // REN redemption ---------------------------------------
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Redeem REN coins', style: RenanceText.bodyMedium),
                        Text(
                          _entitlement == null
                              ? 'sign in to see balance'
                              : '${_entitlement!.renCoins} REN',
                          style: RenanceText.labelMono.copyWith(
                            fontSize: 12, color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Win an arena duel (+1 REN), refer a friend (+3 REN). '
                      'Spend coins on premium days without paying a Naira.',
                      style: RenanceText.caption.copyWith(
                        fontSize: 12, height: 1.4, color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final RenRedemption r in catalog.redemptions)
                          _RedeemChip(
                            label: r.label,
                            coins: r.coins,
                            enabled: (_entitlement?.renCoins ?? 0) >= r.coins && _busyPlan == null,
                            onTap: () => _redeem(r),
                          ),
                      ],
                    ),
                    // WhatsApp ---------------------------------------------
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'School or bulk subscription?',
                            style: RenanceText.bodyMedium.copyWith(color: context.pageBg),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prices are negotiated directly with the founder on '
                            'WhatsApp: ${catalog.whatsapp}',
                            style: RenanceText.caption.copyWith(
                              fontSize: 12.5,
                              color: context.pageBg.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final String num =
                                    '234${catalog.whatsapp.replaceFirst(RegExp(r'^0'), '')}';
                                launchUrl(
                                  Uri.parse('https://wa.me/$num'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.pageBg,
                                side: BorderSide(color: context.pageBg.withValues(alpha: 0.5)),
                              ),
                              icon: const Icon(Icons.chat, size: 16),
                              label: Text('Chat on WhatsApp',
                                  style: RenanceText.bodySecondary.copyWith(
                                    fontSize: 12.5, color: context.pageBg,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _payButton(PremiumPlan p, PlanCatalog catalog) {
    if (!catalog.paystackEnabled) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.outlineVariant),
        ),
        child: Text('Card payments coming',
            style: RenanceText.bodySecondary.copyWith(
              fontSize: 12.5, color: context.textSecondary,
            )),
      );
    }
    return FilledButton(
      onPressed: _busyPlan == null ? () => _subscribe(p) : null,
      style: FilledButton.styleFrom(
        backgroundColor: context.ink,
        foregroundColor: context.pageBg,
      ),
      child: Text(
        _busyPlan == p.code ? 'Opening checkout…' : 'Pay with Paystack',
        style: RenanceText.bodySecondary.copyWith(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: context.pageBg,
        ),
      ),
    );
  }

  String _naira(int n) {
    final String s = n.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final int rem = s.length - i;
      out.write(s[i]);
      if (rem > 1 && rem % 3 == 1) out.write(',');
    }
    return out.toString();
  }
}

class _RedeemChip extends StatelessWidget {
  const _RedeemChip({
    required this.label,
    required this.coins,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int coins;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.outlineVariant),
            color: context.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: RenanceText.bodySecondary.copyWith(fontSize: 12.5)),
              const SizedBox(width: 6),
              Text('$coins REN',
                  style: RenanceText.labelMono.copyWith(
                    fontSize: 11, color: context.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
