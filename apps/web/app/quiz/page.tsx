'use client';

/**
 * The public quiz share page: /quiz/?q=<name-slug>. This route is the
 * link a Renance student sends to friends - the quiz's own name rides
 * in the link tag, the friend plays instantly (client-scored, no
 * login), and the page carries the join CTAs. A static page with a
 * query param because the whole app is a static export.
 */

import { Suspense, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { API_BASE } from '@/lib/api';
import { LogoActivityIndicator } from '@/components/renance-logo';
import type { StudioQuizQuestion } from '@/lib/ai-studio';

interface SharedQuiz {
  title: string;
  subject?: string;
  difficulty?: string;
  body?: string;
  questions: StudioQuizQuestion[];
}

export default function SharedQuizRoute() {
  return (
    <Suspense fallback={null}>
      <SharedQuizClient />
    </Suspense>
  );
}

function SharedQuizClient() {
  const params = useSearchParams();
  const slug = params?.get('q') ?? '';
  const [quiz, setQuiz] = useState<SharedQuiz | null>(null);
  const [state, setState] = useState<'loading' | 'ready' | 'missing'>('loading');

  const [idx, setIdx] = useState(0);
  const [picks, setPicks] = useState<Record<number, string>>({});
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    document.title = 'Renance Quiz';
    if (!slug) {
      setState('missing');
      return;
    }
    let alive = true;
    fetch(`${API_BASE}/quiz/shared/${encodeURIComponent(slug)}`)
      .then(async (res) => {
        if (!res.ok) throw new Error('not found');
        return (await res.json()) as SharedQuiz;
      })
      .then((q) => {
        if (!alive) return;
        setQuiz(q);
        setState('ready');
        if (q.title) document.title = `${q.title} | Renance Quiz`;
      })
      .catch(() => {
        if (alive) setState('missing');
      });
    return () => {
      alive = false;
    };
  }, [slug]);

  const questions = quiz?.questions ?? [];
  const q = questions[idx];
  const score = useMemo(() => {
    let s = 0;
    questions.forEach((qq, i) => {
      if (qq.answer && picks[i] === qq.answer) s++;
    });
    return s;
  }, [questions, picks]);

  if (state === 'loading') {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <LogoActivityIndicator state="busy" label="Opening the quiz…" />
      </main>
    );
  }

  if (state === 'missing' || !quiz) {
    return (
      <main className="flex min-h-dvh flex-col items-center justify-center gap-4 bg-surface-container-lowest px-6 text-center">
        <span className="material-symbols-outlined text-[40px] text-on-surface-variant">quiz</span>
        <h1 className="text-xl font-bold tracking-tight text-on-surface">This quiz link is broken or expired</h1>
        <p className="max-w-sm text-[13.5px] leading-relaxed text-on-surface-variant">
          Ask your friend to share it again from Renance AI Studio - every generated quiz
          carries its own fresh link.
        </p>
        <Link href="/register" className="rounded-xl bg-primary px-6 py-3 text-[13.5px] font-semibold text-on-primary">
          Join Renance free
        </Link>
      </main>
    );
  }

  const letters = q ? Object.keys(q.options ?? {}).sort() : [];
  const picked = picks[idx];
  const last = idx === questions.length - 1;

  return (
    <div className="flex min-h-dvh flex-col bg-surface-container-lowest">
      {/* header */}
      <header className="border-b border-outline-variant/40 bg-card/80 backdrop-blur">
        <div className="mx-auto flex w-full max-w-xl items-center gap-3 px-4 py-3.5">
          <Link href="/" className="font-mono text-[13px] font-bold uppercase tracking-[0.18em] text-on-surface">
            Renance
          </Link>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[14.5px] font-semibold text-on-surface">{quiz.title}</p>
            <p className="truncate font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">
              {[quiz.body, quiz.subject, quiz.difficulty].filter(Boolean).join(' - ')} - shared quiz
            </p>
          </div>
          <span className="rounded-full bg-primary px-3 py-1 font-mono text-[10.5px] uppercase tracking-wider text-on-primary">
            {questions.length} Qs
          </span>
        </div>
      </header>

      {/* progress */}
      <div className="mx-auto w-full max-w-xl px-4 pt-4">
        <div className="flex items-center gap-3">
          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-container">
            <div
              className="h-full rounded-full bg-primary transition-all"
              style={{ width: `${((idx + 1) / Math.max(1, questions.length)) * 100}%` }}
            />
          </div>
          <span className="font-mono text-[11px] text-on-surface-variant">
            {idx + 1}/{questions.length}
          </span>
        </div>
      </div>

      {/* question */}
      <main className="mx-auto flex w-full max-w-xl flex-1 flex-col gap-4 px-4 py-4">
        {q && (
          <div className="rounded-2xl border border-outline-variant/60 bg-card p-4">
            <p className="text-[15.5px] font-medium leading-relaxed text-on-surface">{q.stem}</p>
            <div className="mt-4 flex flex-col gap-2">
              {letters.map((l) => {
                const isPick = picked === l;
                const isRight = submitted && q.answer === l;
                const isWrong = submitted && isPick && q.answer !== l;
                return (
                  <button
                    key={l}
                    type="button"
                    disabled={submitted}
                    onClick={() => setPicks((p) => ({ ...p, [idx]: l }))}
                    className={`flex items-center gap-3 rounded-xl border px-3.5 py-3 text-left text-[14px] transition ${
                      isRight
                        ? 'border-emerald-600 bg-emerald-50 text-accent-emerald dark:bg-emerald-tint'
                        : isWrong
                          ? 'border-red-500 bg-red-50 text-on-error-container dark:bg-error-container dark:border-error'
                          : isPick
                            ? 'border-primary bg-surface-container'
                            : 'border-outline-variant/60 bg-card hover:border-primary/40'
                    }`}
                  >
                    <span
                      className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full font-mono text-[12px] font-semibold ${
                        isPick || isRight ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
                      }`}
                    >
                      {l}
                    </span>
                    <span className="leading-snug">{q.options?.[l]}</span>
                    {isRight && <span className="material-symbols-outlined ml-auto text-[18px]">check_circle</span>}
                    {isWrong && <span className="material-symbols-outlined ml-auto text-[18px]">cancel</span>}
                  </button>
                );
              })}
            </div>
            {submitted && q.explanation && (
              <div className="mt-3 rounded-xl bg-surface-container px-3.5 py-3 text-[13px] leading-relaxed text-on-surface-variant">
                <span className="font-semibold text-on-surface">Why: </span>
                {q.explanation}
              </div>
            )}
          </div>
        )}

        {submitted ? (
          <div className="flex flex-col gap-3">
            <div className="rounded-2xl bg-primary px-5 py-5 text-center text-on-primary">
              <p className="font-mono text-[10px] font-bold uppercase tracking-[0.24em] text-on-primary/90">Your score</p>
              <p className="mt-1 text-3xl font-bold tracking-tight">
                {score}
                <span className="text-base font-semibold text-on-primary/90"> / {questions.length}</span>
              </p>
              <p className="mt-2 text-[12.5px] font-semibold leading-relaxed text-on-primary/95">
                {score === questions.length
                  ? 'Perfect score. Your friend made this with Renance AI - imagine what you would make.'
                  : 'Every question carries a worked explanation. Renance AI can make you one like this in seconds.'}
              </p>
            </div>
            {/* Review navigation (founder directive, 2026-10-02):
                Previous AND Next flip through every question after
                submitting - the friend can study the explanations both
                ways, not just walk forward. */}
            <div className="flex gap-2">
              <button
                type="button"
                disabled={idx === 0}
                onClick={() => setIdx((i) => i - 1)}
                className="flex-1 rounded-xl border border-outline-variant/70 bg-card py-3 text-[13px] font-semibold text-on-surface transition enabled:hover:border-primary/50 disabled:opacity-40"
              >
                Previous
              </button>
              <button
                type="button"
                disabled={idx >= questions.length - 1}
                onClick={() => setIdx((i) => i + 1)}
                className="flex-1 rounded-xl bg-primary py-3 text-[13px] font-semibold text-on-primary transition active:scale-[0.98] disabled:opacity-40"
              >
                Next
              </button>
            </div>
            {/* dual CTAs */}
            <Link
              href="/register"
              className="rounded-xl bg-primary py-3.5 text-center text-[14px] font-semibold text-on-primary transition active:scale-[0.98]"
            >
              Join Renance free - 290,000+ past questions
            </Link>
            <Link
              href="/ai"
              className="rounded-xl border border-outline-variant/70 bg-card py-3.5 text-center text-[14px] font-semibold text-on-surface"
            >
              Try Renance AI Studio
            </Link>
            <button
              type="button"
              onClick={() => {
                setPicks({});
                setSubmitted(false);
                setIdx(0);
              }}
              className="py-1 text-[12.5px] font-semibold text-on-surface-variant underline"
            >
              Play again
            </button>
          </div>
        ) : (
          q && (
            <div className="flex gap-2">
              {idx > 0 && (
                <button
                  type="button"
                  onClick={() => setIdx((i) => i - 1)}
                  className="rounded-xl border border-outline-variant/70 bg-card px-5 py-3 text-[13px] font-semibold text-on-surface"
                >
                  Back
                </button>
              )}
              <button
                type="button"
                disabled={!picked}
                onClick={() => (last ? setSubmitted(true) : setIdx((i) => i + 1))}
                className="flex-1 rounded-xl bg-primary py-3 text-[13px] font-semibold text-on-primary transition active:scale-[0.98] disabled:opacity-40"
              >
                {last ? 'Submit and score me' : 'Next question'}
              </button>
            </div>
          )
        )}
      </main>

      <footer className="border-t border-outline-variant/40 px-4 py-4 text-center">
        <p className="text-[11.5px] text-on-surface-variant">
          Made with Renance AI - the Nigerian educational app for JAMB, WAEC, NECO and tertiary institution
        </p>
      </footer>
    </div>
  );
}
