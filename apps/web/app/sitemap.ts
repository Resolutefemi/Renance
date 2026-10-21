import type { MetadataRoute } from 'next';

// required for output: 'export'
export const dynamic = 'force-static';

/**
 * Single source of truth for public routes. New public pages MUST register
 * here (reviewer checklist item in docs/seo-checklist.md). Lesson slugs
 * come from the committed data/lessons bundles so new content ships in
 * the same commit as its sitemap entry, so the sets can never drift.
 */
import { loadLessons } from '@/lib/site-data';
import { GUIDES } from '@/lib/guides';
import { loadSchools, loadCatalog } from '@/lib/university-data';
import {
  getAllSEOCurriculumParams,
  getAvailableCurriculumClassParams,
  getAvailableSEOExamParams,
  getAvailableSEOSubjectParams,
} from '@/lib/seo-data';

import { SITE_URL } from '@/lib/site-url';

const PUBLIC_ROUTES: Array<{ path: string; priority: number; freq: 'daily' | 'weekly' | 'monthly' }> = [
  { path: '/', priority: 1.0, freq: 'weekly' },
  { path: '/practice/', priority: 0.98, freq: 'weekly' },
  { path: '/lessons/', priority: 0.9, freq: 'daily' },
  { path: '/subjects/', priority: 0.9, freq: 'weekly' },
  { path: '/university/', priority: 0.9, freq: 'weekly' },
  { path: '/curriculum/', priority: 0.9, freq: 'weekly' },
  { path: '/syllabus/', priority: 0.8, freq: 'weekly' },
  { path: '/packs/', priority: 0.8, freq: 'weekly' },
  { path: '/post-utme/', priority: 0.8, freq: 'weekly' },
  { path: '/pricing/', priority: 0.7, freq: 'monthly' },
  { path: '/study-past-questions/', priority: 0.8, freq: 'weekly' },
  { path: '/about/', priority: 0.8, freq: 'monthly' },
  { path: '/guides/', priority: 0.85, freq: 'weekly' },
  { path: '/for-schools/', priority: 0.9, freq: 'weekly' },
  { path: '/educational-app-in-nigeria/', priority: 0.9, freq: 'weekly' },
  { path: '/faq/', priority: 0.7, freq: 'monthly' },
  { path: '/privacy/', priority: 0.5, freq: 'monthly' },
  { path: '/delete-account/', priority: 0.5, freq: 'monthly' },
  { path: '/login/', priority: 0.4, freq: 'monthly' },
  { path: '/register/', priority: 0.6, freq: 'monthly' },
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  const statics = PUBLIC_ROUTES.map((r) => ({
    url: `${SITE_URL}${r.path}`,
    lastModified,
    changeFrequency: r.freq,
    priority: r.priority,
  }));
  const lessonEntries = loadLessons().map((l) => ({
    url: `${SITE_URL}/lessons/${l.slug}/`,
    lastModified,
    changeFrequency: 'weekly' as const,
    priority: 0.8,
  }));
  // Guides ship in the same commit as lib/guides.ts, so the sitemap can
  // never drift from the article pages.
  const guideEntries = GUIDES.map((g) => ({
    url: `${SITE_URL}/guides/${g.slug}/`,
    lastModified: new Date(g.updated),
    changeFrequency: 'monthly' as const,
    priority: 0.85,
  }));
  // The university desk is public per school + course, the same commit
  // that wraps a school's content ships its sitemap entries.
  const schoolEntries = loadSchools()
    .filter((s) => s.live)
    .flatMap((s) => {
      const catalog = loadCatalog(s.slug);
      const courseEntries = (catalog?.courses ?? [])
        .filter((c) => c.bank)
        .map((c) => ({
          url: `${SITE_URL}/university/${s.slug}/${c.slug}/`,
          lastModified,
          changeFrequency: 'weekly' as const,
          priority: 0.8,
        }));
      return [
        {
          url: `${SITE_URL}/university/${s.slug}/`,
          lastModified,
          changeFrequency: 'weekly' as const,
          priority: 0.8,
        },
        ...courseEntries,
      ];
    });
  // ── Phase 2: /practice/* SEO routes ──────────────────────────────────────
  // (The /practice/ root hub rides in PUBLIC_ROUTES.)

  // One entry per exam body (/practice/jamb/, /practice/waec/, etc.)
  const bodyEntries = Array.from(
    new Set(getAvailableSEOSubjectParams().map((p) => p.body)),
  ).map((body) => ({
    url: `${SITE_URL}/practice/${body}/`,
    lastModified,
    changeFrequency: 'weekly' as const,
    priority: 0.9,
  }));

  // One entry per subject pillar (/practice/jamb/physics/, etc.)
  const subjectEntries = getAvailableSEOSubjectParams().map(({ body, subject }) => ({
    url: `${SITE_URL}/practice/${body}/${subject}/`,
    lastModified,
    changeFrequency: 'weekly' as const,
    priority: 0.85,
  }));

  // One entry per exam-paper year (/practice/jamb/physics/2023/, etc.)
  const paperEntries = getAvailableSEOExamParams().map(({ body, subject, year }) => ({
    url: `${SITE_URL}/practice/${body}/${subject}/${year}/`,
    lastModified,
    changeFrequency: 'monthly' as const,
    priority: 0.8,
  }));

  // ── Phase 3: /curriculum/* NERDC routes ──────────────────────────────────
  // NOTE: /curriculum/ itself is already in PUBLIC_ROUTES above - do NOT
  // re-declare a curriculumRoot entry here; it once duplicated the URL and
  // Search Console flagged the sitemap for it.
  const curriculumClassEntries = getAvailableCurriculumClassParams().map(({ classLevel }) => ({
    url: `${SITE_URL}/curriculum/${classLevel}/`,
    lastModified,
    changeFrequency: 'weekly' as const,
    priority: 0.85,
  }));

  const curriculumTermEntries = getAllSEOCurriculumParams().map(
    ({ classLevel, subject, term }) => ({
      url: `${SITE_URL}/curriculum/${classLevel}/${subject}/${term}/`,
      lastModified,
      changeFrequency: 'monthly' as const,
      priority: 0.8,
    }),
  );

  return [
    ...statics,
    ...lessonEntries,
    ...guideEntries,
    ...schoolEntries,
    ...bodyEntries,
    ...subjectEntries,
    ...paperEntries,
    ...curriculumClassEntries,
    ...curriculumTermEntries,
  ];
}
