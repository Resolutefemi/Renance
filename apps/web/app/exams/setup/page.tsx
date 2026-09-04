'use client';

/**
 * Mock Exam Setup, the Stitch exam_mode_setup_light screen, 1:1.
 *
 * "Configure your testing environment to match official JAMB
 * conditions." Exam Format card (Standard UTME Mock with the 2 Hours /
 * 4 Subjects chips, Custom Practice secondary), the Subject Selection
 * card with the English + 3 pill, per-subject past-question year
 * dropdowns, the official-timing notice and the sticky Begin Mock Exam
 * button. Begin hands over to /exams/subjects, the next Stitch step.
 */

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const YEARS = ['2023', '2022', '2021', 'Random'] as const;

interface Subject {
  id: string;
  name: string;
  letter: string;
  letterClass: string;
  avatarClass: string;
  mandatory?: boolean;
}

const SUBJECTS: Subject[] = [
  {
    id: 'english',
    name: 'Use of English',
    letter: 'E',
    letterClass: 'text-accent-violet',
    avatarClass: 'bg-accent-violet/10',
    mandatory: true,
  },
  {
    id: 'math',
    name: 'Mathematics',
    letter: 'M',
    letterClass: 'text-accent-emerald',
    avatarClass: 'bg-accent-emerald/10',
  },
  {
    id: 'physics',
    name: 'Physics',
    letter: 'P',
    letterClass: 'text-accent-amber',
    avatarClass: 'bg-accent-amber/10',
  },
  {
    id: 'biology',
    name: 'Biology',
    letter: 'B',
    letterClass: 'text-secondary',
    avatarClass: 'bg-secondary-container',
  },
];

export default function ExamSetupPage() {
  const router = useRouter();
  const [standard, setStandard] = useState(true);
  const [years, setYears] = useState<Record<string, string>>(
    Object.fromEntries(SUBJECTS.map((s) => [s.id, '2023'])),
  );

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Mock Exam Setup" />

      <div className="mx-auto flex w-full max-w-5xl flex-col px-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl">
          {/* Header Area */}
          <div className="flex flex-col gap-2 pb-4 pt-6">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-[24px] text-accent-violet">timer</span>
              <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
                Mock Exam Setup
              </h1>
            </div>
            <p className="text-[15px] text-on-surface-variant">
              Configure your testing environment to match official JAMB conditions.
            </p>
          </div>

          {/* Exam Format card */}
          <section className="flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
              Exam Format
            </h2>
            <div className="flex flex-col gap-2">
              <button
                type="button"
                onClick={() => setStandard(true)}
                className={`flex w-full items-start gap-4 rounded-lg p-4 text-left transition-colors ${
                  standard ? 'bg-selection-blue/20' : 'bg-surface-container-low'
                }`}
              >
                <span
                  className={`material-symbols-outlined mt-1 text-[22px] ${standard ? 'fill-current text-on-surface' : 'text-outline'}`}
                >
                  {standard ? 'radio_button_checked' : 'radio_button_unchecked'}
                </span>
                <span className="flex flex-1 flex-col gap-2">
                  <span className="text-[15px] font-semibold text-on-surface">Standard UTME Mock</span>
                  <span className="flex flex-wrap items-center gap-1.5">
                    <span className="inline-flex items-center gap-1 rounded bg-surface-container-low px-2 py-1 font-mono text-[11px] text-text-secondary">
                      <span className="material-symbols-outlined text-[14px]">schedule</span> 2 Hours
                    </span>
                    <span className="inline-flex items-center gap-1 rounded bg-surface-container-low px-2 py-1 font-mono text-[11px] text-text-secondary">
                      <span className="material-symbols-outlined text-[14px]">menu_book</span> 4 Subjects
                    </span>
                  </span>
                </span>
              </button>
              <button
                type="button"
                onClick={() => setStandard(false)}
                className={`flex w-full items-start gap-4 rounded-lg p-4 text-left transition-colors ${
                  !standard ? 'bg-selection-blue/20' : 'bg-surface-container-low'
                }`}
              >
                <span
                  className={`material-symbols-outlined mt-1 text-[22px] ${!standard ? 'fill-current text-on-surface' : 'text-outline'}`}
                >
                  {!standard ? 'radio_button_checked' : 'radio_button_unchecked'}
                </span>
                <span className="flex flex-1 flex-col gap-1">
                  <span className="text-[15px] font-semibold text-on-surface-variant">Custom Practice</span>
                  <span className="text-[13px] text-text-secondary">Choose specific topics and time limits.</span>
                </span>
              </button>
            </div>
          </section>

          {/* Subject Selection card */}
          <section className="mt-4 flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <div className="flex items-center justify-between">
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                Subject Selection
              </h2>
              <Link
                href="/exams/subjects"
                className="flex items-center gap-1 rounded-full bg-surface-container px-2 py-1 font-mono text-[11px] text-on-surface-variant transition hover:bg-surface-container-high"
              >
                English + 3
                <span className="material-symbols-outlined text-[12px]">edit</span>
              </Link>
            </div>
            <div className="flex flex-col gap-2">
              {SUBJECTS.map((s) => (
                <div
                  key={s.id}
                  className={`flex items-center justify-between rounded-lg p-2 ${
                    s.mandatory
                      ? 'border border-outline-variant/30 bg-surface-container-low/50'
                      : 'transition-colors hover:bg-surface-container-low/30'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className={`flex h-8 w-8 items-center justify-center rounded ${s.avatarClass}`}>
                      <span className={`text-[16px] font-bold ${s.letterClass}`}>{s.letter}</span>
                    </div>
                    <div className="flex flex-col">
                      <span className="text-[15px] font-semibold text-on-surface">{s.name}</span>
                      {s.mandatory && <span className="text-[11px] text-text-secondary">Mandatory</span>}
                    </div>
                  </div>
                  <div className="relative">
                    <select
                      aria-label={`${s.name} past question year`}
                      value={years[s.id]}
                      onChange={(e) => setYears((p) => ({ ...p, [s.id]: e.target.value }))}
                      className="appearance-none rounded bg-surface-container py-1.5 pl-3 pr-8 font-mono text-[12px] text-on-surface-variant focus:outline-none focus:ring-1 focus:ring-primary"
                    >
                      {YEARS.map((y) => (
                        <option key={y}>{y}</option>
                      ))}
                    </select>
                    <span className="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 text-[16px] text-outline">
                      <span className="material-symbols-outlined">arrow_drop_down</span>
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </section>

          {/* Info notice */}
          <div className="mt-4 flex items-start gap-2 rounded-lg bg-surface-container-high p-3">
            <span className="material-symbols-outlined mt-0.5 text-[18px] text-outline">info</span>
            <p className="text-[13px] leading-[18px] text-on-surface-variant">
              This environment simulates official JAMB timing and rules. Pausing is disabled once the mock begins.
            </p>
          </div>
        </div>
      </div>

      {/* Sticky Bottom Action */}
      <div className="fixed bottom-16 inset-x-0 z-30 bg-gradient-to-t from-surface via-surface/90 to-transparent p-4 pb-6 md:bottom-4">
        <div className="mx-auto w-full max-w-2xl">
          <button
            type="button"
            onClick={() => router.push('/exams/subjects')}
            className="flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] bg-primary text-[15px] font-semibold text-on-primary shadow-md transition-transform active:scale-[0.98]"
          >
            Begin Mock Exam
            <span className="material-symbols-outlined text-[20px]">arrow_forward</span>
          </button>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}
