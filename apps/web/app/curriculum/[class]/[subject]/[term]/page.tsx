import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import {
  getAllSEOCurriculumParams,
  loadSEOCurriculumScheme,
} from '@/lib/seo-data';
import {
  buildBreadcrumbSchema,
  buildCourseSchema,
  serializeJsonLd,
} from '@/lib/seo-schema';
import type { SEOCurriculumScheme } from '@/lib/seo-types';

/**
 * /curriculum/[class]/[subject]/[term]
 *
 * Term-by-term weekly scheme of work page.
 * Renders full week-by-week lesson topics, subtopics, and learning objectives.
 * Injects schema.org/Course JSON-LD for rich Google and AI overview citations.
 */

export const dynamic = 'force-static';

export function generateStaticParams() {
  return getAllSEOCurriculumParams().map(({ classLevel, subject, term }) => ({
    class: classLevel,
    subject,
    term,
  }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ class: string; subject: string; term: string }>;
}): Promise<Metadata> {
  const { class: classLevel, subject, term } = await params;
  const scheme = loadSEOCurriculumScheme(
    classLevel,
    subject,
    term as SEOCurriculumScheme['term'],
  );

  if (!scheme) return { title: 'Scheme of Work' };

  const title = `${scheme.subjectTitle} Scheme of Work - ${scheme.classTitle} (${scheme.termTitle})`;
  const description =
    `Official NERDC approved ${scheme.subjectTitle} scheme of work for ${scheme.classTitle}, ${scheme.termTitle}. ` +
    `Covers ${scheme.weeks.length} weeks of lesson plans, topics, and subtopics. Free on Renance.`;

  return {
    title,
    description,
    keywords: [
      `${scheme.subjectTitle} scheme of work ${scheme.classTitle}`,
      `${scheme.classTitle} ${scheme.subjectTitle} ${scheme.termTitle}`,
      `${scheme.subjectTitle} weekly topics NERDC`,
      `Nigerian curriculum ${scheme.subjectTitle}`,
    ],
    alternates: { canonical: scheme.canonicalUrl },
    openGraph: {
      type: 'website',
      title,
      description,
      url: scheme.canonicalUrl,
    images: [...OG_IMAGES],
    },
  };
}

const TERMS: Array<{ slug: SEOCurriculumScheme['term']; title: string }> = [
  { slug: 'first-term', title: '1st Term' },
  { slug: 'second-term', title: '2nd Term' },
  { slug: 'third-term', title: '3rd Term' },
];

export default async function CurriculumTermPage({
  params,
}: {
  params: Promise<{ class: string; subject: string; term: string }>;
}) {
  const { class: classLevel, subject, term } = await params;
  const scheme = loadSEOCurriculumScheme(
    classLevel,
    subject,
    term as SEOCurriculumScheme['term'],
  );

  if (!scheme) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <p className="text-sm text-on-surface-variant">Scheme of work not found.</p>
      </main>
    );
  }

  const courseSchema = buildCourseSchema(scheme);
  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Curriculum', url: 'https://renance.app/curriculum/' },
    { name: scheme.classTitle, url: `https://renance.app/curriculum/${classLevel}/` },
    { name: scheme.subjectTitle, url: scheme.canonicalUrl },
    { name: scheme.termTitle, url: scheme.canonicalUrl },
  ]);

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(courseSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(breadcrumbSchema) }}
      />

      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
        <div className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">

          {/* ── Breadcrumb ── */}
          <nav aria-label="Breadcrumb" className="mb-6 flex flex-wrap items-center gap-1 text-xs text-on-surface-variant">
            <Link href="/" className="hover:text-primary transition-colors">Home</Link>
            <span>/</span>
            <Link href="/curriculum/" className="hover:text-primary transition-colors">Curriculum</Link>
            <span>/</span>
            <Link href={`/curriculum/${classLevel}/`} className="hover:text-primary transition-colors">{scheme.classTitle}</Link>
            <span>/</span>
            <span className="text-on-surface font-medium">{scheme.subjectTitle}</span>
          </nav>

          {/* ── Header ── */}
          <header className="mb-6">
            <div className="flex items-center gap-2 mb-2">
              <span className="inline-flex h-6 items-center rounded-full bg-primary/10 px-2.5 text-[11px] font-semibold text-primary uppercase tracking-wider">
                {scheme.classTitle}
              </span>
              <span className="inline-flex h-6 items-center rounded-full bg-surface-container px-2.5 text-[11px] font-medium text-on-surface-variant">
                NERDC Approved
              </span>
            </div>
            <h1 className="text-2xl font-bold text-on-surface sm:text-3xl">
              {scheme.subjectTitle} Scheme of Work
            </h1>
            <p className="mt-1.5 text-sm text-on-surface-variant">
              {scheme.termTitle} · {scheme.weeks.length} Weeks of Structured Lesson Topics
            </p>
          </header>

          {/* ── Term Switcher Tabs ── */}
          <nav aria-label="Terms navigation" className="mb-8 flex gap-2 border-b border-outline-variant pb-3">
            {TERMS.map((t) => {
              const isActive = t.slug === term;
              return (
                <Link
                  key={t.slug}
                  href={`/curriculum/${classLevel}/${subject}/${t.slug}/`}
                  className={`rounded-xl px-4 py-2 text-xs font-semibold transition ${
                    isActive
                      ? 'bg-primary text-on-primary shadow-sm'
                      : 'border border-outline-variant bg-card text-on-surface hover:bg-surface-container'
                  }`}
                >
                  {t.title}
                </Link>
              );
            })}
          </nav>

          {/* ── Week by Week Breakdown ── */}
          <section aria-label="Weekly lesson plan">
            <h2 className="mb-4 text-base font-semibold text-on-surface">
              Weekly Lesson Breakdown
            </h2>

            <ol className="space-y-4">
              {scheme.weeks.map((w) => (
                <li
                  key={w.week}
                  className="rounded-2xl border border-outline-variant bg-card p-4 transition hover:border-primary/40"
                >
                  <div className="flex items-start gap-3">
                    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-xs font-bold text-primary">
                      W{w.week}
                    </span>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm text-on-surface">
                        {w.topic}
                      </p>

                      {w.subtopics && w.subtopics.length > 0 && (
                        <div className="mt-2 flex flex-wrap gap-1.5">
                          {w.subtopics.map((sub, idx) => (
                            <span
                              key={idx}
                              className="rounded-lg bg-surface-container px-2.5 py-1 text-[11px] text-on-surface-variant"
                            >
                              {sub}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          </section>

          {/* ── Internal Bridge to Past Questions Practice ── */}
          <div className="mt-10 rounded-2xl border border-outline-variant bg-card p-5 text-center">
            <p className="text-sm font-semibold text-on-surface">
              Preparing for exams in {scheme.subjectTitle}?
            </p>
            <p className="mt-1 text-xs text-on-surface-variant mb-4">
              Practice real JAMB and WAEC past questions on these exact topics with instant explanations.
            </p>
            <Link
              href="/practice/"
              className="inline-flex h-10 items-center justify-center rounded-xl bg-primary px-5 text-xs font-semibold text-on-primary transition active:scale-[0.98]"
            >
              Practice Past Questions →
            </Link>
          </div>
        </div>
      </main>
    </>
  );
}
