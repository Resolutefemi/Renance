import type { MetadataRoute } from 'next';

// required for output: 'export'
export const dynamic = 'force-static';

/**
 * Blocks private surfaces (admin console) from indexing while keeping all
 * public marketing/product pages fully crawlable.
 * Rules reference: docs/seo-checklist.md
 */
export default function robots(): MetadataRoute.Robots {
  const siteUrl =
    process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';
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
