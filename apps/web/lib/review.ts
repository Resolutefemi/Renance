/**
 * Spaced repetition (ROADMAP #3): types + fetchers for GET /me/review.
 * Mirrors the Go payload in apps/study-api/internal/store/review.go.
 */

export interface ReviewItem {
  topic: string;
  ease: number;
  intervalDays: number;
  repetitions: number;
  lapses: number;
  dueOn: string; // YYYY-MM-DD (UTC)
  lastCorrect: number;
  lastTotal: number;
}

export interface ReviewStats {
  tracked: number;
  due: number;
  mature: number;
  learning: number;
}

export interface ReviewSummary {
  due: ReviewItem[];
  upcoming: ReviewItem[];
  stats: ReviewStats;
}

/** Overdue / due / later, the preview status the design renders. */
export function reviewStatus(item: ReviewItem, now = new Date()): 'overdue' | 'due' | 'later' {
  const due = new Date(`${item.dueOn}T00:00:00Z`);
  if (Number.isNaN(due.getTime())) return 'due';
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const days = Math.round((today - due.getTime()) / 86_400_000);
  if (days > 0) return 'overdue';
  if (days === 0) return 'due';
  return 'later';
}

/** "in 3d" / "in 2w" for upcoming rows. */
export function laterLabel(item: ReviewItem): string {
  return item.intervalDays >= 14
    ? `in ${Math.floor(item.intervalDays / 7)}w`
    : `in ${item.intervalDays}d`;
}

/** Due then upcoming, in server order (oldest due first). */
export function queuePreview(sum: ReviewSummary): ReviewItem[] {
  return [...sum.due, ...sum.upcoming];
}
