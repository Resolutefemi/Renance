'use client';

/**
 * Learning-focus flag, the client-side tertiary/secondary switch.
 *
 * The GPA calculator is a tertiary-only tool (founder call): it must
 * never surface on the JAMB / WAEC / NECO interfaces. The dashboard and
 * the profile editor are the two places that learn the student's exam
 * body; they record it here so the navs and the /gpa page can scope
 * themselves without another /me round-trip. The flag survives in
 * localStorage, so a returning student's nav is correct immediately.
 */

const FOCUS_KEY = 'renance.focus.v1';
export const FOCUS_EVENT = 'renance:focus';

export type Focus = 'tertiary' | 'secondary';

export function setFocus(focus: Focus): void {
  try {
    window.localStorage.setItem(FOCUS_KEY, focus);
  } catch {
    /* private mode: the nav falls back to hiding GPA, the safe side */
  }
  window.dispatchEvent(new Event(FOCUS_EVENT));
}

export function getFocus(): Focus | null {
  try {
    const raw = window.localStorage.getItem(FOCUS_KEY);
    return raw === 'tertiary' || raw === 'secondary' ? raw : null;
  } catch {
    return null;
  }
}

/** True when the student's first exam body marks a tertiary desk. */
export function focusFromExams(exams: readonly string[] | undefined): Focus {
  const first = (exams?.[0] ?? '').toLowerCase();
  return first.includes('university') ? 'tertiary' : 'secondary';
}
