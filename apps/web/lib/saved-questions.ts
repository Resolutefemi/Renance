'use client';

/**
 * SavedQuestion store — the web cut of the app's SavedStore (Myschool's
 * Save button). A saved question is a full snapshot of what the reader
 * needs to re-display it forever after: stem, options, correct letter,
 * the written explanation and where it came from.
 *
 * Storage is localStorage under `renance.saved.v1` — these are small
 * typed rows (never raw bundles), so the 5 MB origin quota the bundles
 * outgrew is not a concern here. All reads/writes are lazy and
 * try/catch-guarded: private mode just gets an in-memory session store.
 */

export interface SavedQuestion {
  questionId: string;
  /** Pack the question came from, e.g. `waec-biology-bank` or a composed code. */
  code: string;
  title: string;
  stem: string;
  image?: string;
  passage?: string;
  options: Record<string, string>;
  /** Correct option letter ('' when the paper was ungraded at save time). */
  correct: string;
  explanation?: string;
  topic?: string;
  year?: number;
  savedAt: number;
}

const KEY = 'renance.saved.v1';
const MAX = 500;

let memory: SavedQuestion[] | null = null;

function read(): SavedQuestion[] {
  if (typeof window === 'undefined') return [];
  if (memory) return memory;
  try {
    const raw = window.localStorage.getItem(KEY);
    const parsed = raw ? (JSON.parse(raw) as SavedQuestion[]) : [];
    memory = Array.isArray(parsed) ? parsed : [];
  } catch {
    memory = [];
  }
  return memory;
}

function write(rows: SavedQuestion[]) {
  memory = rows.slice(0, MAX);
  try {
    window.localStorage.setItem(KEY, JSON.stringify(memory));
  } catch {
    /* private mode / quota: the session copy still works */
  }
}

export function listSaved(): SavedQuestion[] {
  return [...read()].sort((a, b) => b.savedAt - a.savedAt);
}

export function isSaved(questionId: string): boolean {
  return read().some((q) => q.questionId === questionId);
}

/** Saved ids for a whole list in one pass (the readers' chip state). */
export function savedIdSet(): Set<string> {
  return new Set(read().map((q) => q.questionId));
}

export function toggleSave(q: Omit<SavedQuestion, 'savedAt'>): boolean {
  const rows = read();
  const at = rows.findIndex((r) => r.questionId === q.questionId);
  if (at >= 0) {
    rows.splice(at, 1);
    write(rows);
    return false;
  }
  rows.unshift({ ...q, savedAt: Date.now() });
  write(rows);
  return true;
}

export function removeSaved(questionId: string) {
  write(read().filter((q) => q.questionId !== questionId));
}

export function clearSaved() {
  write([]);
}
