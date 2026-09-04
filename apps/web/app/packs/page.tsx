'use client';

/**
 * Question Pack, the small launcher behind the packs.
 *
 * The founder pulled the big pack cards off the home page and off the
 * Exams flow ("trash"), so the packs live behind one small Question
 * Pack icon for now. This page is that home: a compact, scannable
 * list of every pack in the manifest with a one-tap route into the
 * Practice Settings flow (/exams/practice?pack=code).
 */

import { useEffect, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import { fetchManifest, type ExamMeta } from '@/lib/exams';

export default function PacksPage() {
  const [exams, setExams] = useState<ExamMeta[] | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let alive = true;
    fetchManifest()
      .then((m) => {
        if (alive) setExams(m.exams);
      })
      .catch(() => {
        if (alive) setFailed(true);
      });
    return () => {
      alive = false;
    };
  }, []);

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Question Pack" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Question Pack
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          Every past question pack on this device, ready to practice.
        </p>

        {failed && (
          <p className="mt-6 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
            Could not reach Renance servers. Check your connection and try again.
          </p>
        )}

        {!exams && !failed && (
          <div className="flex justify-center py-16">
            <LogoActivityIndicator state="busy" label="Loading your question packs…" />
          </div>
        )}

        {exams && exams.length === 0 && (
          <p className="mt-8 text-center text-[15px] text-on-surface-variant">
            No packs yet. Set your target exam and sync to get your first pack.
          </p>
        )}

        {exams && exams.length > 0 && (
          <ul className="mt-6 flex flex-col gap-3">
            {exams.map((exam) => (
              <li key={exam.code}>
                <a
                  href={`/exams/practice?pack=${encodeURIComponent(exam.code)}`}
                  className="flex items-center gap-4 rounded-[12px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] transition hover:shadow-md"
                >
                  <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[12px] bg-surface-container-high text-on-surface">
                    <span className="material-symbols-outlined fill-current text-[24px]">
                      inventory_2
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[15px] font-semibold text-on-surface">
                      {exam.title}
                    </p>
                    <p className="mt-0.5 font-mono text-[12px] text-on-surface-variant">
                      {exam.questionCount} Q
                      {exam.durationMinutes ? ` · ${exam.durationMinutes} min` : ''} ·{' '}
                      {exam.totalMarks} marks
                    </p>
                  </div>
                  <span className="material-symbols-outlined text-[20px] text-outline">
                    chevron_right
                  </span>
                </a>
              </li>
            ))}
          </ul>
        )}
      </div>

      <BottomNav />
    </main>
  );
}
