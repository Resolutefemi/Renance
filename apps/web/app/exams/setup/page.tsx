'use client';

/**
 * Mock Exam Setup, the Stitch exam_mode_setup_light screen — now the
 * ONE place a mock is configured and launched.
 *
 * Exam Format card (Standard UTME Mock with the 2 Hours / 4 Subjects
 * chips, Custom Practice secondary), the Subject Selection card with
 * Use of English locked on and exactly 3 electives to pick, live bank
 * sizes from the manifest, the official-timing notice and the sticky
 * Begin Mock Exam button. Begin talks to the exam backend: it seats an
 * attempt for the canonical composite paper code and deep-links
 * straight into the sitting — no intermediate selection page.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { api } from '@/lib/api';
import {
  fetchManifest,
  mockPaperCode,
  UTME_ELECTIVES,
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
  const [bankSizes, setBankSizes] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Live bank sizes keep the setup honest: the candidate sees how
    // many real past questions stand behind each subject.
    fetchManifest()
      .then((m) => {
        const sizes: Record<string, number> = {};
        for (const exam of m.exams) {
          if (exam.code.startsWith('jamb-') && exam.code.endsWith('-bank')) {
            sizes[exam.code.replace('jamb-', '').replace('-bank', '')] =
              exam.questionCount;
          }
        }
        setBankSizes(sizes);
      })
      .catch(() => {}); // cosmetic only; the setup works without it
  }, []);

  const full = selected.size === 3;

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

  async function begin() {
    if (!standard) {
      // Custom Practice hands over to the question packs, where topics,
      // packs and timers are already configurable.
      router.push('/packs');
      return;
    }
    if (!full || busy) return;
    setBusy(true);
    setError(null);
    try {
      const code = mockPaperCode([...selected]);
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
        title: 'UTME Mock',
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
      router.push(`/exams/${res.code}?resume=1`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not start the mock');
      setBusy(false);
    }
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
                  <span className="text-[13px] text-text-secondary">Choose specific packs, topics and time limits.</span>
                </span>
              </button>
            </div>
          </section>

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
                const count = bankSizes[s.id];
                return (
                  <button
                    key={s.id}
                    type="button"
                    aria-pressed={isSelected}
                    onClick={() => toggle(s.id)}
                    className={`flex items-center justify-between rounded-lg p-2 text-left ${
                      s.mandatory
                        ? 'border border-outline-variant/30 bg-surface-container-low/50'
                        : dimmed
                          ? 'opacity-45 grayscale'
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
                          {s.mandatory
                            ? 'Mandatory'
                            : count != null
                              ? `${count} past questions`
                              : 'Tap to select'}
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
                );
              })}
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
            onClick={() => void begin()}
            disabled={standard && (!full || busy)}
            className={`flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] text-[15px] font-semibold transition-all ${
              standard && (!full || busy)
                ? 'cursor-not-allowed bg-primary/40 text-on-primary/50'
                : 'bg-primary text-on-primary shadow-md active:scale-[0.98]'
            }`}
          >
            {standard ? (
              <>
                {busy ? 'Seating your paper…' : 'Begin Mock Exam'}
                {!busy && <span className="material-symbols-outlined text-[20px]">arrow_forward</span>}
              </>
            ) : (
              <>
                Browse Question Packs
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
