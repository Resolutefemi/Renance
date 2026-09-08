import { Suspense } from 'react';
import ExamClient from '../[code]/exam-client';

/**
 * Static-export-safe route for COMPOSED papers (jamb-mock / jamb-custom
 * / jamb-pick with ~params).
 *
 * `output: 'export'` bakes /exams/<code> pages only for the codes
 * enumerated at build time, so a year-pinned mock code like
 * `jamb-mock-english-biology-chemistry-physics~y=2024` had no page —
 * the candidate hit a 404 and bounced back out of the app the moment a
 * specific year (or any custom/pick option) was chosen. Composed codes
 * are infinite, so they can never be enumerated: they resolve through
 * THIS static page with the code in the query string instead
 * (?code=<paper-code>), which every deep link builds via examHref().
 */
export default function ComposedPaperRoute() {
  return (
    <Suspense fallback={null}>
      <ExamClient code="" />
    </Suspense>
  );
}
