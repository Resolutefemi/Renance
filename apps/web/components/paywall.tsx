'use client';

/**
 * PaywallModal - the subscribe dialog the 20-question cap opens. Strictly
 * black and white, Paystack-grade clean: the four premium tiers, the REN
 * redemption row for students who earned coins in the arena, and the
 * founder's WhatsApp line for bulk and school negotiation. Progress in
 * the capped paper is saved server-side; a student who subscribes
 * continues exactly where they stopped.
 */

import { useEffect, useState } from 'react';
import {
  fetchPlans,
  initializePaystack,
  redeemWithCoins,
  naira,
  type PlanCatalog,
  type Entitlement,
} from '@/lib/billing';
import { RenanceMark } from '@/components/renance-logo';

interface Props {
  open: boolean;
  onClose: () => void;
  /** What the student was doing when the cap hit, printed on top. */
  context?: string;
  /** Signed-in entitlement (REN wallet); null keeps redemption hidden. */
  entitlement?: Entitlement | null;
  /** Refresh the entitlement after a successful redemption. */
  onRedeemed?: (e: Entitlement) => void;
}

export default function PaywallModal({ open, onClose, context, entitlement, onRedeemed }: Props) {
  const [catalog, setCatalog] = useState<PlanCatalog | null>(null);
  const [busyPlan, setBusyPlan] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setDone(null);
    setError(null);
    fetchPlans()
      .then(setCatalog)
      .catch(() => setError('Could not load the plans, check the connection.'));
  }, [open]);

  if (!open) return null;

  const subscribe = async (code: string) => {
    setBusyPlan(code);
    setError(null);
    try {
      const res = await initializePaystack(code);
      window.location.href = res.authorizationUrl;
    } catch (err) {
      setBusyPlan(null);
      setError(err instanceof Error ? err.message : 'Could not start the payment.');
    }
  };

  const redeem = async (code: string) => {
    setBusyPlan(code);
    setError(null);
    try {
      const res = await redeemWithCoins(code);
      setDone(`Premium applied: ${res.entitlement.premiumType}. Your progress is right where you left it.`);
      onRedeemed?.(res.entitlement);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Redemption failed.');
    } finally {
      setBusyPlan(null);
    }
  };

  const hasCoins = (entitlement?.renCoins ?? 0) > 0;

  return (
    <div
      className="fixed inset-0 z-[90] flex items-end justify-center bg-[#0B0C0E]/70 p-0 backdrop-blur-[2px] sm:items-center sm:p-6"
      role="dialog"
      aria-modal="true"
      aria-label="Subscribe to Renance premium"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="renance-rise max-h-[92dvh] w-full max-w-lg overflow-y-auto rounded-t-2xl bg-white text-[#101418] shadow-2xl sm:rounded-2xl">
        {/* head */}
        <div className="sticky top-0 z-10 border-b border-[#101418]/10 bg-white/95 px-5 pb-4 pt-5 backdrop-blur sm:px-7">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-[#71717A]">
                Renance Premium
              </p>
              <h2 className="mt-1 text-xl font-bold tracking-tight">
                {context ?? 'Unlock the full paper'}
              </h2>
              <p className="mt-1 text-[13px] leading-relaxed text-[#52525B]">
                One subscription covers every body: JAMB, WAEC, NECO and
                Post-UTME. Your progress stays saved.
              </p>
            </div>
            <button
              onClick={onClose}
              aria-label="Close"
              className="shrink-0 rounded-full p-2 text-[#71717A] transition hover:bg-[#F4F4F5] hover:text-[#101418]"
            >
              <span className="material-symbols-outlined text-[20px]">close</span>
            </button>
          </div>
        </div>

        <div className="px-5 py-5 sm:px-7">
          {error && (
            <p className="mb-4 rounded-lg bg-[#FEF2F2] px-4 py-3 text-[13px] text-[#B91C1C]">{error}</p>
          )}
          {done && (
            <p className="mb-4 rounded-lg bg-[#F0FDF4] px-4 py-3 text-[13px] text-[#166534]">{done}</p>
          )}

          {!catalog ? (
            <div className="flex items-center justify-center py-10">
              <RenanceMark size={28} state="busy" />
            </div>
          ) : (
            <>
              {/* tiers */}
              <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                {catalog.plans.map((p) => {
                  const best = p.code === 'year';
                  return (
                    <button
                      key={p.code}
                      onClick={() => subscribe(p.code)}
                      disabled={busyPlan !== null || !catalog.paystackEnabled}
                      className={`group flex flex-col rounded-xl border p-4 text-left transition active:scale-[0.99] disabled:opacity-70 ${
                        best
                          ? 'border-2 border-[#101418] shadow-[4px_4px_0_0_#101418]'
                          : 'border-[#101418]/20 hover:border-[#101418]/60'
                      }`}
                    >
                      <span className="flex items-center justify-between">
                        <span className="font-mono text-[10px] uppercase tracking-[0.18em] text-[#71717A]">
                          {p.label}
                        </span>
                        {best && (
                          <span className="rounded-full bg-[#101418] px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-white">
                            best value
                          </span>
                        )}
                      </span>
                      <span className="mt-1.5 text-2xl font-bold tracking-tight">
                        {naira(p.amountNaira)}
                      </span>
                      <span className="mt-1 text-[12px] leading-snug text-[#52525B]">{p.perks}</span>
                      <span className="mt-3 flex h-9 items-center justify-center rounded-full bg-[#101418] text-[12.5px] font-semibold text-white transition group-hover:opacity-90">
                        {catalog.paystackEnabled
                          ? busyPlan === p.code
                            ? 'Opening checkout…'
                            : 'Pay with Paystack'
                          : 'Card payments coming'}
                      </span>
                    </button>
                  );
                })}
              </div>

              {!catalog.paystackEnabled && (
                <p className="mt-3 rounded-lg bg-[#FAFAF9] px-4 py-3 font-mono text-[11px] leading-relaxed text-[#52525B]">
                  Card checkout is being connected. Meanwhile: redeem REN coins below, or
                  message the founder on WhatsApp {catalog.whatsapp} to subscribe.
                </p>
              )}

              {/* REN redemption */}
              <div className="mt-5 rounded-xl border border-dashed border-[#101418]/25 p-4">
                <div className="flex items-baseline justify-between">
                  <p className="text-[13px] font-bold">Redeem REN coins</p>
                  <p className="font-mono text-[11px] text-[#71717A]">
                    balance: {entitlement ? `${entitlement.renCoins} REN` : 'sign in to see'}
                  </p>
                </div>
                <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-3">
                  {catalog.redemptions.map((r) => (
                    <button
                      key={r.code}
                      onClick={() => redeem(r.code)}
                      disabled={!hasCoins || busyPlan !== null}
                      className="flex flex-col items-center rounded-lg border border-[#101418]/20 px-3 py-2.5 transition hover:border-[#101418]/60 disabled:opacity-50"
                    >
                      <span className="text-[12px] font-semibold">{r.label}</span>
                      <span className="font-mono text-[11px] text-[#71717A]">{r.coins} REN</span>
                    </button>
                  ))}
                </div>
                <p className="mt-2.5 font-mono text-[10.5px] leading-relaxed text-[#71717A]">
                  Earn coins: win an arena duel (+1 REN), refer a friend (+3 REN each).
                </p>
              </div>

              {/* bulk / school line */}
              <div className="mt-5 flex flex-col items-start gap-2 rounded-xl bg-[#101418] px-4 py-3.5 text-white sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="text-[13px] font-semibold">School or bulk subscription?</p>
                  <p className="text-[11.5px] text-white/70">
                    Message the founder directly on WhatsApp: {catalog.whatsapp}
                  </p>
                </div>
                <a
                  href={`https://wa.me/234${catalog.whatsapp.replace(/^0/, '')}`}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-full bg-white px-4 py-1.5 text-[12px] font-semibold text-[#101418] transition hover:opacity-90"
                >
                  Chat on WhatsApp
                </a>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
