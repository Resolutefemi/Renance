/// The Gem Shop - the Flutter twin of the web's ShopPanel
/// (components/learn/shop-panel.tsx, embedded at /profile#shop): the
/// wallet row (gems + hearts), the item list (Streak Freeze 200, Heart
/// Refill 350, Double XP 100) with amber buy keys, and the quiet
/// offline poll.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../learn_controller.dart';
import '../learn_models.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

class ShopPanel extends StatefulWidget {
  const ShopPanel({super.key});

  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  bool _loading = true;
  String? _error;
  ShopResponse? _shop;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final ShopResponse shop = await api.learnShop();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _buy(ShopItem item) async {
    final LearnController learn = context.read<LearnController>();
    try {
      final ShopResponse shop = await learn.buy(item.key);
      if (!mounted) return;
      setState(() => _shop = shop);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchased!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // The server prefixes learn errors with "learn: " (web strips it).
      String msg = e.message.replaceFirst('learn: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      _load();
    } on NetworkException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: RenanceMark(size: 34, busy: true)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: <Widget>[
            Text(
              'The shop is syncing…',
              style: RenanceText.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Items appear the moment the connection is back.',
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      );
    }
    final ShopResponse shop = _shop!;
    final int gems = context.watch<LearnController>().gems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // wallet row
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  // the web's gems tile: learn-tile rounded-2xl
                  // border-2 border-macaw-ring bg-macaw-light
                  color: RenanceColors.macawLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RenanceColors.macawRing, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: context.outlineVariant
                          .withValues(alpha: 0.55),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const GemIcon(size: 20),
                    const SizedBox(width: 7),
                    Text(
                      '$gems',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: RenanceColors.macawDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'gems',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: RenanceColors.macawDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  // the web's hearts tile: border-2 border-outline-variant
                  // bg-card - a white card, never a pink wash
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.outlineVariant, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: context.outlineVariant
                          .withValues(alpha: 0.55),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const MsIcon('favorite',
                        size: 20, color: RenanceColors.cardinal, fill: true),
                    const SizedBox(width: 7),
                    Text(
                      '${shop.hearts}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'hearts',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final ShopItem item in shop.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShopRow(
              item: item,
              affordable: gems >= item.gems,
              onBuy: () => _buy(item),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Gems come from quests, topic chests, first clears and perfect '
          'scores. Unlimited hearts stay on for everyone at launch.',
          style: RenanceText.caption.copyWith(
            fontSize: 12,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.item,
    required this.affordable,
    required this.onBuy,
  });

  final ShopItem item;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final bool soldOut = item.soldOut;
    final String priceLabel = soldOut
        ? (item.key == 'heart_refill'
            ? 'Full'
            : item.key == 'freeze'
                ? 'Maxed'
                : 'Active')
        : '${item.gems}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.outlineVariant, width: 2),
        // the web's learn-tile: the hard 4px extruded ledge
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.outlineVariant.withValues(alpha: 0.55),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // The web's item icon chip: flex h-10 w-10 items-center
          // justify-center - the glyph MUST center in the well. (The
          // founder's shop-alignment bug: the MsIcon branch had no
          // centering and parked top-left inside the 40px box.)
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.icon == 'diamond'
                ? const Center(child: GemIcon(size: 20))
                : MsIcon(
                    item.icon.isEmpty ? 'diamond' : item.icon,
                    size: 22,
                    color: context.primaryInk,
                    fill: true,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (item.key == 'freeze' && item.max > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '(${item.owned}/${item.max})',
                style: RenanceText.labelMono.copyWith(
                  fontSize: 11,
                  color: context.textSecondary,
                ),
              ),
            ),
          TactileButton(
            onPressed: soldOut || !affordable ? null : onBuy,
            expand: false,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            fontSize: 13,
            face: RenanceColors.bee,
            onFace: Colors.white,
            edge: RenanceColors.beeDark,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!soldOut) ...<Widget>[
                  const GemIcon(size: 14),
                  const SizedBox(width: 5),
                ],
                Text(priceLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
