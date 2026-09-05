import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

/**
 * Build-time access to the committed data/ directory (same walk-up rule
 * as the exam route's manifestCodes). Static export bakes whatever the
 * commit contains, content and site can never drift between builds.
 */

export interface LessonBlock {
  type: 'p' | 'ul' | 'ol' | 'callout' | 'h3';
  text?: string;
  items?: string[];
}

export interface LessonSection {
  heading: string;
  blocks: LessonBlock[];
}

export interface Lesson {
  slug: string;
  title: string;
  subject?: string;
  body?: string;
  tags?: string[];
  minutes: number;
  summary: string;
  contentSha256?: string;
  sections: LessonSection[];
}

export interface SyllabusFile {
  body: string;
  subjects: Array<{
    subject: string;
    sections: Array<{ title: string; topics: string[] }>;
  }>;
}

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

export function loadLessons(): Lesson[] {
  const base = dataDir();
  if (!base) return [];
  const dir = path.join(base, 'lessons');
  if (!existsSync(dir)) return [];
  const out: Lesson[] = [];
  for (const name of readdirSync(dir)) {
    if (!name.endsWith('.json')) continue;
    try {
      out.push(JSON.parse(readFileSync(path.join(dir, name), 'utf8')) as Lesson);
    } catch {
      // a broken bundle refuses the API boot; the site build skips it
    }
  }
  return out.sort((a, b) => a.slug.localeCompare(b.slug));
}

export function loadLesson(slug: string): Lesson | null {
  const base = dataDir();
  if (!base) return null;
  const file = path.join(base, 'lessons', `${slug}.json`);
  if (!existsSync(file)) return null;
  try {
    return JSON.parse(readFileSync(file, 'utf8')) as Lesson;
  } catch {
    return null;
  }
}

export function loadSyllabi(): SyllabusFile[] {
  const base = dataDir();
  if (!base) return [];
  const dir = path.join(base, 'syllabus');
  if (!existsSync(dir)) return [];
  const out: SyllabusFile[] = [];
  for (const name of readdirSync(dir)) {
    if (!name.endsWith('.json')) continue;
    try {
      out.push(JSON.parse(readFileSync(path.join(dir, name), 'utf8')) as SyllabusFile);
    } catch {
      // skip unreadable syllabus at site-build time
    }
  }
  return out.sort((a, b) => a.body.localeCompare(b.body));
}

// ------------------------------------------------------- career (18)

export interface CareerScholarship {
  id: string;
  name: string;
  provider: string;
  level: string; // undergraduate | postgraduate | both
  coverage: string;
  window: string;
  tags: string[];
  url: string;
  eligibility: string;
}

export interface CareerPath {
  id: string;
  course: string;
  field: string;
  blurb: string;
  cutoff: string;
  subjects: string[];
  universities: string[];
  topics: string[];
}

export interface CareerData {
  scholarships: CareerScholarship[];
  paths: CareerPath[];
}

/**
 * The curated career bridge (ROADMAP #18), baked from data/career/*.json
 * at build time, exactly what GET /career serves the app. Null when the
 * install carries no career data.
 */
export function loadCareer(): CareerData | null {
  const base = dataDir();
  if (!base) return null;
  try {
    const scholarships = JSON.parse(
      readFileSync(path.join(base, 'career', 'scholarships.json'), 'utf8'),
    ) as { scholarships?: CareerScholarship[] };
    const paths = JSON.parse(
      readFileSync(path.join(base, 'career', 'paths.json'), 'utf8'),
    ) as { paths?: CareerPath[] };
    return {
      scholarships: scholarships.scholarships ?? [],
      paths: paths.paths ?? [],
    };
  } catch {
    return null;
  }
}
