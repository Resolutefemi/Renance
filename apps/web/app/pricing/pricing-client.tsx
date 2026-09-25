'use client';

/**
 * Pricing - the student premium page. Founder pricing in plain black on
 * white: the four Paystack tiers, exactly what the free tier keeps, the
 * REN coin exchange table and the WhatsApp line for bulk and school
 * negotiation. One premium covers JAMB, WAEC, NECO and Post-UTME.
 */

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import PaywallModal from '@/components/paywall';
import BlueTick from '@/components/blue-tick';
import { fetchPlans, fetchEntitlement, naira, type PlanCatalog, type Entitlement } from '@/lib/billing';
import { getToken } from '@/lib/session';

const FREE_KEEPS = [
  'Arena duels, every day, unlimited',
  "Today's Daily Challenge and its leaderboard",
  'XP and arena leaderboards',
  '20 answers on every exam paper',
  'One full CBT for testing when you sign up',
  'REN coins: +1 per arena win, +3 per referral',
];

const PREMIUM_GETS = [
  'Every paper in full: no question cap, anywhere',
  'JAMB UTME mocks graded on the official 400 scale',
  'WAEC, NECO and Post-UTME included with the same plan',
  'The official score slip: per-subject marks and time used',
  'Pacing forensics after every paper',
  'The blue tick next to your name on every board',
  'Redeem REN coins for free premium days',
];

export default function PricingClient() {
  const router = useRouter();
  const params = useSearchParams();
  const [catalog, setCatalog] = useState<PlanCatalog | null>(null);
  const [entitlement, setEntitlement] = useState<Entitlement | null>(null);
  const [paywallOpen, setPaywallOpen] = useState(false);

  useEffect(() => {
    document.title = 'Premium · Renance';
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

  return (
    <div className="min-h-dvh bg-surface-container-lowest">
      <PageBar title="Premium" backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4 sm:px-6">
        {/* hero */}
        <section className="rounded-2xl bg-[#101418] px-6 py-8 text-white">
          <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-white/60">
            One key, every exam
          </p>
          <h1 className="mt-2 flex items-center gap-2 text-2xl font-bold tracking-tight">
            Renance Premium <BlueTick size={22} />
          </h1>
          <p className="mt-2 max-w-md text-[13.5px] leading-relaxed text-white/75">
            Pay for JAMB and unlock WAEC, NECO and Post-UTME with it. Full
            papers, the official 400-scale score slip, and the blue tick on
            every leaderboard.
          </p>
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
                p.code === 'year'
                  ? 'border-2 border-[#101418] bg-white shadow-[4px_4px_0_0_#101418]'
                  : 'border-outline-variant/60 bg-white hover:border-[#101418]/60'
              }`}
            >
              <span className="flex items-center justify-between">
                <span className="font-mono text-[10px] uppercase tracking-[0.18em] text-on-surface-variant">
                  {p.label}
                </span>
                {p.code === 'year' && (
                  <span className="rounded-full bg-[#101418] px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-white">
                    best value
                  </span>
                )}
              </span>
              <span className="mt-1.5 text-2xl font-bold tracking-tight text-[#101418]">
                {naira(p.amountNaira)}
              </span>
              <span className="mt-1 text-[12px] leading-snug text-on-surface-variant">{p.perks}</span>
              <span className="mt-3 flex h-9 items-center justify-center rounded-full bg-[#101418] text-[12.5px] font-semibold text-white">
                Pay with Paystack
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
            <h2 className="text-[15px] font-bold tracking-tight text-on-surface">Premium adds</h2>
            <p className="mt-0.5 text-[12px] text-on-surface-variant">
              Everything the free cap holds back.
            </p>
            <ul className="mt-3 space-y-2">
              {PREMIUM_GETS.map((f) => (
                <li key={f} className="flex items-start gap-2 text-[13px] leading-snug text-on-surface">
                  <span className="material-symbols-outlined mt-0.5 text-[15px] text-[#1D9BF0]">
                    verified
                  </span>
                  {f}
                </li>
              ))}
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
                onClick={() => setPaywallOpen(true)}
                className="flex items-center justify-between rounded-lg border border-outline-variant/60 px-4 py-3 text-left transition hover:border-[#101418]/60"
              >
                <span className="text-[13px] font-semibold text-on-surface">{r.label}</span>
                <span className="font-mono text-[12px] text-on-surface-variant">{r.coins} REN</span>
              </button>
            ))}
          </div>
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

        {/* WhatsApp */}
        <section className="mt-4 flex flex-col items-start gap-2 rounded-xl bg-[#101418] px-5 py-4 text-white sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-[13.5px] font-semibold">Bulk or school subscription?</p>
            <p className="text-[12px] text-white/70">
              Prices are negotiated directly with the founder on WhatsApp:{' '}
              {catalog?.whatsapp ?? '07046203544'}
            </p>
          </div>
          <a
            href={`https://wa.me/234${(catalog?.whatsapp ?? '07046203544').replace(/^0/, '')}`}
            target="_blank"
            rel="noreferrer"
            className="rounded-full bg-white px-4 py-1.5 text-[12px] font-semibold text-[#101418] transition hover:opacity-90"
          >
            Message the founder
          </a>
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
