/**
 * The one true social preview card + the one true description.
 *
 * Every page that declares its own `openGraph` metadata REPLACES the root
 * layout's object wholesale (Next.js merges at the field level, not
 * per-property inside openGraph). That is how og:image silently vanished
 * from every page that set `openGraph: { url }` - the layout's images
 * array was dropped on the floor. This module is the fix: pages import
 * OG_IMAGES / RENANCE_DESCRIPTION and spread them into their metadata,
 * so the card and the founder's words ship on every shareable URL.
 *
 * The card file is versioned (og-2026.jpg): WhatsApp, Facebook, X,
 * Telegram and iMessage cache og:image by EXACT URL for months, so a
 * new image under the same /og.jpg path would keep showing the old art.
 * Bump the filename whenever the card changes; /og.jpg and /og.png are
 * refreshed alongside for every link that already points at them.
 */

/** The founder's positioning copy (2026-10-16) - the canonical
 *  description for the landing page, og:description and twitter:
 *  description. One source of truth; edit here only. */
export const RENANCE_DESCRIPTION =
  "Renance is an educational app in Nigeria built for JAMB, WAEC, NECO, and tertiary institution success. Learn exam-ready courses step by step, drill 90,000+ JAMB, NECO, and WAEC past questions from 1978 to 2026, and practice over 200,000 Post-UTME and tertiary institution course questions with server-graded CBT mocks. Stay engaged and motivated with daily quests, competitive leagues, a live arena, and a community feed that celebrates your wins. For institutions, Renance provides a comprehensive school portal to seamlessly manage syllabuses, lecture notes, attendance, exam results, and fee payments. Available for free on Android, iOS, Windows, macOS, and the web.";

export const OG_IMAGE = {
  url: '/og-2026.jpg',
  width: 1200,
  height: 630,
  alt: 'Renance - the educational app in Nigeria: 90,000+ JAMB, WAEC and NECO past questions from 1978 to 2026, over 200,000 Post-UTME and tertiary institution course questions, server-graded CBT mocks, daily quests, leagues, a live arena and a community feed - free on Android, iOS, Windows, macOS and the web.',
} as const;

export const OG_IMAGES = [OG_IMAGE];
