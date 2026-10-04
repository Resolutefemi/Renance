/**
 * The one true social preview card.
 *
 * Every page that declares its own `openGraph` metadata REPLACES the root
 * layout's object wholesale (Next.js merges at the field level, not
 * per-property inside openGraph). That is how og:image silently vanished
 * from every page that set `openGraph: { url }` - the layout's images
 * array was dropped on the floor. This module is the fix: pages import
 * `OG_IMAGES` and spread it into their openGraph, so the card ships on
 * every shareable URL in the product.
 */

export const OG_IMAGE = {
  url: '/og.jpg',
  width: 1200,
  height: 630,
  alt: 'Renance - 235,110+ free JAMB, WAEC and NECO past questions with worked explanations, server-graded CBT practice and Renance AI.',
} as const;

export const OG_IMAGES = [OG_IMAGE];
