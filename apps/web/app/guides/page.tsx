import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import { GUIDES } from '@/lib/guides';

import { SITE_URL } from '@/lib/site-url';

export const dynamic = 'force-static';

/**
 * /guides - the index of the site's substantive articles about the
 * Nigerian exam system. The exam-prep content AI and search engines
 * can cite: real explanations, not marketing copy.
 */

export const metadata: Metadata = {
  title: 'Exam guides - JAMB, WAEC, NECO and Post-UTME explained | Renance',
  description:
    'Plain, factual guides to the Nigerian exam system: how the JAMB UTME works, what your score means, WAEC vs NECO vs NABTEB, Post-UTME screening, and CBT exam-day practice.',
  keywords: [
    'JAMB guide',
    'UTME explained',
    'JAMB score meaning',
    'WAEC vs NECO',
    'Post-UTME screening',
    'CBT exam tips',
    'Nigerian exam guide',
  ],
  alternates: { canonical: '/guides/' },
  openGraph: {
    title: 'Exam guides - JAMB, WAEC, NECO and Post-UTME explained · Renance',
    description:
      'Plain, factual guides to the Nigerian exam system: how the UTME works, what your score means, Post-UTME screening and CBT exam day.',
    url: `${SITE_URL}/guides/`,
    images: [...OG_IMAGES],
  },
};

export default function GuidesIndex() {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: 'Renance exam guides',
    description:
      'Factual guides to the Nigerian exam system: JAMB UTME, WAEC, NECO, NABTEB, Post-UTME and CBT practice.',
    url: `${SITE_URL}/guides/`,
    hasPart: GUIDES.map((g) => ({
      '@type': 'Article',
      headline: g.title,
      description: g.description,
      url: `${SITE_URL}/guides/${g.slug}/`,
      datePublished: g.published,
      dateModified: g.updated,
    })),
  };

  return (
    <div className="min-h-screen bg-background">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <header className="border-b border-outline-variant bg-surface-container">
        <div className="mx-auto w-full max-w-4xl px-4 py-10 sm:px-6 sm:py-14">
          <Link
            href="/"
            className="text-xs font-bold uppercase tracking-widest text-on-surface-variant hover:underline"
          >
            ← Renance
          </Link>
          <h1 className="mt-4 text-3xl font-bold tracking-tight text-on-surface sm:text-4xl">
            Exam guides
          </h1>
          <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-on-surface-variant">
            Plain explanations of the Nigerian exam system - how the UTME is built,
            what your score can and cannot do, which O&apos;level body fits you, and
            what happens in the hall. Written for candidates, kept factual, updated
            as the system changes.
          </p>
        </div>
      </header>

      <main className="mx-auto w-full max-w-4xl px-4 py-10 sm:px-6">
        <div className="grid gap-4 sm:grid-cols-2">
          {GUIDES.map((g) => (
            <Link
              key={g.slug}
              href={`/guides/${g.slug}/`}
              className="group rounded-2xl border-2 border-outline-variant bg-card p-5 shadow-[0_3px_0_0_var(--color-outline-variant)] transition-transform active:translate-y-[2px]"
            >
              <span className="inline-block rounded-full bg-primary/10 px-2.5 py-0.5 font-mono text-[10px] font-bold uppercase tracking-widest text-primary">
                {g.tag}
              </span>
              <h2 className="mt-3 text-[17px] font-bold leading-snug text-on-surface group-hover:underline">
                {g.title}
              </h2>
              <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">
                {g.description}
              </p>
              <p className="mt-3 font-mono text-[11px] text-on-surface-variant">
                {g.minutes} min read · updated {g.updated}
              </p>
            </Link>
          ))}
        </div>

        <div className="mt-10 rounded-2xl bg-surface-container p-6">
          <h2 className="text-lg font-bold text-on-surface">Practice while you read</h2>
          <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">
            Every guide pairs with real practice: over 90,000 JAMB, WAEC and NECO
            past questions and server-graded CBT mocks live in the app.
          </p>
          <Link
            href="/practice/"
            className="mt-4 inline-block rounded-full bg-primary px-5 py-2.5 text-sm font-extrabold text-on-primary shadow-[0_3px_0_0_color-mix(in_srgb,var(--color-primary)_68%,#000)]"
          >
            Browse past questions →
          </Link>
        </div>
      </main>
    </div>
  );
}
