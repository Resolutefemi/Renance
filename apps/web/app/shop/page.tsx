'use client';

/**
 * Shop — the gem store of the merged learn module (founder directive
 * 2026-10-14): streak freezes, heart refills (armed when the unlimited
 * launch flag goes off), double-XP boosts and the Super trial. Buys
 * hit the study-api and the gem wallet updates everywhere.
 */

import { useCallback, useEffect, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { GemIcon, ToastBanner } from '@/components/learn/bits';
import { getStoredUser } from '@/lib/session';
import { useRouter } from 'next/navigation';
import { ShopResponse, buyShopItem, fetchShop } from '@/lib/learn';

export default function ShopPage() {
  const router = useRouter();
  const [shop, setShop] = useState<ShopResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [buying, setBuying] = useState('');
  const [toast, setToast] = useState('');
  const [tone, setTone] = useState<'green' | 'red'>('green');
  const [error, setError] = useState('');

  const load = useCallback(() => {
    setError('');
    setLoading(true);
    fetchShop().then(setShop).catch(() => setError('The shop could not load. Check your connection, then retry.')).finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/shop');
      return;
    }
    load();
  }, [load, router]);

  const buy = useCallback(async (item: string) => {
    setBuying(item);
    try {
      const res = await buyShopItem(item);
      setShop(res);
      setTone('green');
      setToast('Purchased!');
    } catch (e) {
      setTone('red');
      setToast(e instanceof Error && e.message ? e.message.replace('learn: ', '') : 'Purchase failed');
    } finally {
      setBuying('');
      setTimeout(() => setToast(''), 2200);
    }
  }, []);

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <ToastBanner text={toast} tone={tone} />
      <PageBar title="Shop" backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        {error && (
          <div className="learn-tile flex flex-col items-center gap-3 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-10 text-center">
            <span className="material-symbols-outlined text-[34px] text-on-surface-variant">wifi_off</span>
            <p className="text-[13.5px] font-bold text-on-surface-variant">{error}</p>
            <button type="button" onClick={load} className="key-btn bg-primary text-white">Retry</button>
          </div>
        )}
        {loading && <div className="h-40 animate-pulse rounded-2xl bg-surface-container" aria-hidden />}

        {shop && (
          <div className="flex flex-col gap-4">
            {/* Gem wallet */}
            <div className="learn-tile flex items-center justify-center gap-2 rounded-2xl border-2 border-macaw-ring bg-macaw-light px-4 py-5">
              <GemIcon size={28} />
              <span className="text-[26px] font-black text-macaw-dark">{shop.gems.toLocaleString()}</span>
              <span className="text-[13px] font-extrabold text-macaw-dark">gems</span>
            </div>

            <div className="flex flex-col gap-2.5">
              {shop.items.map((it) => (
                <div key={it.key} className="learn-tile flex items-center gap-3 rounded-2xl border-2 border-outline-variant bg-card p-3.5">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/15">
                    <span className="material-symbols-outlined text-[24px] text-primary-ink">{it.icon}</span>
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-[14px] font-black text-on-surface">
                      {it.title}
                      {it.max > 0 && <span className="ml-1.5 text-[11px] font-bold text-on-surface-variant">({it.owned}/{it.max})</span>}
                    </p>
                    <p className="text-[12px] font-bold leading-snug text-on-surface-variant">{it.desc}</p>
                  </div>
                  {it.soldOut ? (
                    <span className="shrink-0 rounded-xl border-2 border-outline-variant px-3 py-1.5 text-[12px] font-black text-on-surface-variant">
                      {it.key === 'heart_refill' ? 'Full' : 'Maxed'}
                    </span>
                  ) : (
                    <button
                      type="button"
                      onClick={() => void buy(it.key)}
                      disabled={buying === it.key || shop.gems < it.gems}
                      className="key-btn flex shrink-0 items-center gap-1 bg-accent-amber px-3 text-[12.5px] text-white disabled:opacity-50"
                    >
                      <GemIcon size={14} />{it.gems}
                    </button>
                  )}
                </div>
              ))}

              {/* Super trial */}
              <div className="learn-tile flex items-center gap-3 rounded-2xl border-2 border-macaw-ring bg-gradient-to-br from-macaw to-macaw-dark p-4 text-white">
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-white/20">
                  <span className="material-symbols-outlined text-[26px]">workspace_premium</span>
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-[15px] font-black">{shop.superTrial.title}</p>
                  <p className="text-[12px] font-bold leading-snug text-white/90">{shop.superTrial.desc}</p>
                </div>
                {shop.superTrial.soldOut ? (
                  <span className="shrink-0 rounded-xl border-2 border-white/60 bg-white/20 px-3 py-1.5 text-[12px] font-black">Active</span>
                ) : (
                  <button
                    type="button"
                    onClick={() => void buy('super_trial')}
                    disabled={buying === 'super_trial'}
                    className="key-btn shrink-0 border-white bg-white px-3 text-[12.5px] text-macaw-dark"
                  >
                    Free trial
                  </button>
                )}
              </div>
            </div>

            <p className="px-1 text-center text-[12px] font-bold text-on-surface-variant">
              Gems come from quests, topic chests, first clears and perfect scores. Unlimited hearts are on for everyone at launch.
            </p>
          </div>
        )}
      </main>
      <BottomNav />
    </div>
  );
}
