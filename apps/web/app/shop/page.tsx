'use client';

/**
 * /shop - the FULL shop page again (founder directive 2026-10-22:
 * "move the shop features from the profile page and turn it into a
 * full page where people can buy alot of things with diamonds"). The
 * profile embed is gone; the home grid's Shop tile and the navbar gem
 * chip both land here. Streak freezes, heart refills, double-XP
 * boosts and the Super trial - diamonds from quests, chests, perfect
 * scores and 100-per-friend referrals.
 */

import ShopPanel from '@/components/learn/shop-panel';

export default function ShopPage() {
  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <div className="mx-auto w-full max-w-2xl px-4 py-6">
        <div className="mb-1 flex items-center gap-2">
          <span className="material-symbols-outlined text-[24px] text-primary-ink">storefront</span>
          <h1 className="text-[22px] font-bold text-on-surface">Shop</h1>
        </div>
        <p className="mb-5 text-[13px] leading-relaxed text-on-surface-variant">
          Spend your diamonds on streak freezes, heart refills and XP boosts. Diamonds come from
          quests, topic chests, first clears and perfect scores - and every friend who joins with
          your referral code adds 100 more.
        </p>
        <div className="rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          <ShopPanel id="shop" />
        </div>
      </div>
    </main>
  );
}
