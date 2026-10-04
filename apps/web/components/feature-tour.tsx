'use client';

/**
 * FeatureTour: the new-student walkthrough (founder directive,
 * 2026-09-30). Shows once per account on the dashboard - a stack of
 * cards that makes every Renance surface discoverable before the first
 * study session, with a Skip button always in reach and Back/Next
 * controls. The dismissed state persists in localStorage.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';

const TOUR_KEY = 'renance.tour.v1';

interface Step {
  icon: string;
  tint?: string;
  title: string;
  body: string;
  cta?: { label: string; href: string };
}

const STEPS: Step[] = [
  {
    icon: 'school',
    title: 'Welcome to Renance',
    body: 'Your study OS for JAMB, WAEC, NECO, Post-UTME and university - 235,110+ real past questions, spaced review, and an AI that was raised on all of it. Here is the tour.',
  },
  {
    icon: 'edit_note',
    title: 'Practice with real past questions',
    body: 'Pick your exam body and subject, then drill actual past papers year by year. Every question carries a worked explanation on the review screen.',
    cta: { label: 'Open Packs', href: '/packs' },
  },
  {
    icon: 'auto_awesome',
    title: 'Renance AI Studio',
    body: 'Chat with an AI grounded on the full past-question corpus, generate playable quizzes, study notes, NotebookLM-style notebooks and school lesson notes - all exportable as PDF, with folders, history and memories that follow your account.',
    cta: { label: 'Open the Studio', href: '/ai' },
  },
  {
    icon: 'auto_stories',
    title: 'Notes that write themselves',
    body: 'Every note, notebook and lesson note the AI generates lands on your Notes page, ready to open, download as PDF or share with classmates.',
    cta: { label: 'Open Notes', href: '/notes' },
  },
  {
    icon: 'history_edu',
    title: 'Review that never forgets',
    body: 'Wrong answers come back on a spaced-repetition schedule, and every paper you sit lands in your history with a full report - pace, accuracy, topics.',
    cta: { label: 'Open Review', href: '/review' },
  },
  {
    icon: 'swords',
    title: 'Duel and climb',
    body: 'Challenge friends to live 1v1 arena duels, take the daily quiz, and climb the leaderboards. Wins earn REN you can redeem for premium.',
    cta: { label: 'Open Arena', href: '/arena' },
  },
  {
    icon: 'rocket_launch',
    title: 'You are all set',
    body: 'Set your learning focus in Profile whenever your target changes - the whole app reshapes around it. Happy studying, scholar.',
    cta: { label: 'Start studying', href: '/packs' },
  },
];

export default function FeatureTour() {
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState(0);

  useEffect(() => {
    try {
      if (window.localStorage.getItem(TOUR_KEY) !== 'done') {
        // Tiny delay so the dashboard paints first.
        const t = window.setTimeout(() => setOpen(true), 900);
        return () => window.clearTimeout(t);
      }
    } catch {
      /* storage blocked: never block the dashboard on it */
    }
  }, []);

  function dismiss() {
    try {
      window.localStorage.setItem(TOUR_KEY, 'done');
    } catch {
      /* private mode: the tour just will not re-show this session */
    }
    setOpen(false);
  }

  if (!open) return null;
  const s = STEPS[step];
  const last = step === STEPS.length - 1;

  return (
    <div
      className="fixed inset-0 z-[70] flex items-end justify-center bg-on-background/70 backdrop-blur-sm sm:items-center"
      role="dialog"
      aria-label="Renance feature tour"
      onClick={dismiss}
    >
      <div
        className="renance-rise w-full max-w-md rounded-t-2xl bg-surface-container-lowest p-6 shadow-xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-primary text-on-primary">
            <span className="material-symbols-outlined text-[24px]">{s.icon}</span>
          </div>
          <button
            type="button"
            onClick={dismiss}
            className="rounded-full px-3 py-1.5 font-mono text-[11px] font-semibold uppercase tracking-wider text-on-surface-variant transition hover:bg-surface-container"
          >
            Skip
          </button>
        </div>

        <div className="mt-4 flex items-center gap-1.5">
          {STEPS.map((_, i) => (
            <span
              key={i}
              className={`h-1.5 rounded-full transition-all ${i === step ? 'w-6 bg-primary' : 'w-1.5 bg-outline-variant/60'}`}
            />
          ))}
          <span className="ml-auto font-mono text-[10.5px] text-on-surface-variant">
            {step + 1}/{STEPS.length}
          </span>
        </div>

        <h3 className="mt-3 text-xl font-bold tracking-tight text-on-surface">{s.title}</h3>
        <p className="mt-2 text-[13.5px] leading-relaxed text-on-surface-variant">{s.body}</p>

        <div className="mt-5 flex items-center gap-2">
          {step > 0 && (
            <button
              type="button"
              onClick={() => setStep((v) => v - 1)}
              className="rounded-xl border border-outline-variant/70 px-4 py-3 text-[13px] font-semibold text-on-surface transition hover:border-primary/40"
            >
              Back
            </button>
          )}
          {s.cta && !last && (
            <Link
              href={s.cta.href}
              onClick={dismiss}
              className="flex-1 rounded-xl border border-outline-variant/70 py-3 text-center text-[13px] font-semibold text-on-surface"
            >
              {s.cta.label}
            </Link>
          )}
          {last ? (
            <button
              type="button"
              onClick={dismiss}
              className="flex-1 rounded-xl bg-primary py-3 text-[13.5px] font-semibold text-on-primary transition active:scale-[0.98]"
            >
              {s.cta?.label ?? 'Start studying'}
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setStep((v) => v + 1)}
              className="flex-1 rounded-xl bg-primary py-3 text-[13.5px] font-semibold text-on-primary transition active:scale-[0.98]"
            >
              Next
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
