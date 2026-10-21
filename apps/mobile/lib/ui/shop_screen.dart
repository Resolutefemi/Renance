/// The full-page Shop (founder directive 2026-10-22): the shop left the
/// profile page and became its own destination where diamonds buy the
/// whole store - streak freezes, heart refills, XP boosts. The home grid
/// carries the Storefront tile and the header gems chip opens this page
/// directly, so the wallet is always one tap away.
library;

import 'package:flutter/material.dart';

import 'learn_bits.dart';
import 'shop_panel.dart';
import 'tactile.dart';
import 'theme.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    TactileBackKey(
                      onTap: () => Navigator.of(context).pop(),
                      size: 42,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            // Title row + the live diamond balance, so the spender sees
            // what they hold without scrolling into the wallet tile.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Shop',
                      style: RenanceText.displayMd.copyWith(
                        fontSize: 26,
                        color: context.ink,
                      ),
                    ),
                  ),
                  GemStatChip(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Spend your diamonds on streak freezes, heart refills and '
                'XP boosts. Diamonds come from quests, topic chests, '
                'first clears, perfect scores - and every friend who '
                'joins with your referral code adds 100 more.',
                style: RenanceText.bodySecondary.copyWith(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(child: ShopPanel()),
          ],
        ),
      ),
    );
  }
}
