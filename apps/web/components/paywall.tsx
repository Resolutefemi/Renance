'use client';

/**
 * PaywallModal - the subscribe dialog the 20-question cap opens. Strictly
 * black and white, Paystack-grade clean: the premium tiers, the REN
 * redemption row for students who earned coins in the arena, and the
 * founder's WhatsApp line. Progress in the capped paper is saved
 * server-side; a student who subscribes continues exactly where they
 * stopped. While the server says subscriptions are paused the modal
 * leads with the all-unlocked notice - no buy buttons, no nagging.
 */

import { useEffect, useState } from 'react';
import {
  fetchPlans,
  initializePaystack,
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

export default function PaywallModal({ open, onClose, context, entitlement }: Props) {
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

  return (
    <div
      className="fixed inset-0 z-[90] flex items-end justify-center bg-[#0B0C0E]/70 p-0 backdrop-blur-[2px] sm:items-center sm:p-6"
      role="dialog"
      aria-modal="true"
      aria-label="Subscribe to Renance premium"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="renance-rise max-h-[92dvh] w-full max-w-lg overflow-y-auto rounded-t-2xl bg-card text-on-surface shadow-2xl sm:rounded-2xl">
        {/* head */}
        <div className="sticky top-0 z-10 border-b border-primary/10 bg-card/95 px-5 pb-4 pt-5 backdrop-blur sm:px-7">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-on-surface-variant">
                Renance Premium
              </p>
              <h2 className="mt-1 text-xl font-bold tracking-tight">
                {context ?? 'Unlock the full paper'}
              </h2>
              <p className="mt-1 text-[13px] leading-relaxed text-on-surface-variant">
                JAMB for ₦5,000 a year (WAEC, NECO and Post-UTME included),
                or premium bursts from ₦500 a week. Your progress stays
                saved.
              </p>
            </div>
            <button
              onClick={onClose}
              aria-label="Close"
              className="shrink-0 rounded-full p-2 text-on-surface-variant transition hover:bg-surface-container hover:text-on-surface"
            >
              <span className="material-symbols-outlined text-[20px]">close</span>
            </button>
          </div>
        </div>

        <div className="px-5 py-5 sm:px-7">
          {error && (
            <p className="mb-4 rounded-lg bg-error-container px-4 py-3 text-[13px] text-on-error-container">{error}</p>
          )}
          {done && (
            <p className="mb-4 rounded-lg bg-emerald-tint px-4 py-3 text-[13px] text-accent-emerald">{done}</p>
          )}

          {!catalog ? (
            <div className="flex items-center justify-center py-10">
              <RenanceMark size={28} state="busy" />
            </div>
          ) : catalog.studentBillingEnabled === false ? (
            <>
              {/* paused billing: everything is open, nothing to buy.
                  Supreme gradient hero + solid white copy (founder pass
                  2026-10-13 - small text must stay readable on big
                  coloured cards). */}
              <div className="rounded-xl bg-gradient-to-br from-primary to-treefrog-dark px-5 py-5 text-white shadow-[0_4px_0_0_color-mix(in_srgb,var(--color-primary)_62%,#000)]">
                <p className="flex items-center gap-2 text-[15px] font-extrabold">
                  <span className="material-symbols-outlined text-[18px]">verified</span>
                  Everything is unlocked right now
                </p>
                <p className="mt-2 text-[13px] font-semibold leading-relaxed text-white/95">
                  Subscriptions are paused - every paper, the AI tutor and
                  every premium perk are open to every student, free. Your
                  coins are safe and keep stacking; spend them the day
                  billing returns.
                </p>
              </div>
              <button
                onClick={onClose}
                className="mt-4 flex h-10 w-full items-center justify-center rounded-full bg-macaw text-[13px] font-extrabold text-white transition hover:opacity-90"
              >
                Back to my paper - it&apos;s all open
              </button>
            </>
          ) : (
            <>
              {/* tiers */}
              <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                {catalog.plans.map((p) => {
                  const best = p.code === 'jamb';
                  return (
                    <button
                      key={p.code}
                      onClick={() => subscribe(p.code)}
                      disabled={busyPlan !== null || !catalog.paystackEnabled}
                      className={`group flex flex-col rounded-xl border p-4 text-left transition active:scale-[0.99] disabled:opacity-70 ${
                        best
                          ? 'border-2 border-primary shadow-[4px_4px_0_0_var(--color-primary)]'
                          : 'border-primary/20 hover:border-primary/60'
                      }`}
                    >
                      <span className="flex items-center justify-between">
                        <span className="font-mono text-[10px] uppercase tracking-[0.18em] text-on-surface-variant">
                          {p.label}
                        </span>
                        {best && (
                          <span className="rounded-full bg-primary-ink px-2 py-0.5 font-mono text-[9px] font-bold uppercase tracking-wider text-white">
                            best value
                          </span>
                        )}
                      </span>
                      <span className="mt-1.5 text-2xl font-bold tracking-tight">
                        {naira(p.amountNaira)}
                      </span>
                      <span className="mt-1 text-[12px] leading-snug text-on-surface-variant">{p.perks}</span>
                      {(p.features?.length ?? 0) > 0 && (
                        <ul className="mt-2 space-y-1">
                          {p.features.slice(0, 4).map((f) => (
                            <li key={f} className="flex items-start gap-1.5 text-[11.5px] leading-snug text-on-surface-variant">
                              <span className="material-symbols-outlined mt-0.5 text-[13px] text-on-surface">check</span>
                              {f}
                            </li>
                          ))}
                          {p.features.length > 4 && (
                            <li className="font-mono text-[10.5px] text-on-surface-variant">
                              +{p.features.length - 4} more on the plans page
                            </li>
                          )}
                        </ul>
                      )}
                      {/* Blue pay key - money actions wear macaw (founder
                          2026-10-13), the Supreme pay-button recipe. */}
                      <span className="mt-3 flex h-9 items-center justify-center rounded-full bg-macaw text-[12.5px] font-extrabold text-white shadow-[0_2px_0_0_var(--color-macaw-dark)] transition group-hover:opacity-90">
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
                <p className="mt-3 rounded-lg bg-surface-container px-4 py-3 font-mono text-[11px] leading-relaxed text-on-surface-variant">
                  Card checkout is being connected. Meanwhile:
                  message the founder on WhatsApp {catalog.whatsapp} to subscribe.
                </p>
              )}

              {/* REN coins retired (founder 2026-10-22): the earn loop
                  runs on diamonds - quests, chests, perfect scores and
                  100 diamonds per referred friend. */}
              <p className="mt-5 rounded-xl border border-dashed border-primary/25 p-4 font-mono text-[10.5px] leading-relaxed text-on-surface-variant">
                Earn diamonds, not points: quests, chests, perfect scores and 100 diamonds for
                every friend who joins with your referral code.
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
