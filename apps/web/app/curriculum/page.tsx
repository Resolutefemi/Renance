import type { Metadata } from 'next';
import { CurriculumClient } from './curriculum-client';

/**
 * /curriculum: the national curriculum bank, straight from the
 * codebase corpus. Nursery through SSS 3, every subject's week-by-week
 * scheme of work with the lesson note sitting under its week. Public,
 * crawlable, and readable signed-out because the whole bank ships in
 * the static export.
 */

export const metadata: Metadata = {
  title: 'Curriculum bank | scheme of work and lesson notes for every class',
  description:
    'The NERDC-aligned scheme of work and lesson notes from Nursery 1 to SSS 3. Pick a class, pick a subject, read the weekly scheme and the full note under every topic.',
  alternates: { canonical: '/curriculum/' },
};

export default function CurriculumPage() {
  return <CurriculumClient />;
}
