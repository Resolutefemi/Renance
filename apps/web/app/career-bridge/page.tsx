import type { Metadata } from 'next';
import { loadCareer } from '@/lib/site-data';
import { SITE_URL } from '@/lib/site-url';
import CareerClient from './career-client';

/**
 * /career-bridge, the curated career bridge (ROADMAP #18). The catalogue
 * is baked from data/career/*.json at build time, the same files the API
 * serves the app, so the page is crawlable, cacheable and free: honest
 * scholarship windows and JAMB course paths linking real syllabus topics.
 */

export const dynamic = 'force-static';

export const metadata: Metadata = {
  title: 'Scholarships & course paths for Nigerian students | Renance',
  description:
    'Curated scholarships for Nigerian undergraduates with honest application windows, plus the JAMB course explorer: subject combinations, typical competitive cut-offs and the syllabus topics that decide admission.',
  alternates: { canonical: '/career-bridge/' },
  openGraph: {
    title: 'Scholarships & course paths for Nigerian students | Renance',
    description:
      'Curated Nigerian scholarships and the JAMB course cut-off explorer, mapped to the syllabus topics you study.',
    url: `${SITE_URL}/career-bridge/`,
  },
};

export default function CareerBridgePage() {
  return <CareerClient data={loadCareer()} />;
}
