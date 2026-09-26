'use client';

/**
 * Review, two faces (Stitch review_queue_light + answer_review_light):
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
import TutorChat from '@/components/tutor-chat';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { apiImg, QText } from '@/lib/qtext';
import ExplanationSheet, { type ExplanationData } from '@/components/explanation-sheet';

interface ReviewQuestion {
  questionId: string;
  stem: string;
  topic?: string;
  year?: number;
  options?: Record<string, string>;
  selected?: string;
  correct: string;
  explanation?: string;
  correctly: boolean;
  image?: string;
  answerImage?: string;
  passage?: string;
  video?: string;
  type?: string;
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
  // The Myschool explanation sheet rides on the visible list: the
  // pager keeps one sheet open across questions.
  const [sheetIdx, setSheetIdx] = useState<number | null>(null);

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
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title={`Review · ${review.title || review.code}`} />
      <div className="mx-auto w-full max-w-2xl px-4 pt-6 sm:px-6">
      <div className="flex items-center justify-between">
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
      </div>

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

      {(wrongCount > 0 || skippedCount > 0) && (
        <TutorChat attemptId={review.attemptId} questions={review.questions} />
      )}

      <div className="mt-5 space-y-4">
        {visible.length === 0 && (
          <p className="rounded-xl bg-card p-6 text-center text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            {filter === 'wrong' ? 'Nothing wrong here, flawless paper.' : filter === 'skipped' ? 'No skipped questions.' : 'No questions.'}
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
                    {q.year ? <span className="ml-1 font-mono text-[10px] text-outline">{q.year}</span> : null}
                  </span>
                )}
              </div>
              {q.passage && (
                <details className="mt-3 rounded-lg border border-outline-variant/50 bg-surface-container-lowest/60">
                  <summary className="cursor-pointer select-none px-3 py-2 font-mono text-[10px] uppercase tracking-wider text-outline">
                    comprehension passage
                  </summary>
                  <div className="max-h-56 overflow-y-auto px-3 pb-3 text-[14px] leading-relaxed text-on-surface">
                    <QText html={q.passage} />
                  </div>
                </details>
              )}
              <div className="mt-3 text-[15px] leading-relaxed text-on-surface">
                <QText html={q.stem} />
              </div>
              {q.image && (
                <div className="mt-3 flex justify-center">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={apiImg(q.image)}
                    alt="question diagram"
                    loading="lazy"
                    className="max-h-72 max-w-full rounded-lg border border-outline-variant/40 bg-card object-contain"
                  />
                </div>
              )}

              {pickedWrong && (
                <AnswerBlock
                  letter={q.selected!}
                  text={q.options?.[q.selected!] ?? ''}
                  label="You Picked"
                  tone="wrong"
                />
              )}
              {!q.selected && (
                <p className="mt-3 text-[13px] text-accent-amber">Skipped, you left this one blank.</p>
              )}
              <div className="mt-3">
                <AnswerBlock
                  letter={q.correct}
                  text={q.options?.[q.correct] ?? ''}
                  label="Correct Answer"
                  tone="right"
                />
              </div>

              {q.answerImage && (
                <div className="mt-3">
                  <p className="font-mono text-[10px] uppercase tracking-wider text-outline">worked solution</p>
                  <div className="mt-1.5 flex justify-center">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={apiImg(q.answerImage)}
                      alt="worked solution diagram"
                      loading="lazy"
                      className="max-h-80 max-w-full rounded-lg border border-outline-variant/40 bg-card object-contain"
                    />
                  </div>
                </div>
              )}
              {q.explanation && (
                <div className="mt-3 rounded-lg bg-surface-container-low p-3 text-[13px] leading-relaxed text-on-surface-variant">
                  <QText html={q.explanation} />
                </div>
              )}
              {q.video && (
                <a
                  href={q.video}
                  target="_blank"
                  rel="noreferrer noopener"
                  className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-surface-container-low px-3 py-1.5 text-[12px] font-medium text-on-surface transition hover:bg-surface-container"
                >
                  <span className="material-symbols-outlined text-[16px]">play_circle</span>
                  Watch the worked video
                </a>
              )}
              {/* View Explanation - the school app's card footer button;
                  it opens the full explanation sheet at this card. */}
              <button
                onClick={() => setSheetIdx(review.questions.indexOf(q))}
                className="mt-3.5 flex h-11 w-full items-center justify-center gap-2 rounded-[10px] bg-accent-ink text-[13.5px] font-bold text-white transition hover:opacity-90 active:scale-[0.99]"
              >
                <span className="material-symbols-outlined text-[17px]">auto_stories</span>
                View Explanation
              </button>
            </article>
          );
        })}
      </div>
      </div>

      {/* the explanation sheet - Save, correct-option check, Report,
          Prev/Next and Get Renance's AI Explanation, Myschool's exact
          positions, anchored to the graded attempt for the AI pill */}
      {sheetIdx != null && review.questions[sheetIdx] && (
        <ExplanationSheet
          open
          onClose={() => setSheetIdx(null)}
          attemptId={review.attemptId}
          number={sheetIdx + 1}
          question={
            {
              questionId: review.questions[sheetIdx].questionId,
              code: review.code,
              title: review.title || review.code,
              stem: review.questions[sheetIdx].stem,
              passage: review.questions[sheetIdx].passage,
              image: review.questions[sheetIdx].image,
              options: review.questions[sheetIdx].options ?? {},
              correct: review.questions[sheetIdx].correct,
              selected: review.questions[sheetIdx].selected ?? '',
              explanation: review.questions[sheetIdx].explanation,
              topic: review.questions[sheetIdx].topic,
              year: review.questions[sheetIdx].year,
            } satisfies ExplanationData
          }
          onPrevious={sheetIdx > 0 ? () => setSheetIdx(sheetIdx - 1) : undefined}
          onNext={
            sheetIdx < review.questions.length - 1 ? () => setSheetIdx(sheetIdx + 1) : undefined
          }
        />
      )}
      <SideNav />
      <BottomNav />
    </main>
  );
}

// prettyPaper turns a raw pack code into the label a student reads:
// jamb-biology-bank -> "JAMB · Biology", jamb-mock-english-... ->
// "JAMB UTME Mock", waec-custom-... -> "WAEC Practice".
export function prettyPaper(code: string): string {
  const parts = (code || '').split('-');
  const body = (parts[0] || '').replace(/_/g, ' ').toUpperCase();
  if (code.startsWith('jamb-mock-')) return 'JAMB UTME Mock';
  if (parts[1] === 'custom' || parts[1] === 'pick') {
    return `${body.charAt(0) + body.slice(1).toLowerCase()} Practice`;
  }
  const subject = parts
    .slice(1)
    .filter((p) => p !== 'bank' && p !== 'enrich' && p !== 'theory' && p !== 'quizbank')
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(' ');
  const prettyBody = body.charAt(0) + body.slice(1).toLowerCase();
  return subject ? `${prettyBody} · ${subject}` : prettyBody || code;
}

// ------------------------------------------------------------ review queue

function ReviewQueue() {
  const [sum, setSum] = useState<ReviewSummary | null>(null);
  const [attempts, setAttempts] = useState<AttemptRow[] | null>(null);
  const [showAllPapers, setShowAllPapers] = useState(false);
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
  const gradedAttempts = attempts.filter((a) => a.status === 'graded' && a.score != null);
  const openAttempts = attempts.filter((a) => a.status !== 'graded' && a.status !== 'error');
  const latestGraded = gradedAttempts[0];

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="Review" />
      <div className="mx-auto w-full max-w-2xl px-4 pt-6 sm:px-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight text-on-surface">Review</h1>
        <Link href="/dashboard" className="text-sm text-on-surface-variant hover:text-on-surface">
          Dashboard
        </Link>
      </div>

      {/* black hero: what the plan wants today */}
      <section className="renance-rise mt-6 overflow-hidden rounded-xl bg-dark-surface px-6 py-7 text-center">
        <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-dark-text-secondary">
          {hasWork ? 'Spaced repetition plan' : 'Review desk'}
        </p>
        <p className="mt-3 flex items-baseline justify-center gap-2">
          <span
            className={`text-6xl font-bold leading-none tracking-tight ${
              hasWork ? 'text-white' : 'text-accent-emerald'
            }`}
          >
            {due}
          </span>
          <span className="text-base font-medium text-dark-text-secondary">
            {hasWork ? 'topics due' : 'all caught up'}
          </span>
        </p>
        <p className="mt-2 font-mono text-[11.5px] text-dark-text-secondary">
          {hasWork
            ? `${overdue.length} overdue · about ${due * 2} minutes today`
            : latestGraded
              ? 'Nothing scheduled. Grade a paper and its topics join the plan.'
              : 'Grade your first paper and its topics join the plan.'}
        </p>
        {latestGraded && (
          <Link
            href={`/review?attemptId=${latestGraded.attemptId}`}
            className="mt-5 inline-flex h-12 items-center justify-center gap-2 rounded-[10px] bg-white px-8 text-sm font-semibold text-[#101418] transition hover:bg-white/90"
          >
            {hasWork ? 'Start reviewing' : 'Revise your latest paper'}
            <span className="material-symbols-outlined text-[18px]">arrow_forward</span>
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

      {/* Exam history: every paper, the score bar telling the story */}
      {(gradedAttempts.length > 0 || openAttempts.length > 0) && (
        <section className="mt-8">
          <div className="flex items-baseline justify-between">
            <h2 className="text-lg font-semibold tracking-tight text-on-surface">Exam history</h2>
            <span className="text-sm text-on-surface-variant">
              {gradedAttempts.length} graded
            </span>
          </div>
          <div className="mt-4 space-y-2.5">
            {[...openAttempts, ...gradedAttempts]
              .slice(0, showAllPapers ? undefined : 6)
              .map((a) => {
                const pct =
                  a.score != null && a.total ? Math.round((a.score * 100) / a.total) : null;
                const graded = a.status === 'graded' && pct != null;
                const date = a.submittedAt
                  ? new Date(a.submittedAt).toLocaleDateString('en-NG', {
                      day: 'numeric', month: 'short',
                    })
                  : '';
                return (
                  <Link
                    key={a.attemptId}
                    href={a.status === 'graded' ? `/review?attemptId=${a.attemptId}` : '/review'}
                    className="block rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition hover:shadow-md"
                  >
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <p className="truncate text-[14.5px] font-semibold text-on-surface">
                          {prettyPaper(a.code)}
                        </p>
                        <p className="mt-0.5 font-mono text-[11px] text-on-surface-variant">
                          {date || 'in progress'}
                          {graded ? ` · ${a.score}/${a.total} correct` : ` · ${a.status}`}
                        </p>
                      </div>
                      {graded ? (
                        <p
                          className={`shrink-0 font-mono text-base font-bold ${
                            (pct ?? 0) >= 50 ? 'text-on-surface' : 'text-error'
                          }`}
                        >
                          {pct}%
                        </p>
                      ) : (
                        <span className="shrink-0 rounded-full bg-surface-container px-3 py-1 text-[11px] font-medium text-on-surface-variant">
                          resume
                        </span>
                      )}
                    </div>
                    {graded && (
                      <div className="mt-2.5 h-1.5 overflow-hidden rounded-full bg-surface-container">
                        <div
                          className={`h-full rounded-full ${(pct ?? 0) >= 50 ? 'bg-on-surface' : 'bg-error'}`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    )}
                  </Link>
                );
              })}
            {gradedAttempts.length + openAttempts.length > 6 && (
              <button
                type="button"
                onClick={() => setShowAllPapers((v) => !v)}
                className="mx-auto block rounded-full border border-outline px-4 py-1.5 text-[12.5px] font-medium text-on-surface transition hover:bg-surface-container"
              >
                {showAllPapers
                  ? 'Show fewer'
                  : `Show all ${gradedAttempts.length + openAttempts.length} papers`}
              </button>
            )}
          </div>
        </section>
      )}
      </div>
      <SideNav />
      <BottomNav />
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
        <span className="mt-0.5 block text-sm text-on-surface">
          <QText html={text} />
        </span>
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
