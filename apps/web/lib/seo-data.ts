/**
 * @file apps/web/lib/seo-data.ts
 *
 * Phase 1 - Data Harvester for Renance Programmatic SEO Engine.
 *
 * SERVER-ONLY: uses Node `fs` APIs. Never import this from a Client Component.
 * Uses the same dataDir() walk-up pattern as site-data.ts so it resolves
 * correctly from any Next.js build working directory.
 *
 * Exports:
 *   loadSEOExamPaper()         → SEOExamPaperSummary | null
 *   loadSEOSubjectPillar()     → SEOSubjectPillar   | null
 *   getAvailableSEOExamParams()→ Array<{body, subject, year}>
 *   loadSEOCurriculumScheme()  → SEOCurriculumScheme | null
 *   getAllSEOCurriculumParams() → Array<{classLevel, subject, term}>
 */

import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

import { SITE_URL } from './site-url';
import type {
  ExamBodySlug,
  SEOCurriculumScheme,
  SEOCurriculumWeek,
  SEOExamPaperSummary,
  SEOSampleQuestion,
  SEOSubjectPillar,
} from './seo-types';

// ─── Constants ───────────────────────────────────────────────────────────────

/** Maximum sample questions to embed in a single paper summary. */
const MAX_SAMPLE_QUESTIONS = 5;

/**
 * Maps the URL-safe body slug -> directory name inside data/questions/.
 * Extend when new exam bodies are added to the data vault.
 */
const BODY_DIR_MAP: Record<ExamBodySlug, string> = {
  jamb: 'JAMB',
  waec: 'WAEC',
  neco: 'NECO',
  'post-utme': 'POST_UTME',
};

/** Human-readable titles for each exam body. */
const BODY_TITLE_MAP: Record<ExamBodySlug, string> = {
  jamb: 'JAMB',
  waec: 'WAEC',
  neco: 'NECO',
  'post-utme': 'Post UTME',
};

/** NERDC class-level slug → scheme JSON file basename (inside data/school-schemes/nerdc/). */
const NERDC_FILE_MAP: Record<string, string> = {
  pry1: 'pry_1.json',
  pry2: 'pry_2.json',
  pry4: 'pry_4.json',
  pry5: 'pry_5.json',
  jss1: 'jss_1.json',
  jss2: 'jss_2.json',
  sss1: 'sss_1.json',
  sss2: 'sss_2.json',
};

/** Friendly class-level labels. */
const CLASS_TITLE_MAP: Record<string, string> = {
  pry1: 'Primary 1',
  pry2: 'Primary 2',
  pry4: 'Primary 4',
  pry5: 'Primary 5',
  jss1: 'Junior Secondary 1',
  jss2: 'Junior Secondary 2',
  sss1: 'Senior Secondary 1',
  sss2: 'Senior Secondary 2',
};

const TERM_TITLE_MAP: Record<SEOCurriculumScheme['term'], string> = {
  'first-term': 'First Term',
  'second-term': 'Second Term',
  'third-term': 'Third Term',
};

// ─── Internal raw types (mirroring the JSON shapes in data/) ─────────────────

interface RawQuestion {
  id: string;
  type?: string;
  stem: string;
  options?: Record<string, string>;
  marks?: number;
  year?: number;
  answer?: string;
  explanation?: string;
  topic?: string;
  image?: string;
  passage?: string;
  video?: string;
  answer_image?: string;
}

interface RawQuestionBundle {
  code: string;
  title: string;
  version?: number;
  questionCount?: number;
  totalMarks?: number;
  questions: RawQuestion[];
}

interface RawNerdcOutlineEntry {
  theme: string;
  topics?: string[];
}

interface RawNerdcDocument {
  subject: string;
  sourceUrl?: string;
  pages?: number;
  file?: string;
  outline?: RawNerdcOutlineEntry[];
}

interface RawNerdcSchemeFile {
  level: string;
  label: string;
  source?: string;
  documents: RawNerdcDocument[];
}

// ─── dataDir walk-up (mirrors apps/web/lib/site-data.ts) ─────────────────────

function dataDir(): string | null {
  let dir = process.cwd();
  for (let i = 0; i < 6; i++) {
    if (existsSync(path.join(dir, 'data', 'manifest.json'))) {
      return path.join(dir, 'data');
    }
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
  return null;
}

// ─── Internal helpers ─────────────────────────────────────────────────────────

/**
 * Loads and parses a question-bundle JSON file for the given body + subject.
 * Returns null if the file doesn't exist or is malformed.
 */
function loadBundle(body: ExamBodySlug, subjectSlug: string): RawQuestionBundle | null {
  if (subjectSlug.startsWith('_') || subjectSlug.startsWith('.')) return null;

  const base = dataDir();
  if (!base) return null;

  const dir = BODY_DIR_MAP[body];
  if (!dir) return null;

  const filePath = path.join(base, 'questions', dir, `${subjectSlug}.json`);
  if (!existsSync(filePath)) return null;

  try {
    const bundle = JSON.parse(readFileSync(filePath, 'utf8')) as RawQuestionBundle;
    if (!bundle || !Array.isArray(bundle.questions)) return null;
    return bundle;
  } catch {
    return null;
  }
}

/** Converts a raw question record into the public SEOSampleQuestion shape. */
function toSampleQuestion(raw: RawQuestion): SEOSampleQuestion {
  return {
    id: raw.id,
    stem: raw.stem,
    options: raw.options,
    answer: raw.answer,
    explanation: raw.explanation,
    year: raw.year,
    marks: raw.marks,
    topic: raw.topic,
    image: raw.image,
  };
}

/** Title-cases a slug like "further-mathematics" → "Further Mathematics". */
function slugToTitle(slug: string): string {
  return slug
    .split('-')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Loads a single exam paper summary for a specific body + subject + year.
 *
 * Picks the first {@link MAX_SAMPLE_QUESTIONS} questions for that year from
 * the question bank and returns a fully shaped {@link SEOExamPaperSummary}
 * ready for schema generation and static page rendering.
 *
 * @example
 *   const paper = loadSEOExamPaper('jamb', 'physics', 2023);
 */
export function loadSEOExamPaper(
  body: ExamBodySlug,
  subjectSlug: string,
  year: number,
): SEOExamPaperSummary | null {
  const bundle = loadBundle(body, subjectSlug);
  if (!bundle || !Array.isArray(bundle.questions)) return null;

  const forYear = bundle.questions.filter((q) => q && q.year === year);
  if (forYear.length === 0) return null;

  const sample = forYear.slice(0, MAX_SAMPLE_QUESTIONS).map(toSampleQuestion);

  return {
    body,
    bodyTitle: BODY_TITLE_MAP[body],
    subjectSlug,
    subjectTitle: slugToTitle(subjectSlug),
    year,
    totalQuestions: forYear.length,
    // JAMB is 2 hrs; WAEC/NECO are typically 3 hrs - sensible defaults
    durationMinutes: body === 'jamb' ? 120 : 180,
    sampleQuestions: sample,
    canonicalUrl: `${SITE_URL}/practice/${body}/${subjectSlug}/${year}/`,
  };
}

/**
 * Returns a full subject-pillar summary for a given body + subject slug:
 * total banked questions, every available year, and syllabus theme list.
 *
 * @example
 *   const pillar = loadSEOSubjectPillar('jamb', 'mathematics');
 */
export function loadSEOSubjectPillar(
  body: ExamBodySlug,
  subjectSlug: string,
): SEOSubjectPillar | null {
  const bundle = loadBundle(body, subjectSlug);
  if (!bundle || !Array.isArray(bundle.questions)) return null;

  const yearSet = new Set<number>();
  const topicSet = new Set<string>();

  for (const q of bundle.questions) {
    if (q && q.year) yearSet.add(q.year);
    if (q && q.topic) topicSet.add(q.topic);
  }

  const availableYears = Array.from(yearSet).sort((a, b) => b - a); // newest first

  return {
    body,
    bodyTitle: BODY_TITLE_MAP[body],
    subjectSlug,
    subjectTitle: slugToTitle(subjectSlug),
    totalBankedQuestions: bundle.questions.length,
    availableYears,
    syllabusThemes: Array.from(topicSet).slice(0, 20), // top 20 themes
    canonicalUrl: `${SITE_URL}/practice/${body}/${subjectSlug}/`,
  };
}

/**
 * Returns every (body, subject, year) triple that has at least one question.
 * Used in `generateStaticParams()` for the dynamic SEO exam-paper pages.
 *
 * ⚠️  This scans *all* question bundles - run only at build time.
 */
export function getAvailableSEOExamParams(): Array<{
  body: ExamBodySlug;
  subject: string;
  year: string;
}> {
  const base = dataDir();
  if (!base) return [];

  const results: Array<{ body: ExamBodySlug; subject: string; year: string }> = [];

  for (const [bodySlug, dirName] of Object.entries(BODY_DIR_MAP) as [ExamBodySlug, string][]) {
    const dir = path.join(base, 'questions', dirName);
    if (!existsSync(dir)) continue;

    for (const file of readdirSync(dir)) {
      if (!file.endsWith('.json') || file.startsWith('_') || file.startsWith('.')) continue;
      const subjectSlug = file.replace(/\.json$/, '');

      try {
        const raw = JSON.parse(readFileSync(path.join(dir, file), 'utf8')) as RawQuestionBundle;
        if (!raw || !Array.isArray(raw.questions)) continue;
        const yearSet = new Set<number>();
        for (const q of raw.questions) {
          if (q && q.year) yearSet.add(q.year);
        }
        for (const year of yearSet) {
          results.push({ body: bodySlug, subject: subjectSlug, year: String(year) });
        }
      } catch {
        // skip malformed bundles silently - build must never crash
      }
    }
  }

  return results;
}

/**
 * Returns a list of all available subject slugs for a given exam body.
 * Useful for generating the subject-pillar index pages.
 */
export function getAvailableSEOSubjectParams(): Array<{
  body: ExamBodySlug;
  subject: string;
}> {
  const base = dataDir();
  if (!base) return [];

  const results: Array<{ body: ExamBodySlug; subject: string }> = [];

  for (const [bodySlug, dirName] of Object.entries(BODY_DIR_MAP) as [ExamBodySlug, string][]) {
    const dir = path.join(base, 'questions', dirName);
    if (!existsSync(dir)) continue;

    for (const file of readdirSync(dir)) {
      if (!file.endsWith('.json') || file.startsWith('_') || file.startsWith('.')) continue;
      const subjectSlug = file.replace(/\.json$/, '');
      try {
        const raw = JSON.parse(readFileSync(path.join(dir, file), 'utf8')) as RawQuestionBundle;
        if (!raw || !Array.isArray(raw.questions) || raw.questions.length === 0) continue;
        results.push({ body: bodySlug, subject: subjectSlug });
      } catch {
        // skip
      }
    }
  }

  return results;
}

// ─── NERDC Curriculum Schemes ─────────────────────────────────────────────────

/**
 * Loads a NERDC curriculum scheme for a given class level and subject.
 * The scheme is mapped to three terms by slicing the outline themes into thirds.
 *
 * @param classLevel  e.g. `'sss1'` | `'jss2'` | `'pry3'`
 * @param subjectSlug e.g. `'english-language'`
 * @param term        `'first-term'` | `'second-term'` | `'third-term'`
 */
export function loadSEOCurriculumScheme(
  classLevel: string,
  subjectSlug: string,
  term: SEOCurriculumScheme['term'],
): SEOCurriculumScheme | null {
  const base = dataDir();
  if (!base) return null;

  const schemeFile = NERDC_FILE_MAP[classLevel];
  if (!schemeFile) return null;

  const filePath = path.join(base, 'school-schemes', 'nerdc', schemeFile);
  if (!existsSync(filePath)) return null;

  let schemeData: RawNerdcSchemeFile;
  try {
    schemeData = JSON.parse(readFileSync(filePath, 'utf8')) as RawNerdcSchemeFile;
  } catch {
    return null;
  }

  // Find the matching document by normalising subject name → slug
  const doc = schemeData.documents.find(
    (d) => slugFromSubjectName(d.subject) === subjectSlug,
  );
  if (!doc) return null;

  const outline = doc.outline ?? [];

  // Partition themes into three equal-ish terms
  const termIndex = term === 'first-term' ? 0 : term === 'second-term' ? 1 : 2;
  const chunkSize = Math.ceil(outline.length / 3);
  const termOutline = outline.slice(termIndex * chunkSize, (termIndex + 1) * chunkSize);

  // Map each outline entry → SEOCurriculumWeek
  const weeks: SEOCurriculumWeek[] = termOutline.map((entry, i) => ({
    week: i + 1,
    topic: entry.theme,
    subtopics: (entry.topics ?? []).filter(Boolean),
  }));

  const subjectTitle = doc.subject;

  return {
    classLevel,
    classTitle: CLASS_TITLE_MAP[classLevel] ?? classLevel.toUpperCase(),
    subjectSlug,
    subjectTitle,
    term,
    termTitle: TERM_TITLE_MAP[term],
    weeks,
    canonicalUrl: `${SITE_URL}/curriculum/${classLevel}/${subjectSlug}/${term}/`,
  };
}

/**
 * Returns list of available curriculum classes with titles and document counts.
 */
export function getAvailableCurriculumClasses(): Array<{
  classLevel: string;
  classTitle: string;
  documentCount: number;
}> {
  const base = dataDir();
  if (!base) return [];

  const results: Array<{
    classLevel: string;
    classTitle: string;
    documentCount: number;
  }> = [];

  for (const [classLevel, schemeFile] of Object.entries(NERDC_FILE_MAP)) {
    const filePath = path.join(base, 'school-schemes', 'nerdc', schemeFile);
    if (!existsSync(filePath)) continue;

    try {
      const raw = JSON.parse(readFileSync(filePath, 'utf8')) as RawNerdcSchemeFile;
      results.push({
        classLevel,
        classTitle: CLASS_TITLE_MAP[classLevel] ?? classLevel.toUpperCase(),
        documentCount: raw.documents?.length ?? 0,
      });
    } catch {
      // skip
    }
  }

  return results;
}

/**
 * Returns class level static params for /curriculum/[class]
 */
export function getAvailableCurriculumClassParams(): Array<{ classLevel: string }> {
  return Object.keys(NERDC_FILE_MAP).map((classLevel) => ({ classLevel }));
}

/**
 * Returns subjects available for a given class level
 */
export function getCurriculumSubjectsForClass(classLevel: string): Array<{
  subjectSlug: string;
  subjectTitle: string;
  pages?: number;
}> {
  const base = dataDir();
  if (!base) return [];

  const schemeFile = NERDC_FILE_MAP[classLevel];
  if (!schemeFile) return [];

  const filePath = path.join(base, 'school-schemes', 'nerdc', schemeFile);
  if (!existsSync(filePath)) return [];

  try {
    const raw = JSON.parse(readFileSync(filePath, 'utf8')) as RawNerdcSchemeFile;
    return (raw.documents ?? []).map((doc) => ({
      subjectSlug: slugFromSubjectName(doc.subject),
      subjectTitle: doc.subject,
      pages: doc.pages,
    }));
  } catch {
    return [];
  }
}

/**
 * Returns every (classLevel, subject, term) triple available in the NERDC vault.
 * Used for `generateStaticParams()` in the curriculum scheme pages.
 */
export function getAllSEOCurriculumParams(): Array<{
  classLevel: string;
  subject: string;
  term: SEOCurriculumScheme['term'];
}> {
  const base = dataDir();
  if (!base) return [];

  const terms: SEOCurriculumScheme['term'][] = [
    'first-term',
    'second-term',
    'third-term',
  ];

  const results: Array<{
    classLevel: string;
    subject: string;
    term: SEOCurriculumScheme['term'];
  }> = [];

  for (const [classLevel, schemeFile] of Object.entries(NERDC_FILE_MAP)) {
    const filePath = path.join(base, 'school-schemes', 'nerdc', schemeFile);
    if (!existsSync(filePath)) continue;

    try {
      const raw = JSON.parse(readFileSync(filePath, 'utf8')) as RawNerdcSchemeFile;
      for (const doc of raw.documents) {
        const subjectSlug = slugFromSubjectName(doc.subject);
        for (const term of terms) {
          results.push({ classLevel, subject: subjectSlug, term });
        }
      }
    } catch {
      // skip unreadable files
    }
  }

  return results;
}

// ─── Internal util ────────────────────────────────────────────────────────────

/**
 * Converts a NERDC document subject name into a URL-safe slug.
 * e.g. "English Language (Core and Compulsory)" → "english-language"
 */
function slugFromSubjectName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\(.*?\)/g, '') // strip parenthetical suffixes
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
