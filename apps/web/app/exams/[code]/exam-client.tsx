'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import { parsePaperCode, segmentSubjects } from '@/lib/paper-compose';
import {
  examHref,
  fetchBundle,
  fetchBundleByCode,
  fetchManifest,
  gradeLocally,
  isComposedPaperCode,
  isMockPaperCode,
  migrateBundleCache,
  subjectName,
  type Bundle,
  type Manifest,
} from '@/lib/exams';
import { clearActiveExam, loadActiveExam, saveActiveExam, type ActiveExam } from '@/lib/active-exam';
import { bodySlug } from '@/lib/syllabus';
import { assessFatigue, FATIGUE_NONE, type FatigueSignal } from '@/lib/fatigue';
import { FatigueNudgeOverlay } from '@/components/fatigue-nudge';
import CalculatorSheet from '@/components/calculator';
import { LogoActivityIndicator } from '@/components/renance-logo';
import { apiImg, QText } from '@/lib/qtext';
import { assessLivePacing, computePacingForensics, type QuestionTimeRecord } from '@/lib/pacing';
import PacingGauge from '@/components/pacing-gauge';
import PacingForensicsCard from '@/components/pacing-forensics';

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
  /** true when graded on-device (offline / signed-out fallback). */
  local?: boolean;
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

/**
 * Deep links arrive from the wild: chats, address bars, other clients
 * that append params with a second "?" (?code=…~n=40?shuffle=1). Only
 * the first "?" starts the query string, so everything after a stray
 * one rides INSIDE the code value and poisons the compose. Strip it,
 * and trim the board-room whitespace while at it.
 */
function sanitizeCode(raw: string): string {
  const cut = raw.indexOf('?');
  const base = cut >= 0 ? raw.slice(0, cut) : raw;
  return base.trim();
}

/** The single pinned year on a composed paper code, when there is one. */
function specYearLabel(code: string): string | null {
  const spec = parsePaperCode(code);
  if (!spec || spec.years.length === 0) return null;
  const distinct = new Set(spec.years);
  if (distinct.size !== 1) return null;
  const y = spec.years[0];
  return y > 0 ? String(y) : null;
}

export default function ExamPage({ code: routeCode }: { code: string }) {
  const router = useRouter();

  // Practice Settings overrides (?timer=15|30|60, ?timer=0 = No timer).
  // State (not consts) so a resumed paper can restore the timer the
  // sitting was started with, the resume deep link carries no ?timer.
  const searchParams = useSearchParams();
  const timerParam = searchParams.get('timer');
  // Composed papers land on the static /exams/paper/ route with the
  // real code in the query string (?code=…), static export cannot
  // enumerate their infinite ~param combinations as paths.
  const code = sanitizeCode(routeCode || searchParams.get('code') || '');
  const [untimed, setUntimed] = useState(timerParam === '0');
  const [timerOverride, setTimerOverride] = useState<number | null>(
    timerParam && timerParam !== '0' ? Math.max(1, Number(timerParam) || 0) : null,
  );

  const [phase, setPhase] = useState<Phase>('loading');
  const [retry, setRetry] = useState(0);
  const [bundle, setBundle] = useState<Bundle | null>(null);
  const [meta, setMeta] = useState<ExamMetaLite | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [attempt, setAttempt] = useState<AttemptResponse | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  // Theory drafts: the essay text typed per question, device-local only,
  // never submitted (ADR-0003: student content stays client-side).
  const [theoryDrafts, setTheoryDrafts] = useState<Record<string, string>>({});
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
  // Official UTME mocks run in exam mode and skip the smart walk;
  // custom practice papers and carved subsets play like practice.
  const [adaptive, setAdaptive] = useState(!isMockPaperCode(code));
  const [smartApplied, setSmartApplied] = useState(false);
  const startedAtRef = useRef<number>(0);
  const submittedRef = useRef(false);
  // Fatigue telemetry (ROADMAP #6): per-answer latencies, the running
  // signal, the nudge state and the 5-minute break it can trigger.
  // No PII beyond timing leaves the browser.
  const latenciesRef = useRef<number[]>([]);
  const shownAtRef = useRef<number>(0);
  const questionMsMapRef = useRef<Record<string, number>>({});
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
  // Composite UTME mocks run in exam mode (full CBT chrome, no smart
  // walk); answers stay editable there too - the founder pulled the
  // lock, options are changeable on every quiz page. Custom/pick
  // papers compose server-side but play in practice mode.
  const examMode = isMockPaperCode(code);
  const [calcOpen, setCalcOpen] = useState(false);
  // The manifest feeds the instructions page's Summary (per-subject
  // counts on custom papers); a confirmation dialog replaces the raw
  // window.confirm for Quit / Submit (the school app's dialog cut).
  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [confirm, setConfirm] = useState<{
    title: string;
    body: string;
    confirmLabel: string;
    danger?: boolean;
    onConfirm: () => void;
  } | null>(null);

  useEffect(() => {
    if (phase !== 'graded') return;
    api<{ state: { currentStreak: number; totalXp: number } }>('/me/gamification', { noRedirect: true })
      .then(setGam)
      .catch(() => {});
    api<{ attempts: AttemptSummary[] }>('/me/attempts', { noRedirect: true })
      .then((a) => setAllAttempts(a.attempts))
      .catch(() => {});
  }, [phase]);

  useEffect(() => {
    let alive = true;
    // The instructions page reads the manifest for its subject summary;
    // same-origin static, one small JSON, fails soft.
    fetchManifest()
      .then((m) => alive && setManifest(m))
      .catch(() => {});
    (async () => {
      try {
        if (!code) throw new Error('No paper code, open it from the dashboard');
        migrateBundleCache(); // heal quota-struck localStorage on entry
        // Composite mock papers never appear in the manifest, the server
        // composes them on demand, so resolve those straight by code.
        // Daily challenges resolve through /daily/{body} first.
        let b: Bundle;
        let meta: ExamMetaLite | null = null;
        let dailyInfo: DailyInfo | null = null;
        if (searchParams.get('daily') === '1') {
          dailyInfo = await api<DailyInfo>('/daily/jamb');
          if (!alive) return;
          if (dailyInfo.code !== code) {
            // A paused seat from earlier today (dashboard resume) must
            // keep ITS paper - borrow the daily head for the title and
            // load the bundle straight by code; any other entry jumps to
            // today's sprint as before.
            const snapNow = loadActiveExam();
            if (searchParams.get('resume') === '1' && snapNow && snapNow.code === code) {
              b = await fetchBundleByCode(code);
              if (b.durationMinutes == null) setUntimed(true);
            } else {
              router.replace(examHref(dailyInfo.code, { daily: '1' }));
              return;
            }
          } else {
            const manifest = await fetchManifest();
            const exam = manifest.exams.find((e) => e.code === code);
            if (exam) {
              meta = exam;
              b = await fetchBundle(exam);
            } else if (isComposedPaperCode(code)) {
              // The founder-rule combination rides a composed paper that
              // never appears in the manifest - compose it on demand.
              b = await fetchBundleByCode(code);
              if (b.durationMinutes == null) setUntimed(true);
            } else {
              throw new Error("Today's challenge pack is missing");
            }
          }
        } else if (isComposedPaperCode(code)) {
          // mock / custom / pick papers compose server-side on demand
          b = await fetchBundleByCode(code);
          if (b.durationMinutes == null) {
            // untimed composed practice: count-up clock
            setUntimed(true);
          }
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
  }, [code, retry]);

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
      // The daily sprint keeps its head: the paused seat reopens under
      // "Daily Quiz", never the composed paper's plumbing label.
      title: daily ? 'Daily Quiz' : bundle?.title ?? attempt.code,
      daily: daily ? true : undefined,
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
    if (bundle && bundle.questions[current]) {
      const qid = bundle.questions[current].id;
      const spent = Date.now() - shownAtRef.current;
      if (spent > 0) {
        questionMsMapRef.current[qid] = (questionMsMapRef.current[qid] || 0) + spent;
      }
    }
    const localAttempt = attempt.attemptId.startsWith('local-');
    // Fire-and-forget telemetry (ROADMAP #6): the server re-computes the
    // same pure signal from the raw latencies and logs the sitting.
    if (!localAttempt) {
      void api('/me/sessions', {
        method: 'POST',
        noRedirect: true, // telemetry must never bounce the paper
        body: {
          attemptId: attempt.attemptId,
          code: attempt.code,
          startedAt: attempt.startedAt,
          durationMs: Math.round(Date.now() - startedAtRef.current - pausedMsRef.current),
          latenciesMs: [...latenciesRef.current],
        },
      }).catch(() => {});
    }
    setPhase('grading');
    if (localAttempt) {
      // On-device sitting: grade in the browser from the merged answers.
      // The paper set is identical to the server's composition (same
      // deterministic walk), so the score matches the hall's arithmetic.
      await new Promise((r) => setTimeout(r, 350)); // let the grading state land
      setResult(gradeLocally(bundle!, answers));
      clearActiveExam();
      setPhase('graded');
      return;
    }
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
        noRedirect: true, // a stale session grades on-device, never bounces
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
      if (err instanceof ApiError && err.code === 'already_submitted') {
        clearActiveExam();
        setError(err instanceof Error ? err.message : 'Submission failed');
        setPhase('error');
        return;
      }
      // Network died between picking and submitting - grade on-device
      // rather than throwing the sitting away. Same paper, same answers.
      if (bundle && bundle.questions.some((q) => q.answer)) {
        setResult(gradeLocally(bundle, answers));
        clearActiveExam();
        setPhase('graded');
        return;
      }
      setError(err instanceof Error ? err.message : 'Submission failed');
      setPhase('error');
    }
  }, [attempt, answers, bundle]);

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
      let res: AttemptResponse;
      try {
        res = await api<AttemptResponse>('/attempts', {
          method: 'POST',
          body: {
            code: bundle.code,
            ...(daily ? { daily: true } : {}),
            ...(wantsAdaptive ? { adaptive: true } : {}),
          },
          // A 401 (signed-out / stale session) must fall through to the
          // on-device attempt below, never hard-bounce the candidate to
          // /login from inside their own paper.
          noRedirect: true,
        });
      } catch (serverErr) {
        // Server unreachable or the student is signed out (GitHub Pages
        // static deploys, API cold starts): practise fully on-device.
        // The paper is identical (composed from the same banks); grading
        // happens in the browser from the merged answers.
        if (daily) throw serverErr; // the daily sprint is server-born
        res = {
          attemptId: `local-${Date.now().toString(36)}`,
          code: bundle.code,
          status: 'local',
          startedAt: new Date().toISOString(),
          durationMinutes: bundle.durationMinutes ?? null,
          questionCount: bundle.questionCount,
          adaptive: false,
          order: null,
        };
      }
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
  // The school app's big clock always carries the hours seat.
  const hhmmss = (s: number) => {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = s % 60;
    return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  };

  /** Records an answer: latency telemetry + fatigue assessment first.
   *  Answers stay editable everywhere - CBT hall or practice, a picked
   *  option can always be swapped for another before Submit. */
  const pick = (questionId: string, letter: string) => {
    if (!answers[questionId] && letter !== '') {
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

  /** Theory questions submit an empty marker pick (the essay text never
   *  leaves the browser); the model answer unlocks in review. */
  const markTheory = (questionId: string) => {
    setAnswers((a) => (a[questionId] ? a : { ...a, [questionId]: '' }));
  };

  /** Question navigation resets the per-question latency clock and records dwell time. */
  const goTo = (i: number) => {
    if (bundle && bundle.questions[current]) {
      const qid = bundle.questions[current].id;
      const spent = Date.now() - shownAtRef.current;
      if (spent > 0) {
        questionMsMapRef.current[qid] = (questionMsMapRef.current[qid] || 0) + spent;
      }
    }
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

  /** The two-step hand-in: every submit route (S key, Enter at the end,
   *  either on-screen Submit button) opens the same confirm dialog -
   *  Y then confirms it. */
  const requestSubmit = () => {
    if (!bundle) return;
    const left = bundle.questionCount - answeredCount;
    setConfirm({
      title: 'Submit paper?',
      body:
        left > 0
          ? `${left} question(s) unanswered, they will be marked wrong.`
          : `All ${bundle.questionCount} answered, ready to hand in.`,
      confirmLabel: 'Submit',
      onConfirm: () => void submit(),
    });
  };

  /* ------------------------------------------------------------ */
  /* Keyboard controls (desktop CBT, like the real JAMB hall):      */
  /*   A-F / 1-6 pick an option · ←/→ move · F flag · Enter next.   */
  /*   S submit · Y confirm submit.                                 */
  /* Suspended while any overlay (navigator, calculator, break,     */
  /* fatigue nudge) is open or while typing in a theory textarea.   */
  /* ------------------------------------------------------------- */
  useEffect(() => {
    if (phase !== 'playing' || !bundle || !question || navOpen || calcOpen || breakLeft > 0 || nudgeVisible) {
      return;
    }
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === 'TEXTAREA' || target.tagName === 'INPUT' || target.isContentEditable)) {
        return;
      }
      const key = e.key;
      // The confirm dialog owns the keys while it is up: Y (or Enter)
      // confirms, Esc backs out, everything else is held so nothing
      // moves behind the dialog.
      if (confirm) {
        e.preventDefault();
        if (key === 'y' || key === 'Y' || key === 'Enter') {
          const action = confirm.onConfirm;
          setConfirm(null);
          action();
        } else if (key === 'Escape') {
          setConfirm(null);
        }
        return;
      }
      if (question.type !== 'theory') {
        // A-F by letter, 1-6 by position
        const upper = key.length === 1 ? key.toUpperCase() : '';
        const byLetter = upper && (question.options ?? {})[upper] !== undefined ? upper : null;
        const digit = /^[1-6]$/.test(key) ? LETTERS[Number(key) - 1] : null;
        const letter = byLetter ?? (digit && (question.options ?? {})[digit] !== undefined ? digit : null);
        if (letter) {
          e.preventDefault();
          pick(question.id, letter);
          return;
        }
      }
      if (key === 'ArrowRight' || key === 'n' || key === 'N' || key === 'PageDown') {
        e.preventDefault();
        if (current < bundle.questionCount - 1) goTo(current + 1);
        return;
      }
      if (key === 'ArrowLeft' || key === 'p' || key === 'P' || key === 'PageUp') {
        e.preventDefault();
        if (current > 0) goTo(current - 1);
        return;
      }
      if (key === 'f' || key === 'F') {
        e.preventDefault();
        setFlags((f) => ({ ...f, [question.id]: !f[question.id] }));
        return;
      }
      if (key === 'g' || key === 'G') {
        e.preventDefault();
        setNavOpen(true);
        return;
      }
      if (key === 'c' || key === 'C') {
        e.preventDefault();
        setCalcOpen(true);
        return;
      }
      if (key === 's' || key === 'S') {
        // S opens the submit hand-in from anywhere in the paper - the
        // on-screen Submit buttons route through the same dialog.
        e.preventDefault();
        requestSubmit();
        return;
      }
      if (key === 'Enter') {
        // Enter advances; at the end of the walk it opens the submit
        // confirm exactly like the on-screen button.
        e.preventDefault();
        const answered = Object.keys(answers).length;
        if (current === bundle.questionCount - 1 || answered === bundle.questionCount) {
          requestSubmit();
        } else if (current < bundle.questionCount - 1) {
          goTo(current + 1);
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase, bundle, question, current, navOpen, calcOpen, breakLeft, nudgeVisible, answers, confirm]);


  /* ------------------------------------------------------------- views */

  // The quiz name - never the subject receipt. The daily sprint answers
  // to "Daily Quiz" (the API now titles it so); everything else keeps
  // its composed label ("Custom Practice", "UTME Mock", …).
  const paperTitle = daily?.title ?? bundle?.title ?? meta?.title ?? 'Practice';

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
        <div className="mt-4 flex items-center gap-4">
          <button
            onClick={() => setRetry((n) => n + 1)}
            className="flex h-11 items-center gap-2 rounded-[10px] bg-primary px-5 text-sm font-semibold text-on-primary transition-transform active:scale-[0.98]"
          >
            <span className="material-symbols-outlined text-[20px]">refresh</span>
            Retry
          </button>
          <button
            onClick={() => router.push('/dashboard')}
            className="text-sm text-primary underline-offset-4 hover:underline"
          >
            ← back to dashboard
          </button>
        </div>
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

    // Summary subjects - the standard UTME mock's canonical split
    // (English first, 40 per elective), the custom papers' even share,
    // sections when the bundle ships them.
    const subjectRows: Array<{ name: string; count: number }> = (() => {
      if (bundle.sections && bundle.sections.length > 1) {
        return bundle.sections.map((sec) => ({ name: subjectName(sec.subject), count: sec.questionIds.length }));
      }
      const spec = parsePaperCode(code);
      if (spec && (spec.family === 'mock' || spec.family === 'custom') && manifest) {
        const dict = new Set<string>();
        for (const e of manifest.exams) {
          const m = e.code.match(/^(jamb|waec|neco)-(.+)-bank$/);
          if (m) dict.add(m[2]);
        }
        const subjects = segmentSubjects(spec.subjects.join('-').split('-'), dict);
        if (subjects.length > 0) {
          if (spec.family === 'mock') {
            const en = spec.enN || 60;
            let at = 0;
            return subjects.map((s, i) => {
              const count = Math.min(at + (i === 0 ? en : 40), bundle.questionCount) - at;
              at += count;
              return { name: subjectName(s), count };
            });
          }
          const each = Math.floor(bundle.questionCount / subjects.length);
          return subjects.map((s, i) => ({
            name: subjectName(s),
            count: i === 0 ? bundle.questionCount - each * (subjects.length - 1) : each,
          }));
        }
      }
      return [{ name: meta?.title ?? bundle.title, count: bundle.questionCount }];
    })();

    // Exam year seat: one distinct year on the paper names it, a spread
    // stays honest as "Mixed years", none at all reads "All years".
    const yearsOnPaper = [...new Set(bundle.questions.map((q) => q.year).filter((y): y is number => !!y))];
    const yearLabel =
      specYearLabel(code) ?? (yearsOnPaper.length === 1 ? String(yearsOnPaper[0]) : yearsOnPaper.length > 1 ? 'Mixed years' : 'All years');

    return (
      <main className="min-h-dvh bg-surface-container-lowest pb-16">
        {/* back bar - every page gets a back button (founder rule) */}
        <div className="mx-auto w-full max-w-2xl px-4 pt-3 sm:px-6">
          <button
            onClick={() =>
              setConfirm({
                title: 'Leave the paper?',
                body: 'Leave now and nothing is submitted, you keep your seat in the paper list.',
                confirmLabel: 'Leave',
                onConfirm: () => router.push('/dashboard'),
              })
            }
            aria-label="Back"
            className="flex h-11 w-11 items-center justify-center rounded-full border border-outline-variant bg-card text-on-surface transition hover:bg-surface-container-low"
          >
            <span className="material-symbols-outlined text-[20px]">arrow_back</span>
          </button>
        </div>

        <div className="renance-rise mx-auto w-full max-w-2xl px-4 pt-2 sm:px-6">
          {/* simulator banner - the school app's banner with the abstract
              corner shapes, Renance's ink ground */}
          <div className="relative overflow-hidden rounded-[14px] bg-accent-ink px-5 py-[22px] text-white">
            <div className="pointer-events-none absolute -right-6 -top-8 h-32 w-32 rounded-full border-[10px] border-white/10" />
            <div className="pointer-events-none absolute -bottom-10 right-16 h-24 w-24 rounded-full border-[8px] border-white/5" />
            <div className="pointer-events-none absolute right-2 bottom-6 h-3 w-16 rotate-12 rounded-full bg-white/10" />
            <p className="relative z-10 text-[19px] font-bold tracking-tight">
              {examMode ? 'JAMB CBT Simulator' : daily ? 'Daily Quiz' : 'Practice Simulator'}
            </p>
          </div>

          <h1 className="mt-6 text-xl font-semibold text-on-surface">{paperTitle}</h1>
          <p className="mt-1.5 text-sm text-on-surface-variant">
            {bundle.questionCount} questions ·{' '}
            {bundle.durationMinutes != null ? `${bundle.durationMinutes} minutes` : 'untimed'} ·{' '}
            {bundle.totalMarks} marks
          </p>

          {/* CBT Exam Instructions ------------------------------- */}
          <div className="mt-6 flex items-center gap-2.5">
            <span className="flex h-[34px] w-[34px] items-center justify-center rounded-[10px] bg-accent-ink text-white">
              <span className="material-symbols-outlined text-[18px]">fact_check</span>
            </span>
            <h2 className="text-[21px] font-bold tracking-tight text-on-surface">CBT Exam Instructions</h2>
          </div>

          {/* Pre-exam instructions, the sheet a candidate reads in the
              hall before the invigilator says "start", the school
              app's seven-line list, Renance's pause semantics. */}
          <ul className="mt-4 space-y-2.5">
            {[
              'Questions will appear one at a time.',
              "You're free to move to any question using the question navigation at the bottom of your exam environment.",
              "After answering a question, click 'Next' to proceed to the next one.",
              "When you finish all the questions, click 'Submit'.",
              'If you wish to exit before completing the test, click "Quit". Your paper pauses and you can resume from the dashboard.',
              'A simple calculator has also been provided at the top of your screen, so feel free to use it as applicable.',
              'Keep an eye on your countdown time. If you run out of time, your answers will be automatically submitted, and your performance summary will be displayed.',
            ].map((line, i) => (
              <li key={i} className="flex items-start gap-2.5 text-[13.5px] leading-relaxed text-on-surface-variant">
                <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-outline" />
                {line}
              </li>
            ))}
          </ul>
          <p className="mt-4 border-t border-outline-variant/50 pt-3 font-mono text-[10px] uppercase tracking-[0.2em] text-on-surface-variant">
            keyboard · desktop
          </p>
          <div className="mt-1.5 flex flex-wrap gap-1.5 text-[11px] text-on-surface-variant">
            <span className="rounded border border-outline-variant bg-card px-1.5 py-0.5 font-mono">A-F</span> pick
            <span className="rounded border border-outline-variant bg-card px-1.5 py-0.5 font-mono">←→</span> move
            <span className="rounded border border-outline-variant bg-card px-1.5 py-0.5 font-mono">F</span> flag
            <span className="rounded border border-outline-variant bg-card px-1.5 py-0.5 font-mono">Enter</span> next / submit
            <span className="rounded border border-outline-variant bg-card px-1.5 py-0.5 font-mono">S</span> submit
            <span className="rounded border border-outline-variant bg-card px-1.5 py-0.5 font-mono">Y</span> confirm submit
          </div>
          {/* Daily: show today's seated score + board link once played */}
          {daily && daily.myResult && (
            <div className="mt-5 flex w-full items-center justify-between rounded-xl bg-accent-emerald/10 px-4 py-3 text-left">
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
            <div className="mt-5 w-full rounded-xl border border-accent-amber/50 bg-accent-amber/10 px-4 py-3 text-left">
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
                    ? 'Time is up, resuming submits the paper for marking'
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

          {/* Summary - Subjects / Test Mode / Exam Year cards ---------- */}
          <h2 className="mt-7 text-[21px] font-bold tracking-tight text-on-surface">Summary</h2>

          <div className="mt-3 rounded-[14px] border border-outline-variant/50 bg-card p-4">
            <div className="flex items-center gap-2.5">
              <span className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full bg-accent-emerald text-white">
                <span className="material-symbols-outlined text-[18px]">menu_book</span>
              </span>
              <div>
                <p className="text-[15px] font-bold text-on-surface">Subjects</p>
                <p className="text-[12px] text-on-surface-variant">
                  You have selected, and will be examined on the following subjects.
                </p>
              </div>
            </div>
            <div className="mt-3 border-t border-outline-variant/40 pt-2.5">
              {subjectRows.map((row) => (
                <div key={row.name} className="flex items-center justify-between py-1.5">
                  <span className="text-[14.5px] text-on-surface">{row.name}</span>
                  <span className="text-[13.5px] text-on-surface-variant">{row.count} Questions</span>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-3 rounded-[14px] border border-outline-variant/50 bg-card p-4">
            <div className="flex items-center gap-2.5">
              <span className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full bg-accent-ink text-white">
                <span className="material-symbols-outlined text-[18px]">timer</span>
              </span>
              <div>
                <p className="text-[15px] font-bold text-on-surface">Test Mode</p>
                <p className="text-[12px] text-on-surface-variant">
                  {examMode
                    ? 'Full test mode: the clock auto-submits at zero, answers stay editable.'
                    : timerOverride != null
                      ? `Practice mode: ${timerOverride} minutes on the clock, answers stay editable.`
                      : bundle.durationMinutes != null
                        ? `Practice mode: ${bundle.durationMinutes} minutes, answers stay editable.`
                        : 'Practice mode: untimed, answers stay editable.'}
                </p>
              </div>
            </div>
          </div>

          <div className="mt-3 rounded-[14px] border border-outline-variant/50 bg-card p-4">
            <div className="flex items-center gap-2.5">
              <span className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full bg-accent-amber text-white">
                <span className="material-symbols-outlined text-[18px]">event</span>
              </span>
              <div>
                <p className="text-[15px] font-bold text-on-surface">Exam Year</p>
                <p className="text-[12px] text-on-surface-variant">
                  {yearLabel === 'All years'
                    ? 'Questions drawn from every year on the shelf.'
                    : yearLabel === 'Mixed years'
                      ? 'A spread of past years, the way the hall mixes papers.'
                      : `Pinned to the ${yearLabel} paper.`}
                </p>
              </div>
            </div>
          </div>

          {/* Smart order (ROADMAP #5), practice packs only */}
          {!examMode && !daily && (
            <div className="mt-5 flex w-full items-center justify-between rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5">
              <div className="flex items-center gap-2 text-left">
                <span
                  className={`material-symbols-outlined text-[18px] ${adaptive ? 'text-accent-ink' : 'text-outline'}`}
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

          {/* Proceed to Test ----------------------------------------- */}
          <button
            onClick={startAttempt}
            className="mt-7 flex h-[54px] w-full items-center justify-center gap-2 rounded-[12px] bg-accent-ink text-[15px] font-bold text-white shadow-md transition hover:opacity-90 active:scale-[0.99]"
          >
            <span className="material-symbols-outlined text-[20px]">play_arrow</span>
            {paused ? 'Start a fresh paper instead' : daily ? 'Start the challenge' : 'Proceed to Test'}
          </button>
          <button
            onClick={() =>
              setConfirm({
                title: 'Leave the paper?',
                body: 'Leave now and nothing is submitted, you keep your seat in the paper list.',
                confirmLabel: 'Leave',
                onConfirm: () => router.push('/dashboard'),
              })
            }
            className="mt-3 w-full text-[13px] font-medium text-on-surface-variant underline-offset-4 hover:underline"
          >
            Edit Selections
          </button>
        </div>
      </main>
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

    const timeRecords: QuestionTimeRecord[] = (bundle?.questions ?? []).map((q, idx) => ({
      questionId: q.id,
      index: idx,
      stem: q.stem,
      topic: q.topic,
      durationMs: questionMsMapRef.current[q.id] || 0,
      selected: answers[q.id],
      correct: q.answer ? answers[q.id] === q.answer : false,
    }));
    const pacingReport = computePacingForensics(
      timeRecords,
      timerOverride != null ? timerOverride : bundle?.durationMinutes ?? 30,
      bundle?.questionCount ?? 40,
    );

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

          {/* Pacing & Panic Forensics Card */}
          <PacingForensicsCard report={pacingReport} attemptId={attempt?.attemptId} />

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

        {/* Pacing & Panic Forensics Card */}
        <PacingForensicsCard report={pacingReport} attemptId={attempt?.attemptId} />

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
      {/* CBT command bar - ONE row on every screen, spanning the deck:
          the quiz name pinned to the LHS edge, the clock with Quit /
          Submit pinned to the RHS edge. Nothing floats mid-bar - the
          subject being attempted lives in the slim strip UNDER this bar
          (full papers only), never in the bar itself. Copy + calculator
          live in the question card, next to the question they act on. */}
      <header className="sticky top-0 z-40 border-b border-outline-variant/45 bg-surface-container-lowest/95 backdrop-blur-xl">
        <div className="mx-auto w-full max-w-2xl px-4 sm:px-6 md:max-w-none md:px-8">
          <div className="flex items-center gap-2.5 py-2.5">
            {/* LHS - the quiz name, pinned to the screen's left edge */}
            <h1 className="min-w-0 flex-1 truncate text-[14.5px] font-semibold text-on-surface">
              {paperTitle}
            </h1>
            {/* RHS - clock first, Quit + Submit right behind it, pinned
                to the screen's right edge */}
            <div className="ml-auto flex shrink-0 items-center gap-2 md:gap-2.5">
              {(() => {
                const breaking = breakLeft > 0;
                const clock = breaking
                  ? `BREAK ${mmss(breakLeft)}`
                  : untimed || remaining === null
                    ? mmss(remaining ?? 0)
                    : hhmmss(remaining);
                const clockTone = breaking
                  ? 'text-on-surface'
                  : remaining !== null && remaining < 60
                    ? 'text-error'
                    : remaining !== null && remaining < 300
                      ? 'text-accent-amber'
                      : 'text-[#0E9F6E]';
                return (
                  <p
                    className={`shrink-0 text-[16.5px] font-extrabold leading-none tracking-[0.04em] tabular-nums md:text-[19px] ${clockTone}`}
                  >
                    {clock}
                  </p>
                );
              })()}
              <button
                onClick={() =>
                  setConfirm({
                    title: 'Quit the paper?',
                    body: 'Quitting leaves the test environment. Your paper pauses, resume it from the dashboard, the clock keeps its honest count.',
                    confirmLabel: 'Quit',
                    danger: true,
                    onConfirm: () => router.push('/dashboard'),
                  })
                }
                aria-label="Quit the paper"
                title="Quit the paper"
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-error text-error transition hover:bg-error-container/40 active:scale-[0.97] md:h-auto md:w-auto md:px-[16px] md:py-2"
              >
                <span className="material-symbols-outlined text-[18px] md:hidden">logout</span>
                <span className="hidden text-[13.5px] font-bold md:inline">Quit</span>
              </button>
              <button
                onClick={requestSubmit}
                className="shrink-0 rounded-full bg-accent-ink px-3.5 py-[7px] text-[13px] font-bold text-white transition hover:opacity-90 active:scale-[0.97] md:px-[16px] md:py-2 md:text-[14px]"
              >
                Submit
              </button>
            </div>
          </div>
          {/* The subject being attempted - one slim strip UNDER the
              command bar, full papers only (JAMB mock + composed combos).
              It carries the current subject's name, its answered count
              and a hairline progress bar. < > sit at the strip's two
              ends and jump straight to the previous / next subject, so
              a student can start the paper with any subject they like.
              The command bar itself stays short. Single-subject quizzes
              keep no strip at all. */}
          {bundle.sections && bundle.sections.length > 1 && (() => {
            const sections = bundle.sections;
            const starts: number[] = [];
            let walk = 0;
            let secIdx = 0;
            sections.forEach((sec, i) => {
              starts.push(walk);
              if (current >= walk) secIdx = i;
              walk += sec.questionIds.length;
            });
            const sec = sections[secIdx];
            const start = starts[secIdx];
            const answered = sec.questionIds.filter((id) => answers[id]).length;
            const total = sec.questionIds.length;
            const pct = total ? Math.round((answered / total) * 100) : 0;
            const chev =
              'flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-outline-variant bg-card text-on-surface transition hover:bg-surface-container-low disabled:opacity-35 active:scale-[0.95]';
            return (
              <div className="border-t border-outline-variant/25 bg-surface-container-lowest/60">
                <div className="mx-auto w-full px-4 sm:px-6 md:px-8">
                  <div className="flex items-center gap-2 py-1.5">
                    <button
                      onClick={() => goTo(starts[secIdx - 1])}
                      disabled={secIdx === 0}
                      aria-label="Previous subject"
                      title="Previous subject"
                      className={chev}
                    >
                      <span className="material-symbols-outlined text-[16px]">chevron_left</span>
                    </button>
                    <span className="material-symbols-outlined shrink-0 text-[15px] text-primary">subject</span>
                    <span className="shrink-0 text-[12.5px] font-semibold text-on-surface">
                      {subjectName(sec.subject)}
                    </span>
                    <span className="shrink-0 font-mono text-[10.5px] text-outline">
                      {answered}/{total}
                    </span>
                    <span className="h-[3px] min-w-8 flex-1 overflow-hidden rounded-full bg-surface-container-high">
                      <span
                        className="block h-full rounded-full bg-primary transition-[width] duration-300"
                        style={{ width: `${pct}%` }}
                      />
                    </span>
                    <span className="shrink-0 font-mono text-[10.5px] text-outline">
                      Q{current - start + 1}/{total}
                    </span>
                    <button
                      onClick={() => goTo(starts[secIdx + 1])}
                      disabled={secIdx === sections.length - 1}
                      aria-label="Next subject"
                      title="Next subject"
                      className={chev}
                    >
                      <span className="material-symbols-outlined text-[16px]">chevron_right</span>
                    </button>
                  </div>
                </div>
              </div>
            );
          })()}
        </div>
      </header>

      {/* The school app's single-column CBT body: question card up
          top, radio-circle options, the persistent bottom navigator. */}
      <div className="mx-auto w-full max-w-2xl px-4 pb-44 pt-4 sm:px-6">
        {/* question card */}
        <div className="renance-rise rounded-[14px] border border-outline-variant/50 bg-card p-[18px] shadow-[0_2px_12px_0_rgba(20,28,45,0.10)] sm:p-6">
          <div className="flex items-center justify-between gap-3">
            {/* "Question N" pill + Live Pacing Gauge */}
            <div className="flex flex-wrap items-center gap-2">
              <span className="shrink-0 rounded-full border border-outline-variant bg-card px-3.5 py-[7px] text-[14.5px] font-medium text-on-surface shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                Question {current + 1}
                <span className="ml-1.5 font-mono text-[11px] text-outline">/ {bundle.questionCount}</span>
              </span>
              {!untimed && (
                <PacingGauge
                  pacing={assessLivePacing(
                    (questionMsMapRef.current[question.id] || 0) + (Date.now() - shownAtRef.current),
                    timerOverride != null ? timerOverride : bundle.durationMinutes ?? 30,
                    bundle.questionCount,
                  )}
                />
              )}
            </div>
            <div className="flex min-w-0 items-center gap-2">
            {question.topic && (
              <span className="hidden min-w-0 truncate rounded-full bg-surface-container-low px-2.5 py-1 text-[11px] text-on-surface-variant sm:block">
                {question.topic}
                {question.year ? (
                  <span className="ml-1.5 font-mono text-[10px] text-outline">{question.year}</span>
                ) : null}
              </span>
            )}
            {/* copy + calculator: they act on THIS question, so they live
                on the card - keeps the command bar to clock + Quit/Submit */}
            <button
              onClick={() => {
                const buf = [question.stem ?? ''];
                for (const [k, v] of Object.entries(question.options ?? {})) buf.push(`${k}) ${v}`);
                void navigator.clipboard?.writeText(buf.join('\n'));
              }}
              aria-label="Copy question"
              title="Copy question"
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-outline-variant bg-card text-on-surface-variant transition hover:bg-surface-container-low hover:text-on-surface"
            >
              <span className="material-symbols-outlined text-[16px]">content_copy</span>
            </button>
            <button
              onClick={() => setCalcOpen(true)}
              aria-label="Open calculator"
              title="Calculator"
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-outline-variant bg-card text-on-surface-variant transition hover:bg-surface-container-low hover:text-on-surface"
            >
              <span className="material-symbols-outlined text-[16px]">calculate</span>
            </button>
            <button
              onClick={() => setFlags((f) => ({ ...f, [question.id]: !f[question.id] }))}
              aria-label={flags[question.id] ? 'Unflag question' : 'Flag question'}
              title="Flag for review"
              className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full border transition md:h-auto md:w-auto md:gap-1 md:px-2.5 md:py-1 md:text-[11px] ${
                flags[question.id]
                  ? 'border-accent-amber bg-accent-amber/15 text-accent-ink'
                  : 'border-outline-variant bg-card text-on-surface-variant hover:border-outline'
              }`}
            >
              <span className={`material-symbols-outlined text-[15px] md:text-[14px] ${flags[question.id] ? 'fill-current text-accent-amber' : ''}`}>
                flag
              </span>
              <span className="hidden md:inline">{flags[question.id] ? 'flagged' : 'flag'}</span>
            </button>
            </div>
          </div>
          {/* Comprehension passage: every group question carries the
              shared text, collapsible so it never eats the screen. */}
          {question.passage && (
            <details open className="mt-4 rounded-xl border border-outline-variant/50 bg-surface-container-lowest/60">
              <summary className="cursor-pointer select-none px-4 py-2.5 font-mono text-[10px] uppercase tracking-wider text-outline">
                comprehension passage
              </summary>
              <div className="max-h-64 overflow-y-auto px-4 pb-3 text-[15px] leading-relaxed text-on-surface">
                <QText html={question.passage} />
              </div>
            </details>
          )}
          <QText className="mt-4 text-[16px] leading-relaxed text-on-surface" html={question.stem} />
          {question.image && (
            <div className="mt-3 flex justify-center">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={apiImg(question.image)}
                alt="question diagram"
                loading="lazy"
                className="max-h-72 max-w-full rounded-lg border border-outline-variant/40 bg-card object-contain"
              />
            </div>
          )}
          {question.type === 'theory' ? (
            <div className="mt-6 flex flex-col gap-3">
              <div className="flex items-center gap-2 rounded-lg bg-accent-amber/10 px-3 py-2">
                <span className="material-symbols-outlined text-[18px] text-accent-ink">edit_note</span>
                <p className="text-[12px] leading-4 text-on-surface-variant">
                  Theory question, write your answer below, then tick it when done.
                  The model answer unlocks in the review after submission.
                </p>
              </div>
              <textarea
                value={theoryDrafts[question.id] ?? ''}
                onChange={(e) =>
                  setTheoryDrafts((d) => ({ ...d, [question.id]: e.target.value }))
                }
                rows={6}
                placeholder="Write your answer here (kept on this device)…"
                className="w-full rounded-xl border border-outline-variant bg-surface-container-lowest/60 px-4 py-3 text-sm leading-relaxed text-on-surface outline-none transition focus:border-primary"
              />
              <button
                type="button"
                onClick={() => markTheory(question.id)}
                className={`flex w-fit items-center gap-2 rounded-full px-4 py-2 text-[13px] font-semibold transition ${
                  answers[question.id] !== undefined
                    ? 'bg-accent-emerald/15 text-on-surface'
                    : 'bg-primary text-on-primary shadow-sm'
                }`}
              >
                <span className="material-symbols-outlined text-[16px]">
                  {answers[question.id] !== undefined ? 'check_circle' : 'task_alt'}
                </span>
                {answers[question.id] !== undefined ? 'Answered, submitted with the paper' : 'Mark as answered'}
              </button>
            </div>
          ) : (
          <div className="mt-6 space-y-2.5">
            {Object.entries(question.options ?? {}).map(([letter, text]) => {
              const selected = answers[question.id] === letter;
              return (
                <button
                  key={letter}
                  onClick={() => pick(question.id, letter)}
                  className={`flex w-full items-start gap-3.5 rounded-[12px] border px-4 py-3.5 text-left text-sm transition ${
                    selected
                      ? 'border-primary border-[1.6px] bg-selection-blue/45'
                      : 'border-outline-variant bg-card hover:border-outline hover:shadow-sm active:scale-[0.995]'
                  }`}
                >
                  {/* the radio circle - hollow, ink-filled when picked */}
                  <span
                    className={`mt-0.5 h-6 w-6 shrink-0 rounded-full border transition ${
                      selected ? 'border-primary bg-primary' : 'border-outline bg-card'
                    } ${selected ? '' : 'border-[1.6px]'}`}
                  />
                  <span className="w-4 shrink-0 pt-[1px] text-[15.5px] font-extrabold text-error/90">
                    {letter}
                  </span>
                  <span className="flex-1 min-w-0 pt-[1px] text-[15px] leading-snug text-on-surface">
                    <QText html={text} />
                  </span>
                </button>
              );
            })}
          </div>
          )}
        </div>
      </div>

      {/* The persistent bottom navigator - the school app's bar:
          ← Previous | the "N Questions" pill + the jump strip | Next →. */}
      <div className="fixed inset-x-0 bottom-0 z-40 border-t border-outline-variant/40 bg-surface-container-lowest/95 pb-[max(env(safe-area-inset-bottom),6px)] backdrop-blur-xl">
        <div className="mx-auto w-full max-w-2xl px-4 pt-2.5 sm:px-6">
          <div className="flex items-center justify-between gap-2 md:gap-2.5">
            <button
              onClick={() => goTo(Math.max(0, current - 1))}
              disabled={current === 0}
              className="flex h-11 shrink-0 items-center gap-0.5 rounded-full border border-outline-variant bg-card px-3 text-[14px] font-semibold text-on-surface transition hover:bg-surface-container-low disabled:opacity-40 md:h-[46px] md:px-4 md:text-[14.5px]"
            >
              <span className="material-symbols-outlined text-[18px]">chevron_left</span>
              Previous
            </button>
            <button
              onClick={() => setNavOpen(true)}
              className="flex h-9 min-w-0 shrink items-center justify-center gap-1.5 rounded-full bg-primary px-3 text-[12.5px] font-bold leading-none text-on-primary shadow-sm transition active:scale-[0.97] md:min-w-[92px] md:shrink-0 md:px-3.5"
              aria-label="Open the question navigator"
            >
              {answeredCount}/{bundle.questionCount}
              <span className="hidden md:inline">&nbsp;· Questions</span>
              <span className="material-symbols-outlined text-[15px]">expand_less</span>
            </button>
            {current === bundle.questionCount - 1 || answeredCount === bundle.questionCount ? (
              <button
                onClick={requestSubmit}
                className="flex h-11 shrink-0 items-center gap-0.5 rounded-full border border-outline-variant bg-card px-3 text-[14px] font-bold text-error transition hover:bg-error-container/30 md:h-[46px] md:px-4 md:text-[14.5px]"
              >
                Submit
                <span className="material-symbols-outlined text-[18px]">chevron_right</span>
              </button>
            ) : (
              <button
                onClick={() => goTo(Math.min(bundle.questionCount - 1, current + 1))}
                className="flex h-11 shrink-0 items-center gap-0.5 rounded-full border border-outline-variant bg-card px-3 text-[14px] font-bold text-error transition hover:bg-error-container/20 md:h-[46px] md:px-4 md:text-[14.5px]"
              >
                Next
                <span className="material-symbols-outlined text-[18px]">chevron_right</span>
              </button>
            )}
          </div>
          {/* the jump strip: mini number circles, answered = ink fill,
              current = ring - a PHONE affordance (the finger-tap map);
              the PC keeps the deck clean and uses the Questions sheet */}
          <div className="no-scrollbar mt-1.5 flex items-center gap-1.5 overflow-x-auto pb-1.5 md:hidden">
            {navIndices.slice(0, 150).map(({ q, i }) => {
              const answered = navIsAnswered(q.id);
              const flagged = navIsFlagged(q.id);
              return (
                <button
                  key={q.id}
                  onClick={() => goTo(i)}
                  aria-label={`Go to question ${i + 1}`}
                  className={`relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-[12.5px] font-semibold transition ${
                    answered
                      ? 'border-accent-ink bg-accent-ink text-white'
                      : 'border-outline-variant/70 bg-card text-on-surface-variant'
                  } ${i === current ? 'ring-2 ring-accent-ink ring-offset-1 ring-offset-surface-container-lowest' : ''}`}
                >
                  {i + 1}
                  {flagged && <span className="absolute right-0.5 top-0.5 h-1.5 w-1.5 rounded-full bg-accent-amber" />}
                </button>
              );
            })}
            {bundle.questionCount > 150 && (
              <button
                onClick={() => setNavOpen(true)}
                className="shrink-0 px-1 font-mono text-[11px] text-outline"
              >
                +{bundle.questionCount - 150} more
              </button>
            )}
          </div>
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
                          <p className="col-span-5 py-3 text-center text-[12px] text-outline">-</p>
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

      {/* The school app's confirm dialog (Quit / Submit / Leave). */}
      {confirm && (
        <div className="fixed inset-0 z-[75] flex items-center justify-center px-5">
          <button aria-label="Dismiss" onClick={() => setConfirm(null)} className="absolute inset-0 bg-accent-ink/45" />
          <div className="relative w-full max-w-sm rounded-[18px] bg-surface-container-lowest p-6 shadow-2xl">
            <h3 className="text-[18px] font-bold tracking-tight text-on-surface">{confirm.title}</h3>
            <p className="mt-2 text-[14px] leading-relaxed text-on-surface-variant">{confirm.body}</p>
            <div className="mt-5 flex justify-end gap-2">
              <button
                onClick={() => setConfirm(null)}
                className="rounded-full px-4 py-2.5 text-[14px] font-semibold text-on-surface-variant transition hover:bg-surface-container-low"
              >
                Keep working
              </button>
              <button
                onClick={() => {
                  const action = confirm.onConfirm;
                  setConfirm(null);
                  action();
                }}
                className={`rounded-full px-5 py-2.5 text-[14px] font-bold transition active:scale-[0.97] ${
                  confirm.danger ? 'bg-error text-white' : 'bg-primary text-on-primary'
                }`}
              >
                {confirm.confirmLabel}
              </button>
            </div>
            <p className="mt-4 text-center font-mono text-[10px] uppercase tracking-[0.2em] text-outline">
              Y confirm · Esc dismiss
            </p>
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
