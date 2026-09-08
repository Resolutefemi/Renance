'use client';

import { api } from './api';
import { idbGetBundle, idbSetBundle, migrateLocalStorageBundles } from './bundle-store';

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
  /** Question diagram (origin-less /qimages/ path) the stem refers to. */
  image?: string;
  /** Shared comprehension text the question belongs to (per-question so
   *  any member of the group can render it). */
  passage?: string;
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

/**
 * Cache keys live under the renance.bundle.* namespace in IndexedDB
 * (the old localStorage namespace, migrated once at boot). Bundles are
 * multi-megabyte JSON — localStorage blew the ~5MB origin quota on the
 * English bank, so all bundle persistence goes through bundle-store.ts
 * and never touches localStorage again.
 */
function cacheKey(code: string, sha: string) {
  return `renance.bundle.${code}.${sha.slice(0, 12)}`;
}

export async function fetchBundle(exam: ExamMeta): Promise<Bundle> {
  const key = cacheKey(exam.code, exam.bundleSha256);
  const cached = (await idbGetBundle(key)) as Bundle | null;
  if (cached && cached.questions) return cached;
  const bundle = await api<Bundle>(`/bundles/${exam.code}`);
  // sha pinned cache: old versions simply become unreachable keys
  void idbSetBundle(key, bundle);
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

/** Custom-practice composed papers — any body: jamb/waec/neco. */
export const CUSTOM_PAPER_PREFIX = 'jamb-custom-';
export const WAEC_CUSTOM_PAPER_PREFIX = 'waec-custom-';
export const NECO_CUSTOM_PAPER_PREFIX = 'neco-custom-';

export function isCustomPaperCode(code: string): boolean {
  return (
    (code.startsWith(CUSTOM_PAPER_PREFIX) && code.length > CUSTOM_PAPER_PREFIX.length) ||
    (code.startsWith(WAEC_CUSTOM_PAPER_PREFIX) && code.length > WAEC_CUSTOM_PAPER_PREFIX.length) ||
    (code.startsWith(NECO_CUSTOM_PAPER_PREFIX) && code.length > NECO_CUSTOM_PAPER_PREFIX.length)
  );
}

/** Exam body a custom paper composes from ("jamb" | "waec" | "neco"). */
export function customPaperBody(code: string): 'jamb' | 'waec' | 'neco' | null {
  if (code.startsWith(WAEC_CUSTOM_PAPER_PREFIX) && code.length > WAEC_CUSTOM_PAPER_PREFIX.length) return 'waec';
  if (code.startsWith(NECO_CUSTOM_PAPER_PREFIX) && code.length > NECO_CUSTOM_PAPER_PREFIX.length) return 'neco';
  if (code.startsWith(CUSTOM_PAPER_PREFIX) && code.length > CUSTOM_PAPER_PREFIX.length) return 'jamb';
  return null;
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
  /** Include comprehension-passage questions (default false). */
  comprehension?: boolean;
  /** How many comprehension questions the English section carries (default 10). */
  comprehensionCount?: number;
  /** Include the JAMB novel questions ("The Lekki Headmaster") —
   *  default false, mirroring the real "do you want the novel?" ask. */
  novel?: boolean;
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
  // Comprehension defaults ON in the server grammar (absent = on), so a
  // switched-on section simply omits the param; OFF is stated explicitly.
  // Emitting comp=1 would break the byte-for-byte canonical check.
  if (opts.comprehension === false) parts.push('comp=0');
  else if (opts.comprehensionCount != null && opts.comprehensionCount !== 10) {
    parts.push(`compN=${opts.comprehensionCount}`);
  }
  if (opts.novel) parts.push('nov=1');
  if (opts.timer != null && opts.timer !== 120 && opts.timer > 0) parts.push(`t=${opts.timer}`);
  return `jamb-mock-${subjects.join('-')}${joinParams(parts)}`;
}

export interface CustomOptions {
  /** Total questions, spread across the subjects (default 40). */
  count: number;
  /** Single year for every subject, a per-subject list (null = random
   *  entries, semicolon-encoded), or null for all-random. */
  year?: number | Array<number | null> | null;
  /** Timer minutes; 0/undefined = untimed. */
  timer?: number;
}

/** Canonical custom-practice paper code: subjects fully sorted, ≥1.
 *  Params follow the server's canonical order y,n,t — emitting n before
 *  y fails the byte-for-byte canonical check for any year-pinned paper. */
export function buildCustomCode(subjects: ReadonlyArray<string>, opts: CustomOptions): string {
  const sorted = [...new Set(subjects)].sort();
  const parts: string[] = [];
  const y = yearsParam(opts.year ?? null);
  if (y) parts.push(`y=${y}`);
  if (opts.count > 0) parts.push(`n=${Math.min(opts.count, 500)}`);
  if (opts.timer != null && opts.timer > 0) parts.push(`t=${opts.timer}`);
  return `jamb-custom-${sorted.join('-')}${joinParams(parts)}`;
}

/** Exam bodies whose banks can back a custom paper. */
export type CustomBody = 'jamb' | 'waec' | 'neco';

/**
 * Canonical body custom-practice code: the same grammar as the JAMB
 * custom family, but the prefix pins the exam body whose banks the
 * server composes from (waec-custom-… pulls waec-<slug>-bank only).
 * WAEC/NECO papers carry y/n/t only — the English comprehension/novel
 * controls are JAMB-section features the server refuses elsewhere.
 */
export function buildBodyCustomCode(
  body: Exclude<CustomBody, 'jamb'>,
  subjects: ReadonlyArray<string>,
  opts: CustomOptions,
): string {
  const sorted = [...new Set(subjects)].sort();
  if (sorted.length === 0) return `${body}-custom-`;
  const parts: string[] = [];
  const y = yearsParam(opts.year ?? null);
  if (y) parts.push(`y=${y}`);
  if (opts.count > 0) parts.push(`n=${Math.min(opts.count, 500)}`);
  if (opts.timer != null && opts.timer > 0) parts.push(`t=${opts.timer}`);
  return `${body}-custom-${sorted.join('-')}${joinParams(parts)}`;
}

export interface PickOptions {
  /** Subset size (default 40; contiguous slices default 50). */
  count: number;
  /** 1-based start of a CONTIGUOUS slice — the university portals'
   *  Part chunks (from=51, n=50 serves Q51–Q100 in original order).
   *  Omitted = seeded shuffle of the whole pool. */
  from?: number;
  /** Particular exam year, or null for random. */
  year?: number | null;
  /** Timer minutes; 0/undefined = the base pack's own timing. */
  timer?: number;
}

/**
 * Canonical practice-subset code: carves `count` questions out of one
 * static manifest pack (optionally pinned to one year, optionally a
 * contiguous slice via `from`), so practice sessions and their grading
 * stay server-composed and resumable.
 */
export function buildPickCode(base: string, opts: PickOptions): string {
  const parts: string[] = [];
  const y = yearsParam(opts.year ?? null);
  if (y) parts.push(`y=${y}`);
  if (opts.from != null && opts.from > 0) parts.push(`from=${Math.min(opts.from, 100000)}`);
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
  const cached = (await idbGetBundle(key)) as Bundle | null;
  const fallback = cached && cached.questions ? cached : null;
  try {
    const bundle = await api<Bundle>(`/bundles/${code}`);
    void idbSetBundle(key, bundle);
    return bundle;
  } catch (err) {
    if (fallback) return fallback; // offline: resume from the cached paper
    throw err;
  }
}

/* ------------------------------------------------------------------ */
/* Exam deep links (static-export safe)                                */
/* ------------------------------------------------------------------ */

/**
 * The site ships as a Next.js static export: /exams/<code> pages exist
 * ONLY for the manifest packs and the param-less mock combos baked in
 * at build time. Composed papers (mock with year/count params, custom,
 * pick) resolve through the static /exams/paper/ route with the code
 * in the query string — a query string needs no build-time page. Every
 * deep link to an exam MUST go through this helper, otherwise year-
 * pinned papers 404 and bounce the candidate off the app.
 */
export function examHref(code: string, query?: Record<string, string | undefined>): string {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(query ?? {})) {
    if (v != null && v !== '') qs.set(k, v);
  }
  const tail = qs.toString() ? `?${qs.toString()}` : '';
  if (isComposedPaperCode(code)) {
    return `/exams/paper/?code=${encodeURIComponent(code)}${tail}`;
  }
  return `/exams/${code}${tail}`;
}

/** Boot-time cache migration, safe to call from any client surface. */
export function migrateBundleCache(): void {
  void migrateLocalStorageBundles();
}

/** Silent background asset sync (web side): prefetch every pack.
 *  Best-effort per pack — one offline fetch must not kill the sweep. */
export async function prefetchAll(
  manifest: Manifest,
  onProgress?: (done: number, total: number) => void,
): Promise<number> {
  let done = 0;
  for (const exam of manifest.exams) {
    try {
      await fetchBundle(exam);
    } catch {
      /* offline or pack missing: keep sweeping, retry next boot */
    }
    done += 1;
    onProgress?.(done, manifest.exams.length);
  }
  return done;
}
