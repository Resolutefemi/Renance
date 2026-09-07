'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import {
  fetchBundle,
  fetchBundleByCode,
  fetchManifest,
  isMockPaperCode,
  type Bundle,
} from '@/lib/exams';
import { clearActiveExam, loadActiveExam, saveActiveExam, type ActiveExam } from '@/lib/active-exam';
import { bodySlug } from '@/lib/syllabus';
import { assessFatigue, FATIGUE_NONE, type FatigueSignal } from '@/lib/fatigue';
import { FatigueNudgeOverlay } from '@/components/fatigue-nudge';
import CalculatorSheet from '@/components/calculator';
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

interface DailyInfo {
  day: string;
  body: string;
  code: string;
  title: string;
  questionCount: number;
  myResult?: { attemptId: string; score: number; total: number } | null;
}

type Phase = 'loading' | 'intro' | 'playing' | 'grading' | 'graded' | 'error';

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

export default function ExamPage({ code }: { code: string }) {
  const router = useRouter();

  // Practice Settings overrides (?timer=15|30|60, ?timer=0 = No timer).
  // State (not consts) so a resumed paper can restore the timer the
  // sitting was started with — the resume deep link carries no ?timer.
  const searchParams = useSearchParams();
  const timerParam = searchParams.get('timer');
  const [untimed, setUntimed] = useState(timerParam === '0');
  const [timerOverride, setTimerOverride] = useState<number | null>(
    timerParam && timerParam !== '0' ? Math.max(1, Number(timerParam) || 0) : null,
  );

  const [phase, setPhase] = useState<Phase>('loading');
  const [bundle, setBundle] = useState<Bundle | null>(null);
  const [meta, setMeta] = useState<ExamMetaLite | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [attempt, setAttempt] = useState<AttemptResponse | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [flags, setFlags] = useState<Record<string, boolean>>({});
  const [visited, setVisited] = useState<Record<string, boolean>>({});
  const [navOpen, setNavOpen] = useState(false);
  const [navFilter, setNavFilter] = useState<'all' | 'flagged' | 'skipped' | 'unseen'>('all');
  const [current, setCurrent] = useState(0);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [result, setResult] = useState<ResultPayload | null>(null);
  const [gam, setGam] = useState<{ state: { currentStreak: number; totalXp: number } } | null>(null);
  const [allAttempts, setAllAttempts] = useState<AttemptSummary[] | null>(null);
  // Smart order (ROADMAP #5): begin weak-topic-first by default; the
  // intro toggle flips it back to the pack's natural exam order.
  const [adaptive, setAdaptive] = useState(!isMockPaperCode(code));
  const [smartApplied, setSmartApplied] = useState(false);
  const startedAtRef = useRef<number>(0);
  const submittedRef = useRef(false);
  // Fatigue telemetry (ROADMAP #6): per-answer latencies, the running
  // signal, the nudge state and the 5-minute break it can trigger.
  // No PII beyond timing leaves the browser.
  const latenciesRef = useRef<number[]>([]);
  const shownAtRef = useRef<number>(0);
  const pausedMsRef = useRef(0);
  const breakLeftRef = useRef(0);
  const nudgeDismissedRef = useRef(false);
  const [breakLeft, setBreakLeft] = useState(0);
  const [fatigue, setFatigue] = useState<FatigueSignal>(FATIGUE_NONE);
  const [nudgeVisible, setNudgeVisible] = useState(false);
  // Pause & resume: the sitting the student walked away from, if any.
  const [paused, setPaused] = useState<ActiveExam | null>(null);
  // Daily challenge (?daily=1): today's sprint description from the API.
  const [daily, setDaily] = useState<DailyInfo | null>(null);
  // Composite UTME mocks run in exam mode: answers lock once picked
  // (the same rule as the real CBT hall and jamb-cbt-web's exam mode).
  const examMode = isMockPaperCode(code);
  const [calcOpen, setCalcOpen] = useState(false);

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
        // Composite mock papers never appear in the manifest — the server
        // composes them on demand, so resolve those straight by code.
        // Daily challenges resolve through /daily/{body} first.
        let b: Bundle;
        let meta: ExamMetaLite | null = null;
        let dailyInfo: DailyInfo | null = null;
        if (searchParams.get('daily') === '1') {
          dailyInfo = await api<DailyInfo>('/daily/jamb');
          if (!alive) return;
          if (dailyInfo.code !== code) {
            router.replace(`/exams/${dailyInfo.code}?daily=1`);
            return;
          }
          const manifest = await fetchManifest();
          const exam = manifest.exams.find((e) => e.code === code);
          if (!exam) throw new Error("Today's challenge pack is missing");
          meta = exam;
          b = await fetchBundle(exam);
        } else if (isMockPaperCode(code)) {
          b = await fetchBundleByCode(code);
        } else {
          const manifest = await fetchManifest();
          const exam = manifest.exams.find((e) => e.code === code);
          if (!exam) throw new Error('This pack is not in your manifest');
          meta = exam;
          b = await fetchBundle(exam);
        }
        if (!alive) return;
        setDaily(dailyInfo);
        setMeta(meta);
        setBundle(b);
        // Coming back for a paused paper (dashboard deep link) resumes
        // straight into the sitting; otherwise surface the resume card.
        const snap = loadActiveExam();
        if (snap && snap.code === code) {
          setPaused(snap);
          if (searchParams.get('resume') === '1') {
            resumeAttempt(snap, b);
            return;
          }
        }
        setPhase('intro');
      } catch (err) {
        if (!alive) return;
        setError(err instanceof Error ? err.message : 'Could not load pack');
        setPhase('error');
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
    return () => {
      alive = false;
    };
  }, [code]);

  /** Rebuild a paused sitting: same picks, same walk, honest clock. */
  function resumeAttempt(snap: ActiveExam, b: Bundle) {
    let ordered = b;
    if (snap.order?.length) {
      const byId = new Map(b.questions.map((q) => [q.id, q]));
      const seq = snap.order
        .map((id) => byId.get(id))
        .filter((q): q is NonNullable<typeof q> => Boolean(q));
      for (const q of b.questions) {
        if (!snap.order.includes(q.id)) seq.push(q);
      }
      ordered = { ...b, questions: seq };
    }
    setBundle(ordered);
    setAttempt({
      attemptId: snap.attemptId,
      code: snap.code,
      status: 'in_progress',
      startedAt: new Date(snap.startedAt).toISOString(),
      durationMinutes: b.durationMinutes ?? null,
      questionCount: b.questionCount,
      adaptive: snap.adaptive,
      order: snap.order,
    });
    setAnswers(snap.answers ?? {});
    setFlags(snap.flags ?? {});
    setVisited(snap.visited ?? {});
    setCurrent(Math.min(snap.current ?? 0, Math.max(b.questionCount - 1, 0)));
    setAdaptive(snap.adaptive);
    setUntimed(snap.untimed);
    setTimerOverride(snap.timerMinutes);
    submittedRef.current = false;
    startedAtRef.current = snap.startedAt; // the clock never paused with you
    pausedMsRef.current = snap.pausedMs ?? 0;
    shownAtRef.current = Date.now();
    latenciesRef.current = [];
    breakLeftRef.current = 0;
    setBreakLeft(0);
    nudgeDismissedRef.current = false;
    setNudgeVisible(false);
    setFatigue(FATIGUE_NONE);
    setSmartApplied(Boolean(snap.order?.length));
    setNavFilter('all');
    setNavOpen(false);
    setResult(null);
    setPaused(null);
    setPhase('playing');
  }

  // Leaving mid-paper is a pause, not a loss: every change lands in the
  // snapshot, so the dashboard can offer the exact seat back.
  useEffect(() => {
    if (phase !== 'playing' || !attempt) return;
    saveActiveExam({
      attemptId: attempt.attemptId,
      code: attempt.code,
      title: bundle?.title ?? attempt.code,
      questionCount: bundle?.questionCount ?? 0,
      startedAt: startedAtRef.current,
      pausedMs: pausedMsRef.current,
      answers,
      flags,
      visited,
      current,
      order: attempt.order ?? null,
      adaptive: attempt.adaptive ?? false,
      untimed,
      timerMinutes: timerOverride,
      savedAt: Date.now(),
    });
  }, [phase, attempt, bundle, answers, flags, visited, current, breakLeft, untimed, timerOverride]);

  const submit = useCallback(async () => {
    if (!attempt || submittedRef.current) return;
    submittedRef.current = true;
    // Fire-and-forget telemetry (ROADMAP #6): the server re-computes the
    // same pure signal from the raw latencies and logs the sitting.
    void api('/me/sessions', {
      method: 'POST',
      body: {
        attemptId: attempt.attemptId,
        code: attempt.code,
        startedAt: attempt.startedAt,
        durationMs: Math.round(Date.now() - startedAtRef.current - pausedMsRef.current),
        latenciesMs: [...latenciesRef.current],
      },
    }).catch(() => {});
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
      // Submitted: the pause snapshot has served its purpose.
      clearActiveExam();
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
          throw new Error('Grading hit an error, our team sees it too. Try again.');
        }
        await new Promise((r) => setTimeout(r, 1000));
      }
      throw new Error('Grading is taking unusually long.');
    } catch (err) {
      // Closed elsewhere (e.g. resubmit guard): the pause is dead too.
      if (err instanceof ApiError && err.code === 'already_submitted') clearActiveExam();
      setError(err instanceof Error ? err.message : 'Submission failed');
      setPhase('error');
    }
  }, [attempt, answers]);

  // countdown
  useEffect(() => {
    if (phase !== 'playing' || !attempt) return;
    const totalSec =
      timerOverride != null
        ? timerOverride * 60
        : untimed
          ? 0
          : (bundle?.durationMinutes ?? 30) * 60;
    const tick = () => {
      // "Take 5": the break runs its own countdown and the exam clock is
      // paused for it, that is the whole point of the break.
      if (breakLeftRef.current > 0) {
        breakLeftRef.current -= 1;
        setBreakLeft(breakLeftRef.current);
        pausedMsRef.current += 1000;
        return;
      }
      const elapsed = Math.floor(
        (Date.now() - startedAtRef.current - pausedMsRef.current) / 1000,
      );
      // Untimed practice runs a count-up clock and never auto-submits.
      if (untimed) {
        setRemaining(elapsed);
        return;
      }
      const left = totalSec - elapsed;
      setRemaining(Math.max(left, 0));
      if (left <= 0) void submit();
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [phase, attempt, bundle, submit, untimed, timerOverride]);

  async function startAttempt() {
    if (!bundle) return;
    // One paper at a time (JAMB style): a fresh start retires any pause.
    clearActiveExam();
    setPaused(null);
    try {
      // Daily sprints pin the server's seeded order and mocks keep the
      // composed paper order, so neither takes the adaptive walk.
      const wantsAdaptive = adaptive && !daily && !examMode;
      const res = await api<AttemptResponse>('/attempts', {
        method: 'POST',
        body: {
          code: bundle.code,
          ...(daily ? { daily: true } : {}),
          ...(wantsAdaptive ? { adaptive: true } : {}),
        },
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
      setVisited(bundle ? { [bundle.questions[0].id]: true } : {});
      setNavFilter('all');
      setCurrent(0);
      setResult(null);
      submittedRef.current = false;
      startedAtRef.current = Date.now();
      shownAtRef.current = Date.now();
      latenciesRef.current = [];
      pausedMsRef.current = 0;
      breakLeftRef.current = 0;
      setBreakLeft(0);
      nudgeDismissedRef.current = false;
      setNudgeVisible(false);
      setFatigue(FATIGUE_NONE);
      setPhase('playing');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not start attempt');
      setPhase('error');
    }
  }

  const question = bundle?.questions[current];
  const answeredCount = useMemo(() => Object.keys(answers).length, [answers]);
  const mmss = (s: number) => {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = s % 60;
    return h > 0
      ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
      : `${m}:${String(sec).padStart(2, '0')}`;
  };

  /** Records an answer: latency telemetry + fatigue assessment first. */
  const pick = (questionId: string, letter: string) => {
    // Exam mode (UTME mock): the hall rule — a pick is final.
    if (examMode && answers[questionId]) return;
    if (!answers[questionId]) {
      const latencies = [...latenciesRef.current, Date.now() - shownAtRef.current];
      latenciesRef.current = latencies;
      const minutes =
        (Date.now() - startedAtRef.current - pausedMsRef.current) / 60000;
      const sig = assessFatigue(latencies, minutes);
      setFatigue(sig);
      if (sig.suggestBreak && !nudgeDismissedRef.current) setNudgeVisible(true);
    }
    setAnswers((a) => ({ ...a, [questionId]: letter }));
  };

  /** Question navigation resets the per-question latency clock. */
  const goTo = (i: number) => {
    setCurrent(i);
    setVisited((v) => {
      const q = bundle?.questions[i];
      return q && !v[q.id] ? { ...v, [q.id]: true } : v;
    });
    shownAtRef.current = Date.now();
  };

  const takeBreak = () => {
    breakLeftRef.current = 300;
    setBreakLeft(300);
    setNudgeVisible(false);
    nudgeDismissedRef.current = true;
    shownAtRef.current = Date.now(); // the break is not answer time
  };

  const keepGoing = () => {
    setNudgeVisible(false);
    nudgeDismissedRef.current = true;
  };

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
    // Time left on the paused paper, if it was timed (JAMB-fair clock).
    const pausedLeftSec =
      paused && !paused.untimed
        ? Math.max(
            (paused.timerMinutes ?? bundle.durationMinutes ?? 30) * 60 -
              Math.floor((Date.now() - paused.startedAt - (paused.pausedMs ?? 0)) / 1000),
            0,
          )
        : null;
    return (
      <Centered>
        <div className="renance-rise w-full max-w-lg rounded-2xl bg-surface-container-lowest p-8 text-center shadow-md">
          <div className="mb-4 flex justify-center">
            <RenanceMark size={56} />
          </div>
          {examMode && (
            <p className="mx-auto mb-2 w-fit rounded-full bg-accent-ink/5 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.2em] text-accent-ink">
              Standard UTME Mock
            </p>
          )}
          {daily && (
            <p className="mx-auto mb-2 w-fit rounded-full bg-accent-amber/15 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.2em] text-on-surface">
              Daily Challenge · {daily.day}
            </p>
          )}
          <h1 className="text-xl font-semibold text-on-surface">{bundle.title}</h1>
          <p className="mt-2 text-sm text-on-surface-variant">
            {bundle.questionCount} questions · {bundle.durationMinutes ?? 30} minutes ·{' '}
            {bundle.totalMarks} marks
          </p>
          <ul className="mx-auto mt-6 max-w-xs space-y-1.5 text-left text-xs text-on-surface-variant">
            <li>· Timer starts the moment you begin</li>
            <li>· Auto-submit when time runs out</li>
            {examMode && <li>· Exam mode: answers lock once picked</li>}
            {daily && <li>· Same 10 questions for every student today</li>}
            <li>· Grading happens server-side: leave any time after submitting</li>
          </ul>
          {/* Daily: show today's seated score + board link once played */}
          {daily && daily.myResult && (
            <div className="mx-auto mt-5 flex w-full max-w-xs items-center justify-between rounded-xl bg-accent-emerald/10 px-4 py-3 text-left">
              <p className="text-[13px] font-semibold text-on-surface">
                Played today · {daily.myResult.score}/{daily.myResult.total}
              </p>
              <Link
                href="/leaderboard?tab=daily"
                className="text-[12px] font-semibold text-primary underline-offset-2 hover:underline"
              >
                Board
              </Link>
            </div>
          )}
          {/* Paused paper card: only shows when the student left mid-sitting */}
          {paused && (
            <div className="mx-auto mt-5 w-full max-w-xs rounded-xl border border-accent-amber/50 bg-accent-amber/10 px-4 py-3 text-left">
              <div className="flex items-center justify-between gap-2">
                <p className="text-[13px] font-semibold text-on-surface">Paused paper found</p>
                <span className="shrink-0 rounded-full bg-accent-amber/20 px-2 py-0.5 font-mono text-[10px] text-on-surface">
                  {Object.keys(paused.answers ?? {}).length}/{paused.questionCount} answered
                </span>
              </div>
              <p className="mt-1 text-[11px] text-on-surface-variant">
                {pausedLeftSec == null
                  ? 'Untimed paper · your clock continues where it stopped'
                  : pausedLeftSec <= 0
                    ? 'Time is up — resuming submits the paper for marking'
                    : `Time left on this paper: ${mmss(pausedLeftSec)}`}
              </p>
              <button
                onClick={() => resumeAttempt(paused, bundle)}
                className="mt-2.5 w-full rounded-lg bg-primary px-3 py-2 text-[13px] font-semibold text-on-primary transition active:scale-[0.98]"
              >
                Resume Exam
              </button>
              <button
                onClick={() => {
                  clearActiveExam();
                  setPaused(null);
                }}
                className="mt-1.5 w-full text-[11px] text-on-surface-variant underline-offset-2 hover:underline"
              >
                Discard and start fresh
              </button>
            </div>
          )}
          {/* Smart order (ROADMAP #5) — practice packs only */}
          {!examMode && !daily && (
          <div className="mx-auto mt-5 flex w-full max-w-xs items-center justify-between rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5">
            <div className="flex items-center gap-2 text-left">
              <span
                className={`material-symbols-outlined text-[18px] ${adaptive ? 'text-accent-ink' : 'text-outline-dark'}`}
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
          )}
          <button
            onClick={startAttempt}
            className="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
          >
            {paused ? 'Start a fresh paper instead' : daily ? 'Start the challenge' : 'Begin'}
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

    // results_recovery_light: the low-score variant of the score report.
    if (pct < 50) {
      const weak = [...result.breakdown]
        .filter((r) => r.total > 0 && r.correct / r.total < 0.8)
        .sort((a, b) => a.correct / a.total - b.correct / b.total);
      const C = 2 * Math.PI * 52;
      return (
        <main className="mx-auto w-full max-w-2xl px-4 pb-16 sm:px-6">
          <section className="renance-rise rounded-xl bg-[#FDF3F2] px-6 py-8 text-center">
            <div className="relative mx-auto h-32 w-32">
              <svg viewBox="0 0 120 120" className="h-full w-full -rotate-90" aria-hidden>
                <circle cx="60" cy="60" r="52" fill="none" stroke="#E7EEFF" strokeWidth="10" />
                <circle
                  cx="60" cy="60" r="52" fill="none" stroke="#BA1A1A" strokeWidth="10"
                  strokeLinecap="round"
                  strokeDasharray={`${(pct / 100) * C} ${C}`}
                />
              </svg>
              <p className="absolute inset-0 flex items-center justify-center text-2xl font-bold text-error">
                {pct}%
              </p>
            </div>
            <h1 className="mx-auto mt-5 max-w-sm text-xl font-semibold leading-snug tracking-tight text-on-surface">
              The review list below is where the points are.
            </h1>
            <p className="mt-2 text-[15px] text-on-surface-variant">
              Don&apos;t sweat it. Focus on the gaps.
            </p>
            <div className="mt-5 inline-flex items-center gap-2 rounded-full bg-surface-container px-4 py-2">
              <span className="material-symbols-outlined fill-current text-[18px] text-accent-ink">stars</span>
              <span className="text-sm font-semibold text-on-surface">+{xpEarned}</span>
              <span className="text-sm text-on-surface-variant">XP Earned</span>
            </div>
          </section>

          <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Topics to Review</h2>
          <div className="mt-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            {weak.length === 0 && (
              <p className="text-[13px] text-on-surface-variant">
                Nothing critical here, the review list has every question from this paper.
              </p>
            )}
            {weak.map((row) => {
              const frac = row.total > 0 ? row.correct / row.total : 0;
              const bar = frac < 0.5 ? 'bg-error' : 'bg-accent-amber';
              return (
                <div key={row.topic} className="py-1">
                  <div className="flex items-center justify-between">
                    <span className="text-[15px] font-semibold text-on-surface">{row.topic}</span>
                    <span className={`text-sm font-semibold ${bar.replace('bg-', 'text-')}`}>
                      {row.correct}/{row.total} pts
                    </span>
                  </div>
                  <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-surface-container">
                    <div className={`h-full rounded-full ${bar}`} style={{ width: `${frac * 100}%` }} />
                  </div>
                </div>
              );
            })}
          </div>

          <div className="mt-8 flex flex-col gap-2">
            {attempt && (
              <Link
                href={`/review?attemptId=${attempt.attemptId}`}
                className="flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
              >
                Review answers
                <span className="material-symbols-outlined text-[18px]">arrow_forward</span>
              </Link>
            )}
            <button
              onClick={() => {
                setAdaptive(true);
                setPhase('intro');
                setAttempt(null);
              }}
              className="flex h-[52px] w-full items-center justify-center rounded-[10px] bg-transparent text-sm font-semibold text-on-surface shadow-[inset_0_0_0_1px_#C6C6CD] transition-all active:scale-[0.98]"
            >
              Retry weak topics
            </button>
            <Link href="/dashboard" className="py-2 text-center text-sm text-on-surface-variant hover:text-on-surface">
              Back to dashboard
            </Link>
          </div>
        </main>
      );
    }

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
              {elapsedMs ? mmss(Math.round(elapsedMs / 1000)) : mmss(0)}
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
              No topic data on this paper, every question counted toward the overall score.
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
          {daily && (
            <Link
              href="/leaderboard?tab=daily"
              className="flex h-[52px] w-full items-center justify-center gap-2 rounded-[10px] bg-accent-ink text-sm font-semibold text-white shadow-md transition-all hover:opacity-90 active:scale-[0.98]"
            >
              <span className="material-symbols-outlined text-[18px]">leaderboard</span>
              See today's challenge board
            </Link>
          )}
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

  /* ------------------------------------------------- navigator bookkeeping */

  const navIsAnswered = (id: string) => Boolean(answers[id]);
  const navIsFlagged = (id: string) => Boolean(flags[id]);
  const navIsVisited = (id: string) => Boolean(visited[id]);
  const navIndices = bundle.questions.map((q, i) => ({ q, i }));
  const navCounts = {
    all: navIndices.length,
    flagged: navIndices.filter((x) => navIsFlagged(x.q.id)).length,
    skipped: navIndices.filter((x) => navIsVisited(x.q.id) && !navIsAnswered(x.q.id)).length,
    unseen: navIndices.filter((x) => !navIsVisited(x.q.id)).length,
  };
  const navShown = navIndices.filter(({ q }) =>
    navFilter === 'all'
      ? true
      : navFilter === 'flagged'
        ? navIsFlagged(q.id)
        : navFilter === 'skipped'
          ? navIsVisited(q.id) && !navIsAnswered(q.id)
          : !navIsVisited(q.id),
  );
  const navTileClass = (id: string) => {
    const answered = navIsAnswered(id);
    const flagged = navIsFlagged(id);
    if (answered && flagged) return 'border-2 border-accent-amber bg-primary text-on-primary';
    if (answered) return 'bg-primary text-on-primary';
    if (flagged) return 'border-2 border-accent-amber bg-card text-on-surface';
    if (navIsVisited(id)) return 'border border-surface-container bg-surface-container text-on-surface-variant';
    return 'border border-outline-variant/60 bg-card text-on-surface-variant';
  };

  /* ----------------------------------------------------------- playing */

  return (
    <>
      <FatigueNudgeOverlay
        visible={nudgeVisible}
        reasons={fatigue.reasons}
        onTakeBreak={takeBreak}
        onKeepGoing={keepGoing}
      />
      <main className="min-h-dvh bg-gradient-to-b from-selection-blue/60 via-background to-background">
      {/* sticky exam chrome: leave · title · calculator · clock · map */}
      <header className="sticky top-0 z-40 border-b border-outline-variant/40 bg-surface/90 backdrop-blur-xl">
        <div className="mx-auto flex h-14 w-full max-w-3xl items-center justify-between gap-2 px-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-1">
            <Link
              href="/dashboard"
              aria-label="Leave exam"
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
            >
              <span className="material-symbols-outlined text-[22px]">arrow_back</span>
            </Link>
            <p className="min-w-0 truncate text-[13px] font-semibold text-on-surface-variant">
              {bundle.title}
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-1.5">
            <button
              onClick={() => setCalcOpen(true)}
              aria-label="Open calculator"
              title="Calculator"
              className="flex h-10 items-center gap-1.5 rounded-full bg-accent-ink px-3 text-white shadow-sm transition hover:opacity-90 active:scale-95"
            >
              <span className="material-symbols-outlined fill-current text-[19px]">calculate</span>
              <span className="hidden text-[12px] font-semibold sm:inline">Calculator</span>
            </button>
            <div
              className={`rounded-lg border px-3 py-1.5 font-mono text-sm tabular-nums ${
                breakLeft > 0
                  ? 'border-accent-ink text-accent-ink'
                  : remaining !== null && remaining < 60
                    ? 'border-error bg-error-container text-on-error-container'
                    : remaining !== null && remaining < 300
                      ? 'border-accent-amber bg-accent-amber/10 text-on-surface'
                      : 'border-outline-variant bg-card text-on-surface'
              }`}
            >
              {breakLeft > 0
                ? `break ${mmss(breakLeft)}`
                : remaining !== null
                  ? mmss(remaining)
                  : mmss(0)}
            </div>
            <button
              onClick={() => setNavOpen(true)}
              aria-label="Question navigator"
              className="flex h-10 w-10 items-center justify-center rounded-full bg-card text-on-surface shadow-sm transition hover:bg-surface-container"
            >
              <span className="material-symbols-outlined text-[22px]">grid_view</span>
            </button>
          </div>
        </div>
        {/* answered progress rail */}
        <div className="h-1 w-full bg-surface-variant/50">
          <div
            className="h-full rounded-r-full bg-gradient-to-r from-primary to-accent-emerald transition-all duration-300"
            style={{ width: `${(answeredCount / Math.max(bundle.questionCount, 1)) * 100}%` }}
          />
        </div>
        {/* subject tabs (composite UTME papers) */}
        {bundle.sections && bundle.sections.length > 1 && (
          <div className="mx-auto w-full max-w-3xl px-4 sm:px-6">
            <div className="no-scrollbar flex items-center gap-2 overflow-x-auto pb-2 pt-2">
              {(() => {
                let index = 0;
                return bundle.sections.map((sec) => {
                  const startIndex = index;
                  index += sec.questionIds.length;
                  const answered = sec.questionIds.filter((id) => answers[id]).length;
                  const active =
                    current >= startIndex && current < startIndex + sec.questionIds.length;
                  return (
                    <button
                      key={sec.subject}
                      type="button"
                      onClick={() => goTo(startIndex)}
                      className={`flex shrink-0 items-center gap-2 rounded-full px-3.5 py-1.5 text-[12px] transition ${
                        active
                          ? 'bg-primary font-semibold text-on-primary shadow-sm'
                          : 'bg-card text-on-surface-variant shadow-sm hover:bg-surface-container'
                      }`}
                    >
                      <span
                        className={`h-1.5 w-1.5 rounded-full ${
                          answered === sec.questionIds.length
                            ? 'bg-accent-emerald'
                            : answered > 0
                              ? 'bg-accent-amber'
                              : active
                                ? 'bg-on-primary/60'
                                : 'bg-outline-variant'
                        }`}
                      />
                      {sec.subject}
                      <span className={`font-mono text-[10px] ${active ? 'text-on-primary/70' : 'text-outline'}`}>
                        {answered}/{sec.questionIds.length}
                      </span>
                    </button>
                  );
                });
              })()}
            </div>
          </div>
        )}
      </header>

      <div className="mx-auto w-full max-w-3xl px-4 pb-40 pt-5 sm:px-6">
        {/* question card */}
        <div className="renance-rise rounded-2xl border border-outline-variant/50 bg-card p-6 shadow-[0_2px_12px_0_rgba(20,28,45,0.10)] sm:p-7">
          <div className="flex items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-2.5">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary font-mono text-[13px] font-bold text-on-primary shadow-sm">
                {current + 1}
              </span>
              <span className="flex min-w-0 flex-col">
                <span className="font-mono text-[10px] uppercase tracking-wider text-outline">
                  of {bundle.questionCount}
                </span>
                {question.topic && (
                  <span className="truncate text-[11px] font-medium text-on-surface-variant">
                    {question.topic}
                  </span>
                )}
              </span>
            </div>
            <button
              onClick={() => setFlags((f) => ({ ...f, [question.id]: !f[question.id] }))}
              className={`flex shrink-0 items-center gap-1 rounded-full border px-2.5 py-1 text-[11px] transition ${
                flags[question.id]
                  ? 'border-accent-amber bg-accent-amber/15 text-accent-ink'
                  : 'border-outline-variant text-on-surface-variant hover:border-outline'
              }`}
            >
              <span className={`material-symbols-outlined text-[14px] ${flags[question.id] ? 'fill-current text-accent-amber' : ''}`}>
                flag
              </span>
              {flags[question.id] ? 'flagged' : 'flag'}
            </button>
          </div>
          <p className="mt-4 text-[16px] leading-relaxed text-on-surface">{question.stem}</p>
          <div className="mt-6 space-y-2.5">
            {Object.entries(question.options ?? {}).map(([letter, text]) => {
              const selected = answers[question.id] === letter;
              const locked = examMode && Boolean(answers[question.id]) && !selected;
              return (
                <button
                  key={letter}
                  onClick={() => pick(question.id, letter)}
                  disabled={locked}
                  className={`flex w-full items-start gap-3 rounded-xl border px-4 py-3.5 text-left text-sm transition ${
                    selected
                      ? 'border-primary bg-selection-blue/60 shadow-[inset_0_0_0_1px_var(--color-primary)]'
                      : locked
                        ? 'border-transparent bg-surface-container-low/40 opacity-55'
                        : 'border-outline-variant bg-surface-container-lowest/60 hover:border-outline hover:shadow-sm active:scale-[0.995]'
                  }`}
                >
                  <span
                    className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border text-xs font-bold uppercase ${
                      selected
                        ? 'border-primary bg-primary text-on-primary'
                        : 'border-outline-light bg-card text-on-surface-variant'
                    }`}
                  >
                    {letter}
                  </span>
                  <span className="flex-1 text-on-surface">{text}</span>
                  {selected && examMode && (
                    <span className="material-symbols-outlined fill-current text-[16px] text-primary" title="Locked in exam mode">
                      lock
                    </span>
                  )}
                </button>
              );
            })}
          </div>
          {examMode && answers[question.id] && (
            <p className="mt-3 flex items-center gap-1.5 text-[11px] text-on-surface-variant">
              <span className="material-symbols-outlined text-[14px]">lock</span>
              Exam mode — this answer is locked, exactly like the hall.
            </p>
          )}
        </div>
      </div>

      {/* sticky action bar */}
      <div className="fixed bottom-0 inset-x-0 z-40 border-t border-outline-variant/40 bg-surface/95 backdrop-blur-xl">
        <div className="mx-auto flex h-[68px] w-full max-w-3xl items-center justify-between gap-3 px-4 pb-[env(safe-area-inset-bottom)] sm:px-6">
          <button
            onClick={() => goTo(Math.max(0, current - 1))}
            disabled={current === 0}
            className="rounded-xl border border-outline-variant bg-card px-5 py-2.5 text-sm font-medium text-on-surface transition hover:border-outline disabled:opacity-40"
          >
            ← Prev
          </button>
          <p className="text-center font-mono text-[11px] text-on-surface-variant">
            {answeredCount}/{bundle.questionCount} answered
          </p>
          {current === bundle.questionCount - 1 || answeredCount === bundle.questionCount ? (
            <button
              onClick={() => {
                if (answeredCount < bundle.questionCount) {
                  const left = bundle.questionCount - answeredCount;
                  if (!window.confirm(`${left} unanswered. Submit anyway?`)) return;
                }
                void submit();
              }}
              className="rounded-xl bg-primary px-6 py-2.5 text-sm font-semibold text-on-primary shadow-md transition-all hover:shadow-lg active:scale-[0.98]"
            >
              Submit paper
            </button>
          ) : (
            <button
              onClick={() => goTo(Math.min(bundle.questionCount - 1, current + 1))}
              className="rounded-xl bg-accent-ink px-6 py-2.5 text-sm font-semibold text-white shadow-md transition-all hover:opacity-90 active:scale-[0.98]"
            >
              Next →
            </button>
          )}
        </div>
      </div>
      </main>

      {/* JAMB-hall calculator */}
      <CalculatorSheet open={calcOpen} onClose={() => setCalcOpen(false)} />

      {/* question_navigator_light sheet */}
      {navOpen && (
        <div className="fixed inset-0 z-50 flex items-end justify-center">
          <button
            aria-label="Close navigator"
            onClick={() => setNavOpen(false)}
            className="absolute inset-0 bg-accent-ink/40"
          />
          <div className="relative max-h-[88dvh] w-full overflow-y-auto rounded-t-3xl bg-background p-4 pb-6 shadow-2xl sm:p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-semibold tracking-tight text-on-surface">
                Question Navigator
              </h2>
              <button
                onClick={() => setNavOpen(false)}
                aria-label="Close"
                className="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-low text-on-surface"
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>

            <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
              {(['all', 'flagged', 'skipped', 'unseen'] as const).map((f) => (
                <button
                  key={f}
                  onClick={() => setNavFilter(f)}
                  className={`whitespace-nowrap rounded-full px-4 py-2.5 text-sm transition ${
                    navFilter === f
                      ? 'bg-selection-blue font-semibold text-on-surface'
                      : 'bg-surface-container-low font-medium text-on-surface-variant'
                  }`}
                >
                  {f === 'all'
                    ? `All (${navCounts.all})`
                    : `${f[0].toUpperCase()}${f.slice(1)} (${navCounts[f]})`}
                </button>
              ))}
            </div>

            {bundle.sections && bundle.sections.length > 1 ? (
              // Composite papers: one labelled grid per subject, the way
              // the real CBT navigator splits the paper.
              (() => {
                let index = 0;
                return bundle.sections.map((sec) => {
                  const start = index;
                  index += sec.questionIds.length;
                  const tiles = navIndices.filter(({ i }) => i >= start && i < start + sec.questionIds.length);
                  const shown = tiles.filter(({ q }) =>
                    navFilter === 'all'
                      ? true
                      : navFilter === 'flagged'
                        ? navIsFlagged(q.id)
                        : navFilter === 'skipped'
                          ? navIsVisited(q.id) && !navIsAnswered(q.id)
                          : !navIsVisited(q.id),
                  );
                  return (
                    <div key={sec.subject} className="mt-4">
                      <p className="mb-2 flex items-center gap-2 font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">
                        {sec.subject}
                        <span className="text-outline">
                          {tiles.filter(({ q }) => navIsAnswered(q.id)).length}/{tiles.length}
                        </span>
                      </p>
                      <div className="grid grid-cols-5 gap-3">
                        {shown.length === 0 && (
                          <p className="col-span-5 py-3 text-center text-[12px] text-outline">—</p>
                        )}
                        {shown.map(({ q, i }) => (
                          <button
                            key={q.id}
                            onClick={() => {
                              goTo(i);
                              setNavOpen(false);
                            }}
                            className={`relative flex h-14 items-center justify-center rounded-xl text-base font-semibold transition ${navTileClass(q.id)}`}
                          >
                            {i + 1}
                            {navIsFlagged(q.id) && (
                              <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-accent-amber" />
                            )}
                          </button>
                        ))}
                      </div>
                    </div>
                  );
                });
              })()
            ) : (
            <div className="mt-4 grid grid-cols-5 gap-3">
              {navShown.length === 0 && (
                <p className="col-span-5 py-8 text-center text-[13px] text-on-surface-variant">
                  Nothing here yet.
                </p>
              )}
              {navShown.map(({ q, i }) => (
                <button
                  key={q.id}
                  onClick={() => {
                    goTo(i);
                    setNavOpen(false);
                  }}
                  className={`relative flex h-14 items-center justify-center rounded-xl text-base font-semibold transition ${navTileClass(q.id)}`}
                >
                  {i + 1}
                  {navIsFlagged(q.id) && (
                    <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-accent-amber" />
                  )}
                </button>
              ))}
            </div>
            )}

            <div className="mt-4 flex flex-wrap gap-x-4 gap-y-2 text-[13px] text-on-surface-variant">
              <span className="flex items-center gap-1.5">
                <span className="h-3 w-3 rounded-[3px] bg-primary" /> Answered
              </span>
              <span className="flex items-center gap-1.5">
                <span className="relative h-3 w-3 rounded-[3px] border-[1.5px] border-accent-amber bg-card">
                  <span className="absolute -right-0.5 -top-0.5 h-1 w-1 rounded-full bg-accent-amber" />
                </span>
                Flagged
              </span>
              <span className="flex items-center gap-1.5">
                <span className="h-3 w-3 rounded-[3px] bg-surface-container" /> Skipped
              </span>
              <span className="flex items-center gap-1.5">
                <span className="h-3 w-3 rounded-[3px] border border-outline-variant bg-card" /> Unseen
              </span>
            </div>

            <button
              onClick={() => setNavOpen(false)}
              className="mt-5 flex h-[52px] w-full items-center justify-center rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98]"
            >
              Resume Exam
            </button>
          </div>
        </div>
      )}
    </>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-background px-6">
      {children}
    </main>
  );
}
