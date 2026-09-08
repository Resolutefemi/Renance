'use client';

import { api } from './api';

export interface ExamMeta {
  code: string;
  title: string;
  questionCount: number;
  totalMarks: number;
  durationMinutes?: number;
  bundleSha256: string;
  sizeBytes: number;
  /** Exam body this pack serves: JAMB | WAEC | NECO | University Modules. */
  body?: string;
  /** Exam years present in the pack (sorted) — the year pickers' data. */
  years?: number[];
}

export interface Manifest {
  generatedAt: string;
  version: string;
  exams: ExamMeta[];
}

export interface BundleQuestion {
  id: string;
  type: string;
  stem: string;
  options?: Record<string, string>;
  marks: number;
  topic?: string;
  difficulty?: string;
  /** Exam year the past question was drawn from (banks carry it when known). */
  year?: number;
  /** Question family the player treats specially ("comprehension" =
   *  passage-based English questions); empty for ordinary questions. */
  group?: string;
}

export interface BundleSection {
  subject: string;
  questionIds: string[];
}

export interface Bundle {
  code: string;
  title: string;
  version: number;
  questionCount: number;
  totalMarks: number;
  durationMinutes?: number;
  category?: string;
  body?: string;
  questions: BundleQuestion[];
  /** Composite UTME mock papers only: per-subject grouping for tabs. */
  sections?: BundleSection[];
}

export async function fetchManifest(): Promise<Manifest> {
  return api<Manifest>('/manifest');
}

function cacheKey(code: string, sha: string) {
  return `renance.bundle.${code}.${sha.slice(0, 12)}`;
}

export async function fetchBundle(exam: ExamMeta): Promise<Bundle> {
  const key = cacheKey(exam.code, exam.bundleSha256);
  const cached = window.localStorage.getItem(key);
  if (cached) {
    try {
      return JSON.parse(cached) as Bundle;
    } catch {
      window.localStorage.removeItem(key);
    }
  }
  const bundle = await api<Bundle>(`/bundles/${exam.code}`);
  // sha pinned cache: old versions simply become unreachable keys
  window.localStorage.setItem(key, JSON.stringify(bundle));
  return bundle;
}

/* ------------------------------------------------------------------ */
/* Composite UTME mock papers (jamb-mock-…)                            */
/* ------------------------------------------------------------------ */

/** Every UTME mock paper code starts with this prefix. */
export const MOCK_PAPER_PREFIX = 'jamb-mock-';

export function isMockPaperCode(code: string): boolean {
  return code.startsWith(MOCK_PAPER_PREFIX) && code.length > MOCK_PAPER_PREFIX.length;
}

/** Custom-practice composed papers. */
export const CUSTOM_PAPER_PREFIX = 'jamb-custom-';

export function isCustomPaperCode(code: string): boolean {
  return code.startsWith(CUSTOM_PAPER_PREFIX) && code.length > CUSTOM_PAPER_PREFIX.length;
}

/** Carved practice-subset papers. */
export const PICK_PAPER_PREFIX = 'jamb-pick-';

export function isPickPaperCode(code: string): boolean {
  return code.startsWith(PICK_PAPER_PREFIX) && code.length > PICK_PAPER_PREFIX.length;
}

/** Any server-composed paper (never in the manifest, resolves by code). */
export function isComposedPaperCode(code: string): boolean {
  return isMockPaperCode(code) || isCustomPaperCode(code) || isPickPaperCode(code);
}

/** The subjects a candidate can pick beyond the mandatory Use of English. */
export const UTME_ELECTIVES = [
  { slug: 'mathematics', name: 'Mathematics' },
  { slug: 'physics', name: 'Physics' },
  { slug: 'chemistry', name: 'Chemistry' },
  { slug: 'biology', name: 'Biology' },
  { slug: 'economics', name: 'Economics' },
  { slug: 'government', name: 'Government' },
  { slug: 'geography', name: 'Geography' },
  { slug: 'literature', name: 'Literature in English' },
  { slug: 'crs', name: 'Christian Religious Studies' },
  { slug: 'irs', name: 'Islamic Religious Studies' },
  { slug: 'agricultural-science', name: 'Agricultural Science' },
  { slug: 'commerce', name: 'Commerce' },
  { slug: 'accounting', name: 'Principles of Accounts' },
  { slug: 'computer-studies', name: 'Computer Studies' },
  { slug: 'civic-education', name: 'Civic Education' },
  { slug: 'history', name: 'History' },
  { slug: 'french', name: 'French' },
  { slug: 'arabic', name: 'Arabic' },
  { slug: 'hausa', name: 'Hausa' },
  { slug: 'igbo', name: 'Igbo' },
  { slug: 'yoruba', name: 'Yoruba' },
  { slug: 'music', name: 'Music' },
  { slug: 'fine-arts', name: 'Fine Arts' },
  { slug: 'home-economics', name: 'Home Economics' },
  { slug: 'physical-education', name: 'Physical Education' },
] as const;

/** Subject display names for every slug the mock setup can list. */
export function subjectName(slug: string): string {
  if (slug === 'english') return 'Use of English';
  const hit = UTME_ELECTIVES.find((e) => e.slug === slug);
  return hit ? hit.name : slug.replace(/-/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

/* ------------------------------------------------------------------ */
/* Composed paper codes (jamb-mock / jamb-custom / jamb-pick)          */
/* ------------------------------------------------------------------ */

/**
 * The server composes these papers purely from the code (see
 * apps/study-api/internal/cbtdata/papercode.go): subjects + optional
 * dot-joined params, canonically ordered y,n,enN,comp,compN,t. The
 * client MUST build codes through these builders — the server refuses
 * non-canonical strings.
 */

export interface MockOptions {
  /** Per-subject years aligned with `subjects` (0/random entries as null).
   *  A single year pins every subject. */
  years?: Array<number | null> | number | null;
  /** Use-of-English section size (default 60). */
  englishSize?: number;
  /** Include comprehension-passage questions (default true). */
  comprehension?: boolean;
  /** How many comprehension questions the English section carries (default 10). */
  comprehensionCount?: number;
  /** Timer minutes (default 120). */
  timer?: number;
}

function yearsParam(spec: Array<number | null> | number | null): string | null {
  if (spec == null) return null;
  if (typeof spec === 'number') return spec > 0 ? String(spec) : null;
  const allRandom = spec.every((y) => y == null);
  if (allRandom) return null;
  const allSame = spec[0] != null && spec.every((y) => y === spec[0]);
  if (allSame) return String(spec[0]);
  return spec.map((y) => (y == null ? 'r' : String(y))).join(';');
}

function joinParams(parts: string[]): string {
  return parts.length ? `~${parts.join('.')}` : '';
}

/** Canonical official-UTME mock code: Use of English first, electives sorted. */
export function buildMockCode(electives: ReadonlyArray<string>, opts: MockOptions = {}): string {
  const rest = [...new Set(electives)].sort();
  const subjects = ['english', ...rest];
  const parts: string[] = [];
  const y = yearsParam(opts.years ?? null);
  if (y) parts.push(`y=${y}`);
  if (opts.englishSize != null && opts.englishSize !== 60) parts.push(`enN=${opts.englishSize}`);
  if (opts.comprehension === false) parts.push('comp=0');
  else if (opts.comprehensionCount != null && opts.comprehensionCount !== 10) {
    parts.push(`compN=${opts.comprehensionCount}`);
  }
  if (opts.timer != null && opts.timer !== 120 && opts.timer > 0) parts.push(`t=${opts.timer}`);
  return `jamb-mock-${subjects.join('-')}${joinParams(parts)}`;
}

export interface CustomOptions {
  /** Total questions, spread across the subjects (default 40). */
  count: number;
  /** Single year for every subject, or null for random. */
  year?: number | null;
  /** Timer minutes; 0/undefined = untimed. */
  timer?: number;
}

/** Canonical custom-practice paper code: subjects fully sorted, ≥1. */
export function buildCustomCode(subjects: ReadonlyArray<string>, opts: CustomOptions): string {
  const sorted = [...new Set(subjects)].sort();
  const parts: string[] = [];
  if (opts.count > 0) parts.push(`n=${Math.min(opts.count, 500)}`);
  const y = yearsParam(opts.year ?? null);
  if (y) parts.push(`y=${y}`);
  if (opts.timer != null && opts.timer > 0) parts.push(`t=${opts.timer}`);
  return `jamb-custom-${sorted.join('-')}${joinParams(parts)}`;
}

export interface PickOptions {
  /** Subset size (default 40). */
  count: number;
  /** Particular exam year, or null for random. */
  year?: number | null;
  /** Timer minutes; 0/undefined = the base pack's own timing. */
  timer?: number;
}

/**
 * Canonical practice-subset code: carves `count` questions out of one
 * static manifest pack (optionally pinned to one year), so practice
 * sessions and their grading stay server-composed and resumable.
 */
export function buildPickCode(base: string, opts: PickOptions): string {
  const parts: string[] = [];
  const y = yearsParam(opts.year ?? null);
  if (y) parts.push(`y=${y}`);
  if (opts.count > 0) parts.push(`n=${Math.min(opts.count, 500)}`);
  if (opts.timer != null && opts.timer > 0) parts.push(`t=${opts.timer}`);
  return `jamb-pick-${base}${joinParams(parts)}`;
}

/**
 * Canonical mock paper code: Use of English first (mandatory), the
 * elected subjects sorted. The server refuses non-canonical codes, so
 * every surface that links a paper MUST build it through here.
 */
export function mockPaperCode(electives: ReadonlyArray<string>): string {
  const rest = [...new Set(electives)].sort();
  return `${MOCK_PAPER_PREFIX}english-${rest.join('-')}`;
}

/**
 * Fetch a pack by code without the manifest (composite mock papers are
 * composed on the server and never appear in the manifest). The cached
 * copy keeps offline resume working; a successful fetch always replaces
 * it, so staleness self-heals on the next online load.
 */
export async function fetchBundleByCode(code: string): Promise<Bundle> {
  const key = `renance.bundle.${code}`;
  const cached = window.localStorage.getItem(key);
  let fallback: Bundle | null = null;
  if (cached) {
    try {
      fallback = JSON.parse(cached) as Bundle;
    } catch {
      window.localStorage.removeItem(key);
    }
  }
  try {
    const bundle = await api<Bundle>(`/bundles/${code}`);
    window.localStorage.setItem(key, JSON.stringify(bundle));
    return bundle;
  } catch (err) {
    if (fallback) return fallback; // offline: resume from the cached paper
    throw err;
  }
}

/** Silent background asset sync (web side): prefetch every pack. */
export async function prefetchAll(
  manifest: Manifest,
  onProgress?: (done: number, total: number) => void,
): Promise<number> {
  let done = 0;
  for (const exam of manifest.exams) {
    await fetchBundle(exam);
    done += 1;
    onProgress?.(done, manifest.exams.length);
  }
  return done;
}
