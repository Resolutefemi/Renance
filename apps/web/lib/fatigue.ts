/**
 * Fatigue (ROADMAP #6) — the pure rule, mirrored from the Go package
 * (apps/study-api/internal/fatigue) so app, web and API always agree on
 * what "your pace is dipping" means. No PII beyond timing.
 */

export const FATIGUE_MIN_ANSWERS = 8;
export const FATIGUE_DRIFT_MILD = 1.8;
export const FATIGUE_DRIFT_HIGH = 2.6;
export const FATIGUE_DRIFT_FLOOR_MINUTES = 30;
export const FATIGUE_MILD_MINUTES = 50;
export const FATIGUE_HIGH_MINUTES = 75;
export const FATIGUE_COMBO_MINUTES = 40;

export interface FatigueSignal {
  level: 'none' | 'mild' | 'high';
  suggestBreak: boolean;
  reasons: string[];
  driftRatio: number;
  medianFirst5Ms: number;
  medianLast5Ms: number;
}

export const FATIGUE_NONE: FatigueSignal = {
  level: 'none',
  suggestBreak: false,
  reasons: [],
  driftRatio: 0,
  medianFirst5Ms: 0,
  medianLast5Ms: 0,
};

/** Median of ms samples (empty → 0). Never mutates the input. */
export function medianOf(xs: number[]): number {
  if (xs.length === 0) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[mid] : Math.floor((s[mid - 1] + s[mid]) / 2);
}

function windowOf(ms: number[], n: number): [number[], number[]] {
  return [ms.slice(0, n), ms.length > n ? ms.slice(ms.length - n) : ms];
}

/** The same thresholds and escalation ladder as the Go original. */
export function assessFatigue(
  latenciesMs: number[],
  sessionMinutes: number,
): FatigueSignal {
  const [first, last] = windowOf(latenciesMs, 5);
  const mFirst = medianOf(first);
  const mLast = medianOf(last);
  const ratio = mFirst > 0 ? mLast / mFirst : 0;

  let level: FatigueSignal['level'] = 'none';
  const reasons: string[] = [];

  const driftMild = latenciesMs.length >= FATIGUE_MIN_ANSWERS && ratio >= FATIGUE_DRIFT_MILD;
  const driftHigh =
    latenciesMs.length >= FATIGUE_MIN_ANSWERS &&
    ratio >= FATIGUE_DRIFT_HIGH &&
    sessionMinutes >= FATIGUE_DRIFT_FLOOR_MINUTES;

  if (driftHigh) {
    level = 'high';
    reasons.push('Answers are taking much longer than they did at the start');
  } else if (driftMild && sessionMinutes >= FATIGUE_COMBO_MINUTES) {
    level = 'high';
    reasons.push('Your pace is dipping and this has been a long sitting');
  } else if (driftMild) {
    level = 'mild';
    reasons.push('Your pace is dipping');
  }

  if (sessionMinutes >= FATIGUE_HIGH_MINUTES) {
    level = 'high';
    reasons.push('This has been a long session');
  } else if (sessionMinutes >= FATIGUE_MILD_MINUTES && level === 'none') {
    level = 'mild';
    reasons.push('This has been a long session');
  }

  return {
    level,
    suggestBreak: level !== 'none',
    reasons,
    driftRatio: ratio,
    medianFirst5Ms: mFirst,
    medianLast5Ms: mLast,
  };
}
