/**
 * Study plan values (Stitch study_plan_light), the pure derivation
 * mirrored from the app's lib/ui/study_plan_screen.dart so both platforms
 * agree on the numbers. Unknown inputs collapse to the Stitch defaults so
 * the design never shows a hole.
 */

import type { CardProgress } from '@/lib/flashcards';

/** GET /me/fatigue, the advisory the home banner and this screen read. */
export interface FatigueState {
  level: 'none' | 'mild' | 'high';
  suggestBreak: boolean;
  reason?: string;
  minutesToday: number;
  minutesLast3h: number;
  sessionsToday: number;
}

/** Leitner rows due today (or overdue), the voice block's input. */
export function cardsDueToday(progress: CardProgress[] | null): number | null {
  if (progress == null) return null;
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
  // An empty dueOn counts as due, matching the app's CardProgress.isDue.
  return progress.filter((p) => p.dueOn === '' || p.dueOn <= today).length;
}

export interface StudyPlanValues {
  practiceTitle: string;
  practiceMinutes: number; // a focused practice block, 15 min
  reviewMinutes: number;
  cardsMinutes: number;
  totalMinutes: number;
  insight: string;
}

/** Stitch fallbacks, the numbers the design mock carries. */
export const PLAN_PRACTICE_MINUTES = 15;
export const PLAN_REVIEW_MINUTES = 12;
export const PLAN_CARDS_MINUTES = 15;

export function deriveStudyPlanValues(opts: {
  signedIn: boolean;
  dueTopics?: number | null;
  cardsDue?: number | null;
  weakestSubject?: string | null;
  fatigue?: FatigueState | null;
}): StudyPlanValues {
  const { signedIn, dueTopics, cardsDue, weakestSubject, fatigue } = opts;

  // Review block: the review tab estimates 2 min per due topic; a clean
  // queue still gets a 5 min warm-up block, an unknown queue the mock 12.
  let reviewMinutes = PLAN_REVIEW_MINUTES;
  if (dueTopics != null) {
    if (dueTopics <= 0) reviewMinutes = 5;
    else reviewMinutes = Math.min(40, Math.max(6, dueTopics * 2));
  }

  // Voice block: about 45 seconds per due card, 5 to 20 min window.
  let cardsMinutes = PLAN_CARDS_MINUTES;
  if (cardsDue != null) {
    if (cardsDue <= 0) cardsMinutes = 5;
    else cardsMinutes = Math.min(20, Math.max(5, Math.round(cardsDue * 0.75)));
  }

  const practiceTitle = weakestSubject
    ? `${weakestSubject} Practice`
    : 'Biology Practice';

  return {
    practiceTitle,
    practiceMinutes: PLAN_PRACTICE_MINUTES,
    reviewMinutes,
    cardsMinutes,
    totalMinutes: PLAN_PRACTICE_MINUTES + reviewMinutes + cardsMinutes,
    insight: insight(signedIn, fatigue ?? null, weakestSubject ?? null),
  };
}

function insight(
  signedIn: boolean,
  fatigue: FatigueState | null,
  weakestSubject: string | null,
): string {
  const topicsPart = weakestSubject
    ? `your heaviest topics (${weakestSubject})`
    : 'your heaviest topics';

  // Signed out: the design mock copy, exactly as Stitch wrote it.
  if (!signedIn) {
    return "You usually fade after ~25 min in the evening. We've placed "
      + 'your heaviest topics (Biology) first to maximize retention.';
  }
  // Signed in, no sittings yet: the honest zero state.
  if (fatigue == null || fatigue.sessionsToday === 0) {
    return `No sittings logged today yet. We've placed ${topicsPart} first `
      + 'to maximize retention.';
  }

  const mins = Math.round(fatigue.minutesToday);
  const studied = mins >= 1
    ? `You've studied ${mins} min today`
    : 'Welcome back';
  switch (fatigue.level) {
    case 'high':
      return `${studied} and your pace is dipping. Take five before the `
        + 'next block to maximize retention.';
    case 'mild':
      return `${studied} and your pace is easing. The heavier topics go `
        + 'first while your focus holds.';
    default:
      return `${studied}. We've placed ${topicsPart} first to maximize `
        + 'retention.';
  }
}
