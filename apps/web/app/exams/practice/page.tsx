'use client';

/**
 * Practice Settings, the Stitch practice_mode_setup_light screen, 1:1.
 *
 * "Configure your JAMB practice session." The Past Question Year grid
 * (2024 / 2023 / 2022 / Random), the Question Count stepper with the
 * big stat and the 10 / 20 / 40 / 50 presets, the Timer grid (No
 * timer / 15m / 30m / 60m), the Shuffle Questions / Shuffle Options /
 * Show Answer Instantly toggle rows and the sticky Start Practice
 * button. Start launches the pack the student came from (?pack=code);
 * without one it returns to the pack library.
 */

import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const YEARS = ['2024', '2023', '2022', 'Random'] as const;
const TIMERS: Array<{ label: string; minutes: number | null }> = [
  { label: 'No timer', minutes: null },
  { label: '15m', minutes: 15 },
  { label: '30m', minutes: 30 },
  { label: '60m', minutes: 60 },
];
const PRESETS = [10, 20, 40, 50] as const;

function PracticeSettingsInner() {
  const router = useRouter();
  const params = useSearchParams();
  const pack = params.get('pack') ?? '';

  const [year, setYear] = useState<string>('2024');
  const [count, setCount] = useState<number>(40);
  const [timerMinutes, setTimerMinutes] = useState<number | null>(60);
  const [shuffleQuestions, setShuffleQuestions] = useState(true);
  const [shuffleOptions, setShuffleOptions] = useState(true);
  const [showAnswerInstantly, setShowAnswerInstantly] = useState(false);

  function start() {
    const overrides = new URLSearchParams();
    overrides.set('count', String(count));
    overrides.set('timer', timerMinutes == null ? '0' : String(timerMinutes));
    if (shuffleQuestions) overrides.set('shuffle', '1');
    if (showAnswerInstantly) overrides.set('instant', '1');
    if (pack) {
      router.push(`/exams/${encodeURIComponent(pack)}?${overrides.toString()}`);
    } else {
      router.push('/packs');
    }
  }

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Practice Settings" />

      <div className="mx-auto flex w-full max-w-5xl flex-col px-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl pb-8 pt-4">
          <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
            Practice Settings
          </h1>
          <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
            Configure your JAMB practice session.
          </p>

          {/* Past Question Year */}
          <section className="mt-6 flex flex-col gap-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-outline-light">history</span>
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                Past Question Year
              </h2>
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {YEARS.map((y) => (
                <YearButton key={y} label={y} selected={year === y} onSelect={() => setYear(y)} />
              ))}
            </div>
          </section>

          {/* Question Count */}
          <section className="mt-6 flex flex-col gap-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-outline-light">format_list_numbered</span>
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                Question Count
              </h2>
            </div>
            <div className="flex items-center justify-between">
              <StepButton
                icon="remove"
                onClick={() => setCount((c) => Math.max(5, c - 5))}
                label="Remove questions"
              />
              <div className="flex flex-col items-center">
                <span className="text-[32px] font-bold leading-9 tracking-[-0.02em] text-on-surface">{count}</span>
                <span className="font-mono text-[13px] text-on-surface-variant">Questions</span>
              </div>
              <StepButton
                icon="add"
                onClick={() => setCount((c) => Math.min(100, c + 5))}
                label="Add questions"
              />
            </div>
            <div className="mt-1 flex gap-2">
              {PRESETS.map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setCount(p)}
                  className={`flex-1 rounded-md py-2 text-center transition-colors ${
                    count === p
                      ? 'bg-selection-blue text-[15px] font-semibold text-on-surface'
                      : 'bg-surface-container-low text-[15px] text-on-surface hover:bg-surface-variant'
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </section>

          {/* Timer */}
          <section className="mt-6 flex flex-col gap-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-outline-light">timer</span>
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">Timer</h2>
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {TIMERS.map((t) => (
                <YearButton
                  key={t.label}
                  label={t.label}
                  selected={timerMinutes === t.minutes}
                  onSelect={() => setTimerMinutes(t.minutes)}
                />
              ))}
            </div>
          </section>

          {/* Toggles */}
          <section className="mt-6 flex flex-col rounded-[12px] bg-card p-2 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <ToggleRow
              icon="shuffle"
              label="Shuffle Questions"
              value={shuffleQuestions}
              onChange={setShuffleQuestions}
            />
            <ToggleRow
              icon="format_list_bulleted"
              label="Shuffle Options"
              value={shuffleOptions}
              onChange={setShuffleOptions}
            />
            <ToggleRow
              icon="bolt"
              label="Show Answer Instantly"
              value={showAnswerInstantly}
              onChange={setShowAnswerInstantly}
            />
          </section>
        </div>
      </div>

      {/* Sticky CTA */}
      <div className="fixed bottom-16 inset-x-0 z-30 bg-surface/90 p-4 pb-6 backdrop-blur-md md:bottom-4">
        <div className="mx-auto w-full max-w-2xl">
          <button
            type="button"
            onClick={start}
            className="flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] bg-primary text-[15px] font-semibold text-on-primary shadow-md transition-transform active:scale-[0.98]"
          >
            <span className="material-symbols-outlined text-[22px]">play_arrow</span>
            Start Practice
          </button>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}

export default function PracticeSettingsPage() {
  // useSearchParams needs a Suspense boundary under static export.
  return (
    <Suspense
      fallback={
        <main className="min-h-dvh bg-surface pb-28 md:pb-16">
          <PageBar title="Practice Settings" />
        </main>
      }
    >
      <PracticeSettingsInner />
    </Suspense>
  );
}

/** Selection-blue cell with the ink 2px ring when active. */
function YearButton({
  label,
  selected,
  onSelect,
}: {
  label: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={`rounded-lg border-2 py-3 text-[15px] font-semibold transition-all ${
        selected
          ? 'border-primary bg-selection-blue text-on-surface'
          : 'border-transparent bg-surface-container-low text-on-surface hover:bg-surface-variant'
      }`}
    >
      {label}
    </button>
  );
}

/** 48px round stepper button (remove / add). */
function StepButton({ icon, onClick, label }: { icon: string; onClick: () => void; label: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-container-low text-on-surface transition-colors hover:bg-surface-variant"
    >
      <span className="material-symbols-outlined">{icon}</span>
    </button>
  );
}

/** Stitch toggle row: black track + white right thumb when on. */
function ToggleRow({
  icon,
  label,
  value,
  onChange,
}: {
  icon: string;
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between border-b border-surface-container-low p-3 last:border-0">
      <div className="flex items-center gap-3">
        <span className="material-symbols-outlined text-on-surface-variant">{icon}</span>
        <span className="text-[15px] font-semibold text-on-surface">{label}</span>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={value}
        aria-label={label}
        onClick={() => onChange(!value)}
        className={`relative h-6 w-12 rounded-full transition-colors ${
          value ? 'bg-primary' : 'bg-surface-container-high'
        }`}
      >
        <span
          className={`absolute top-1 h-4 w-4 rounded-full transition-all ${
            value ? 'right-1 bg-card' : 'left-1 bg-on-surface-variant'
          }`}
        />
      </button>
    </div>
  );
}
