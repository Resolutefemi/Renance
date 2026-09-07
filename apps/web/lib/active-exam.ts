'use client';

/**
 * Active (paused) exam snapshot — the client half of pause & resume.
 *
 * Answers only leave the browser at submit time, so an exam the student
 * walked away from is fully reconstructable from this localStorage
 * snapshot: picks, flags, visited set, cursor, question order and the
 * honest clock (startedAt + pausedMs). One paper at a time, JAMB style.
 */

export interface ActiveExam {
  attemptId: string;
  code: string;
  title: string;
  questionCount: number;
  /** epoch ms — the exam clock start; time keeps running while away */
  startedAt: number;
  /** accumulated non-play ms (fatigue breaks), excluded from the clock */
  pausedMs: number;
  answers: Record<string, string>;
  flags: Record<string, boolean>;
  visited: Record<string, boolean>;
  current: number;
  /** question walk persisted on the attempt (adaptive / daily), if any */
  order: string[] | null;
  adaptive: boolean;
  untimed: boolean;
  /** Practice Settings timer override in minutes (?timer=15|30|60) */
  timerMinutes: number | null;
  savedAt: number;
}

const KEY = 'renance.activeExam.v1';

/** A paused paper older than this is dead weight, not a resume. */
const MAX_AGE_MS = 7 * 86_400_000;

export function loadActiveExam(): ActiveExam | null {
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return null;
    const snap = JSON.parse(raw) as ActiveExam;
    if (!snap?.attemptId || !snap?.code || !snap?.startedAt) return null;
    if (Date.now() - snap.savedAt > MAX_AGE_MS) {
      window.localStorage.removeItem(KEY);
      return null;
    }
    return snap;
  } catch {
    return null;
  }
}

export function saveActiveExam(snap: ActiveExam): void {
  try {
    window.localStorage.setItem(KEY, JSON.stringify({ ...snap, savedAt: Date.now() }));
  } catch {
    /* storage full / private mode: resume is best-effort */
  }
}

export function clearActiveExam(): void {
  try {
    window.localStorage.removeItem(KEY);
  } catch {
    /* ignore */
  }
}

/** Seconds left on an untimed? null : possibly-already-expired clock. */
export function activeExamSecondsLeft(snap: ActiveExam): number | null {
  if (snap.untimed) return null;
  const total = snap.timerMinutes != null ? snap.timerMinutes * 60 : null;
  if (total == null) return total; // caller falls back to the pack duration
  const elapsed = Math.floor((Date.now() - snap.startedAt - snap.pausedMs) / 1000);
  return Math.max(total - elapsed, 0);
}

/** True when the paper is for the same pack (used to key the resume UI). */
export function isActiveExamFor(snap: ActiveExam | null, code: string): boolean {
  return Boolean(snap && snap.code === code);
}
