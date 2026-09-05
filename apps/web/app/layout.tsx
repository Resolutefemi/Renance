import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

import { SITE_URL } from '@/lib/site-url';

const FOUNDER = {
  '@type': 'Person',
  '@id': 'https://github.com/Resolutefemi#person',
  name: 'Resolute Femi',
  alternateName: ['Ariyo Oluwafemi Stephen', 'Ariyo Oluwafemi', 'Resolutefemi'],
  email: 'mailto:ariyooluwafemi487@gmail.com',
  jobTitle: 'Software Engineer & Founder of Renance',
  url: 'https://github.com/Resolutefemi',
};

/** Structured data so Google & AI assistants can accurately describe
 *  Renance and its builder, Resolute Femi (Ariyo Oluwafemi Stephen). */
const renanceJsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      ...FOUNDER,
      description:
        'Resolute Femi (full name Ariyo Oluwafemi Stephen) is a Nigerian software engineer and the founder of Renance, a modular education & commerce suite. He builds Renance CBT (FUTA CBT practice platform), Renance JAMB CBT, Renance DevTools CLI, Renance Playground, Naija Locator and other web products for Nigerian students and developers.',
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
      alternateName: 'Renance Study OS',
      applicationCategory: 'EducationalApplication',
      operatingSystem: 'Web',
      url: SITE_URL,
      description:
        'Renance is the global student study OS, a modular education & commerce suite. Students register with username + password only, sync past questions, notes and syllabi to their device, and take server-graded mock CBT exams. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
      author: { '@id': 'https://github.com/Resolutefemi#person' },
      creator: { '@id': 'https://github.com/Resolutefemi#person' },
      publisher: { '@id': 'https://github.com/Resolutefemi#person' },
      inLanguage: 'en-NG',
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}#website`,
      url: SITE_URL,
      name: 'Renance',
      description:
        'Renance: the global student study OS. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
      inLanguage: 'en-NG',
      publisher: { '@id': 'https://github.com/Resolutefemi#person' },
    },
  ],
};

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'Renance | the global student study OS | Built by Resolute Femi',
    template: '%s · Renance',
  },
  description:
    'Renance is the global student study OS, a modular education & commerce suite. Register in seconds, set your exams, and Renance syncs past questions, notes and syllabi to your device, then grades your mock exams server-side on a goroutine engine. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
  keywords: [
    'Renance',
    'Renance study OS',
    'student study platform',
    'CBT practice platform',
    'past questions Nigeria',
    'JAMB CBT',
    'WAEC practice',
    'FUTA CBT practice',
    'Resolute Femi',
    'Ariyo Oluwafemi Stephen',
    'Built by Resolute Femi',
    'Nigerian edtech',
  ],
  authors: [{ name: 'Resolute Femi', url: 'https://github.com/Resolutefemi' }],
  creator: 'Resolute Femi (Ariyo Oluwafemi Stephen)',
  publisher: 'Renance | Built by Resolute Femi',
  alternates: { canonical: '/' },
  robots: { index: true, follow: true },
  openGraph: {
    type: 'website',
    siteName: 'Renance',
    url: SITE_URL,
    locale: 'en_NG',
    title: 'Renance | the global student study OS | Built by Resolute Femi',
    description:
      'Past questions, CBT mocks, spaced review and exam intelligence, purpose-built for JAMB, WAEC, NECO and university modules. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Renance | the global student study OS | Built by Resolute Femi',
    description:
      'Past questions, CBT mocks, spaced review and exam intelligence, purpose-built for JAMB, WAEC, NECO and university modules. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
    creator: '@Resolutefemi',
  },
};

/* Appearance bootstrap: applied before first paint so the chosen tier
   (light / mixed / dark, persisted in localStorage) never flashes. */
const themeBootstrap = `(function(){try{var t=localStorage.getItem('renance.theme');if(t!=='mixed'&&t!=='dark')t='light';document.documentElement.dataset.theme=t;}catch(e){document.documentElement.dataset.theme='light';}})();`;

/* suppressHydrationWarning: the inline theme bootstrap writes data-theme
   onto <html> before React hydrates, so the DOM attribute never matches
   the server render by design. Without this flag the mismatch can break
   hydration and leave client pages stuck. */
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
        {/* Founder mockups load Inter + JetBrains Mono, kept as runtime
            links so `next build` stays hermetic (no font fetch at build). */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap"
          rel="stylesheet"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200&display=block"
          rel="stylesheet"
        />
        <meta name="author" content="Ariyo Oluwafemi Stephen (Resolute Femi)" />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(renanceJsonLd) }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
