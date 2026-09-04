'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { fetchBundle, fetchManifest, type Bundle } from '@/lib/exams';
import { bodySlug } from '@/lib/syllabus';
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
  adaptive?: boolean;
  order?: string[] | null;
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

interface AttemptSummary {
  attemptId: string;
  code: string;
  status: string;
  score?: number;
  total?: number;
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
  const [gam, setGam] = useState<{ state: { currentStreak: number; totalXp: number } } | null>(null);
  const [allAttempts, setAllAttempts] = useState<AttemptSummary[] | null>(null);
  // Smart order (ROADMAP #5): begin weak-topic-first by default; the
  // intro toggle flips it back to the pack's natural exam order.
  const [adaptive, setAdaptive] = useState(true);
  const [smartApplied, setSmartApplied] = useState(false);
  const startedAtRef = useRef<number>(0);
  const submittedRef = useRef(false);

  useEffect(() => {
    if (phase !== 'graded') return;
    api<{ state: { currentStreak: number; totalXp: number } }>('/me/gamification')
      .then(setGam)
      .catch(() => {});
    api<{ attempts: AttemptSummary[] }>('/me/attempts')
      .then((a) => setAllAttempts(a.attempts))
      .catch(() => {});
  }, [phase]);

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
        body: { code: bundle.code, ...(adaptive ? { adaptive: true } : {}) },
      });
      setAttempt(res);
      setSmartApplied(false);
      // The server walked the pack weak-topic-first (ROADMAP #5):
      // re-sequence the in-memory copy; the cached bundle stays intact.
      if (adaptive && res.order?.length) {
        const byId = new Map(bundle.questions.map((q) => [q.id, q]));
        const ordered = res.order
          .map((id) => byId.get(id))
          .filter((q): q is NonNullable<typeof q> => Boolean(q));
        for (const q of bundle.questions) {
          if (!res.order.includes(q.id)) ordered.push(q);
        }
        setBundle({ ...bundle, questions: ordered });
        setSmartApplied(true);
      }
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
          {/* Smart order (ROADMAP #5) */}
          <div className="mx-auto mt-5 flex w-full max-w-xs items-center justify-between rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5">
            <div className="flex items-center gap-2 text-left">
              <span
                className={`material-symbols-outlined text-[18px] ${adaptive ? 'text-accent-violet' : 'text-outline-dark'}`}
              >
                auto_awesome
              </span>
              <span>
                <span className="block text-[13px] font-medium text-on-surface">Smart order</span>
                <span className="block text-[11px] text-on-surface-variant">
                  {adaptive ? 'weak topics first · easy → hard' : "pack's natural exam order"}
                </span>
              </span>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={adaptive}
              onClick={() => setAdaptive((v) => !v)}
              className={`relative h-6 w-11 shrink-0 rounded-full transition ${adaptive ? 'bg-primary' : 'bg-outline-light'}`}
            >
              <span
                className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${
                  adaptive ? 'left-[22px]' : 'left-0.5'
                }`}
              />
            </button>
          </div>
          <button
            onClick={startAttempt}
            className="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
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
    const elapsedMs = startedAtRef.current ? Date.now() - startedAtRef.current : 0;
    // delta vs the previous graded attempt on the same pack (real history)
    const samePack = (allAttempts ?? []).filter(
      (a) => a.status === 'graded' && a.code === bundle?.code && a.score != null,
    );
    let delta: number | null = null;
    if (samePack.length >= 2 && bundle?.code) {
      const prev = Math.round((samePack[1].score! * 100) / samePack[1].total!);
      delta = pct - prev;
    }
    const xpEarned = result.score * 10; // XPPerCorrect = 10 (server rule)
    return (
      <main className="mx-auto w-full max-w-2xl px-4 pb-16 sm:px-6">
        {/* dark DIAGNOSTIC COMPLETE hero */}
        <section className="renance-rise relative overflow-hidden rounded-xl bg-dark-surface px-6 py-8 text-center">
          <p className="font-mono text-xs uppercase tracking-[0.24em] text-dark-text-secondary">
            Diagnostic Complete
          </p>
          <p className="mt-2 text-6xl font-bold tracking-tight text-dark-text-primary">
            {pct}
            <span className="text-2xl text-dark-text-secondary">%</span>
          </p>
          {delta != null && (
            <div className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1">
              <span
                className={`material-symbols-outlined text-sm ${delta >= 0 ? 'text-accent-emerald' : 'text-error'}`}
              >
                {delta >= 0 ? 'trending_up' : 'trending_down'}
              </span>
              <span
                className={`font-mono text-xs ${delta >= 0 ? 'text-accent-emerald' : 'text-error'}`}
              >
                {delta >= 0 ? `+${delta}` : delta} vs last attempt
              </span>
            </div>
          )}
        </section>

        {/* XP / streak card */}
        <section className="mt-4 flex items-center justify-between rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-accent-amber/10">
              <span className="material-symbols-outlined fill-current text-accent-amber">stars</span>
            </div>
            <div>
              <p className="text-sm font-semibold text-on-surface">Experience Gained</p>
              <p className="text-[13px] text-on-surface-variant">Keep the momentum going</p>
            </div>
          </div>
          <div className="text-right">
            <p className="text-lg font-bold text-accent-amber">+{xpEarned} XP</p>
            <p className="flex items-center justify-end gap-1 font-mono text-[11px] text-on-surface-variant">
              <span className="material-symbols-outlined fill-current text-[14px] text-accent-amber">
                local_fire_department
              </span>
              Streak Day {gam?.state.currentStreak ?? 0}
            </p>
          </div>
        </section>

        {/* stats grid */}
        <section className="mt-3 grid grid-cols-2 gap-3">
          <div className="rounded-xl bg-card p-4 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <span className="material-symbols-outlined text-secondary">timer</span>
            <p className="mt-1 text-xl font-bold text-on-surface">
              {elapsedMs ? mmss(Math.round(elapsedMs / 1000)) : '--:--'}
            </p>
            <p className="text-[13px] text-on-surface-variant">Time Used</p>
          </div>
          <div className="rounded-xl bg-card p-4 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <span className="material-symbols-outlined text-secondary">track_changes</span>
            <p className="mt-1 text-xl font-bold text-on-surface">
              {result.score}/{result.total}
            </p>
            <p className="text-[13px] text-on-surface-variant">Correct Answers</p>
          </div>
        </section>

        <h2 className="mt-6 text-lg font-semibold tracking-tight text-on-surface">Topic Breakdown</h2>
        <div className="mt-3 space-y-3">
          {result.breakdown.length === 0 && (
            <p className="rounded-xl bg-card p-4 text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
              No topic data on this paper — every question counted toward the overall score.
            </p>
          )}
          {result.breakdown.map((row) => {
            const rowPct = row.total > 0 ? Math.round((row.correct / row.total) * 100) : 0;
            const bar = rowPct >= 80 ? 'bg-accent-emerald' : rowPct >= 50 ? 'bg-accent-amber' : 'bg-error';
            return (
              <div
                key={row.topic}
                className="rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
              >
                <div className="mb-2 flex items-baseline justify-between text-sm">
                  <span className="font-semibold text-on-surface">{row.topic}</span>
                  <span className="font-mono text-xs text-on-surface-variant">
                    {rowPct}% · {row.correct}/{row.total}
                  </span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-surface-container">
                  <div className={`h-full rounded-full ${bar}`} style={{ width: `${rowPct}%` }} />
                </div>
              </div>
            );
          })}
          {/* Weak-topic recap (ROADMAP #4): under 60% becomes a chip that
              deep-links the syllabus map on this body. */}
          {(() => {
            const weak = result.breakdown
              .filter((r) => r.total > 0 && r.correct / r.total < 0.6)
              .sort((a, b) => a.correct / a.total - b.correct / b.total)
              .slice(0, 4);
            if (!weak.length) return null;
            const slug = bodySlug(bundle?.body ?? '') || 'jamb';
            return (
              <div className="pt-2">
                <h3 className="text-sm text-on-surface-variant">Focus next</h3>
                <div className="mt-2 flex flex-wrap gap-2">
                  {weak.map((row) => (
                    <Link
                      key={row.topic}
                      href={`/syllabus?body=${encodeURIComponent(slug)}&topic=${encodeURIComponent(row.topic)}`}
                      className="inline-flex items-center gap-1.5 rounded-full border border-accent-amber/40 bg-accent-amber/10 px-3 py-1.5 font-mono text-xs text-on-surface transition hover:shadow-sm"
                    >
                      <span className="material-symbols-outlined text-[14px] text-accent-amber">
                        local_fire_department
                      </span>
                      {row.topic} · {row.correct}/{row.total}
                    </Link>
                  ))}
                </div>
              </div>
            );
          })()}
        </div>

        <div className="mt-8 flex flex-col gap-2">
          {attempt && (
            <Link
              href={`/review?attemptId=${attempt.attemptId}`}
              className="flex h-[52px] w-full items-center justify-center rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
            >
              Review Answers
            </Link>
          )}
          <button
            onClick={() => {
              setAdaptive(true); // Retry Weak Topics = a smart-order paper
              setPhase('intro');
              setAttempt(null);
            }}
            className="flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] bg-transparent text-sm font-semibold text-on-surface shadow-[inset_0_0_0_1px_#C6C6CD] transition-all active:scale-[0.98]"
          >
            Retry Weak Topics
            <span className="material-symbols-outlined text-sm">arrow_forward</span>
          </button>
          <Link href="/dashboard" className="py-2 text-center text-sm text-on-surface-variant hover:text-on-surface">
            Back to dashboard
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
