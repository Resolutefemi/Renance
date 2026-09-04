'use client';

/**
 * Arena live match, the Stitch arena_match_light screen.
 * A local 5-question duel simulation: the 42s round clock, the LIVE
 * question card ("LIVE · first to 5"), option rows with your ink chip and
 * the opponent's gray chip, the "answered in" caption and the "Answer
 * locks in" bottom rail. Founder rule: no purple, the opponent accent is
 * the gray secondary.
 */

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import BottomNav from '@/components/bottom-nav';

interface MatchQ {
  topic: string;
  stem: string;
  options: string[];
  correct: number;
}

const QUESTIONS: MatchQ[] = [
  { topic: 'Biology', stem: 'Which organelle is known as the powerhouse of the cell?', options: ['Ribosome', 'Mitochondrion', 'Golgi apparatus', 'Nucleolus'], correct: 1 },
  { topic: 'Biology', stem: 'Which blood cells carry oxygen?', options: ['Platelets', 'Rods', 'Red cells', 'White cells'], correct: 2 },
  { topic: 'Biology', stem: 'Photosynthesis mainly occurs in the:', options: ['Mitochondria', 'Chloroplasts', 'Vacuole', 'Nucleus'], correct: 1 },
  { topic: 'Biology', stem: 'The basic unit of heredity is the:', options: ['Enzyme', 'Protein', 'Cell', 'Gene'], correct: 3 },
  { topic: 'Biology', stem: 'Which vitamin is produced in the skin by sunlight?', options: ['Vitamin A', 'Vitamin C', 'Vitamin D', 'Vitamin K'], correct: 2 },
];

const mmss = (s: number) => `0:${String(s).padStart(2, '0')}`;

export default function ArenaMatchPage() {
  const router = useRouter();
  const [index, setIndex] = useState(0);
  const [you, setYou] = useState(3);
  const [rival, setRival] = useState(2);
  const [yourPick, setYourPick] = useState<number | null>(null);
  const [rivalPick, setRivalPick] = useState<number | null>(null);
  const [roundLeft, setRoundLeft] = useState(42);
  const [lockLeft, setLockLeft] = useState(12);
  const [rivalNote, setRivalNote] = useState('');
  const lockRef = useRef<(pick: number) => void>(() => {});

  const q = QUESTIONS[index];

  // round lifecycle
  useEffect(() => {
    setYourPick(null);
    setRivalPick(null);
    setRivalNote('');
    setRoundLeft(42);
    setLockLeft(12);
    const beat = 2000 + ((index * 37) % 9) * 1000;
    const t = setTimeout(() => {
      setRivalPick((index + 1) % 4);
      setRivalNote(
        `Tunde answered in ${(1.2 + index * 0.7).toFixed(1)}s. Tap your answer to lock it`,
      );
    }, beat);
    return () => clearTimeout(t);
  }, [index]);

  useEffect(() => {
    const t = setInterval(() => {
      setRoundLeft((s) => (s > 0 ? s - 1 : 0));
      setLockLeft((s) => (s > 0 ? s - 1 : 0));
    }, 1000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (roundLeft === 0 && yourPick === null) lockRef.current(-1);
  }, [roundLeft, yourPick]);

  const lock = (pick: number) => {
    if (yourPick !== null) return;
    setYourPick(pick);
    if (pick === q.correct) setYou((v) => v + 1);
    if (rivalPick === q.correct) setRival((v) => v + 1);
    setTimeout(() => {
      setIndex((i) => (i >= QUESTIONS.length - 1 ? 0 : i + 1));
    }, 2000);
  };
  lockRef.current = lock;

  return (
    <main className="flex min-h-dvh flex-col bg-background">
      <div className="mx-auto w-full max-w-2xl flex-1 px-4 pb-28 sm:px-6">
        {/* scoreboard */}
        <div className="flex items-center pt-4">
          <button
            onClick={() => router.push('/arena')}
            aria-label="Leave match"
            className="flex h-10 w-10 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-[24px]">chevron_left</span>
          </button>
          <span className="ml-1 flex h-9 w-9 items-center justify-center rounded-full bg-primary font-mono text-[13px] font-bold text-on-primary">Y</span>
          <span className="ml-2 text-[17px] font-semibold text-on-surface">You</span>
          <span className="mx-auto text-[22px] font-bold tracking-tight text-on-surface">{you} — {rival}</span>
          <span className="text-[17px] font-semibold text-on-surface">Tunde</span>
          <span className="ml-2 flex h-9 w-9 items-center justify-center rounded-full bg-secondary font-mono text-[13px] font-bold text-white">T</span>
          <span className="ml-2.5 flex items-center gap-1 rounded-full bg-amber-tint px-2.5 py-1.5 font-mono text-xs text-accent-amber">
            <span className="material-symbols-outlined text-[15px]">timer</span>
            {mmss(roundLeft)}
          </span>
        </div>

        {/* round rail */}
        <div className="mt-4 flex items-center gap-3">
          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-container-high">
            <div
              className="h-full rounded-full bg-primary transition-all"
              style={{ width: `${((index + 1) / QUESTIONS.length) * 100}%` }}
            />
          </div>
          <span className="text-[15px] text-on-surface">Q{index + 1}/5</span>
        </div>

        {/* question card */}
        <section className="mt-4 rounded-2xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center justify-between">
            <span className="rounded-full bg-selection-blue px-3.5 py-2 text-[15px] font-semibold text-on-surface">
              {q.topic}
            </span>
            <span className="font-mono text-[11px] uppercase tracking-wide text-on-surface-variant">
              LIVE · first to 5
            </span>
          </div>
          <h1 className="mt-3.5 text-xl font-semibold leading-7 tracking-tight text-on-surface">
            {q.stem}
          </h1>
        </section>

        {/* options */}
        <div className="mt-4 space-y-2.5">
          {q.options.map((opt, i) => {
            const mine = yourPick === i;
            const theirs = rivalPick === i && !mine;
            return (
              <button
                key={opt}
                onClick={() => lock(i)}
                disabled={yourPick !== null}
                className={`flex w-full items-center gap-3 rounded-2xl border p-2.5 text-left transition ${
                  mine
                    ? 'border-[1.5px] border-primary bg-selection-blue'
                    : 'border-outline-light bg-card'
                }`}
              >
                <span
                  className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-bold ${
                    mine ? 'bg-primary text-on-primary' : 'bg-surface-container-low text-on-surface'
                  }`}
                >
                  {String.fromCharCode(65 + i)}
                </span>
                <span className={`flex-1 text-base ${mine ? 'font-bold text-on-surface' : 'font-semibold text-on-surface'}`}>
                  {opt}
                </span>
                {mine && (
                  <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary font-mono text-[11px] font-bold text-on-primary">Y</span>
                )}
                {theirs && (
                  <span className="flex h-7 w-7 items-center justify-center rounded-full bg-secondary font-mono text-[11px] font-bold text-white">T</span>
                )}
              </button>
            );
          })}
        </div>

        <p className="mt-3 text-center text-[15px] text-on-surface-variant">
          {rivalNote || 'Tap your answer to lock it'}
        </p>
      </div>

      {/* Answer locks in */}
      <div className="fixed inset-x-0 bottom-0 border-t border-outline-light/40 bg-card px-4 pb-24 pt-3 sm:px-6">
        <div className="mx-auto w-full max-w-2xl">
          <div className="flex items-center justify-between">
            <p className="text-[15px] font-semibold text-on-surface">Answer locks in</p>
            <p className="font-mono text-[13px] text-accent-amber">{mmss(lockLeft)}</p>
          </div>
          <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-surface-container-high">
            <div
              className="h-full rounded-full bg-accent-amber transition-all"
              style={{ width: `${(lockLeft / 12) * 100}%` }}
            />
          </div>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}
