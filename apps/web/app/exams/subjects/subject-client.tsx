'use client';

/**
 * Subject Selection, the Stitch jamb_subject_selection_light screen,
 * 1:1.
 *
 * The JAMB Requirements card (uppercase caption, emerald Selected 2/4
 * counter, English mandatory pill, progress rail), the Available
 * Subjects list with syllabus-coverage bar glyphs, mandatory Use of
 * English locked on, the 4-subject cap with dimmed leftovers, and the
 * Start Mock Exam button that arms only at 4/4. Start launches the
 * primary pack's player.
 */

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const MAX_SELECTIONS = 4;

interface Subject {
  id: string;
  name: string;
  icon: string;
  covered: number;
  total: number;
  amber?: boolean;
  mandatory?: boolean;
}

const SUBJECTS: Subject[] = [
  { id: 'english', name: 'Use of English', icon: 'menu_book', covered: 3, total: 3, mandatory: true },
  { id: 'math', name: 'Mathematics', icon: 'calculate', covered: 2, total: 3 },
  { id: 'physics', name: 'Physics', icon: 'psychology', covered: 3, total: 3 },
  { id: 'chemistry', name: 'Chemistry', icon: 'science', covered: 1, total: 3, amber: true },
  { id: 'biology', name: 'Biology', icon: 'biotech', covered: 0, total: 3 },
];

export default function SubjectSelectionClient({ startCode }: { startCode: string }) {
  const router = useRouter();
  // The Stitch initial state: English (mandatory) + Physics pre-selected.
  const [selected, setSelected] = useState<Set<string>>(new Set(['english', 'physics']));

  const full = selected.size === MAX_SELECTIONS;
  const progress = selected.size / MAX_SELECTIONS;

  function toggle(id: string) {
    if (id === 'english') return; // English mandatory (design + JAMB rules)
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else if (next.size < MAX_SELECTIONS) {
        next.add(id);
      }
      return next;
    });
  }

  function start() {
    if (!full) return;
    if (startCode) {
      router.push(`/exams/${startCode}`);
    } else {
      router.push('/dashboard#packs');
    }
  }

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16">
      <PageBar title="Subject Selection" backHref="/exams/setup" />

      <div className="mx-auto flex w-full max-w-5xl flex-col px-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl pb-8 pt-4">
          {/* JAMB Requirements card */}
          <div className="flex flex-col gap-3 rounded-[12px] bg-surface-container p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-end justify-between gap-3">
              <div className="flex min-w-0 flex-col gap-1">
                <span className="font-mono text-[13px] uppercase tracking-wider text-on-surface-variant">
                  JAMB Requirements
                </span>
                <h2 className="flex items-center gap-2 text-[20px] font-bold leading-7 tracking-[-0.01em] text-on-surface">
                  Selected:{' '}
                  <span className={full ? 'font-bold text-primary' : 'text-accent-emerald'}>
                    {selected.size}/{MAX_SELECTIONS}
                  </span>
                </h2>
              </div>
              <div className="flex shrink-0 items-center gap-1.5 rounded-full bg-surface-container-highest px-3 py-1">
                <span className="material-symbols-outlined text-[14px] text-on-surface-variant">info</span>
                <span className="font-mono text-[11px] text-on-surface-variant">English mandatory</span>
              </div>
            </div>
            <div className="h-1.5 w-full overflow-hidden rounded-full bg-surface-variant">
              <div
                className={`h-full rounded-full transition-all duration-300 ease-out ${full ? 'bg-primary' : 'bg-accent-emerald'}`}
                style={{ width: `${Math.round(progress * 100)}%` }}
              />
            </div>
          </div>

          {/* Available Subjects header */}
          <div className="mb-3 mt-6 flex items-center justify-between">
            <h3 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-background">
              Available Subjects
            </h3>
            <span className="text-[13px] font-normal text-on-surface-variant">Tap to select</span>
          </div>

          {/* Subject rows */}
          <div className="flex flex-col gap-3">
            {SUBJECTS.map((s) => {
              const isSelected = selected.has(s.id);
              const dimmed = !isSelected && full && !s.mandatory;
              const tileColor = s.mandatory
                ? 'bg-primary text-on-primary'
                : isSelected
                  ? 'bg-accent-emerald text-white'
                  : 'bg-surface-container text-on-surface-variant';
              return (
                <button
                  key={s.id}
                  type="button"
                  aria-pressed={isSelected}
                  onClick={() => toggle(s.id)}
                  className={`flex w-full items-center justify-between overflow-hidden rounded-[12px] p-4 text-left shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition-all ${
                    isSelected || s.mandatory
                      ? `bg-surface-container ${s.mandatory ? 'border-2 border-primary' : 'border-2 border-accent-emerald'}`
                      : 'border border-transparent bg-card hover:bg-surface-container-low'
                  } ${dimmed ? 'opacity-50 grayscale' : ''}`}
                >
                  <span className="flex items-center gap-4">
                    <span
                      className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-[10px] shadow-sm ${tileColor}`}
                    >
                      <span className={`material-symbols-outlined ${isSelected || s.mandatory ? 'fill-current' : ''}`}>
                        {s.icon}
                      </span>
                    </span>
                    <span className="flex flex-col">
                      <span className="text-[16px] font-semibold text-on-surface">{s.name}</span>
                      <span className="mt-0.5 flex items-center gap-1.5">
                        {s.mandatory ? (
                          <>
                            <span className="h-1.5 w-1.5 rounded-full bg-accent-amber" />
                            <span className="text-[13px] text-on-surface-variant">Mandatory</span>
                          </>
                        ) : (
                          <>
                            <span className="flex gap-0.5">
                              {Array.from({ length: s.total }, (_, i) => (
                                <span
                                  key={i}
                                  className={`h-3 w-1.5 rounded-[1px] ${
                                    i < s.covered
                                      ? s.amber
                                        ? 'bg-accent-amber'
                                        : 'bg-accent-emerald'
                                      : 'bg-surface-variant'
                                  }`}
                                />
                              ))}
                            </span>
                            <span className="text-[13px] text-on-surface-variant">
                              {Math.round((s.covered / s.total) * 100)}% Syllabus
                            </span>
                          </>
                        )}
                      </span>
                    </span>
                  </span>
                  <span
                    className={`flex h-6 w-6 items-center justify-center rounded-full border transition-colors ${
                      isSelected || s.mandatory
                        ? s.mandatory
                          ? 'border-transparent bg-primary text-on-primary'
                          : 'border-transparent bg-accent-emerald text-white'
                        : 'border-outline-light'
                    }`}
                  >
                    {(isSelected || s.mandatory) && (
                      <span className="material-symbols-outlined fill-current text-[14px]">check</span>
                    )}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Sticky Start Mock Exam */}
      <div className="pointer-events-none fixed bottom-16 inset-x-0 z-30 bg-gradient-to-t from-background via-background/90 to-transparent px-4 pb-6 pt-8 md:bottom-4">
        <div className="mx-auto w-full max-w-2xl">
          <button
            type="button"
            onClick={start}
            disabled={!full}
            className={`pointer-events-auto flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] text-[15px] font-semibold transition-all ${
              full
                ? 'bg-primary text-on-primary shadow-md active:scale-[0.98]'
                : 'cursor-not-allowed bg-primary/40 text-on-primary/50'
            }`}
          >
            <span className={`material-symbols-outlined text-[20px] ${full ? 'fill-current' : ''}`}>
              rocket_launch
            </span>
            Start Mock Exam
          </button>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}
