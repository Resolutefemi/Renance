'use client';

/**
 * Mock Exam Setup — the ONE place a paper is configured and launched.
 *
 * Standard UTME Mock: Use of English locked on + exactly 3 electives,
 * a per-subject year picker (Random by default, exactly like the real
 * "treat a past paper" flow), English passage controls (comprehension
 * on/off + how many) and the official-timing notice.
 *
 * Custom Practice: any number of subjects (English toggleable), the
 * question count, your own timer and a particular year or random —
 * composed server-side from the same banks, so grading and resume
 * stay honest.
 */

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { api } from '@/lib/api';
import {
  buildCustomCode,
  buildMockCode,
  examHref,
  fetchManifest,
  migrateBundleCache,
  UTME_ELECTIVES,
  type Manifest,
} from '@/lib/exams';
import { saveActiveExam } from '@/lib/active-exam';

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
    letterClass: 'text-accent-ink',
    avatarClass: 'bg-accent-ink/10',
    mandatory: true,
  },
  ...UTME_ELECTIVES.map((e, i) => ({
    id: e.slug,
    name: e.name,
    letter: e.name[0],
    letterClass: ['text-accent-emerald', 'text-accent-amber', 'text-secondary', 'text-accent-ink', 'text-accent-emerald', 'text-accent-amber', 'text-secondary'][i % 7],
    avatarClass: ['bg-accent-emerald/10', 'bg-accent-amber/10', 'bg-secondary-container', 'bg-accent-ink/10', 'bg-accent-emerald/10', 'bg-accent-amber/10', 'bg-secondary-container'][i % 7],
  })),
];

interface AttemptResponse {
  attemptId: string;
  code: string;
  startedAt: string;
  questionCount?: number;
}

export default function ExamSetupPage() {
  const router = useRouter();
  const [standard, setStandard] = useState(true);
  // English is mandatory and locked on (JAMB rules); the Stitch initial
  // state pre-selects Mathematics + Physics + Chemistry.
  const [selected, setSelected] = useState<Set<string>>(
    new Set(['mathematics', 'physics', 'chemistry']),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // year pickers: subject slug -> exam year, null = Random (the default)
  const [yearFor, setYearFor] = useState<Record<string, number | null>>({});
  // English section controls (standard mock). Comprehension and the
  // JAMB novel both default OFF — the candidate opts IN, the same way
  // the hall ask works ("do you want the novel this year?").
  const [englishSize, setEnglishSize] = useState(60);
  const [comprehension, setComprehension] = useState(false);
  const [compCount, setCompCount] = useState(10);
  const [novel, setNovel] = useState(false);
  // Custom Practice panel
  const [customSubjects, setCustomSubjects] = useState<Set<string>>(
    new Set(['english', 'mathematics', 'physics', 'chemistry']),
  );
  const [customCount, setCustomCount] = useState(40);
  const [customMinutes, setCustomMinutes] = useState<number | ''>('');
  const [customYear, setCustomYear] = useState<number | null>(null);

  // Years per bank come from the manifest (no question counts shown here).
  const [years, setYears] = useState<Record<string, number[]>>({});
  useEffect(() => {
    migrateBundleCache(); // heal quota-struck localStorage on first entry
    let alive = true;
    fetchManifest()
      .then((m: Manifest) => {
        if (!alive) return;
        const map: Record<string, number[]> = {};
        for (const e of m.exams) {
          const hit = /^jamb-(.+)-bank$/.exec(e.code);
          if (hit && e.years?.length) map[hit[1]] = e.years;
        }
        setYears(map);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  const full = selected.size === 3;
  const customFull = customSubjects.size >= 1;

  /** Union of years across the custom subjects (for the custom picker). */
  const customYearPool = useMemo(() => {
    const s = new Set<number>();
    for (const slug of customSubjects) (years[slug] ?? []).forEach((y) => s.add(y));
    return [...s].sort((a, b) => b - a);
  }, [customSubjects, years]);

  function toggle(id: string) {
    if (id === 'english') return; // English mandatory (design + JAMB rules)
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else if (next.size < 3) {
        next.add(id);
      }
      return next;
    });
  }

  function toggleCustom(id: string) {
    if (id === 'english' && customSubjects.size === 1) return; // keep one subject
    setCustomSubjects((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function seat(code: string, title: string) {
    setBusy(true);
    setError(null);
    try {
      const res = await api<AttemptResponse>('/attempts', {
        method: 'POST',
        body: { code },
      });
      // Seat the sitting locally, then walk straight into it: the
      // resume deep link rebuilds the exact attempt — JAMB style,
      // one paper at a time.
      saveActiveExam({
        attemptId: res.attemptId,
        code: res.code,
        title,
        questionCount: res.questionCount ?? 0,
        startedAt: Date.now(),
        pausedMs: 0,
        answers: {},
        flags: {},
        visited: {},
        current: 0,
        order: null,
        adaptive: false,
        untimed: false,
        timerMinutes: null,
        savedAt: Date.now(),
      });
      // examHref() routes composed codes (this one carries ~params) to
      // the static /exams/paper/?code=… page — a direct /exams/<code>
      // link 404s on the static export for any year-pinned paper.
      router.push(examHref(res.code, { resume: '1' }));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not start the paper');
      setBusy(false);
    }
  }

  function beginMock() {
    if (!full || busy) return;
    const subjects = ['english', ...[...selected].sort()];
    const yearsSpec = subjects.map((s) => yearFor[s] ?? null);
    const anyPinned = yearsSpec.some((y) => y != null);
    const code = buildMockCode([...selected], {
      years: anyPinned ? yearsSpec : null,
      englishSize: englishSize !== 60 ? englishSize : undefined,
      comprehension,
      comprehensionCount: comprehension && compCount !== 10 ? compCount : undefined,
      novel,
    });
    void seat(code, 'UTME Mock');
  }

  function beginCustom() {
    if (!customFull || busy) return;
    const code = buildCustomCode([...customSubjects], {
      count: customCount,
      year: customYear,
      timer: typeof customMinutes === 'number' ? customMinutes : 0,
    });
    void seat(code, 'Custom Practice');
  }

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Mock Exam Setup" />

      <div className="mx-auto flex w-full max-w-5xl flex-col px-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl">
          {/* Header Area */}
          <div className="flex flex-col gap-2 pb-4 pt-6">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-[24px] text-accent-ink">timer</span>
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
                  <span className="text-[13px] text-text-secondary">
                    Pick subjects, question count, your own timer and year.
                  </span>
                </span>
              </button>
            </div>
          </section>

          {standard ? (
            <>
              {/* Subject Selection card — English locked, exactly 3 electives */}
              <section className="mt-4 flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                <div className="flex items-center justify-between">
                  <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                    Subject Selection
                  </h2>
                  <span
                    className={`flex items-center gap-1 rounded-full px-2.5 py-1 font-mono text-[11px] transition ${
                      full
                        ? 'bg-accent-emerald/15 text-on-surface'
                        : 'bg-surface-container text-on-surface-variant'
                    }`}
                  >
                    {full ? 'English + 3 ✓' : `English + ${selected.size}/3`}
                  </span>
                </div>
                <div className="flex flex-col gap-2">
                  {SUBJECTS.map((s) => {
                    const isSelected = s.mandatory || selected.has(s.id);
                    const dimmed = !isSelected && full;
                    const yearPool = years[s.id] ?? [];
                    const year = yearFor[s.id] ?? null;
                    return (
                      <div
                        key={s.id}
                        className={`rounded-lg ${dimmed ? 'opacity-45 grayscale' : ''}`}
                      >
                        <button
                          type="button"
                          aria-pressed={isSelected}
                          onClick={() => toggle(s.id)}
                          className={`flex w-full items-center justify-between p-2 text-left ${
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
                              <span className="text-[11px] text-text-secondary">
                                {s.mandatory ? 'Mandatory' : 'Tap to select'}
                              </span>
                            </div>
                          </div>
                          <span
                            className={`flex h-6 w-6 items-center justify-center rounded-full transition-colors ${
                              isSelected
                                ? s.mandatory
                                  ? 'bg-primary text-on-primary'
                                  : 'bg-accent-emerald text-white'
                                : 'border border-outline-light'
                            }`}
                          >
                            {isSelected && (
                              <span className="material-symbols-outlined fill-current text-[14px]">check</span>
                            )}
                          </span>
                        </button>
                        {/* Year picker: Random by default, one row per selected subject */}
                        {isSelected && yearPool.length > 0 && (
                          <div className="mt-1 flex items-center gap-2 px-2 pb-1.5">
                            <span className="material-symbols-outlined text-[16px] text-outline">history</span>
                            <div className="no-scrollbar flex flex-1 gap-1.5 overflow-x-auto">
                              <YearChip
                                label="Random"
                                selected={year == null}
                                onClick={() => setYearFor((p) => ({ ...p, [s.id]: null }))}
                              />
                              {[...yearPool].reverse().map((y) => (
                                <YearChip
                                  key={y}
                                  label={String(y)}
                                  selected={year === y}
                                  onClick={() => setYearFor((p) => ({ ...p, [s.id]: y }))}
                                />
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </section>

              {/* English section controls */}
              <section className="mt-4 flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                  Use of English
                </h2>
                <div className="flex flex-col gap-2">
                  <ToggleRow
                    icon="menu_book"
                    label="English comprehension passages"
                    hint="Include passage-based questions in the English section (off by default)"
                    value={comprehension}
                    onChange={setComprehension}
                  />
                  {comprehension && (
                    <div className="flex items-center justify-between px-1 py-1.5">
                      <span className="text-[14px] text-on-surface-variant">
                        How many comprehension questions
                      </span>
                      <div className="flex items-center gap-2">
                        <StepperButton
                          icon="remove"
                          label="Fewer comprehension questions"
                          onClick={() => setCompCount((c) => Math.max(0, c - 5))}
                        />
                        <span className="w-9 text-center font-mono text-[15px] font-semibold text-on-surface">
                          {compCount}
                        </span>
                        <StepperButton
                          icon="add"
                          label="More comprehension questions"
                          onClick={() => setCompCount((c) => Math.min(30, c + 5))}
                        />
                      </div>
                    </div>
                  )}
                  <ToggleRow
                    icon="auto_stories"
                    label="JAMB novel questions"
                    hint="The Lekki Headmaster — the current JAMB recommended text (off by default)"
                    value={novel}
                    onChange={setNovel}
                  />
                  <div className="flex items-center justify-between px-1 py-1.5">
                    <span className="text-[14px] text-on-surface-variant">
                      English section size
                    </span>
                    <div className="flex items-center gap-2">
                      <StepperButton
                        icon="remove"
                        label="Smaller English section"
                        onClick={() => setEnglishSize((c) => Math.max(10, c - 10))}
                      />
                      <span className="w-9 text-center font-mono text-[15px] font-semibold text-on-surface">
                        {englishSize}
                      </span>
                      <StepperButton
                        icon="add"
                        label="Larger English section"
                        onClick={() => setEnglishSize((c) => Math.min(60, c + 10))}
                      />
                    </div>
                  </div>
                </div>
              </section>

              {/* Info notice */}
              <div className="mt-4 flex items-start gap-2 rounded-lg bg-surface-container-high p-3">
                <span className="material-symbols-outlined mt-0.5 text-[18px] text-outline">info</span>
                <p className="text-[13px] leading-[18px] text-on-surface-variant">
                  This environment simulates official JAMB timing and rules: one paper
                  at a time, answers lock once picked, and pausing is disabled once the
                  mock begins. Leaving mid-paper keeps your seat — the clock keeps running.
                </p>
              </div>
            </>
          ) : (
            <>
              {/* Custom subjects — English toggleable, any count */}
              <section className="mt-4 flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                <div className="flex items-center justify-between">
                  <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                    Subjects
                  </h2>
                  <span className="flex items-center rounded-full bg-surface-container px-2.5 py-1 font-mono text-[11px] text-on-surface-variant">
                    {customSubjects.size} picked
                  </span>
                </div>
                <div className="flex flex-wrap gap-2">
                  {SUBJECTS.map((s) => {
                    const on = customSubjects.has(s.id);
                    return (
                      <button
                        key={s.id}
                        type="button"
                        aria-pressed={on}
                        onClick={() => toggleCustom(s.id)}
                        className={`rounded-full px-3 py-1.5 text-[13px] transition ${
                          on
                            ? 'bg-primary font-semibold text-on-primary shadow-sm'
                            : 'bg-surface-container-low text-on-surface-variant hover:bg-surface-variant'
                        }`}
                      >
                        {s.name}
                      </button>
                    );
                  })}
                </div>
              </section>

              {/* Custom question count */}
              <section className="mt-4 flex flex-col gap-4 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                  Question Count
                </h2>
                <div className="flex items-center justify-between">
                  <StepperButton
                    icon="remove"
                    label="Fewer questions"
                    onClick={() => setCustomCount((c) => Math.max(5, c - 5))}
                  />
                  <span className="font-mono text-[26px] font-bold text-on-surface">{customCount}</span>
                  <StepperButton
                    icon="add"
                    label="More questions"
                    onClick={() => setCustomCount((c) => Math.min(200, c + 5))}
                  />
                </div>
                <div className="flex gap-2">
                  {[10, 20, 40, 60].map((p) => (
                    <button
                      key={p}
                      type="button"
                      onClick={() => setCustomCount(p)}
                      className={`flex-1 rounded-md py-2 text-center text-[14px] transition-colors ${
                        customCount === p
                          ? 'bg-selection-blue font-semibold text-on-surface'
                          : 'bg-surface-container-low text-on-surface hover:bg-surface-variant'
                      }`}
                    >
                      {p}
                    </button>
                  ))}
                </div>
              </section>

              {/* Custom timer */}
              <section className="mt-4 flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                  Time
                </h2>
                <div className="flex items-center justify-between px-1">
                  <span className="text-[14px] text-on-surface-variant">
                    Minutes (leave empty for untimed)
                  </span>
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
                <div className="flex gap-2">
                  {[15, 30, 60, 120].map((p) => (
                    <button
                      key={p}
                      type="button"
                      onClick={() => setCustomMinutes(p)}
                      className={`flex-1 rounded-md py-2 text-center text-[14px] transition-colors ${
                        customMinutes === p
                          ? 'bg-selection-blue font-semibold text-on-surface'
                          : 'bg-surface-container-low text-on-surface hover:bg-surface-variant'
                      }`}
                    >
                      {p}m
                    </button>
                  ))}
                </div>
              </section>

              {/* Custom year */}
              <section className="mt-4 flex flex-col gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                  Past Question Year
                </h2>
                {customYearPool.length === 0 ? (
                  <p className="text-[13px] text-on-surface-variant">
                    Pick a subject to see its available years.
                  </p>
                ) : (
                  <div className="no-scrollbar flex flex-wrap gap-1.5">
                    <YearChip
                      label="Random"
                      selected={customYear == null}
                      onClick={() => setCustomYear(null)}
                    />
                    {customYearPool.map((y) => (
                      <YearChip
                        key={y}
                        label={String(y)}
                        selected={customYear === y}
                        onClick={() => setCustomYear(y)}
                      />
                    ))}
                  </div>
                )}
              </section>
            </>
          )}

          {error && (
            <p className="mt-3 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
              {error}
            </p>
          )}
        </div>
      </div>

      {/* Sticky Bottom Action */}
      <div className="fixed bottom-16 inset-x-0 z-30 bg-gradient-to-t from-surface via-surface/90 to-transparent p-4 pb-6 md:bottom-4">
        <div className="mx-auto w-full max-w-2xl">
          <button
            type="button"
            onClick={() => (standard ? beginMock() : beginCustom())}
            disabled={busy || (standard ? !full : !customFull)}
            className={`flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] text-[15px] font-semibold transition-all ${
              busy || (standard ? !full : !customFull)
                ? 'cursor-not-allowed bg-primary/40 text-on-primary/50'
                : 'bg-primary text-on-primary shadow-md active:scale-[0.98]'
            }`}
          >
            {busy ? (
              'Seating your paper…'
            ) : standard ? (
              <>
                Begin Mock Exam
                <span className="material-symbols-outlined text-[20px]">arrow_forward</span>
              </>
            ) : (
              <>
                Start Custom Practice
                <span className="material-symbols-outlined text-[20px]">arrow_forward</span>
              </>
            )}
          </button>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}

/** Selection-blue year chip: "Random" or a pinned exam year. */
function YearChip({
  label,
  selected,
  onClick,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`shrink-0 rounded-full border px-2.5 py-1 font-mono text-[11px] transition ${
        selected
          ? 'border-primary bg-selection-blue font-semibold text-on-surface'
          : 'border-outline-variant/60 bg-surface-container-low text-on-surface-variant hover:bg-surface-variant'
      }`}
    >
      {label}
    </button>
  );
}

/** 36px round stepper button (remove / add). */
function StepperButton({ icon, onClick, label }: { icon: string; onClick: () => void; label: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-container-low text-on-surface transition-colors hover:bg-surface-variant"
    >
      <span className="material-symbols-outlined text-[18px]">{icon}</span>
    </button>
  );
}

/** Toggle row with an optional hint line. */
function ToggleRow({
  icon,
  label,
  hint,
  value,
  onChange,
}: {
  icon: string;
  label: string;
  hint?: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between rounded-lg px-1 py-1.5">
      <div className="flex items-center gap-3">
        <span className="material-symbols-outlined text-on-surface-variant">{icon}</span>
        <span className="flex flex-col">
          <span className="text-[14px] font-semibold text-on-surface">{label}</span>
          {hint && <span className="text-[11px] text-text-secondary">{hint}</span>}
        </span>
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
