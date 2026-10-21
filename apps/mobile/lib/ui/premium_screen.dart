import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

/// PremiumScreen: the paywall and the plans desk. Founder pricing on
/// paper white: the tiers (JAMB annual, 1 week, 1 month, 3 months)
/// rendered straight from the catalog, the REN coin redemption
/// table (arena wins pay 1, referrals pay 3), and the WhatsApp line for
/// bulk and school negotiation. While the server says subscriptions are
/// paused the screen becomes an "everything is unlocked" notice - the
/// plans still render, buy buttons and coin spending step aside.
/// Paystack may still be unconnected; the screen says so honestly and
/// keeps the coins and the WhatsApp line working.
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
                    if (!catalog!.studentBillingEnabled) ...<Widget>[
                      // Founder directive, 2026-09-28: subscriptions are
                      // PAUSED - every student rides premium for free.
                      // The screen becomes an all-unlocked notice; the
                      // catalog still shows where pricing will land.
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                MsIcon('verified',
                                    size: 20, color: context.pageBg),
                                const SizedBox(width: 8),
                                Text('Everything is unlocked',
                                    style: RenanceText.bodyMedium.copyWith(
                                        color: context.pageBg,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Subscriptions are paused for now - every '
                              'paper, the AI tutor and every premium perk '
                              'are open to every student, free. No card, '
                              'no cap, no nagging.',
                              style: RenanceText.bodyMedium.copyWith(
                                color: context.pageBg,
                                fontSize: 13, height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.capNotice && catalog.studentBillingEnabled)
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
                    ...List<Widget>.generate(catalog.plans.length, (int i) {
                      final PremiumPlan p = catalog.plans[i];
                      final bool best = p.code == 'jamb';
                      final String period = p.durationDays >= 360
                          ? '/ year'
                          : p.durationDays >= 28
                              ? '/ month'
                              : '/ ${p.durationDays} days';
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
                                Text(period,
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
                            if (p.features.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              for (final String f in p.features)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      MsIcon('check_circle',
                                          size: 14, color: context.textSecondary),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          f,
                                          style: RenanceText.caption.copyWith(
                                            fontSize: 12, height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            const SizedBox(height: 12),
                            catalog.studentBillingEnabled
                                ? _payButton(p, catalog)
                                : _includedChip(),
                          ],
                        ),
                      );
                    }),
                    // REN redemption ---------------------------------------
                    if (catalog.studentBillingEnabled) ...<Widget>[
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
                    ],
                    if (!catalog.studentBillingEnabled) ...<Widget>[
                      const SizedBox(height: 18),
                      Text(
                        'Your REN coins are safe and keep stacking - arena wins '
                        '(+1) and referrals (+3). The day billing returns you '
                        'can spend them on premium days.',
                        style: RenanceText.caption.copyWith(
                          fontSize: 12, height: 1.4, color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  /// The paused-billing stand-in for a plan's pay button.
  Widget _includedChip() {
    return TactileButton(
      onPressed: null,
      height: 42,
      radius: BorderRadius.circular(12),
      outline: context.outlineVariant,
      edge: context.outlineVariant,
      edgeWidth: 3,
      fontSize: 12.5,
      child: const Text('Included free right now'),
    );
  }

  Widget _payButton(PremiumPlan p, PlanCatalog catalog) {
    if (!catalog.paystackEnabled) {
      return TactileButton(
        onPressed: null,
        height: 42,
        radius: BorderRadius.circular(12),
        outline: context.outlineVariant,
        edge: context.outlineVariant,
        edgeWidth: 3,
        fontSize: 12.5,
        child: const Text('Card payments coming'),
      );
    }
    return TactileButton(
      onPressed: _busyPlan == null ? () => _subscribe(p) : null,
      height: 42,
      radius: BorderRadius.circular(12),
      face: context.ink,
      onFace: context.pageBg,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      child: Text(
        _busyPlan == p.code ? 'Opening checkout…' : 'Pay with Paystack',
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
    return TactileButton(
      onPressed: enabled ? onTap : null,
      height: 36,
      radius: RenanceRadius.chip,
      outline: context.outlineVariant,
      edge: context.outlineVariant,
      edgeWidth: 3,
      fontSize: 12.5,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const SizedBox(width: 6),
          Text('$coins REN',
              style: RenanceText.labelMono.copyWith(
                fontSize: 11, color: context.textSecondary,
              )),
        ],
      ),
    );
  }
}
