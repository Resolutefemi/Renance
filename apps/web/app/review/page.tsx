'use client';

/**
 * Review — two faces (Stitch review_queue_light + answer_review_light):
 *   /review                     → the spaced-repetition queue (default)
 *   /review?attemptId=<id>      → one graded paper's answer review
 */

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import {
  laterLabel,
  queuePreview,
  reviewStatus,
  type ReviewItem,
  type ReviewSummary,
} from '@/lib/review';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';

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

interface AttemptRow {
  attemptId: string;
  code: string;
  status: string;
  score?: number;
  total?: number;
  submittedAt?: string;
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
    if (!attemptId) return;
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

  // No attemptId → the spaced-repetition queue is the page.
  if (!attemptId) {
    return (
      <Suspense fallback={<Centered><RenanceMark size={40} state="busy" /></Centered>}>
        <ReviewQueue />
      </Suspense>
    );
  }

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
        <Link href="/review" className="text-sm text-on-surface-variant hover:text-on-surface">
          Queue
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

// ------------------------------------------------------------ review queue

function ReviewQueue() {
  const [sum, setSum] = useState<ReviewSummary | null>(null);
  const [attempts, setAttempts] = useState<AttemptRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    Promise.all([
      api<ReviewSummary>('/me/review'),
      api<{ attempts: AttemptRow[] }>('/me/attempts').catch(() => ({ attempts: [] })),
    ])
      .then(([r, a]) => {
        if (!alive) return;
        setSum(r);
        setAttempts(a.attempts);
      })
      .catch((e: unknown) => {
        if (!alive) return;
        setError(e instanceof Error ? e.message : 'Could not load your review queue');
      });
    return () => {
      alive = false;
    };
  }, []);

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
  if (!sum || attempts === null) {
    return (
      <Centered>
        <RenanceMark size={40} state="busy" />
      </Centered>
    );
  }

  const due = sum.stats.due;
  const hasWork = due > 0;
  const overdue = sum.due.filter((it) => reviewStatus(it) === 'overdue');
  const rows = queuePreview(sum);
  const latestGraded = attempts.find((a) => a.status === 'graded');

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-16 pt-8 sm:px-6">
      <header className="flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight text-on-surface">Review</h1>
        <Link href="/dashboard" className="text-sm text-on-surface-variant hover:text-on-surface">
          Dashboard
        </Link>
      </header>

      {/* amber hero (review_queue_light) */}
      <section className="mt-6 rounded-xl bg-accent-amber/10 p-6 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
        <span className="material-symbols-outlined text-4xl text-accent-amber">local_fire_department</span>
        <p className="mt-2 text-4xl font-bold tracking-tight text-on-surface">
          <span className={hasWork ? 'text-accent-amber' : 'text-accent-emerald'}>{due}</span>{' '}
          <span className="text-lg font-medium text-on-surface-variant">
            {hasWork ? (overdue.length ? `topics due · ${overdue.length} overdue` : 'topics due today') : 'all caught up'}
          </span>
        </p>
        <p className="mt-1 text-sm text-on-surface-variant">
          {hasWork
            ? `Estimated time: ~${due * 2} minutes`
            : latestGraded
              ? 'Nothing scheduled — grade a paper and its topics join the plan.'
              : 'Grade your first paper and its topics join the plan.'}
        </p>
        {latestGraded && (
          <Link
            href={`/review?attemptId=${latestGraded.attemptId}`}
            className="mt-5 inline-flex h-12 items-center justify-center gap-2 rounded-[10px] bg-primary px-8 text-sm font-semibold text-on-primary transition hover:opacity-90"
          >
            {hasWork ? 'Start Review' : 'Revise latest paper'} →
          </Link>
        )}
      </section>

      {/* Queue Preview / Next up */}
      {rows.length > 0 && (
        <section className="mt-8">
          <div className="flex items-baseline justify-between">
            <h2 className="text-lg font-semibold text-on-surface">Queue Preview</h2>
            <span className="text-sm text-on-surface-variant">Next up</span>
          </div>
          <div className="mt-4 space-y-3">
            {rows.slice(0, 8).map((it) => (
              <QueueRow key={`${it.topic}-${it.dueOn}`} item={it} />
            ))}
            {rows.length > 8 && (
              <p className="text-xs text-on-surface-variant">+ {rows.length - 8} more topics on the schedule</p>
            )}
          </div>
        </section>
      )}

      {/* Recent papers */}
      {attempts.length > 0 && (
        <section className="mt-8">
          <h2 className="text-lg font-semibold text-on-surface">Recent papers</h2>
          <div className="mt-4 space-y-3">
            {attempts.slice(0, 8).map((a) => {
              const pct = a.score != null && a.total ? Math.round((a.score * 100) / a.total) : null;
              return (
                <Link
                  key={a.attemptId}
                  href={a.status === 'graded' ? `/review?attemptId=${a.attemptId}` : '/review'}
                  className={`flex items-center justify-between rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] ${
                    a.status === 'graded' ? 'hover:shadow-md transition' : 'opacity-80'
                  }`}
                >
                  <span>
                    <span className="block text-sm font-medium text-on-surface">{a.code}</span>
                    <span className="block text-xs text-on-surface-variant">
                      {a.status === 'graded' && a.score != null && a.total
                        ? `${a.status} · ${a.score}/${a.total} correct`
                        : a.status}
                    </span>
                  </span>
                  <span className="font-mono text-sm text-on-surface-variant">{pct == null ? '—' : `${pct}%`}</span>
                </Link>
              );
            })}
          </div>
        </section>
      )}
    </main>
  );
}

function QueueRow({ item }: { item: ReviewItem }) {
  const status = reviewStatus(item);
  const tone =
    status === 'overdue'
      ? { dot: 'bg-error', text: 'text-error', label: 'Overdue' }
      : status === 'due'
        ? { dot: 'bg-accent-amber', text: 'text-accent-amber', label: 'Due now' }
        : { dot: '', text: 'text-on-surface-variant', label: laterLabel(item) };

  return (
    <div className="rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
      <div className="flex items-center justify-between gap-3">
        <span className="rounded-full bg-selection-blue px-3 py-1 text-xs text-on-surface">
          {item.topic}
        </span>
        <span className={`flex items-center gap-1.5 text-sm font-semibold ${tone.text}`}>
          {status !== 'later' && <span className={`h-1.5 w-1.5 rounded-full ${tone.dot}`} />}
          {tone.label}
        </span>
      </div>
      <p className="mt-2 text-xs text-on-surface-variant">
        {item.lastTotal > 0
          ? `last time ${item.lastCorrect}/${item.lastTotal} correct`
          : 'new on the schedule'}
      </p>
    </div>
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
