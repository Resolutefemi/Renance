import type { Metadata } from 'next';
import { loadLessons } from '@/lib/site-data';
import { NotesClient } from './notes-client';

/**
 * /notes, the student's study-notes shelf, scoped to who they are.
 * A FUTA undergraduate sees the FUTA course PDFs and course notes; a
 * JAMB/WAEC/NECO candidate sees the exam notes for their subjects.
 * The public, crawlable lesson library stays at /lessons; this page is
 * the personal entry point every desk's Notes tile opens.
 */

export const dynamic = 'force-static';

export const metadata: Metadata = {
  title: 'Notes | your school and exam study notes',
  description:
    'Study notes scoped to you: course PDFs and lecture materials for your university courses, exam-focused notes for your JAMB, WAEC or NECO subjects.',
  alternates: { canonical: '/notes/' },
};

export default function NotesPage() {
  const lessons = loadLessons().map((l) => ({
    slug: l.slug,
    title: l.title,
    subject: l.subject ?? '',
    body: l.body ?? '',
    summary: l.summary,
    minutes: l.minutes,
  }));
  return <NotesClient lessons={lessons} />;
}
