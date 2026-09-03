'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { LogoActivityIndicator } from '@/components/renance-logo';

interface ReviewQuestion {
  questionId: string;
  stem: string;
  topic?: string;
  options?: Record<string, string>;
  selected?: string;
  correct: string;
  explanation?: string;
  correctly: boolean;
}

interface ReviewPayload {
  attemptId: string;
  code: string;
  title?: string;
  score?: number;
  total?: number;
  questions: ReviewQuestion[];
}

type Filter = 'wrong' | 'skipped' | 'all';

export default function ReviewPage() {
  return (
    <Suspense
      fallback={
        <Centered>
          <LogoActivityIndicator state="busy" label="Opening the marked paper…" />
        </Centered>
      }
    >
      <ReviewInner />
    </Suspense>
  );
}

function ReviewInner() {
  const attemptId = useSearchParams().get('attemptId') ?? '';
  const [review, setReview] = useState<ReviewPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>('wrong');

  useEffect(() => {
    let alive = true;
    api<ReviewPayload>(`/attempts/${attemptId}/review`)
      .then((r) => alive && setReview(r))
      .catch((e: unknown) => {
        if (!alive) return;
        setError(e instanceof Error ? e.message : 'Could not load review');
      });
    return () => {
      alive = false;
    };
  }, [attemptId]);

  if (error) {
    return (
      <Centered>
        <p className="max-w-md text-center text-sm text-on-surface-variant">{error}</p>
        <Link
          href="/dashboard"
          className="mt-4 rounded-lg bg-primary px-5 py-2.5 text-sm font-semibold text-on-primary"
        >
          Back to dashboard
        </Link>
      </Centered>
    );
  }
  if (!review) {
    return (
      <Centered>
        <LogoActivityIndicator state="busy" label="Opening the marked paper…" />
      </Centered>
    );
  }

  const wrongCount = review.questions.filter((q) => !q.correctly && q.selected).length;
  const skippedCount = review.questions.filter((q) => !q.selected).length;
  const visible = review.questions.filter((q) =>
    filter === 'wrong' ? !q.correctly && q.selected : filter === 'skipped' ? !q.selected : true,
  );

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-16 pt-8 sm:px-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-on-surface">
            Review · {wrongCount} wrong
          </h1>
          <p className="text-sm text-on-surface-variant">
            {review.title || review.code}
            {review.score != null && review.total ? ` · ${review.score}/${review.total} correct` : ''}
          </p>
        </div>
        <Link href="/dashboard" className="text-sm text-on-surface-variant hover:text-on-surface">
          Dashboard
        </Link>
      </header>

      <div className="mt-6 flex flex-wrap gap-2">
        {(
          [
            ['wrong', `Wrong (${wrongCount})`],
            ['skipped', `Skipped (${skippedCount})`],
            ['all', `All (${review.questions.length})`],
          ] as [Filter, string][]
        ).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`rounded-full px-4 py-1.5 font-mono text-xs transition ${
              filter === key
                ? 'bg-selection-blue font-semibold text-on-surface'
                : 'bg-surface-container-low text-on-surface-variant hover:text-on-surface'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="mt-5 space-y-4">
        {visible.length === 0 && (
          <p className="rounded-xl bg-card p-6 text-center text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            {filter === 'wrong' ? 'Nothing wrong here — flawless paper.' : filter === 'skipped' ? 'No skipped questions.' : 'No questions.'}
          </p>
        )}
        {visible.map((q) => {
          const idx = review.questions.indexOf(q) + 1;
          const pickedWrong = q.selected && !q.correctly;
          return (
            <article
              key={q.questionId}
              className="rounded-xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
            >
              <div className="flex items-center gap-2">
                <span className="font-mono text-[13px] text-on-surface">Q. {idx}</span>
                {q.topic && (
                  <span className="rounded-full bg-surface-container-low px-2 py-0.5 text-[11px] text-on-surface-variant">
                    {q.topic}
                  </span>
                )}
              </div>
              <p className="mt-3 text-[15px] leading-relaxed text-on-surface">{q.stem}</p>

              {pickedWrong && (
                <AnswerBlock
                  letter={q.selected!}
                  text={q.options?.[q.selected!] ?? ''}
                  label="You Picked"
                  tone="wrong"
                />
              )}
              {!q.selected && (
                <p className="mt-3 text-[13px] text-accent-amber">Skipped — you left this one blank.</p>
              )}
              <div className="mt-3">
                <AnswerBlock
                  letter={q.correct}
                  text={q.options?.[q.correct] ?? ''}
                  label="Correct Answer"
                  tone="right"
                />
              </div>

              {q.explanation && (
                <p className="mt-3 rounded-lg bg-surface-container-low p-3 text-[13px] leading-relaxed text-on-surface-variant">
                  {q.explanation}
                </p>
              )}
            </article>
          );
        })}
      </div>
    </main>
  );
}

function AnswerBlock({
  letter,
  text,
  label,
  tone,
}: {
  letter: string;
  text: string;
  label: string;
  tone: 'wrong' | 'right';
}) {
  const color = tone === 'right' ? 'text-accent-emerald' : 'text-error';
  const bg = tone === 'right' ? 'bg-emerald-tint' : 'bg-error-container';
  return (
    <div className="mt-2 flex items-start gap-3">
      <span
        className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg font-mono text-[15px] font-bold ${bg} ${color}`}
      >
        {letter}
      </span>
      <span>
        <span className={`block font-mono text-[11px] ${color}`}>{label}</span>
        <span className="mt-0.5 block text-sm text-on-surface">{text}</span>
      </span>
    </div>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-background px-6">
      {children}
    </main>
  );
}
