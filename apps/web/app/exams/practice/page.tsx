'use client';

/**
 * Practice Settings, the Stitch practice_mode_setup_light screen, 1:1.
 *
 * The Past Question Year grid (Random by default, then every year the
 * pack actually carries), the Question Count stepper with the big stat
 * and the 10 / 20 / 40 / 50 presets, the Timer grid (No timer / 15m /
 * 30m / 60m) plus your own minutes, and the Shuffle toggles. Start
 * carves a server-composed practice subset (jamb-pick-<pack>~params)
 * from the pack the student came from (?pack=code), so the sitting and
 * its grading stay deterministic and resumable.
 */

import { Suspense, useEffect, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { buildPickCode, fetchManifest, type Manifest } from '@/lib/exams';

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

  const [packTitle, setPackTitle] = useState('');
  const [packYears, setPackYears] = useState<number[]>([]);
  const [year, setYear] = useState<number | null>(null); // null = Random
  const [count, setCount] = useState<number>(40);
  const [customMinutes, setCustomMinutes] = useState<number | ''>('');
  const [timerMinutes, setTimerMinutes] = useState<number | null>(60);
  const [shuffleQuestions, setShuffleQuestions] = useState(true);
  const [shuffleOptions, setShuffleOptions] = useState(true);

  useEffect(() => {
    let alive = true;
    if (!pack) return () => { alive = false; };
    fetchManifest()
      .then((m: Manifest) => {
        if (!alive) return;
        const hit = m.exams.find((e) => e.code === pack);
        if (hit) {
          setPackTitle(hit.title);
          setPackYears(hit.years ?? []);
        }
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [pack]);

  const timerMins = useMemo<number | null>(() => {
    if (customMinutes !== '') return customMinutes as number;
    return timerMinutes;
  }, [customMinutes, timerMinutes]);

  function start() {
    if (!pack) {
      router.push('/packs');
      return;
    }
    const code = buildPickCode(pack, {
      count,
      year,
      timer: timerMins ?? 0,
    });
    const overrides = new URLSearchParams();
    if (shuffleQuestions) overrides.set('shuffle', '1');
    router.push(`/exams/${encodeURIComponent(code)}?${overrides.toString()}`);
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
            {packTitle ? `Configure your session · ${packTitle}` : 'Configure your practice session.'}
          </p>

          {/* Past Question Year — real years from the pack, Random default */}
          <section className="mt-6 flex flex-col gap-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-outline-light">history</span>
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                Past Question Year
              </h2>
            </div>
            {packYears.length === 0 ? (
              <p className="text-[13px] text-on-surface-variant">
                This pack runs on random draws — no year metadata.
              </p>
            ) : (
              <div className="no-scrollbar flex flex-wrap gap-2">
                <YearButton
                  label="Random"
                  selected={year == null}
                  onSelect={() => setYear(null)}
                />
                {[...packYears].reverse().map((y) => (
                  <YearButton
                    key={y}
                    label={String(y)}
                    selected={year === y}
                    onSelect={() => setYear(y)}
                  />
                ))}
              </div>
            )}
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
                onClick={() => setCount((c) => Math.min(200, c + 5))}
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
                  selected={customMinutes === '' && timerMinutes === t.minutes}
                  onSelect={() => {
                    setCustomMinutes('');
                    setTimerMinutes(t.minutes);
                  }}
                />
              ))}
            </div>
            <div className="flex items-center justify-between px-1">
              <span className="text-[14px] text-on-surface-variant">Your own minutes</span>
              <input
                type="number"
                inputMode="numeric"
                min={1}
                max={300}
                value={customMinutes}
                onChange={(e) => {
                  const v = e.target.value === '' ? '' : Math.max(1, Math.min(300, Number(e.target.value)));
                  setCustomMinutes(v);
                }}
                placeholder="—"
                className="w-24 rounded-lg border border-outline-variant bg-surface-container-low px-3 py-2 text-center font-mono text-[15px] text-on-surface outline-none focus:border-primary"
              />
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
      className={`min-w-[64px] rounded-lg border-2 px-3 py-2.5 text-[14px] font-semibold transition-all ${
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
