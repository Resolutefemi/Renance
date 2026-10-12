/**
 * National curriculum corpus client (founder directive: the corpus
 * lives in the codebase, not in Neon).
 *
 * The build bakes every class/subject/term file into
 * /school-corpus/... (scripts/bake_school_corpus.py), so the browser
 * reads them same-origin with zero API cold start. The study API's
 * /school/corpus routes stay as the fallback for stale deploys.
 *
 * 2026-10-12 STATIC SHIELD (founder directive: "ultimate security, no
 * openings"): the baked scheme/note files ship as AES-256-GCM
 * ciphertext (scripts/encrypt_pdfs.mjs); every per-term load below
 * decrypts through lib/asset-crypto.ts (the same metered key route as
 * the question banks - anonymous PoW is lighter here, 14 bits). The
 * index stays plain: it is a directory of paths, no content.
 */

import { fetchStaticAssetText } from './asset-crypto';

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

export type CorpusSubject = {
  id: string;
  name: string;
  schemeTerms: number[];
  noteTerms: number[];
};

export type CorpusClass = {
  id: string;
  name: string;
  stage: string;
  stageLabel: string;
  subjects: CorpusSubject[];
};

export type CorpusIndex = {
  source: string;
  classes: CorpusClass[];
};

export type CorpusSchemeWeek = {
  week: number;
  topic: string;
  content: string;
};

export type CorpusSchemeTerm = {
  class: string;
  subject: string;
  term: number;
  weeks: CorpusSchemeWeek[];
};

export type CorpusNoteTopic = {
  week: number;
  title: string;
  content: string;
};

export type CorpusNoteTerm = {
  class: string;
  subject: string;
  term: number;
  topics: CorpusNoteTopic[];
};

async function fetchStatic<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE_PATH}${path}`);
  if (!res.ok) throw new Error(`static ${path}: ${res.status}`);
  return (await res.json()) as T;
}

/** Shielded corpus file load: fetch -> /bundles/key (static:<path>) ->
 * WebCrypto decrypt -> JSON. Pre-shield plain files pass through. */
async function fetchShielded<T>(path: string): Promise<T> {
  const text = await fetchStaticAssetText(path);
  return JSON.parse(text) as T;
}

/** Normalize one class's subjects to the array the UI maps over. The
 * first production bake shipped subjects as a dict keyed by slug, which
 * crashed every subjects.find/map call and blanked the Curriculum Bank;
 * accept both shapes forever so stale deploys and caches heal. */
function normalizeSubjects(raw: unknown): CorpusSubject[] {
  if (Array.isArray(raw)) return raw as CorpusSubject[];
  if (raw && typeof raw === 'object') {
    return Object.entries(raw as Record<string, Omit<CorpusSubject, 'id'>>).map(([id, s]) => ({
      id,
      ...s,
    }));
  }
  return [];
}

export async function fetchCorpusIndex(): Promise<CorpusIndex> {
  const idx = await fetchStatic<CorpusIndex>('/school-corpus/index.json');
  idx.classes = (idx.classes ?? []).map((c) => ({ ...c, subjects: normalizeSubjects(c.subjects) }));
  return idx;
}

/** Every term's scheme of work for one class + subject. */
export async function loadCorpusSchemes(classId: string, subject: string): Promise<CorpusSchemeTerm[]> {
  // The baked per-term files live at schemes/{class}/{subject}-term{N}.json.
  // Probe terms 1..3 and keep what answers.
  const terms = await Promise.all(
    [1, 2, 3].map(async (term) => {
      try {
        return await fetchShielded<CorpusSchemeTerm>(
          `/school-corpus/schemes/${classId}/${subject}-term${term}.json`,
        );
      } catch {
        return null;
      }
    }),
  );
  return terms.filter((t): t is CorpusSchemeTerm => t !== null).sort((a, b) => a.term - b.term);
}

/** Every term's lesson notes for one class + subject. */
export async function loadCorpusNotes(classId: string, subject: string): Promise<CorpusNoteTerm[]> {
  const terms = await Promise.all(
    [1, 2, 3].map(async (term) => {
      try {
        return await fetchShielded<CorpusNoteTerm>(
          `/school-corpus/notes/${classId}/${subject}-term${term}.json`,
        );
      } catch {
        return null;
      }
    }),
  );
  return terms.filter((t): t is CorpusNoteTerm => t !== null).sort((a, b) => a.term - b.term);
}
