import type { Metadata } from 'next';
import { loadLessons, loadSyllabi } from '@/lib/site-data';
import SearchClient, {
  type LessonHit,
  type TopicHit,
} from './search-client';

/** Bodies with shipped trees (server copy: the client lib is 'use client'). */
const BODIES: Array<[string, string]> = [
  ['jamb', 'JAMB'],
  ['waec', 'WAEC'],
  ['university-modules', 'University'],
];

/**
 * /search: one field over four shelves (packs, lessons, decks, topics).
 * Lessons and syllabus topics are baked at build time from data/ (the
 * static-export rule: content and site can never drift); packs and decks
 * come from the authed API at runtime. No new server surface, nothing to
 * attack.
 */

export const metadata: Metadata = {
  title: 'Search',
  description:
    'Search Renance for practice packs, lessons, flashcard decks and syllabus topics in one place.',
  robots: { index: false },
};

export default function SearchPage() {
  const lessons: LessonHit[] = loadLessons().map((l) => ({
    slug: l.slug,
    title: l.title,
    subject: l.subject,
    minutes: l.minutes,
    summary: l.summary,
  }));

  const bodies = new Map(BODIES);
  const topics: TopicHit[] = [];
  for (const tree of loadSyllabi()) {
    const label = bodies.get(tree.body) ?? tree.body;
    for (const subject of tree.subjects) {
      for (const section of subject.sections) {
        for (const topic of section.topics) {
          topics.push({
            body: tree.body,
            label,
            subject: subject.subject,
            topic,
          });
        }
      }
    }
  }

  return <SearchClient lessons={lessons} topics={topics} />;
}
