/**
 * Gamification hub data layer, mirrors GET /me/gamification.
 * Badge catalog mirrors apps/study-api/internal/store/gamification.go
 * (BadgesFor codes) and the Flutter catalog in lib/ui/progress_screen.dart.
 */

export interface StreakState {
  currentStreak: number;
  bestStreak: number;
  totalXp: number;
  totalCorrect: number;
  attempts: number;
  level: number;
  lastActive?: string; // YYYY-MM-DD (UTC)
}

export interface Award {
  code: string;
  earnedAt: string;
}

export interface GamificationSummary {
  state: StreakState;
  awards: Award[];
}

export interface BadgeSpec {
  code: string;
  label: string;
  icon: string; // Material Symbols ligature name
  bgClass: string; // circle background
  fgClass: string; // icon color
  hint: string;
}

export const BADGES: BadgeSpec[] = [
  {
    code: 'first_blood',
    label: 'First Blood',
    icon: 'flag',
    bgClass: 'bg-selection-blue',
    fgClass: 'text-on-surface',
    hint: 'Complete your first exam',
  },
  {
    code: 'xp_500',
    label: 'Scholar',
    icon: 'school',
    bgClass: 'bg-selection-blue',
    fgClass: 'text-on-surface',
    hint: 'Earn 500 XP',
  },
  {
    code: 'streak_3',
    label: 'Warming Up',
    icon: 'local_fire_department',
    bgClass: 'bg-amber-tint',
    fgClass: 'text-accent-amber',
    hint: 'Keep a 3-day streak',
  },
  {
    code: 'century',
    label: 'Century',
    icon: 'emoji_events',
    bgClass: 'bg-emerald-tint',
    fgClass: 'text-accent-emerald',
    hint: 'Answer 100 questions correctly',
  },
  {
    code: 'perfect_paper',
    label: 'Flawless',
    icon: 'workspace_premium',
    bgClass: 'bg-ink-tint',
    fgClass: 'text-accent-ink',
    hint: 'Score 100% on a full exam',
  },
  {
    code: 'streak_7',
    label: 'On Fire',
    icon: 'local_fire_department',
    bgClass: 'bg-amber-tint',
    fgClass: 'text-accent-amber',
    hint: 'Keep a 7-day streak',
  },
  {
    code: 'xp_2000',
    label: 'Champion',
    icon: 'military_tech',
    bgClass: 'bg-amber-tint',
    fgClass: 'text-accent-amber',
    hint: 'Earn 2,000 XP',
  },
  {
    code: 'streak_30',
    label: 'Unstoppable',
    icon: 'rocket_launch',
    bgClass: 'bg-ink-tint',
    fgClass: 'text-accent-ink',
    hint: 'Keep a 30-day streak',
  },
];

export function holds(summary: GamificationSummary, code: string): boolean {
  return summary.awards.some((a) => a.code === code);
}

/** 3240 -> "3,240" */
export function comma(n: number): string {
  return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** "2026-09-01T10:00:00Z" -> "2d ago" */
export function relativeAgo(iso: string, now = new Date()): string {
  const t = new Date(iso).getTime();
  const mins = Math.max(0, Math.floor((now.getTime() - t) / 60000));
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export interface DayDot {
  label: string;
  practiced: boolean;
  isToday: boolean;
}

const WEEKDAY_LABELS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/**
 * The 7-day dot row for the current (Monday-first) week. Practiced days are
 * derived from the streak rule: the currentStreak days ENDING at lastActive.
 */
export function weekDots(state: StreakState, now = new Date()): DayDot[] {
  const monday = new Date(now);
  monday.setHours(0, 0, 0, 0);
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));

  const lastMs = state.lastActive
    ? Date.parse(`${state.lastActive}T00:00:00Z`)
    : null;
  const dayMs = 24 * 60 * 60 * 1000;

  return WEEKDAY_LABELS.map((label, i) => {
    const day = new Date(monday.getTime() + i * dayMs);
    const dayUtc = Date.UTC(day.getFullYear(), day.getMonth(), day.getDate());
    const diff = lastMs === null ? -1 : Math.round((lastMs - dayUtc) / dayMs);
    const practiced = diff >= 0 && diff < state.currentStreak;
    const isToday = day.toDateString() === now.toDateString();
    return { label, practiced, isToday };
  });
}
