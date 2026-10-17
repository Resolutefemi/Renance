import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { GUIDES } from '@/lib/guides';

import { SITE_URL } from '@/lib/site-url';

export const dynamic = 'force-static';

/**
 * /guides/[slug] - one guide, baked at build time from lib/guides.ts.
 * Ships Article + FAQPage structured data so search engines and AI
 * answer engines can cite the content properly.
 */

export function generateStaticParams() {
  return GUIDES.map((g) => ({ slug: g.slug }));
}

function loadGuide(slug: string) {
  return GUIDES.find((g) => g.slug === slug);
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const guide = loadGuide(slug);
  if (!guide) return { title: 'Guide not found' };
  const title = `${guide.title} | Renance`;
  return {
    title,
    description: guide.description,
    keywords: [guide.tag, 'JAMB', 'WAEC', 'NECO', 'Post-UTME', 'Renance'],
    alternates: { canonical: `/guides/${guide.slug}/` },
    openGraph: {
      type: 'article',
      title: `${guide.title} · Renance`,
      description: guide.description,
      url: `${SITE_URL}/guides/${guide.slug}/`,
      publishedTime: guide.published,
      modifiedTime: guide.updated,
      images: [...OG_IMAGES],
    },
  };
}

export default async function GuidePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const guide = loadGuide(slug);
  if (!guide) notFound();

  const others = GUIDES.filter((g) => g.slug !== guide.slug).slice(0, 3);

  const jsonLd = [
    {
      '@context': 'https://schema.org',
      '@type': 'Article',
      headline: guide.title,
      description: guide.description,
      datePublished: guide.published,
      dateModified: guide.updated,
      author: { '@type': 'Organization', name: 'Renance' },
      publisher: { '@type': 'Organization', name: 'Renance' },
      mainEntityOfPage: `${SITE_URL}/guides/${guide.slug}/`,
    },
    {
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: guide.faq.map((f) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a },
      })),
    },
  ];

  return (
    <div className="min-h-screen bg-background">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <header className="border-b border-outline-variant bg-surface-container">
        <div className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6 sm:py-12">
          <Link
            href="/guides/"
            className="text-xs font-bold uppercase tracking-widest text-on-surface-variant hover:underline"
          >
            ← All guides
          </Link>
          <span className="mt-5 inline-block rounded-full bg-primary/10 px-2.5 py-0.5 font-mono text-[10px] font-bold uppercase tracking-widest text-primary">
            {guide.tag}
          </span>
          <h1 className="mt-3 text-2xl font-bold leading-tight tracking-tight text-on-surface sm:text-3xl">
            {guide.title}
          </h1>
          <p className="mt-3 text-[15px] leading-relaxed text-on-surface-variant">
            {guide.description}
          </p>
          <p className="mt-4 font-mono text-[11px] text-on-surface-variant">
            {guide.minutes} min read · published {guide.published} · updated {guide.updated}
          </p>
        </div>
      </header>

      <main className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">
        <article className="prose-guide">
          {guide.sections.map((section) => (
            <section key={section.heading} className="mt-8 first:mt-0">
              <h2 className="text-xl font-bold tracking-tight text-on-surface">
                {section.heading}
              </h2>
              {section.paragraphs.map((p, i) => (
                <p key={i} className="mt-3 text-[15px] leading-relaxed text-on-surface-variant">
                  {p}
                </p>
              ))}
              {section.list && (
                <ul className="mt-4 space-y-2.5">
                  {section.list.map((item, i) => (
                    <li key={i} className="flex gap-2.5 text-[15px] leading-relaxed text-on-surface-variant">
                      <span aria-hidden className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          ))}

          <section className="mt-10">
            <h2 className="text-xl font-bold tracking-tight text-on-surface">
              Frequently asked questions
            </h2>
            {guide.faq.map((f) => (
              <div key={f.q} className="mt-4 rounded-2xl border-2 border-outline-variant bg-card p-4">
                <h3 className="text-[15px] font-bold text-on-surface">{f.q}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-on-surface-variant">{f.a}</p>
              </div>
            ))}
          </section>
        </article>

        <section className="mt-12 rounded-2xl bg-surface-container p-6">
          <h2 className="text-lg font-bold text-on-surface">Turn the reading into practice</h2>
          <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">
            Renance carries 90,000+ JAMB, WAEC and NECO past questions with
            server-graded CBT mocks and a spaced review queue for every question
            you miss.
          </p>
          <Link
            href="/practice/"
            className="mt-4 inline-block rounded-full bg-primary px-5 py-2.5 text-sm font-extrabold text-on-primary shadow-[0_3px_0_0_color-mix(in_srgb,var(--color-primary)_68%,#000)]"
          >
            Start practising →
          </Link>
        </section>

        <nav aria-label="More guides" className="mt-10">
          <h2 className="text-lg font-bold text-on-surface">Keep reading</h2>
          <ul className="mt-3 space-y-2">
            {others.map((g) => (
              <li key={g.slug}>
                <Link
                  href={`/guides/${g.slug}/`}
                  className="text-[15px] font-semibold text-primary hover:underline"
                >
                  {g.title}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </main>
    </div>
  );
}
