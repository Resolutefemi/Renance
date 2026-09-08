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
import { loadSchools, loadCatalog } from '@/lib/university-data';

import { SITE_URL } from '@/lib/site-url';

const PUBLIC_ROUTES: Array<{ path: string; priority: number; freq: 'daily' | 'weekly' | 'monthly' }> = [
  { path: '/', priority: 1.0, freq: 'weekly' },
  { path: '/lessons/', priority: 0.9, freq: 'daily' },
  { path: '/subjects/', priority: 0.9, freq: 'weekly' },
  { path: '/university/', priority: 0.9, freq: 'weekly' },
  { path: '/career-bridge/', priority: 0.8, freq: 'weekly' },
  { path: '/faq/', priority: 0.7, freq: 'monthly' },
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
  // The university desk is public per school + course — the same commit
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
  return [...statics, ...lessonEntries, ...schoolEntries];
}
