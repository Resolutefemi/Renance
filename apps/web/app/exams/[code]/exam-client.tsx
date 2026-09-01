'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { fetchBundle, fetchManifest, type Bundle } from '@/lib/exams';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';

interface ExamMetaLite {
  code: string;
  title: string;
  durationMinutes?: number;
}

interface AttemptResponse {
  attemptId: string;
  code: string;
  status: string;
  startedAt: string;
  durationMinutes?: number | null;
  questionCount?: number;
}

interface TopicRow {
  topic: string;
  correct: number;
  total: number;
}

interface ResultPayload {
  score: number;
  total: number;
  breakdown: TopicRow[];
}

type Phase = 'loading' | 'intro' | 'playing' | 'grading' | 'graded' | 'error';

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

export default function ExamPage({ code }: { code: string }) {
  const router = useRouter();

  const [phase, setPhase] = useState<Phase>('loading');
  const [bundle, setBundle] = useState<Bundle | null>(null);
  const [meta, setMeta] = useState<ExamMetaLite | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [attempt, setAttempt] = useState<AttemptResponse | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [flags, setFlags] = useState<Record<string, boolean>>({});
  const [current, setCurrent] = useState(0);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [result, setResult] = useState<ResultPayload | null>(null);
  const startedAtRef = useRef<number>(0);
  const submittedRef = useRef(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const manifest = await fetchManifest();
        const exam = manifest.exams.find((e) => e.code === code);
        if (!exam) throw new Error('This pack is not in your manifest');
        const b = await fetchBundle(exam);
        if (!alive) return;
        setMeta(exam);
        setBundle(b);
        setPhase('intro');
      } catch (err) {
        if (!alive) return;
        setError(err instanceof Error ? err.message : 'Could not load pack');
        setPhase('error');
      }
    })();
    return () => {
      alive = false;
    };
  }, [code]);

  const submit = useCallback(async () => {
    if (!attempt || submittedRef.current) return;
    submittedRef.current = true;
    setPhase('grading');
    try {
      const payload = {
        answers: Object.entries(answers).map(([questionId, selected]) => ({
          questionId,
          selected,
        })),
        durationMs: Math.round((Date.now() - startedAtRef.current) / 1),
      };
      await api<{ attemptId: string; status: string }>(`/attempts/${attempt.attemptId}/submit`, {
        method: 'POST',
        body: payload,
      });
      // poll until the goroutine engine finishes grading
      for (let i = 0; i < 120; i++) {
        const res = await api<AttemptResponse & { result?: ResultPayload }>(
          `/attempts/${attempt.attemptId}`,
        );
        if (res.status === 'graded' && res.result) {
          setResult(res.result);
          setPhase('graded');
          return;
        }
        if (res.status === 'error') {
          throw new Error('Grading hit an error — our team sees it too. Try again.');
        }
        await new Promise((r) => setTimeout(r, 1000));
      }
      throw new Error('Grading is taking unusually long.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Submission failed');
      setPhase('error');
    }
  }, [attempt, answers]);

  // countdown
  useEffect(() => {
    if (phase !== 'playing' || !attempt) return;
    const totalSec = (bundle?.durationMinutes ?? 30) * 60;
    const tick = () => {
      const elapsed = Math.floor((Date.now() - startedAtRef.current) / 1000);
      const left = totalSec - elapsed;
      setRemaining(Math.max(left, 0));
      if (left <= 0) void submit();
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [phase, attempt, bundle, submit]);

  async function startAttempt() {
    if (!bundle) return;
    try {
      const res = await api<AttemptResponse>('/attempts', {
        method: 'POST',
        body: { code: bundle.code },
      });
      setAttempt(res);
      setAnswers({});
      setFlags({});
      setCurrent(0);
      setResult(null);
      submittedRef.current = false;
      startedAtRef.current = Date.now();
      setPhase('playing');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not start attempt');
      setPhase('error');
    }
  }

  const question = bundle?.questions[current];
  const answeredCount = useMemo(() => Object.keys(answers).length, [answers]);
  const mmss = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

  /* ------------------------------------------------------------- views */

  if (phase === 'loading') {
    return (
      <Centered>
        <LogoActivityIndicator state="busy" label={`Opening ${meta?.title ?? 'pack'}…`} />
      </Centered>
    );
  }

  if (phase === 'error') {
    return (
      <Centered>
        <p className="max-w-md rounded-xl bg-error-container px-6 py-5 text-center text-sm text-on-error-container">
          {error}
        </p>
        <button
          onClick={() => router.push('/dashboard')}
          className="mt-4 text-sm text-primary underline-offset-4 hover:underline"
        >
          ← back to dashboard
        </button>
      </Centered>
    );
  }

  if (phase === 'intro' && bundle) {
    return (
      <Centered>
        <div className="renance-rise w-full max-w-lg rounded-2xl bg-surface-container-lowest p-8 text-center shadow-md">
          <div className="mb-4 flex justify-center">
            <RenanceMark size={56} />
          </div>
          <h1 className="text-xl font-semibold text-on-surface">{bundle.title}</h1>
          <p className="mt-2 text-sm text-on-surface-variant">
            {bundle.questionCount} questions · {bundle.durationMinutes ?? 30} minutes ·{' '}
            {bundle.totalMarks} marks
          </p>
          <ul className="mx-auto mt-6 max-w-xs space-y-1.5 text-left text-xs text-on-surface-variant">
            <li>· Timer starts the moment you begin</li>
            <li>· Auto-submit when time runs out</li>
            <li>· Grading happens server-side — leave any time after submitting</li>
          </ul>
          <button
            onClick={startAttempt}
            className="mt-8 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
          >
            Begin
          </button>
          <Link
            href="/dashboard"
            className="mt-3 block text-xs text-on-surface-variant underline-offset-4 hover:underline"
          >
            back to dashboard
          </Link>
        </div>
      </Centered>
    );
  }

  if (phase === 'grading') {
    return (
      <Centered>
        <LogoActivityIndicator state="grading" label="Marking your paper…" />
        <p className="mt-3 text-xs text-outline">
          the goroutine engine is comparing your picks against the sealed key
        </p>
      </Centered>
    );
  }

  if (phase === 'graded' && result) {
    const pct = result.total > 0 ? Math.round((result.score / result.total) * 100) : 0;
    return (
      <main className="mx-auto w-full max-w-2xl px-4 py-14 sm:px-6">
        <div className="renance-rise rounded-2xl bg-surface-container-lowest p-8 text-center shadow-md">
          <div className="mb-2 flex justify-center">
            <RenanceMark size={44} />
          </div>
          <p className="font-mono text-xs uppercase tracking-[0.2em] text-on-surface-variant">
            {bundle?.title}
          </p>
          <p className="mt-4 text-6xl font-bold tracking-tight text-on-surface">
            {pct}
            <span className="text-2xl text-on-surface-variant">%</span>
          </p>
          <p className="mt-2 text-sm text-on-surface-variant">
            {result.score} of {result.total} correct
          </p>
        </div>

        <h2 className="mt-8 font-mono text-xs font-medium uppercase tracking-[0.2em] text-on-surface-variant">
          Topic breakdown
        </h2>
        <div className="mt-3 space-y-3">
          {result.breakdown.map((row) => {
            const rowPct = row.total > 0 ? Math.round((row.correct / row.total) * 100) : 0;
            return (
              <div
                key={row.topic}
                className="rounded-xl border border-outline-variant bg-surface-container-lowest p-4 shadow-sm"
              >
                <div className="mb-2 flex items-center justify-between text-sm">
                  <span className="text-on-surface">{row.topic}</span>
                  <span className="text-on-surface-variant">
                    {row.correct}/{row.total}
                  </span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-surface-container-high">
                  <div
                    className={`h-full rounded-full ${rowPct >= 50 ? 'bg-emerald-600' : 'bg-amber-500'}`}
                    style={{ width: `${rowPct}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>

        <div className="mt-8 flex gap-3">
          <button
            onClick={() => {
              setPhase('intro');
              setAttempt(null);
            }}
            className="flex-1 rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
          >
            Retake
          </button>
          <Link
            href="/dashboard"
            className="flex-1 rounded-lg border border-outline-variant px-4 py-3 text-center text-sm text-on-surface transition hover:border-outline"
          >
            Dashboard
          </Link>
        </div>
      </main>
    );
  }

  if (!bundle || !question) return null;

  /* ----------------------------------------------------------- playing */

  return (
    <main className="mx-auto w-full max-w-3xl px-4 py-8 sm:px-6">
      <header className="flex items-center justify-between">
        <Link
          href="/dashboard"
          className="flex items-center gap-2 text-sm text-on-surface-variant transition hover:text-on-surface"
        >
          <RenanceMark size={28} /> <span>leave</span>
        </Link>
        <div
          className={`rounded-lg border px-4 py-1.5 font-mono text-sm ${
            remaining !== null && remaining < 60
              ? 'border-error bg-error-container text-on-error-container'
              : 'border-outline-variant text-on-surface'
          }`}
        >
          {remaining !== null ? mmss(remaining) : '--:--'}
        </div>
      </header>

      {/* palette */}
      <div className="mt-6 flex flex-wrap gap-1.5">
        {bundle.questions.map((q, i) => {
          const isAnswered = Boolean(answers[q.id]);
          const isFlagged = flags[q.id];
          const isCurrent = i === current;
          return (
            <button
              key={q.id}
              onClick={() => setCurrent(i)}
              className={`h-8 w-8 rounded-md border text-xs transition ${
                isCurrent
                  ? 'border-primary bg-primary text-on-primary ring-2 ring-primary ring-offset-2 ring-offset-background'
                  : isFlagged
                    ? 'border-amber-500 text-amber-600'
                    : isAnswered
                      ? 'border-outline bg-secondary-container text-on-surface'
                      : 'border-outline-variant text-on-surface-variant'
              }`}
            >
              {i + 1}
            </button>
          );
        })}
      </div>

      {/* question card */}
      <div className="mt-6 rounded-2xl border border-outline-variant bg-surface-container-lowest p-7 shadow-sm">
        <div className="flex items-center justify-between text-xs text-on-surface-variant">
          <span>
            Question {current + 1} of {bundle.questionCount}
            {question.topic ? ` · ${question.topic}` : ''}
          </span>
          <button
            onClick={() => setFlags((f) => ({ ...f, [question.id]: !f[question.id] }))}
            className={`rounded border px-2 py-0.5 text-[11px] transition ${
              flags[question.id]
                ? 'border-amber-500 text-amber-600'
                : 'border-outline-variant text-on-surface-variant hover:border-outline'
            }`}
          >
            {flags[question.id] ? 'flagged' : 'flag'}
          </button>
        </div>
        <p className="mt-4 text-[15px] leading-relaxed text-on-surface">{question.stem}</p>
        <div className="mt-6 space-y-2.5">
          {Object.entries(question.options ?? {}).map(([letter, text]) => {
            const selected = answers[question.id] === letter;
            return (
              <button
                key={letter}
                onClick={() => setAnswers((a) => ({ ...a, [question.id]: letter }))}
                className={`flex w-full items-start gap-3 rounded-xl border px-4 py-3 text-left text-sm transition ${
                  selected
                    ? 'border-primary bg-secondary-container'
                    : 'border-outline-variant hover:border-outline'
                }`}
              >
                <span
                  className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border text-xs font-semibold ${
                    selected
                      ? 'border-primary bg-primary text-on-primary'
                      : 'border-outline text-on-surface-variant'
                  }`}
                >
                  {letter}
                </span>
                <span className="text-on-surface">{text}</span>
              </button>
            );
          })}
        </div>
      </div>

      <footer className="mt-6 flex items-center justify-between">
        <button
          onClick={() => setCurrent((c) => Math.max(0, c - 1))}
          disabled={current === 0}
          className="rounded-lg border border-outline-variant px-4 py-2 text-sm text-on-surface transition hover:border-outline disabled:opacity-40"
        >
          ← Prev
        </button>
        {current === bundle.questionCount - 1 || answeredCount === bundle.questionCount ? (
          <button
            onClick={() => {
              if (answeredCount < bundle.questionCount) {
                const left = bundle.questionCount - answeredCount;
                if (!window.confirm(`${left} unanswered — submit anyway?`)) return;
              }
              void submit();
            }}
            className="rounded-lg bg-primary px-6 py-2 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
          >
            Submit paper
          </button>
        ) : (
          <button
            onClick={() => setCurrent((c) => Math.min(bundle.questionCount - 1, c + 1))}
            className="rounded-lg bg-secondary-container px-5 py-2 text-sm text-on-surface transition hover:bg-surface-container-highest"
          >
            Next →
          </button>
        )}
      </footer>
      <p className="mt-3 text-center text-xs text-outline">
        {answeredCount}/{bundle.questionCount} answered
      </p>
    </main>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-background px-6">
      {children}
    </main>
  );
}
