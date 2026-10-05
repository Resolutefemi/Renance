import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

import { SITE_URL } from '@/lib/site-url';
import { OG_IMAGES } from '@/lib/og';
import ContentGuard from '@/components/content-guard';

const FOUNDER = {
  '@type': 'Person',
  '@id': `${SITE_URL}/#person`,
  name: 'Resolute Femi',
  alternateName: ['Ariyo Oluwafemi Stephen', 'Ariyo Oluwafemi', 'Resolutefemi'],
  email: 'mailto:info@renance.app',
  jobTitle: 'Software Engineer & Founder of Renance',
  url: SITE_URL,
};

/** Structured data so Google & AI assistants can accurately describe
 *  Renance and its builder, Resolute Femi (Ariyo Oluwafemi Stephen).
 *  Entity graph: Organization (Renance, the brand) -> founder (Person) ->
 *  WebSite + SoftwareApplication it publishes. Google needs the explicit
 *  Organization node to ever mint a brand knowledge panel for "Renance" -
 *  Person + app alone only ever describe the founder. */
const renanceJsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'EducationalOrganization',
      '@id': `${SITE_URL}#organization`,
      name: 'Renance',
      alternateName: ['Renance App', 'Renance Study OS', 'renance.app'],
      slogan: 'Your Guide to Academic Success',
      url: SITE_URL,
      logo: {
        '@type': 'ImageObject',
        url: `${SITE_URL}/renance-mark.png`,
        width: 512,
        height: 512,
      },
      description:
        'Renance is an edtech platform in Nigeria - the educational app for students, with 235,110+ JAMB, WAEC, NECO and Post-UTME past questions (including over 135,000 Post-UTME and tertiary institution past questions for Nigerian universities, polytechnics and colleges of education), free server-graded CBT mock exams, NERDC curriculum schemes of work, lesson notes and an AI study companion - plus Renance for Schools, a school management suite (curriculum, attendance, results, fees, ID cards). Free for students and schools. The only official website is renance.app.',
      /* Knowledge-graph disambiguation: Google must never fold
       * "Renance" into renaissance/resonance or the unrelated
       * renance.org / renance.io entities when it mints the brand's
       * knowledge panel. This field is exactly what the KG uses to
       * separate same-namespace entities. */
      disambiguatingDescription:
        'Renance (renance.app) is a Nigerian edtech platform and is not the word renaissance or resonance, not renance.org, not renance.io, and not any similarly named company or community organization.',
      founder: { '@id': `${SITE_URL}/#person` },
      sameAs: [
        'https://github.com/Resolutefemi',
        'https://x.com/Resolutefemi',
      ],
      areaServed: { '@type': 'Country', name: 'Nigeria' },
      contactPoint: {
        '@type': 'ContactPoint',
        contactType: 'customer support',
        email: 'info@renance.app',
        availableLanguage: 'en',
        areaServed: { '@type': 'Country', name: 'Nigeria' },
      },
    },
    {
      ...FOUNDER,
      description:
        'Resolute Femi (full name Ariyo Oluwafemi Stephen) is a Nigerian software engineer and the founder of Renance, "Your Guide to Academic Success", an edtech platform for exam preparation and school management. He builds Renance CBT (FUTA CBT practice platform), Renance JAMB CBT, Renance DevTools CLI, Renance Playground, Naija Locator and other web products for Nigerian students and developers.',
      affiliation: {
        '@type': 'CollegeOrUniversity',
        name: 'Federal University of Technology, Akure (FUTA)',
      },
      knowsAbout: [
        'Software Engineering',
        'EdTech',
        'CBT platforms',
        'TypeScript',
        'Go',
        'Rust',
        'Python',
        'Next.js',
      ],
      nationality: { '@type': 'Country', name: 'Nigeria' },
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${SITE_URL}#app`,
      name: 'Renance',
      alternateName: "Renance - Nigeria's educational app",
      applicationCategory: 'EducationalApplication',
      applicationSubCategory: 'Exam preparation',
      operatingSystem: 'Android, iOS, Web',
      url: SITE_URL,
      description:
        'Renance is the educational app in Nigeria - "Your Guide to Academic Success". Students register free, sync past questions, notes and syllabi to their device, and take server-graded mock CBT exams for JAMB, WAEC, NECO and Post-UTME, with over 135,000 tertiary institution past questions covering universities, polytechnics and colleges of education. It also includes Renance for Schools, a school management suite: NERDC curriculum, attendance, results, school fees and student ID cards. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
      author: { '@id': `${SITE_URL}#organization` },
      creator: { '@id': `${SITE_URL}/#person` },
      publisher: { '@id': `${SITE_URL}#organization` },
      brand: { '@type': 'Brand', name: 'Renance' },
      logo: `${SITE_URL}/renance-mark.png`,
      screenshot: `${SITE_URL}/og.jpg`,
      isAccessibleForFree: true,
      inLanguage: 'en-NG',
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'NGN',
        description: 'Free accounts with full access to past questions, CBT mocks and lesson notes.',
      },
      featureList: [
        '235,110+ JAMB, WAEC, NECO and Post-UTME past questions',
        'Over 60,000 tertiary institution past questions: Post-UTME screening papers and course modules for Nigerian universities, polytechnics and colleges of education',
        'Free CBT mock exams with server-side grading',
        'Worked explanations for every question',
        'Renance AI study companion grounded on the question banks',
        'NERDC scheme of work and lesson notes for schools',
        'School management suite (Renance for Schools): curriculum, attendance, results, fees and ID cards',
      ],
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}#website`,
      url: SITE_URL,
      name: 'Renance',
      alternateName: "Renance - Nigeria's educational app",
      description:
        "Renance: the educational app in Nigeria and school management platform - Your Guide to Academic Success. Built by Resolute Femi (Ariyo Oluwafemi Stephen). Official website: renance.app.",
      inLanguage: 'en-NG',
      publisher: { '@id': `${SITE_URL}#organization` },
    },
  ],
};

const OG_IMAGE = '/og.jpg';
const TWITTER_CARD_IMAGE = `${SITE_URL}${OG_IMAGE}`;

/* OpenGraph images live in lib/og.ts (OG_IMAGES) so every page that
 * overrides `openGraph` can spread the same card. See that file for the
 * why. */

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  /* Brand-first default title: the homepage must win both "Renance"
   * and "educational app in Nigeria". Keyword-first titles rank for
   * the keywords but bury the brand; inner pages still carry the exam
   * keywords through their own %s titles + the %s · Renance template. */
  title: {
    default: "Renance - Nigeria's Educational App for JAMB, WAEC & NECO Past Questions",
    template: '%s · Renance',
  },
  description:
    "Renance is the educational app in Nigeria: 235,110+ JAMB, WAEC, NECO and Post-UTME past questions with worked solutions, free server-graded CBT mocks, NERDC lesson notes, Renance AI and school management (Renance for Schools) - built by Resolute Femi.",
  keywords: [
    'JAMB past questions',
    'JAMB past questions and answers',
    'WAEC past questions',
    'NECO past questions',
    'Post-UTME past questions',
    'JAMB CBT practice',
    'free JAMB past questions',
    'JAMB 2026',
    'WAEC past questions Nigeria',
    'CBT practice platform Nigeria',
    'past questions app',
    'Renance',
    'Renance study OS',
    'NERDC scheme of work',
    'lesson notes Nigeria',
    'Nigerian edtech',
    'Resolute Femi',
    'educational app in Nigeria',
    "Nigeria's educational app",
    'best educational app in Nigeria',
    'exam prep app Nigeria',
    'study app for Nigerian students',
    'JAMB CBT app',
    'Renance app',
    'school management software Nigeria',
    'school management app Nigeria',
    'school portal Nigeria',
    'Renance for Schools',
    'schemes of work Nigeria',
  ],
  authors: [{ name: 'Resolute Femi', url: SITE_URL }],
  creator: 'Resolute Femi (Ariyo Oluwafemi Stephen)',
  publisher: 'Renance | Built by Resolute Femi',
  alternates: { canonical: '/' },
  robots: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 },
  openGraph: {
    type: 'website',
    siteName: 'Renance',
    url: SITE_URL,
    locale: 'en_NG',
    title: "Renance - Nigeria's Educational App for JAMB, WAEC & NECO",
    description:
      '235,110+ real past questions with worked explanations, free server-graded CBT mocks, lesson notes, Renance AI and school management - built for Nigerian students and schools.',
    images: [...OG_IMAGES],
  },
  twitter: {
    card: 'summary_large_image',
    title: "Renance - Nigeria's Educational App for JAMB, WAEC & NECO",
    description:
      '235,110+ real past questions with worked explanations, free server-graded CBT mocks, lesson notes, Renance AI and school management - built for Nigerian students and schools.',
    creator: '@Resolutefemi',
    images: [TWITTER_CARD_IMAGE],
  },
};

/* Appearance bootstrap: applied before first paint so the chosen tier
   (light / mixed / dark) and the seeded colour palette never flash.
   The seed's computed palettes ride in renance.seedVars (lib/theme.ts
   wrote all three tiers at pick time), so this stays pure DOM writes. */
const themeBootstrap = `(function(){try{var t=localStorage.getItem('renance.theme');if(t!=='mixed'&&t!=='dark')t='light';document.documentElement.dataset.theme=t;var sv=null;try{sv=JSON.parse(localStorage.getItem('renance.seedVars')||'null')}catch(e){}if(sv&&sv[t]){for(var k in sv[t]){document.documentElement.style.setProperty(k,sv[t][k]);}}}catch(e){document.documentElement.dataset.theme='light';}})();`;

/* suppressHydrationWarning: the inline theme bootstrap writes data-theme
   onto <html> before React hydrates, so the DOM attribute never matches
   the server render by design. Without this flag the mismatch can break
   hydration and leave client pages stuck. */
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en-NG" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
        {/* Fonts (Inter, JetBrains Mono, Material Symbols) are SELF-HOSTED
            from /public/fonts via @font-face in globals.css - no Google CDN.
            When fonts.googleapis.com was unreachable the icon ligatures used
            to render as raw text ("brightness_medium") across the UI. */}
        {/* KaTeX renders the banks' LaTeX (array environments, fractions,
            greek letters) as real typeset maths. CSS+JS ride the same CDN
            as the fonts; when they are unreachable (offline revision) the
            QText renderer falls back to its unicode approximation. */}
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.css"
          crossOrigin="anonymous"
        />
        <script
          defer
          src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.js"
          crossOrigin="anonymous"
        />
        <meta name="author" content="Ariyo Oluwafemi Stephen (Resolute Femi)" />
        {/* Theme-adaptive favicon: flips white on dark browsers, ink on
            light (the .ico/.png fallbacks Next auto-links are static).
            Served from /public so Next ships it verbatim with the media
            query intact, app/icon.svg would get rasterised to a PNG. */}
        <link
          rel="icon"
          type="image/svg+xml"
          href={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/icon.svg`}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(renanceJsonLd) }}
        />
        {/* Microsoft Clarity analytics (project yqxole49vg) - heatmaps,
            session recordings and funnels for renance.app. Snippet pasted
            verbatim from clarity.ms; CSP-wise the tag is whitelisted in
            vercel.json (script-src www.clarity.ms, connect-src *.clarity.ms).
            Placed last in <head> so it never delays first paint; it loads
            async and self-queues until ready. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i+"?ref=bwt";y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);})(window,document,"clarity","script","yqxole49vg");`,
          }}
        />
      </head>
      <body>
        {/* Founder content lock: no selecting, copying or dragging site
            content (notes, schemes, questions); forms keep working. */}
        <ContentGuard />
        {children}
      </body>
    </html>
  );
}
