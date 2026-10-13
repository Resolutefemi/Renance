'use client';

/**
 * ShopPanel — the gem store of the merged learn module, lifted out of
 * the retired /shop page so it can live ON the profile page (founder
 * directive 2026-10-14: "the shop feature should be under profile and
 * the heart read too"). Streak freezes, heart refills, double-XP
 * boosts and the Super trial. Buys hit the study-api and the gem
 * wallet updates everywhere.
 */

import { useCallback, useEffect, useState } from 'react';
import { GemIcon, ToastBanner } from '@/components/learn/bits';
import { ShopResponse, buyShopItem, fetchShop } from '@/lib/learn';

export default function ShopPanel({ id }: { id?: string }) {
  const [shop, setShop] = useState<ShopResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);
  const [buying, setBuying] = useState('');
  const [toast, setToast] = useState('');
  const [tone, setTone] = useState<'green' | 'red'>('green');

  const load = useCallback(() => {
    fetchShop()
      .then((s) => {
        setShop(s);
        setOffline(false);
      })
      .catch(() => {
        // No dead-end error card (founder: "remove retry"): the quiet
        // poll below keeps trying until the shelves arrive.
        setOffline(true);
      })
      .finally(() => setLoading(false));
  }, []);

  useEffect(load, [load]);

  // The quiet re-sync: until the shop answers, poll every 8s.
  useEffect(() => {
    if (shop || !offline) return;
    const t = window.setInterval(load, 8000);
    return () => window.clearInterval(t);
  }, [shop, offline, load]);

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
    <section id={id} className="flex flex-col gap-3">
      <ToastBanner text={toast} tone={tone} />
      {offline && !shop && (
        <div className="learn-tile flex flex-col items-center gap-2 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-8 text-center">
          <span className="material-symbols-outlined text-[32px] text-primary">storefront</span>
          <p className="text-[14px] font-black text-on-surface">The shop is syncing…</p>
          <p className="max-w-xs text-[12.5px] font-bold text-on-surface-variant">
            The shelves appear the moment the connection is back.
          </p>
        </div>
      )}
      {loading && !shop && <div className="h-40 animate-pulse rounded-2xl bg-surface-container" aria-hidden />}

      {shop && (
        <>
          {/* Wallet row: gems + the heart readout — REAL data, never ∞ */}
          <div className="grid grid-cols-2 gap-3">
            <div className="learn-tile flex items-center justify-center gap-2 rounded-2xl border-2 border-macaw-ring bg-macaw-light px-3 py-4">
              <GemIcon size={22} />
              <span className="text-[21px] font-black text-macaw-dark">{shop.gems.toLocaleString()}</span>
              <span className="text-[12px] font-extrabold text-macaw-dark">gems</span>
            </div>
            <div className="learn-tile flex items-center justify-center gap-2 rounded-2xl border-2 border-outline-variant bg-card px-3 py-4">
              <span className="material-symbols-outlined text-[22px] text-error">favorite</span>
              <span className="text-[21px] font-black text-on-surface">{shop.hearts}</span>
              <span className="text-[12px] font-extrabold text-on-surface-variant">hearts</span>
            </div>
          </div>

          <div className="flex flex-col gap-2.5">
            {shop.items.map((it) => (
              <div key={it.key} className="learn-tile flex items-center gap-3 rounded-2xl border-2 border-outline-variant bg-card p-3.5">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/15">
                  <span className="material-symbols-outlined text-[22px] text-primary-ink">{it.icon}</span>
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-[13.5px] font-black text-on-surface">
                    {it.title}
                    {it.max > 0 && <span className="ml-1.5 text-[11px] font-bold text-on-surface-variant">({it.owned}/{it.max})</span>}
                  </p>
                  <p className="text-[11.5px] font-bold leading-snug text-on-surface-variant">{it.desc}</p>
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
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-white/20">
                <span className="material-symbols-outlined text-[24px]">workspace_premium</span>
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-[14px] font-black">{shop.superTrial.title}</p>
                <p className="text-[11.5px] font-bold leading-snug text-white/90">{shop.superTrial.desc}</p>
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

          <p className="px-1 text-center text-[11.5px] font-bold text-on-surface-variant">
            Gems come from quests, topic chests, first clears and perfect scores. Unlimited hearts stay on for everyone at launch.
          </p>
        </>
      )}
    </section>
  );
}
