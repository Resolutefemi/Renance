import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

/**
 * Build-time access to the university layer of the committed data/
 * directory (same walk-up rule as site-data). The university desk is
 * per-school: every school shares ONE interface, while courses, question
 * banks and PDFs are wrapped per school from data/university/.
 */

export interface School {
  slug: string;
  short: string;
  name: string;
  type: 'university' | 'polytechnic' | 'college-of-education';
  state: string;
  /** true when the school ships a live question library in this repo. */
  live: boolean;
}

export interface UniversityCourse {
  slug: string;
  /** Display code, e.g. "COS 101". */
  code: string;
  /** Course title when the source portal names one, else null. */
  title: string | null;
  semester: 1 | 2;
  /** Material icon name — the university desk's own icon set. */
  icon: string;
  /** Bank pack code when the course ships questions, else null. */
  bank: string | null;
  questionCount: number;
  /** Web path of the course's PDF material, when one ships. */
  pdf: string | null;
}

export interface SchoolCatalog {
  school: string;
  name: string;
  short: string;
  courses: UniversityCourse[];
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

export function loadSchools(): School[] {
  const base = dataDir();
  if (!base) return [];
  const file = path.join(base, 'university', 'schools.json');
  if (!existsSync(file)) return [];
  const parsed = JSON.parse(readFileSync(file, 'utf8')) as { schools: School[] };
  return parsed.schools ?? [];
}

export function loadSchool(slug: string): School | null {
  return loadSchools().find((s) => s.slug === slug) ?? null;
}

export function loadCatalog(school: string): SchoolCatalog | null {
  const base = dataDir();
  if (!base) return null;
  const file = path.join(base, 'university', 'courses', `${school}.json`);
  if (!existsSync(file)) return null;
  return JSON.parse(readFileSync(file, 'utf8')) as SchoolCatalog;
}
