'use client';

/**
 * Pricing - the student plans page. Founder pricing in plain black on
 * white: the tiers exactly as the catalog sells them (JAMB annual, 1
 * week, 1 month, 3 months), what the free tier keeps, the REN coin
 * exchange table. While the server says subscriptions are paused the
 * page leads with the all-unlocked notice and every buy button reads
 * "Included free right now". The catalog owns the feature matrix -
 * this page renders it, it never hardcodes prices or perks.
 */

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import PaywallModal from '@/components/paywall';
import BlueTick from '@/components/blue-tick';
import { fetchPlans, fetchEntitlement, naira, type PlanCatalog, type Entitlement, type PremiumPlan } from '@/lib/billing';
import { getToken } from '@/lib/session';

const FREE_KEEPS = [
  'Arena duels, every day, unlimited',
  "Today's Daily Challenge and its leaderboard",
  'XP and arena leaderboards',
  '20 answers on every exam paper',
  'One full CBT for testing when you sign up',
  'REN coins: +1 per arena win, +3 per referral',
];

/** Duration tail the price renders with: "₦5,000 / year". */
function periodLabel(p: PremiumPlan): string {
  if (p.durationDays >= 360) return '/ year';
  if (p.durationDays >= 80) return '/ quarter';
  if (p.durationDays >= 28) return '/ month';
  return ` / ${p.durationDays} days`;
}

export default function PricingClient() {
  const router = useRouter();
  const params = useSearchParams();
  const [catalog, setCatalog] = useState<PlanCatalog | null>(null);
  const [entitlement, setEntitlement] = useState<Entitlement | null>(null);
  const [paywallOpen, setPaywallOpen] = useState(false);

  useEffect(() => {
    document.title = 'Plans · Renance';
    fetchPlans()
      .then(setCatalog)
      .catch(() => {});
    if (getToken()) {
      fetchEntitlement()
        .then(setEntitlement)
        .catch(() => {});
    }
  }, []);

  const premium = entitlement?.premiumRole && entitlement.premiumExpiresAt !== undefined
    ? Boolean(entitlement.premiumRole)
    : Boolean(entitlement?.premiumRole);
  const paused = catalog?.studentBillingEnabled === false;

  return (
    <div className="min-h-dvh bg-surface-container-lowest">
      <PageBar title="Plans" backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4 sm:px-6">
        {/* hero */}
        <section className="rounded-2xl bg-[#101418] px-6 py-8 text-white">
          <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-white/60">
            The founder&apos;s pricing, no games
          </p>
          <h1 className="mt-2 flex items-center gap-2 text-2xl font-bold tracking-tight">
            Renance Premium <BlueTick size={22} />
          </h1>
          <p className="mt-2 max-w-md text-[13.5px] leading-relaxed text-white/75">
            A full year of JAMB for ₦5,000 - WAEC, NECO and Post-UTME ride
            along. Or a burst of premium from ₦500 a week. Full papers, the
            official 400-scale score slip, and the blue tick on every
            leaderboard.
          </p>
          {paused && (
            <p className="mt-4 rounded-xl bg-white/10 px-4 py-3 text-[13px] leading-relaxed">
              <b className="flex items-center gap-1.5">
                <span className="material-symbols-outlined text-[16px]">verified</span>
                Everything is unlocked right now
              </b>
              <span className="mt-1 block text-white/80">
                Subscriptions are paused - every paper, the AI tutor and
                every premium perk are open to every student, free. No card,
                no cap, no nagging.
              </span>
            </p>
          )}
          {premium && (
            <p className="mt-4 inline-flex items-center gap-2 rounded-full bg-white/10 px-4 py-2 text-[12.5px]">
              <BlueTick size={16} />
              Your premium is active
              {entitlement?.premiumExpiresAt
                ? ` until ${new Date(entitlement.premiumExpiresAt).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' })}`
                : ''}
            </p>
          )}
        </section>

        {/* tiers */}
        <section className="mt-4 grid grid-cols-1 gap-2.5 sm:grid-cols-2">
          {(catalog?.plans ?? []).map((p) => (
            <button
              key={p.code}
              onClick={() => setPaywallOpen(true)}
              className={`flex flex-col rounded-xl border p-4 text-left transition active:scale-[0.99] ${
                p.code === 'jamb'
                  ? 'border-2 border-[#101418] bg-white shadow-[4px_4px_0_0_#101418]'
                  : 'border-outline-variant/60 bg-white hover:border-[#101418]/60'
              }`}
            >
              <span className="flex items-center justify-between">
                <span className="font-mono text-[10px] uppercase tracking-[0.18em] text-on-surface-variant">
                  {p.label}
                </span>
                {p.code === 'jamb' && (
                  <span className="rounded-full bg-[#101418] px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-white">
                    best value
                  </span>
                )}
              </span>
              <span className="mt-1.5 flex items-baseline gap-1">
                <span className="text-2xl font-bold tracking-tight text-[#101418]">
                  {naira(p.amountNaira)}
                </span>
                <span className="text-[11.5px] text-on-surface-variant">{periodLabel(p)}</span>
              </span>
              <span className="mt-1 text-[12px] leading-snug text-on-surface-variant">{p.perks}</span>
              {(p.features?.length ?? 0) > 0 && (
                <ul className="mt-3 space-y-1.5">
                  {p.features.map((f) => (
                    <li key={f} className="flex items-start gap-2 text-[12.5px] leading-snug text-on-surface">
                      <span className="material-symbols-outlined mt-0.5 text-[14px] text-[#1D9BF0]">
                        check
                      </span>
                      {f}
                    </li>
                  ))}
                </ul>
              )}
              <span className="mt-3 flex h-9 items-center justify-center rounded-full bg-[#101418] text-[12.5px] font-semibold text-white">
                {paused ? 'Included free right now' : 'Pay with Paystack'}
              </span>
            </button>
          ))}
          {!catalog && (
            <p className="col-span-full py-8 text-center text-sm text-on-surface-variant">
              Loading plans…
            </p>
          )}
        </section>

        {/* free vs premium */}
        <section className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="rounded-xl bg-white p-5">
            <h2 className="text-[15px] font-bold tracking-tight text-on-surface">Free tier</h2>
            <p className="mt-0.5 text-[12px] text-on-surface-variant">
              What every student keeps, forever.
            </p>
            <ul className="mt-3 space-y-2">
              {FREE_KEEPS.map((f) => (
                <li key={f} className="flex items-start gap-2 text-[13px] leading-snug text-on-surface">
                  <span className="material-symbols-outlined mt-0.5 text-[15px] text-on-surface-variant">
                    check
                  </span>
                  {f}
                </li>
              ))}
            </ul>
          </div>
          <div className="rounded-xl bg-white p-5">
            <h2 className="text-[15px] font-bold tracking-tight text-on-surface">How the plans work</h2>
            <p className="mt-0.5 text-[12px] text-on-surface-variant">
              One premium, four clocks - pick the burst that fits.
            </p>
            <ul className="mt-3 space-y-2.5">
              <li className="text-[13px] leading-snug text-on-surface">
                <b>JAMB Annual (₦5,000 a year)</b> - the candidate&apos;s plan.
                Pay once for JAMB and WAEC, NECO and Post-UTME ride along
                for the full twelve months.
              </li>
              <li className="text-[13px] leading-snug text-on-surface">
                <b>1 Week (₦500)</b> - a full week of everything. Exam week
                fuel: every paper uncapped, every subject.
              </li>
              <li className="text-[13px] leading-snug text-on-surface">
                <b>1 Month (₦1,500)</b> - thirty days of everything, notes
                and flashcards included.
              </li>
              <li className="text-[13px] leading-snug text-on-surface">
                <b>3 Months (₦2,500)</b> - a term of everything, the best
                value after the annual plan.
              </li>
            </ul>
          </div>
        </section>

        {/* REN economy */}
        <section className="mt-4 rounded-xl bg-white p-5">
          <div className="flex items-baseline justify-between">
            <h2 className="text-[15px] font-bold tracking-tight text-on-surface">The REN economy</h2>
            {entitlement && (
              <p className="font-mono text-[12px] text-on-surface-variant">
                balance: {entitlement.renCoins} REN
              </p>
            )}
          </div>
          <p className="mt-1 text-[12.5px] leading-relaxed text-on-surface-variant">
            Win arena duels, refer friends, spend coins on premium days. A
            free student can reach premium without paying a Naira.
          </p>
          <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-3">
            {(catalog?.redemptions ?? []).map((r) => (
              <button
                key={r.code}
                onClick={() => !paused && setPaywallOpen(true)}
                disabled={paused}
                className="flex items-center justify-between rounded-lg border border-outline-variant/60 px-4 py-3 text-left transition hover:border-[#101418]/60 disabled:opacity-60"
              >
                <span className="text-[13px] font-semibold text-on-surface">{r.label}</span>
                <span className="font-mono text-[12px] text-on-surface-variant">{r.coins} REN</span>
              </button>
            ))}
          </div>
          {paused && (
            <p className="mt-2.5 font-mono text-[10.5px] leading-relaxed text-[#71717A]">
              Coins are paused from spending while everything is free - they keep stacking, spend them the day billing returns.
            </p>
          )}
        </section>

        {/* tertiary note */}
        <section className="mt-4 rounded-xl border border-outline-variant/60 bg-white p-5">
          <h2 className="text-[15px] font-bold tracking-tight text-on-surface">
            Tertiary institutions
          </h2>
          <p className="mt-1 text-[13px] leading-relaxed text-on-surface-variant">
            University modules follow the same pattern: the free cap, the
            one testing paper, the same tiers. Students of partner schools
            get premium through their school&apos;s subscription.
          </p>
        </section>

        
        <p className="mt-6 text-center font-mono text-[10.5px] leading-relaxed text-on-surface-variant">
          Payments are processed by Paystack. Subscriptions activate the
          moment the webhook confirms your charge.
        </p>
      </main>

      <BottomNav />
      <PaywallModal
        open={paywallOpen}
        onClose={() => setPaywallOpen(false)}
        entitlement={entitlement}
        onRedeemed={(e) => setEntitlement(e)}
      />
    </div>
  );
}
