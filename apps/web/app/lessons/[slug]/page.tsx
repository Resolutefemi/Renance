import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { loadLesson, loadLessons } from '@/lib/site-data';
import { renderInline } from '@/lib/inline';

/**
 * /lessons/[slug] — one lesson, baked at build time from the committed
 * data/lessons bundle. Each page ships Article structured data so Google
 * can surface it as study content.
 */

export const dynamic = 'force-static';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';

export function generateStaticParams() {
  return loadLessons().map((l) => ({ slug: l.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const les = loadLesson(slug);
  if (!les) return { title: 'Lesson not found' };
  const title = `${les.title} — ${les.subject ?? 'study'} lesson`;
  return {
    title,
    description: les.summary,
    keywords: [...(les.tags ?? []), les.subject ?? '', 'JAMB', 'WAEC', 'Renance'].filter(Boolean),
    alternates: { canonical: `/lessons/${les.slug}/` },
    openGraph: {
      type: 'article',
      title: `${title} · Renance`,
      description: les.summary,
      url: `${SITE_URL}/lessons/${les.slug}/`,
    },
  };
}

export default async function LessonPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const les = loadLesson(slug);
  if (!les) notFound();

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: les.title,
    description: les.summary,
    articleSection: les.subject ?? 'Study',
    keywords: (les.tags ?? []).join(', '),
    inLanguage: 'en-NG',
    author: {
      '@type': 'Person',
      name: 'Resolute Femi',
      url: 'https://github.com/Resolutefemi',
    },
    publisher: {
      '@type': 'Organization',
      name: 'Renance',
      url: SITE_URL,
    },
    mainEntityOfPage: `${SITE_URL}/lessons/${les.slug}/`,
    timeRequired: `PT${les.minutes}M`,
  };

  const others = loadLessons().filter((l) => l.slug !== les.slug).slice(0, 3);

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-20 pt-10 sm:px-6 lg:max-w-3xl">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <nav className="font-mono text-xs text-on-surface-variant">
        <Link href="/lessons/" className="hover:text-on-surface">
          Lessons
        </Link>
        <span className="mx-1.5">/</span>
        <span className="text-on-surface">{les.slug}</span>
      </nav>

      <header className="mt-4">
        <div className="flex flex-wrap items-center gap-2">
          {les.subject && (
            <span className="rounded-full bg-selection-blue px-2.5 py-0.5 text-[11px] font-medium text-on-surface">
              {les.subject}
            </span>
          )}
          {les.body && (
            <span className="rounded-full bg-surface-container-low px-2.5 py-0.5 text-[11px] text-on-surface-variant">
              {les.body}
            </span>
          )}
          <span className="font-mono text-xs text-on-surface-variant">{les.minutes} min read</span>
        </div>
        <h1 className="mt-3 text-3xl font-bold tracking-tight text-on-surface sm:text-4xl">
          {les.title}
        </h1>
        <p className="mt-3 text-[15px] leading-relaxed text-on-surface-variant">
          {renderInline(les.summary)}
        </p>
      </header>

      <article className="mt-8 space-y-8">
        {les.sections.map((sec, si) => (
          <section key={si}>
            <h2 className="text-xl font-bold tracking-tight text-on-surface sm:text-2xl">
              {si + 1}. {sec.heading}
            </h2>
            <div className="mt-3 space-y-3">
              {sec.blocks.map((b, bi) => {
                if (b.type === 'p') {
                  return (
                    <p key={bi} className="text-[15px] leading-relaxed text-on-surface">
                      {renderInline(b.text ?? '')}
                    </p>
                  );
                }
                if (b.type === 'h3') {
                  return (
                    <h3 key={bi} className="pt-2 text-lg font-semibold text-on-surface">
                      {renderInline(b.text ?? '')}
                    </h3>
                  );
                }
                if (b.type === 'callout') {
                  return (
                    <p
                      key={bi}
                      className="rounded-lg border-l-4 border-accent-amber bg-accent-amber/10 p-4 text-[14px] leading-relaxed text-on-surface"
                    >
                      {renderInline(b.text ?? '')}
                    </p>
                  );
                }
                const Tag = b.type === 'ol' ? 'ol' : 'ul';
                return (
                  <Tag
                    key={bi}
                    className={`space-y-1.5 pl-5 text-[15px] leading-relaxed text-on-surface ${
                      b.type === 'ol' ? 'list-decimal' : 'list-disc'
                    }`}
                  >
                    {(b.items ?? []).map((it, ii) => (
                      <li key={ii}>{renderInline(it)}</li>
                    ))}
                  </Tag>
                );
              })}
            </div>
          </section>
        ))}
      </article>

      {others.length > 0 && (
        <footer className="mt-14 border-t border-surface-container-high pt-6">
          <h2 className="text-lg font-semibold text-on-surface">Keep reading</h2>
          <div className="mt-4 grid gap-3 sm:grid-cols-3">
            {others.map((o) => (
              <Link
                key={o.slug}
                href={`/lessons/${o.slug}/`}
                className="rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition hover:shadow-md"
              >
                <span className="block text-sm font-medium text-on-surface">{o.title}</span>
                <span className="mt-1 block font-mono text-xs text-on-surface-variant">
                  {o.minutes} min read →
                </span>
              </Link>
            ))}
          </div>
        </footer>
      )}
    </main>
  );
}
