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

/** The subjects a candidate can pick beyond the mandatory Use of English. */
export const UTME_ELECTIVES = [
  { slug: 'mathematics', name: 'Mathematics' },
  { slug: 'physics', name: 'Physics' },
  { slug: 'chemistry', name: 'Chemistry' },
  { slug: 'biology', name: 'Biology' },
  { slug: 'economics', name: 'Economics' },
  { slug: 'government', name: 'Government' },
  { slug: 'geography', name: 'Geography' },
] as const;

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
