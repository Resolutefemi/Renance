'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
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

export default function ExamPage() {
  const params = useParams<{ code: string }>();
  const router = useRouter();
  const code = params.code;

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
        <p className="max-w-md rounded-xl border border-red-900/60 bg-red-950/40 px-6 py-5 text-center text-sm text-red-300">
          {error}
        </p>
        <button
          onClick={() => router.push('/dashboard')}
          className="mt-4 text-sm text-emerald-400 underline-offset-4 hover:underline"
        >
          ← back to dashboard
        </button>
      </Centered>
    );
  }

  if (phase === 'intro' && bundle) {
    return (
      <Centered>
        <div className="renance-rise w-full max-w-lg rounded-2xl border border-neutral-800 bg-neutral-950 p-8 text-center">
          <div className="mb-4 flex justify-center">
            <RenanceMark size={56} />
          </div>
          <h1 className="text-xl font-semibold">{bundle.title}</h1>
          <p className="mt-2 text-sm text-neutral-500">
            {bundle.questionCount} questions · {bundle.durationMinutes ?? 30} minutes ·{' '}
            {bundle.totalMarks} marks
          </p>
          <ul className="mx-auto mt-6 max-w-xs space-y-1.5 text-left text-xs text-neutral-400">
            <li>· Timer starts the moment you begin</li>
            <li>· Auto-submit when time runs out</li>
            <li>· Grading happens server-side — leave any time after submitting</li>
          </ul>
          <button
            onClick={startAttempt}
            className="mt-8 w-full rounded-lg bg-emerald-500 px-4 py-3 text-sm font-semibold text-black transition hover:bg-emerald-400"
          >
            Begin
          </button>
          <Link
            href="/dashboard"
            className="mt-3 block text-xs text-neutral-500 underline-offset-4 hover:underline"
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
        <p className="mt-3 text-xs text-neutral-600">
          the goroutine engine is comparing your picks against the sealed key
        </p>
      </Centered>
    );
  }

  if (phase === 'graded' && result) {
    const pct = result.total > 0 ? Math.round((result.score / result.total) * 100) : 0;
    return (
      <main className="mx-auto w-full max-w-2xl px-6 py-14">
        <div className="renance-rise rounded-2xl border border-neutral-800 bg-neutral-950 p-8 text-center">
          <div className="mb-2 flex justify-center">
            <RenanceMark size={44} />
          </div>
          <p className="text-xs uppercase tracking-widest text-neutral-500">{bundle?.title}</p>
          <p className="mt-4 text-6xl font-bold tracking-tight">
            {pct}
            <span className="text-2xl text-neutral-500">%</span>
          </p>
          <p className="mt-2 text-sm text-neutral-400">
            {result.score} of {result.total} correct
          </p>
        </div>

        <h2 className="mt-8 text-sm font-medium uppercase tracking-wider text-neutral-500">
          Topic breakdown
        </h2>
        <div className="mt-3 space-y-3">
          {result.breakdown.map((row) => {
            const rowPct = row.total > 0 ? Math.round((row.correct / row.total) * 100) : 0;
            return (
              <div key={row.topic} className="rounded-xl border border-neutral-800 bg-neutral-900/60 p-4">
                <div className="mb-2 flex items-center justify-between text-sm">
                  <span>{row.topic}</span>
                  <span className="text-neutral-500">
                    {row.correct}/{row.total}
                  </span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-neutral-800">
                  <div
                    className={`h-full rounded-full ${rowPct >= 50 ? 'bg-emerald-500' : 'bg-amber-500'}`}
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
            className="flex-1 rounded-lg bg-emerald-500 px-4 py-3 text-sm font-semibold text-black hover:bg-emerald-400"
          >
            Retake
          </button>
          <Link
            href="/dashboard"
            className="flex-1 rounded-lg border border-neutral-700 px-4 py-3 text-center text-sm text-neutral-300 hover:border-neutral-500"
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
    <main className="mx-auto w-full max-w-3xl px-6 py-8">
      <header className="flex items-center justify-between">
        <Link href="/dashboard" className="flex items-center gap-2 text-sm text-neutral-500 hover:text-neutral-300">
          <RenanceMark size={28} /> <span>leave</span>
        </Link>
        <div
          className={`rounded-lg border px-4 py-1.5 font-mono text-sm ${
            remaining !== null && remaining < 60
              ? 'border-red-800 text-red-300'
              : 'border-neutral-700 text-neutral-300'
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
                  ? 'border-white text-white'
                  : isFlagged
                    ? 'border-amber-500 text-amber-300'
                    : isAnswered
                      ? 'border-emerald-600 bg-emerald-600/15 text-emerald-300'
                      : 'border-neutral-800 text-neutral-500'
              }`}
            >
              {i + 1}
            </button>
          );
        })}
      </div>

      {/* question card */}
      <div className="mt-6 rounded-2xl border border-neutral-800 bg-neutral-950 p-7">
        <div className="flex items-center justify-between text-xs text-neutral-500">
          <span>
            Question {current + 1} of {bundle.questionCount}
            {question.topic ? ` · ${question.topic}` : ''}
          </span>
          <button
            onClick={() => setFlags((f) => ({ ...f, [question.id]: !f[question.id] }))}
            className={`rounded border px-2 py-0.5 text-[11px] transition ${
              flags[question.id]
                ? 'border-amber-500 text-amber-300'
                : 'border-neutral-700 text-neutral-500 hover:text-neutral-300'
            }`}
          >
            {flags[question.id] ? 'flagged' : 'flag'}
          </button>
        </div>
        <p className="mt-4 text-[15px] leading-relaxed">{question.stem}</p>
        <div className="mt-6 space-y-2.5">
          {Object.entries(question.options ?? {}).map(([letter, text]) => {
            const selected = answers[question.id] === letter;
            return (
              <button
                key={letter}
                onClick={() => setAnswers((a) => ({ ...a, [question.id]: letter }))}
                className={`flex w-full items-start gap-3 rounded-xl border px-4 py-3 text-left text-sm transition ${
                  selected
                    ? 'border-emerald-500 bg-emerald-500/10'
                    : 'border-neutral-800 hover:border-neutral-600'
                }`}
              >
                <span
                  className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border text-xs font-semibold ${
                    selected ? 'border-emerald-400 text-emerald-300' : 'border-neutral-600 text-neutral-400'
                  }`}
                >
                  {letter}
                </span>
                <span>{text}</span>
              </button>
            );
          })}
        </div>
      </div>

      <footer className="mt-6 flex items-center justify-between">
        <button
          onClick={() => setCurrent((c) => Math.max(0, c - 1))}
          disabled={current === 0}
          className="rounded-lg border border-neutral-800 px-4 py-2 text-sm text-neutral-300 disabled:opacity-40"
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
            className="rounded-lg bg-emerald-500 px-6 py-2 text-sm font-semibold text-black hover:bg-emerald-400"
          >
            Submit paper
          </button>
        ) : (
          <button
            onClick={() => setCurrent((c) => Math.min(bundle.questionCount - 1, c + 1))}
            className="rounded-lg bg-neutral-800 px-5 py-2 text-sm hover:bg-neutral-700"
          >
            Next →
          </button>
        )}
      </footer>
      <p className="mt-3 text-center text-xs text-neutral-600">
        {answeredCount}/{bundle.questionCount} answered
      </p>
    </main>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6">{children}</main>
  );
}
