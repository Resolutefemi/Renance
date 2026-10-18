'use client';

import schoolsJson from '../../../data/university/schools.json';
import futaCatalog from '../../../data/university/courses/futa.json';
import { buildPickCode, examHref } from './exams';
import type { School, SchoolCatalog, UniversityCourse } from './university-data';

/**
 * Client half of the university desk: the school registry (bundled at
 * build time) and the student's chosen school. The interface is one and
 * the same for every school; what changes is the content wrapped under
 * it, courses, question banks, PDFs, keyed by the school slug.
 */

const SCHOOL_KEY = 'renance.uni.school.v1';
const POST_UTME_SCHOOL_KEY = 'renance.postutme.school.v1';

export type { School, UniversityCourse };

export const SCHOOLS = (schoolsJson as { schools: School[] }).schools;

export const LIVE_SCHOOLS = SCHOOLS.filter((s) => s.live);

// --auto-onboarded-catalogs (school content harvest 2026-09) -- do not edit below this line
import cataaua from '../../../data/university/courses/aaua.json';
import cataau from '../../../data/university/courses/aau.json';
import catuniabuja from '../../../data/university/courses/uniabuja.json';
import catabu from '../../../data/university/courses/abu.json';
import catabuad from '../../../data/university/courses/abuad.json';
import catachievers from '../../../data/university/courses/achievers.json';
import catbabcock from '../../../data/university/courses/babcock.json';
import catbowen from '../../../data/university/courses/bowen.json';
import catbouesti from '../../../data/university/courses/bouesti.json';
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
import cattasued from '../../../data/university/courses/tasued.json';
import catui from '../../../data/university/courses/ui.json';
import catuniben from '../../../data/university/courses/uniben.json';
import catunical from '../../../data/university/courses/unical.json';
import catunilag from '../../../data/university/courses/unilag.json';
import catunilorin from '../../../data/university/courses/unilorin.json';
import catuniosun from '../../../data/university/courses/uniosun.json';
import catuniport from '../../../data/university/courses/uniport.json';
import catunn from '../../../data/university/courses/unn.json';
import catveritas from '../../../data/university/courses/veritas.json';
const ONBOARDED_CATALOGS: Record<string, SchoolCatalog> = {
  aau: cataau as unknown as SchoolCatalog,
  aaua: cataaua as unknown as SchoolCatalog,
  uniabuja: catuniabuja as unknown as SchoolCatalog,
  abu: catabu as unknown as SchoolCatalog,
  abuad: catabuad as unknown as SchoolCatalog,
  achievers: catachievers as unknown as SchoolCatalog,
  babcock: catbabcock as unknown as SchoolCatalog,
  bowen: catbowen as unknown as SchoolCatalog,
  bouesti: catbouesti as unknown as SchoolCatalog,
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
  tasued: cattasued as unknown as SchoolCatalog,
  ui: catui as unknown as SchoolCatalog,
  uniben: catuniben as unknown as SchoolCatalog,
  unical: catunical as unknown as SchoolCatalog,
  unilag: catunilag as unknown as SchoolCatalog,
  unilorin: catunilorin as unknown as SchoolCatalog,
  uniosun: catuniosun as unknown as SchoolCatalog,
  uniport: catuniport as unknown as SchoolCatalog,
  unn: catunn as unknown as SchoolCatalog,
  veritas: catveritas as unknown as SchoolCatalog,
};

// "Other Schools" (founder directive 2026-10-04): the merged general
// course desk for students whose school has no banked past questions
// yet. Every course gathers the questions of ALL schools that teach it
// (FUTA BIO 101 + UNILAG BIO 101 + ... become one generic BIO 101) -
// built by scripts/build_others_school.py, 145 courses today.
import catothers from '../../../data/university/courses/others.json';

/** Catalogs bundled client-side, keyed by school slug. */
const CATALOGS: Record<string, SchoolCatalog> = {
  futa: futaCatalog as unknown as SchoolCatalog,
  ...ONBOARDED_CATALOGS,
  others: catothers as unknown as SchoolCatalog,
};

/** The Others school row (pinned last on the selection list). */
export const OTHERS_SCHOOL: School =
  SCHOOLS.find((s) => s.slug === 'others') ?? {
    slug: 'others',
    short: 'OTHERS',
    name: 'Other Schools',
    type: 'university',
    state: 'Nationwide',
    live: true,
  };

/* Type labels + Material icons shared by every school listing (the
   profile picker, the School Desk gate, the directory rows). */
export const TYPE_LABELS: Record<School['type'], string> = {
  university: 'University',
  polytechnic: 'Polytechnic',
  'college-of-education': 'College of Education',
  'college-of-nursing': 'College of Nursing / Health',
};

export const TYPE_ICONS: Record<School['type'], string> = {
  university: 'account_balance',
  polytechnic: 'precision_manufacturing',
  'college-of-education': 'history_edu',
  'college-of-nursing': 'medical_services',
};

/* Pending institution (founder directive 2026-10-16): picking a school
   that has no banked desk yet on the School Desk gate routes the
   student into the shared general pool AND stamps their institution
   here, so the dashboard hero brands itself with the real school name
   (never "Other Schools") before the profile record catches up. */
const PENDING_INSTITUTION_KEY = 'renance.uni.pendingInstitution.v1';

export function readPendingInstitution(): string {
  try {
    return (window.localStorage.getItem(PENDING_INSTITUTION_KEY) ?? '').trim();
  } catch {
    return '';
  }
}

export function storePendingInstitution(name: string): void {
  try {
    window.localStorage.setItem(PENDING_INSTITUTION_KEY, name);
  } catch {
    /* private mode: the pick still routes, it just does not brand */
  }
}

export function clearPendingInstitution(): void {
  try {
    window.localStorage.removeItem(PENDING_INSTITUTION_KEY);
  } catch {
    /* ignore */
  }
}

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

/* ------------------------------------------------------------------ */
/* Post UTME desk school pick: a separate pick from the School Desk    */
/* one, because a Post UTME candidate targets one school's prep banks. */
/* ------------------------------------------------------------------ */

/** The school the student picked for the Post UTME desk, or null. */
export function storedPostUtmeSchoolSlug(): string | null {
  try {
    const slug = window.localStorage.getItem(POST_UTME_SCHOOL_KEY);
    return slug && SCHOOLS.some((s) => s.slug === slug) ? slug : null;
  } catch {
    return null;
  }
}

export function storePostUtmeSchoolSlug(slug: string): void {
  try {
    window.localStorage.setItem(POST_UTME_SCHOOL_KEY, slug);
  } catch {
    /* private mode: the desk still works, it just re-asks */
  }
}

/**href for a school's desk. */
export function schoolHref(slug: string): string {
  return `/university/${slug}`;
}

/* ------------------------------------------------------------------ */
/* Practice math, the renancecbt course-portal logic                   */
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

/** href of a course part, a contiguous Q-chunk, portal-style.
 *  Every course sitting plays as practice with instant answers - the
 *  founder pulled the answer-mode picker, no Exam Mode links exist. */
export function partHref(bank: string, part: number, total: number, timer?: number): string {
  const { from, to } = partRange(part, total);
  return examHref(buildPickCode(bank, { from, count: to - from + 1, timer }));
}

/** href of a Random Mode sitting (shuffled draw). */
export function randomHref(bank: string, count: number, timer?: number): string {
  return examHref(buildPickCode(bank, { count, timer }));
}
