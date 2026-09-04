'use client';

/**
 * Syllabus map types (ROADMAP #4), mirrors GET /syllabus/{body}: the
 * curriculum tree of one exam body overlaid with the student's own SM-2
 * mastery state (the same signal that powers the review queue and the
 * adaptive ordering).
 */

export interface SyllabusTopic {
  topic: string;
  questions: number;
  seen: boolean;
  lastCorrect: number;
  lastTotal: number;
  accuracy: number; // last paper's accuracy, 0 when unseen
  status: 'unseen' | 'learning' | 'mastered';
  dueOn?: string;
  weakness: number;
}

export interface SyllabusSection {
  title: string;
  mastery: number; // 0..1 mean of per-topic mastery
  topics: SyllabusTopic[];
}

export interface SyllabusSubject {
  subject: string;
  sections: SyllabusSection[];
}

export interface SyllabusStats {
  topics: number;
  mastered: number;
  learning: number;
  unseen: number;
  due: number;
}

export interface SyllabusTree {
  body: string;
  stats: SyllabusStats;
  weakest: SyllabusTopic[];
  subjects: SyllabusSubject[];
}

/** Bodies with shipped trees, the body pills on the map. */
export const SYLLABUS_BODIES: Array<{ slug: string; label: string }> = [
  { slug: 'jamb', label: 'JAMB' },
  { slug: 'waec', label: 'WAEC' },
  { slug: 'university-modules', label: 'University' },
];

/** "University Modules" -> "university-modules" (matches cbtdata.Slug). */
export function bodySlug(body: string): string {
  return body.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

/** 0 = red-ish urgency, 1 = fully covered. Drives the header ring. */
export function masteryPct(tree: SyllabusTree): number {
  let learningSum = 0;
  for (const s of tree.subjects) {
    for (const sec of s.sections) {
      for (const t of sec.topics) {
        if (t.status === 'learning') learningSum += t.accuracy;
      }
    }
  }
  if (!tree.stats.topics) return 0;
  return Math.round(((tree.stats.mastered + learningSum) / tree.stats.topics) * 100);
}
