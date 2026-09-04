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
