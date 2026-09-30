import type { MetadataRoute } from 'next';

import { SITE_URL } from '@/lib/site-url';

// required for output: 'export'
export const dynamic = 'force-static';

/**
 * Phase 4 — Search Engine & AI Crawler Policy (Robots.txt)
 *
 * Configures crawl directives for Googlebot, Bingbot, and Generative AI engines
 * (GPTBot, PerplexityBot, ClaudeBot, Google-Extended) to optimize crawl budget
 * and maximize educational citations under GEO (Generative Engine Optimization).
 */
export default function robots(): MetadataRoute.Robots {
  const siteUrl = SITE_URL;

  // Private application routes that carry no indexable content for crawlers
  const privateAppRoutes = [
    '/console/',
    '/api/',
    '/dashboard/',
    '/settings/',
    '/profile/',
    '/saved/',
    '/notifications/',
    '/arena/match/',
    '/review/',
    '/school/attendance/',
    '/school/fees/',
    '/school/idcards/',
    '/school/results/',
    '/school/setup/',
  ];

  return {
    rules: [
      // Standard search engine crawlers (Google, Bing, Yahoo, Yandex)
      {
        userAgent: '*',
        allow: [
          '/',
          '/practice/',
          '/curriculum/',
          '/university/',
          '/lessons/',
          '/subjects/',
          '/study-past-questions/',
          '/career-bridge/',
          '/faq/',
        ],
        disallow: privateAppRoutes,
      },
      // OpenAI ChatGPT / SearchGPT bot (GEO citation optimization)
      {
        userAgent: 'GPTBot',
        allow: [
          '/',
          '/practice/',
          '/curriculum/',
          '/university/',
          '/lessons/',
          '/study-past-questions/',
        ],
        disallow: privateAppRoutes,
      },
      // Perplexity AI search crawler
      {
        userAgent: 'PerplexityBot',
        allow: [
          '/',
          '/practice/',
          '/curriculum/',
          '/university/',
          '/lessons/',
          '/study-past-questions/',
        ],
        disallow: privateAppRoutes,
      },
      // Anthropic Claude search bot
      {
        userAgent: 'ClaudeBot',
        allow: [
          '/',
          '/practice/',
          '/curriculum/',
          '/university/',
          '/lessons/',
          '/study-past-questions/',
        ],
        disallow: privateAppRoutes,
      },
      // Google Gemini / Vertex AI crawler
      {
        userAgent: 'Google-Extended',
        allow: [
          '/',
          '/practice/',
          '/curriculum/',
          '/university/',
          '/lessons/',
          '/study-past-questions/',
        ],
        disallow: privateAppRoutes,
      },
      // Apple Intelligence search bot
      {
        userAgent: 'Applebot-Extended',
        allow: [
          '/',
          '/practice/',
          '/curriculum/',
          '/university/',
          '/lessons/',
          '/study-past-questions/',
        ],
        disallow: privateAppRoutes,
      },
    ],
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
