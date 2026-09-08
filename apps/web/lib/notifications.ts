'use client';

/**
 * Renance notifications — a local, honest notification center.
 *
 * Every item is derived from REAL student state (review queue, streak,
 * paused papers, graded attempts, the daily challenge) on the devices
 * that already hold that state — no push server, no fake marketing
 * rows. Items persist in localStorage, dedupe by key per day, cap at
 * 60, and expose a tiny subscription so the sidebar bell, the header
 * chip and the /notifications page all render the same unread count.
 */

export type NotificationTone = 'error' | 'emerald' | 'blue' | 'violet' | 'amber' | 'neutral';

export interface RenanceNotification {
  /** stable identity — dedupe key (usually `<kind>-<yyyy-mm-dd>` or attempt id) */
  id: string;
  title: string;
  body: string;
  /** material symbol name */
  icon: string;
  tone: NotificationTone;
  /** in-app deep link the row walks to when tapped */
  href?: string;
  /** epoch ms */
  at: number;
  read: boolean;
}

export interface NotificationInput {
  /** current daily streak (0 when the student has none) */
  streak: number;
  /** spaced-review items currently due */
  reviewDue: number;
  /** a paper was paused and left */
  activeExamCode?: string | null;
  activeExamAnswers?: number;
  /** most recent graded attempt today, if any */
  lastGrade?: { attemptId: string; pct: number; at: number } | null;
  /** today's daily challenge code, when the API has one and it is unplayed */
  dailyCode?: string | null;
}

const KEY = 'renance.notifications.v1';
const EVENT = 'renance.notifications';
const CAP = 60;

const dayKey = (ts = Date.now()) => {
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const startOfDay = (ts: number) => {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
};

function load(): RenanceNotification[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed?.items) ? (parsed.items as RenanceNotification[]) : [];
  } catch {
    return [];
  }
}

function save(items: RenanceNotification[]) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify({ items: items.slice(0, CAP) }));
  } catch {
    /* private mode / quota — notifications are best-effort */
  }
  window.dispatchEvent(new Event(EVENT));
}

function emit() {
  if (typeof window !== 'undefined') window.dispatchEvent(new Event(EVENT));
}

/** All notifications, newest first. */
export function getNotifications(): RenanceNotification[] {
  return load().sort((a, b) => b.at - a.at);
}

export function unreadCount(): number {
  return load().filter((n) => !n.read).length;
}

export function markAllRead() {
  save(load().map((n) => (n.read ? n : { ...n, read: true })));
}

export function markRead(id: string) {
  save(load().map((n) => (n.id === id ? { ...n, read: true } : n)));
}

export function clearNotifications() {
  save([]);
}

/**
 * Re-derive today's notifications from live student state and merge them
 * into the store. Existing rows keep their read state; re-firing the
 * same key on the same day never duplicates or unread-marks a row the
 * student already dismissed.
 */
export function refreshNotifications(input: NotificationInput) {
  const now = Date.now();
  const today = dayKey(now);
  const items = load();
  const byId = new Map(items.map((n) => [n.id, n]));
  const candidates: RenanceNotification[] = [];

  const push = (
    id: string,
    title: string,
    body: string,
    icon: string,
    tone: NotificationTone,
    href?: string,
    at = now,
  ) => {
    candidates.push({ id, title, body, icon, tone, href, at, read: false });
  };

  if (input.lastGrade && dayKey(input.lastGrade.at) === today) {
    const pct = input.lastGrade.pct;
    push(
      `grade-${input.lastGrade.attemptId}`,
      pct >= 50 ? 'Score recorded' : 'Paper graded',
      `You scored ${pct}% on your last paper. ${pct >= 75 ? 'Strong work — keep the streak honest.' : pct >= 50 ? 'Review the misses to push past 75%.' : 'Your review queue now carries the weak items.'}`,
      'fact_check',
      'violet',
      '/progress',
      input.lastGrade.at,
    );
  }

  if (input.reviewDue >= 5) {
    push(
      `review-${today}`,
      'Daily review ready',
      `${input.reviewDue} items are due for spaced repetition. A short review today keeps them from piling up.`,
      'history_edu',
      'emerald',
      '/review',
    );
  }

  if (input.streak >= 2) {
    push(
      `streak-risk-${today}`,
      'Streak at risk!',
      `You have a ${input.streak}-day streak going. Complete any practice or review today to keep it alive.`,
      'local_fire_department',
      'error',
      '/exams/setup',
    );
  }

  if (input.dailyCode) {
    push(
      `daily-${today}`,
      'Daily Challenge is live',
      "Today's 10-question sprint is on the desk. It takes two minutes — and it counts toward the streak.",
      'event_repeat',
      'amber',
      '/dashboard',
    );
  }

  if (input.activeExamCode) {
    push(
      `paused-${input.activeExamCode}`,
      'Paused paper waiting',
      `Your seat in ${input.activeExamCode} is saved — the clock has not stopped. Continue anytime.`,
      'pause_circle',
      'blue',
      '/dashboard',
      // keep at day-granularity so it doesn't re-sort every refresh
      startOfDay(now) + 1,
    );
  }

  // Merge: new candidates win only if the id is unseen; seen rows keep
  // their original timestamp + read state (a dismissed row never nags).
  for (const c of candidates) {
    const existing = byId.get(c.id);
    if (!existing) {
      byId.set(c.id, c);
    } else {
      existing.at = existing.at; // touch nothing — no unread re-fire
    }
  }

  const merged = [...byId.values()].sort((a, b) => b.at - a.at).slice(0, CAP);
  if (merged.length !== items.length || merged.some((m, i) => m !== items.slice().sort((a, b) => b.at - a.at)[i])) {
    save(merged);
  } else {
    emit();
  }
}

/** Subscribe to store changes (same tab + cross-tab). */
export function subscribeNotifications(cb: () => void): () => void {
  window.addEventListener(EVENT, cb);
  window.addEventListener('storage', cb);
  return () => {
    window.removeEventListener(EVENT, cb);
    window.removeEventListener('storage', cb);
  };
}

/** Group label for a row's timestamp — the Stitch Today/Yesterday/Older bands. */
export function dayGroup(at: number): 'Today' | 'Yesterday' | 'Older' {
  const now = startOfDay(Date.now());
  const day = startOfDay(at);
  if (day === now) return 'Today';
  if (day === now - 86_400_000) return 'Yesterday';
  return 'Older';
}

/** Compact relative time for a row ("10m ago", "2h ago", "Oct 12"). */
export function relativeTime(at: number): string {
  const diff = Date.now() - at;
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  if (diff < 7 * 86_400_000) return `${Math.floor(diff / 86_400_000)}d ago`;
  return new Date(at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}
