'use client';

import schoolsJson from '../../../data/university/schools.json';
import futaCatalog from '../../../data/university/courses/futa.json';
import { buildPickCode, examHref } from './exams';
import type { School, SchoolCatalog, UniversityCourse } from './university-data';

/**
 * Client half of the university desk: the school registry (bundled at
 * build time) and the student's chosen school. The interface is one and
 * the same for every school; what changes is the content wrapped under
 * it — courses, question banks, PDFs — keyed by the school slug.
 */

const SCHOOL_KEY = 'renance.uni.school.v1';

export type { School, UniversityCourse };

export const SCHOOLS = (schoolsJson as { schools: School[] }).schools;

export const LIVE_SCHOOLS = SCHOOLS.filter((s) => s.live);

/** Catalogs bundled client-side, keyed by school slug. */
const CATALOGS: Record<string, SchoolCatalog> = {
  futa: futaCatalog as unknown as SchoolCatalog,
};

/** The bundled course catalog for a school, or null when it has none. */
export function clientCatalog(slug: string): SchoolCatalog | null {
  return CATALOGS[slug] ?? null;
}

/** Courses of the student's school that ship a playable bank. */
export function liveCourses(catalog: SchoolCatalog | null): UniversityCourse[] {
  return catalog?.courses.filter((c) => c.bank) ?? [];
}

/** Case-insensitive lookup by name or short code (profile matching). */
export function findSchoolByName(name: string): School | null {
  const want = name.trim().toLowerCase();
  if (!want) return null;
  return (
    SCHOOLS.find((s) => s.name.toLowerCase() === want) ??
    SCHOOLS.find((s) => s.short.toLowerCase() === want) ??
    SCHOOLS.find((s) => s.name.toLowerCase().includes(want) && want.length >= 4) ??
    null
  );
}

/** The school slug a student last picked (FUTA until they choose). */
export function storedSchoolSlug(): string | null {
  try {
    return window.localStorage.getItem(SCHOOL_KEY);
  } catch {
    return null;
  }
}

export function storeSchoolSlug(slug: string): void {
  try {
    window.localStorage.setItem(SCHOOL_KEY, slug);
  } catch {
    /* private mode: the desk still works, it just re-asks */
  }
}

/** Resolve the desk school: stored pick → live school → FUTA. */
export function resolveSchoolSlug(): string {
  const stored = storedSchoolSlug();
  if (stored && SCHOOLS.some((s) => s.slug === stored)) return stored;
  return LIVE_SCHOOLS[0]?.slug ?? 'futa';
}

/**href for a school's desk. */
export function schoolHref(slug: string): string {
  return `/university/${slug}`;
}

/* ------------------------------------------------------------------ */
/* Practice math — the renancecbt course-portal logic                   */
/* ------------------------------------------------------------------ */

/** The portals slice every course into 50-question Part chunks. */
export const PART_SIZE = 50;

export function partCount(total: number): number {
  return Math.max(0, Math.ceil(total / PART_SIZE));
}

/** Q-range a part covers, clamped to the course's real size. */
export function partRange(part: number, total: number): { from: number; to: number } {
  const from = (part - 1) * PART_SIZE + 1;
  const to = Math.min(part * PART_SIZE, total);
  return { from, to };
}

/** href of a course part — a contiguous Q-chunk, portal-style. */
export function partHref(bank: string, part: number, total: number, timer?: number): string {
  const { from, to } = partRange(part, total);
  return examHref(buildPickCode(bank, { from, count: to - from + 1, timer }));
}

/** href of a Random Mode sitting (shuffled draw). */
export function randomHref(bank: string, count: number, timer?: number): string {
  return examHref(buildPickCode(bank, { count, timer }));
}
