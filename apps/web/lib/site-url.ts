/**
 * Canonical site origin, normalized: no trailing slash, so every
 * canonical/OG/sitemap URL composes cleanly. NEXT_PUBLIC_SITE_URL may
 * be configured with or without a trailing slash (and any letter case
 * the founder typed), the deploy must not emit `Renance//lessons/`.
 */
const RAW =
  process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';

export const SITE_URL = RAW.replace(/\/+$/, '');
