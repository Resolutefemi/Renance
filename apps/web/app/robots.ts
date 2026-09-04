import type { MetadataRoute } from 'next';

import { SITE_URL } from '@/lib/site-url';

// required for output: 'export'
export const dynamic = 'force-static';

/**
 * Blocks private surfaces (admin console) from indexing while keeping all
 * public marketing/product pages fully crawlable.
 * Rules reference: docs/seo-checklist.md
 */
export default function robots(): MetadataRoute.Robots {
  const siteUrl = SITE_URL;
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/console/', '/api/'],
      },
    ],
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
