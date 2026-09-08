'use client';

/**
 * CoursePractice — the per-course desk, a faithful (and sharper) rebuild
 * of the school CBT portal's course page: a Random Mode card that shuffles
 * the whole bank, and the Part grid slicing the course into 50-question
 * chunks IN ORIGINAL ORDER (Part 2 is exactly Q51–Q100), with the count
 * and timer picks the portals offer before a sitting.
 */

import { useMemo, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import type { School, UniversityCourse } from '@/lib/university-data';
import { PART_SIZE, partCount, partHref, partRange, randomHref } from '@/lib/university';

const TIMER_PRESETS = [0, 15, 30, 60] as const;
const COUNT_PRESETS = [25, 50, 100] as const;

export function CoursePractice({ school, course }: { school: School; course: UniversityCourse }) {
  const [timer, setTimer] = useState<number>(0);
  const [randomCount, setRandomCount] = useState<number>(50);

  const total = course.questionCount;
  const parts = useMemo(() => partCount(total), [total]);
  const bank = course.bank!;

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-60">
      <PageBar title={course.code} backHref={`/university/${school.slug}`} />

      <div className="mx-auto w-full max-w-5xl px-4 py-5 sm:px-6">
        {/* Course header ------------------------------------------------ */}
        <section className="relative overflow-hidden rounded-xl bg-hero p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] sm:p-6">
          <div className="absolute -right-14 -top-14 h-36 w-36 rounded-full bg-on-hero/10" />
          <div className="relative z-10 flex items-start gap-4">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-on-hero/15 text-on-hero">
              <span className="material-symbols-outlined text-[26px]">{course.icon}</span>
            </div>
            <div className="min-w-0">
              <p className="font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-hero-muted">
                {school.short} · {course.semester === 1 ? 'First Semester' : 'Second Semester'}
              </p>
              <h2 className="mt-0.5 text-2xl font-bold tracking-tight text-on-hero sm:text-3xl">
                {course.code}
              </h2>
              {course.title && (
                <p className="mt-0.5 text-sm font-semibold text-hero-muted">{course.title}</p>
              )}
            </div>
          </div>
          <p className="relative z-10 mt-3 font-mono text-xs text-hero-muted">
            {total.toLocaleString()} questions in the bank
          </p>
        </section>

        {/* Random Mode --------------------------------------------------- */}
        <section className="mt-6">
          <h3 className="text-sm font-semibold text-on-surface">Random Mode</h3>
          <p className="text-xs text-on-surface-variant">
            Full shuffle — questions drawn from the whole course in random order.
          </p>
          <div className="mt-3 rounded-xl border border-outline-variant bg-card p-4">
            <div className="flex flex-wrap items-center gap-2">
              <span className="mr-1 text-xs text-on-surface-variant">Questions</span>
              {COUNT_PRESETS.map((n) => (
                <button
                  key={n}
                  type="button"
                  onClick={() => setRandomCount(n)}
                  className={`rounded-full px-4 py-1.5 font-mono text-sm transition ${
                    randomCount === n
                      ? 'bg-primary font-semibold text-on-primary shadow-sm'
                      : 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container'
                  }`}
                >
                  {n}
                </button>
              ))}
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <span className="mr-1 text-xs text-on-surface-variant">Timer</span>
              {TIMER_PRESETS.map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setTimer(t)}
                  className={`rounded-full px-4 py-1.5 font-mono text-sm transition ${
                    timer === t
                      ? 'bg-primary font-semibold text-on-primary shadow-sm'
                      : 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container'
                  }`}
                >
                  {t === 0 ? 'Untimed' : `${t} min`}
                </button>
              ))}
            </div>
            <a
              href={randomHref(bank, Math.min(randomCount, total), timer || undefined)}
              className="mt-4 flex h-12 items-center justify-center gap-2 rounded-[10px] bg-hero-cta text-[15px] font-semibold text-on-hero-cta shadow-md transition-transform active:scale-[0.98]"
            >
              <span className="material-symbols-outlined text-[20px]">shuffle</span>
              Start {Math.min(randomCount, total)} random questions
            </a>
          </div>
        </section>

        {/* Part grid ------------------------------------------------------ */}
        <section className="mt-8">
          <h3 className="text-sm font-semibold text-on-surface">Practice by Part</h3>
          <p className="text-xs text-on-surface-variant">
            The course cut into {PART_SIZE}-question chunks, in the same order the portal numbers
            them — Part 2 is exactly Q{PART_SIZE + 1}–Q{Math.min(PART_SIZE * 2, total)}.
          </p>
          <ul className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: parts }, (_, i) => i + 1).map((p) => {
              const { from, to } = partRange(p, total);
              return (
                <li key={p}>
                  <a
                    href={partHref(bank, p, total, timer || undefined)}
                    className="flex items-center gap-3 rounded-xl border border-outline-variant bg-card p-3 transition hover:border-outline hover:shadow-sm"
                  >
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-surface-container text-on-surface">
                      <span className="material-symbols-outlined text-[20px]">grid_view</span>
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-bold text-on-surface">Part {p}</p>
                      <p className="font-mono text-[11px] text-on-surface-variant">
                        Q{from}–Q{to} · {to - from + 1} questions
                      </p>
                    </div>
                    <span className="material-symbols-outlined text-on-surface-variant">
                      chevron_right
                    </span>
                  </a>
                </li>
              );
            })}
          </ul>
        </section>

        {/* Course PDF ------------------------------------------------------ */}
        {course.pdf && (
          <section className="mt-8">
            <h3 className="text-sm font-semibold text-on-surface">Course Material</h3>
            <a
              href={course.pdf}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-3 flex items-center gap-3 rounded-xl border border-outline-variant bg-card p-3 transition hover:border-outline"
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-surface-container text-on-surface">
                <span className="material-symbols-outlined text-[20px]">picture_as_pdf</span>
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-on-surface">
                  {course.code} — study notes (PDF)
                </p>
                <p className="text-xs text-on-surface-variant">Opens in a new tab</p>
              </div>
              <span className="material-symbols-outlined text-on-surface-variant">open_in_new</span>
            </a>
          </section>
        )}
      </div>
      <SideNav />
      <BottomNav />
    </main>
  );
}
