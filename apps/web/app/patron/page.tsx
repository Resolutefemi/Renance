'use client';

/**
 * Patron portal, the Stitch patron_portal_light screen.
 * The dark PATRON STATUS hero (Add Funds / Share Impact), Student
 * Stories, Needs Funding cards with raised rails and the Transparency
 * Ledger. Static friendly: funding actions are stubs until the payments
 * rail ships. Founder rule: the raised rail is ink, not purple.
 */

import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const NEEDS = [
  { tag: 'Exam Fee', amount: '₦21,500', title: 'WAEC Registration', sub: 'For 5 students in Lagos', raised: '₦8,500 raised', pct: 40, bar: 'bg-primary', barText: 'text-on-surface' },
  { tag: 'Study Material', amount: '₦15,000', title: 'Physics Textbooks', sub: 'Rural library restock', raised: '₦12,000 raised', pct: 80, bar: 'bg-accent-emerald', barText: 'text-accent-emerald' },
] as const;

const LEDGER = [
  { icon: 'account_balance', title: 'Disbursed to JAMB Board', date: 'Oct 12, 2023', amount: '-₦14,200' },
  { icon: 'savings', title: 'Your Contribution', date: 'Oct 10, 2023', amount: '+₦50,000', positive: true },
  { icon: 'menu_book', title: 'Textbook Supplier Payment', date: 'Sep 28, 2023', amount: '-₦8,500' },
] as const;

const STORIES = [
  { name: 'Oluwaseun A.', quote: '"Thanks to the WAEC fee support, I can finally take my final exams this..."', status: 'Funded', from: 'from-[#D8E3FB]', to: 'to-[#B9CFF4]', dot: 'bg-accent-emerald' },
  { name: 'Chidi N.', quote: '"The monthly data grant keeps my access online..."', status: 'In Progress', from: 'from-[#E7EEFF]', to: 'to-[#CBD9F6]', dot: 'bg-accent-amber' },
] as const;

export default function PatronPage() {
  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Patron Portal" />
      </div>

      {/* dark hero */}
      <section className="renance-rise mt-4 rounded-2xl bg-gradient-to-tl from-[#0E2420] to-[#131B2E] p-6">
        <p className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-[1.2px] text-accent-amber">
          <span className="material-symbols-outlined text-[16px]">push_pin</span>
          PATRON STATUS
        </p>
        <p className="mt-3 text-[28px] font-bold tracking-tight text-dark-text-primary">₦184,000</p>
        <p className="mt-1.5 text-[15px] text-dark-text-primary/70">unlocked · 46 students supported</p>
        <div className="mt-5 grid grid-cols-2 gap-2.5">
          <button className="h-12 rounded-xl bg-card text-sm font-semibold text-on-surface transition active:scale-[0.98]">
            + Add Funds
          </button>
          <button className="flex h-12 items-center justify-center gap-1.5 rounded-xl border border-dark-text-primary/25 text-sm font-semibold text-dark-text-primary transition active:scale-[0.98]">
            <span className="material-symbols-outlined text-[16px]">share</span>
            Share Impact
          </button>
        </div>
      </section>

      {/* Student Stories */}
      <div className="mt-7 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight text-on-surface">Student Stories</h2>
        <button className="flex items-center gap-1 rounded px-1 py-0.5 text-sm font-semibold text-on-surface">
          View all
          <span className="material-symbols-outlined text-[15px]">arrow_forward</span>
        </button>
      </div>
      <div className="mt-3.5 flex snap-x gap-3 overflow-x-auto pb-2">
        {STORIES.map((s) => (
          <article key={s.name} className="w-[280px] shrink-0 snap-start overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className={`relative h-[110px] bg-gradient-to-br ${s.from} ${s.to}`}>
              <span className="absolute bottom-2.5 left-2.5 flex items-center gap-1.5 rounded-full bg-card px-2.5 py-1.5 text-xs font-semibold text-on-surface">
                <span className={`h-[7px] w-[7px] rounded-full ${s.dot}`} />
                {s.status}
              </span>
            </div>
            <div className="p-3.5">
              <p className="text-[15px] font-semibold text-on-surface">{s.name}</p>
              <p className="mt-1.5 text-[13px] leading-[19px] text-on-surface-variant">{s.quote}</p>
            </div>
          </article>
        ))}
      </div>

      {/* Needs Funding */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Needs Funding</h2>
      <div className="mt-3.5 space-y-3">
        {NEEDS.map((n) => (
          <section key={n.title} className="rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-center justify-between">
              <span className="rounded-[10px] bg-surface-container-low px-3 py-1.5 text-[13px] text-on-surface-variant">{n.tag}</span>
              <span className="text-xl font-bold tracking-tight text-on-surface">{n.amount}</span>
            </div>
            <h3 className="mt-2.5 text-[17px] font-semibold text-on-surface">{n.title}</h3>
            <p className="mt-0.5 text-[15px] text-on-surface-variant">{n.sub}</p>
            <div className="mt-3.5 flex items-center gap-3">
              <div className="h-2 flex-1 overflow-hidden rounded-full bg-surface-container-high">
                <div className={`h-full rounded-full ${n.bar}`} style={{ width: `${n.pct}%` }} />
              </div>
              <span className="font-mono text-xs text-on-surface">{n.pct}%</span>
            </div>
            <p className="mt-1 font-mono text-xs text-on-surface-variant">{n.raised}</p>
            <button className="mt-3.5 h-12 w-full rounded-xl bg-primary text-[15px] font-semibold text-on-primary transition active:scale-[0.98]">
              Fund this
            </button>
          </section>
        ))}
      </div>

      {/* Transparency Ledger */}
      <div className="mt-7 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight text-on-surface">Transparency Ledger</h2>
        <span className="rounded-[10px] bg-selection-blue px-3 py-1.5 text-xs font-semibold text-on-surface">Verified</span>
      </div>
      <div className="mt-3.5 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        {LEDGER.map((l) => (
          <div key={l.title} className="flex items-center gap-3 p-4">
            <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-container-low">
              <span className="material-symbols-outlined text-[20px] text-on-surface">{l.icon}</span>
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[15px] font-semibold text-on-surface">{l.title}</span>
              <span className="block text-[13px] text-on-surface-variant">{l.date}</span>
            </span>
            <span className={`text-[15px] font-bold ${'positive' in l && l.positive ? 'text-accent-emerald' : 'text-on-surface'}`}>
              {l.amount}
            </span>
          </div>
        ))}
      </div>

      <p className="mt-4 flex items-center justify-center gap-2 text-sm font-semibold text-on-surface">
        <span className="material-symbols-outlined text-[18px]">download</span>
        Download Full Ledger (PDF)
      </p>

      <BottomNav />
    </main>
  );
}
