import type { MetadataRoute } from 'next';

// required for output: 'export'
export const dynamic = 'force-static';

/**
 * Single source of truth for public routes. New public pages MUST register
 * here (reviewer checklist item in docs/seo-checklist.md).
 */
const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';

const PUBLIC_ROUTES: Array<{ path: string; priority: number; freq: 'daily' | 'weekly' | 'monthly' }> = [
  { path: '/', priority: 1.0, freq: 'weekly' },
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  return PUBLIC_ROUTES.map((r) => ({
    url: `${SITE_URL}${r.path}`,
    lastModified,
    changeFrequency: r.freq,
    priority: r.priority,
  }));
}
