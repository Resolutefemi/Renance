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

// --auto-onboarded-catalogs (school content harvest 2026-09) -- do not edit below this line
import cataaua from '../../../data/university/courses/aaua.json';
import catabu from '../../../data/university/courses/abu.json';
import catabuad from '../../../data/university/courses/abuad.json';
import catachievers from '../../../data/university/courses/achievers.json';
import catbabcock from '../../../data/university/courses/babcock.json';
import catbowen from '../../../data/university/courses/bowen.json';
import catbsu from '../../../data/university/courses/bsu.json';
import catcaleb from '../../../data/university/courses/caleb.json';
import catcovenant from '../../../data/university/courses/covenant.json';
import catdelsu from '../../../data/university/courses/delsu.json';
import cateksu from '../../../data/university/courses/eksu.json';
import catelizade from '../../../data/university/courses/elizade.json';
import catesut from '../../../data/university/courses/esut.json';
import catfuto from '../../../data/university/courses/futo.json';
import catgreenfield from '../../../data/university/courses/greenfield.json';
import catigbinedion from '../../../data/university/courses/igbinedion.json';
import catjabu from '../../../data/university/courses/jabu.json';
import catksu from '../../../data/university/courses/ksu.json';
import catlasu from '../../../data/university/courses/lasu.json';
import catlautech from '../../../data/university/courses/lautech.json';
import catleadcity from '../../../data/university/courses/leadcity.json';
import catmountain_top from '../../../data/university/courses/mountain-top.json';
import catnoun from '../../../data/university/courses/noun.json';
import catoau from '../../../data/university/courses/oau.json';
import catrsu from '../../../data/university/courses/rsu.json';
import catui from '../../../data/university/courses/ui.json';
import catuniben from '../../../data/university/courses/uniben.json';
import catunilag from '../../../data/university/courses/unilag.json';
import catunilorin from '../../../data/university/courses/unilorin.json';
import catuniosun from '../../../data/university/courses/uniosun.json';
import catuniport from '../../../data/university/courses/uniport.json';
import catunn from '../../../data/university/courses/unn.json';
import catveritas from '../../../data/university/courses/veritas.json';
const ONBOARDED_CATALOGS: Record<string, SchoolCatalog> = {
  aaua: cataaua as unknown as SchoolCatalog,
  abu: catabu as unknown as SchoolCatalog,
  abuad: catabuad as unknown as SchoolCatalog,
  achievers: catachievers as unknown as SchoolCatalog,
  babcock: catbabcock as unknown as SchoolCatalog,
  bowen: catbowen as unknown as SchoolCatalog,
  bsu: catbsu as unknown as SchoolCatalog,
  caleb: catcaleb as unknown as SchoolCatalog,
  covenant: catcovenant as unknown as SchoolCatalog,
  delsu: catdelsu as unknown as SchoolCatalog,
  eksu: cateksu as unknown as SchoolCatalog,
  elizade: catelizade as unknown as SchoolCatalog,
  esut: catesut as unknown as SchoolCatalog,
  futo: catfuto as unknown as SchoolCatalog,
  greenfield: catgreenfield as unknown as SchoolCatalog,
  igbinedion: catigbinedion as unknown as SchoolCatalog,
  jabu: catjabu as unknown as SchoolCatalog,
  ksu: catksu as unknown as SchoolCatalog,
  lasu: catlasu as unknown as SchoolCatalog,
  lautech: catlautech as unknown as SchoolCatalog,
  leadcity: catleadcity as unknown as SchoolCatalog,
  'mountain-top': catmountain_top as unknown as SchoolCatalog,
  noun: catnoun as unknown as SchoolCatalog,
  oau: catoau as unknown as SchoolCatalog,
  rsu: catrsu as unknown as SchoolCatalog,
  ui: catui as unknown as SchoolCatalog,
  uniben: catuniben as unknown as SchoolCatalog,
  unilag: catunilag as unknown as SchoolCatalog,
  unilorin: catunilorin as unknown as SchoolCatalog,
  uniosun: catuniosun as unknown as SchoolCatalog,
  uniport: catuniport as unknown as SchoolCatalog,
  unn: catunn as unknown as SchoolCatalog,
  veritas: catveritas as unknown as SchoolCatalog,
};

/** Catalogs bundled client-side, keyed by school slug. */
const CATALOGS: Record<string, SchoolCatalog> = {
  futa: futaCatalog as unknown as SchoolCatalog,
  ...ONBOARDED_CATALOGS,
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
