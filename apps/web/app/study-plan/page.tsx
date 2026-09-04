'use client';

/**
 * Study plan, the Stitch study_plan_light screen.
 * TODAY'S PLAN card with the three focus blocks, the Current Energy Level
 * selector (local state) and the Fatigue Insight card. Static-friendly:
 * the plan is the Stitch copy and the play rows route into the shelves
 * that already exist.
 */

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const PLAN = [
  { icon: 'science', iconBg: 'bg-emerald-tint', iconColor: 'text-accent-emerald', title: 'Biology Practice', meta: '15 min', focus: 'High focus', href: '/dashboard#packs' },
  { icon: 'style', iconBg: 'bg-surface-container-high', iconColor: 'text-accent-ink', title: 'Review Cards', meta: '12 min', focus: 'Medium focus', href: '/review' },
  { icon: 'mic', iconBg: 'bg-amber-tint', iconColor: 'text-accent-amber', title: 'Voice Flashcards', meta: '15 min', focus: 'Low focus', href: '/flashcards' },
] as const;

const ENERGIES = [
  { label: 'Sharp', icon: 'bolt' },
  { label: 'Normal', icon: 'battery_charging_full' },
  { label: 'Tired', icon: 'battery_1_bar' },
] as const;

export default function StudyPlanPage() {
  const router = useRouter();
  const [energy, setEnergy] = useState(0);

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Study Plan" />
      </div>

      {/* TODAY'S PLAN card */}
      <section className="mt-4 rounded-2xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        <div className="flex items-start justify-between">
          <p className="font-mono text-[11px] uppercase tracking-[1.2px] text-accent-amber">
            TODAY&apos;S PLAN
          </p>
          <button
            aria-label="Edit plan"
            className="flex h-11 w-11 items-center justify-center rounded-full bg-surface-container-low text-on-surface"
          >
            <span className="material-symbols-outlined text-[20px]">edit</span>
          </button>
        </div>
        <p className="mt-1 text-2xl font-bold tracking-tight text-on-surface">
          42 min remaining
        </p>

        <div className="mt-4 space-y-2.5">
          {PLAN.map((row) => (
            <button
              key={row.title}
              onClick={() => router.push(row.href)}
              className="flex w-full items-center gap-3 rounded-2xl bg-surface-container-low px-3 py-3.5 text-left transition active:scale-[0.99]"
            >
              <span className="grid grid-cols-2 gap-1">
                {[0, 1, 2, 3].map((d) => (
                  <span key={d} className="h-[3.5px] w-[3.5px] rounded-full bg-outline-light" />
                ))}
              </span>
              <span className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-full ${row.iconBg}`}>
                <span className={`material-symbols-outlined text-[24px] ${row.iconColor}`}>{row.icon}</span>
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[17px] font-semibold text-on-surface">{row.title}</span>
                <span className="block text-[15px] text-on-surface-variant">{row.meta} • {row.focus}</span>
              </span>
              <span className="material-symbols-outlined text-[26px] text-on-surface">play_arrow</span>
            </button>
          ))}
        </div>
      </section>

      {/* Current Energy Level */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Current Energy Level</h2>
      <div className="mt-3.5 grid grid-cols-3 gap-2.5">
        {ENERGIES.map((e, i) => (
          <button
            key={e.label}
            onClick={() => setEnergy(i)}
            className={`flex items-center justify-center gap-1.5 rounded-full py-3 text-[15px] transition ${
              energy === i
                ? 'bg-selection-blue font-semibold text-on-surface'
                : 'bg-surface-container-low text-on-surface-variant'
            }`}
          >
            <span className="material-symbols-outlined text-[18px]">{e.icon}</span>
            {e.label}
          </button>
        ))}
      </div>

      {/* Fatigue Insight */}
      <section className="mt-7 flex items-start gap-4 rounded-2xl bg-[#E4EAFB] p-5">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-card text-on-surface">
          <span className="material-symbols-outlined text-[22px]">lightbulb</span>
        </span>
        <div>
          <p className="text-[15px] font-semibold text-on-surface">Fatigue Insight</p>
          <p className="mt-2 text-[15px] leading-6 text-on-surface-variant">
            You usually fade after ~25 min in the evening. We&apos;ve placed your
            heaviest topics (Biology) first to maximize retention.
          </p>
        </div>
      </section>

      <BottomNav />
    </main>
  );
}
