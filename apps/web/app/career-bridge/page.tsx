'use client';

/**
 * Career bridge, the Stitch career_bridge_light screen.
 * The "Where can Biology take you?" hero, Scholarships open now and the
 * Course cut-off explorer with filter chips (local state).
 */

import { useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const SCHOLARSHIPS: ReadonlyArray<{ icon: string; title: string; meta: string; urgent?: boolean }> = [
  { icon: 'school', title: 'National STEM Grant', meta: 'Closes in 12 days • $5,000', urgent: true },
  { icon: 'biotech', title: 'Future Biotech Leaders', meta: 'Nov 15 Deadline • Full Tuition' },
  { icon: 'eco', title: 'Conservation Initiative', meta: 'Dec 01 Deadline • $2,500' },
];

const FILTERS = ['Health', 'Research', 'Ecology'] as const;

export default function CareerBridgePage() {
  const [filters, setFilters] = useState<string[]>(['Health']);

  const toggle = (f: string) =>
    setFilters((cur) => (cur.includes(f) ? cur.filter((x) => x !== f) : [...cur, f]));

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Career Bridge" />
      </div>

      {/* hero */}
      <section className="mt-4 flex min-h-[190px] flex-col rounded-2xl bg-gradient-to-br from-[#EAF1FE] via-[#D8E3FB] to-[#C7D9F7] p-5">
        <p className="font-mono text-[11px] uppercase tracking-[1.2px] text-on-surface-variant">
          Career Bridge
        </p>
        <h1 className="mt-auto text-2xl font-bold tracking-tight text-on-surface">
          Where can Biology take you?
        </h1>
        <p className="mt-2 text-[15px] text-on-surface-variant">
          Explore pathways and funding
        </p>
      </section>

      {/* Scholarships open now */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Scholarships open now</h2>
      <div className="mt-3.5 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        {SCHOLARSHIPS.map((s) => (
          <button key={s.title} className="flex w-full items-center gap-3.5 p-4 text-left transition hover:bg-surface-container-low/50">
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-surface-container-high">
              <span className="material-symbols-outlined text-[24px] text-accent-ink">{s.icon}</span>
            </span>
            <span className="min-w-0 flex-1">
              <span className="flex items-center gap-2">
                <span className="truncate text-[17px] font-semibold text-on-surface">{s.title}</span>
                {s.urgent && (
                  <span className="shrink-0 rounded-full bg-error-container px-2.5 py-1 font-mono text-[12px] font-bold tracking-wide text-error">
                    URGENT
                  </span>
                )}
              </span>
              <span className="mt-0.5 block text-[15px] text-on-surface-variant">{s.meta}</span>
            </span>
            <span className="material-symbols-outlined text-[24px] text-on-surface-variant">chevron_right</span>
          </button>
        ))}
      </div>

      {/* Course cut-off explorer */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Course cut-off explorer</h2>
      <div className="mt-3.5 rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        <label className="flex items-center gap-2 rounded-xl bg-surface-container-low px-4 py-3.5">
          <span className="material-symbols-outlined text-[22px] text-on-surface-variant">search</span>
          <input
            type="text"
            placeholder="Search degrees (e.g. B.Sc Marine Biology)"
            className="w-full bg-transparent text-[15px] text-on-surface outline-none placeholder:text-on-surface-variant"
          />
        </label>
        <div className="mt-3.5 flex flex-wrap gap-2">
          {FILTERS.map((f) => (
            <button
              key={f}
              onClick={() => toggle(f)}
              className={`rounded-full px-4 py-2.5 text-[15px] transition ${
                filters.includes(f)
                  ? 'bg-selection-blue font-semibold text-on-surface'
                  : 'bg-surface-container-low text-on-surface-variant'
              }`}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      <BottomNav />
    </main>
  );
}
