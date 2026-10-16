import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import { buildBreadcrumbSchema, serializeJsonLd } from '@/lib/seo-schema';

/**
 * /practice  - SEO practice hub root
 *
 * Entry page for the entire programmatic SEO tree.
 * Links out to each exam body index page.
 */

export const dynamic = 'force-static';

export const metadata: Metadata = {
  title: 'Practice Past Questions - JAMB, WAEC, NECO',
  description:
    'Free JAMB, WAEC, NECO and Post UTME past questions with full explanations and CBT mode. ' +
    'Nigeria\'s largest exam practice bank - 290,000+ questions, 100% free.',
  keywords: [
    'JAMB past questions',
    'WAEC past questions',
    'NECO past questions',
    'Post UTME past questions',
    'free past questions Nigeria',
    'CBT practice Nigeria',
  ],
  alternates: { canonical: 'https://renance.app/practice/' },
  openGraph: {
    type: 'website',
    title: 'Practice Past Questions - JAMB, WAEC, NECO',
    description:
      'Free JAMB, WAEC, NECO and Post UTME past questions with full explanations. Nigeria\'s largest exam practice bank.',
    url: 'https://renance.app/practice/',
    images: [...OG_IMAGES],
  },
};

const EXAM_BODIES = [
  {
    slug: 'jamb',
    title: 'JAMB / UTME',
    subtitle: 'Unified Tertiary Matriculation Examination',
    emoji: '🎓',
    color: 'bg-blue-500/10 text-blue-600 dark:text-blue-400',
    border: 'hover:border-blue-300 dark:hover:border-blue-500/60',
  },
  {
    slug: 'waec',
    title: 'WAEC',
    subtitle: 'West African Senior School Certificate',
    emoji: '📚',
    color: 'bg-green-500/10 text-green-700 dark:text-green-400',
    border: 'hover:border-green-300 dark:hover:border-green-500/60',
  },
  {
    slug: 'neco',
    title: 'NECO',
    subtitle: 'National Examinations Council',
    emoji: '✏️',
    color: 'bg-orange-500/10 text-orange-600 dark:text-orange-400',
    border: 'hover:border-orange-300 dark:hover:border-orange-500/60',
  },
  {
    slug: 'post-utme',
    title: 'Post UTME',
    subtitle: 'Tertiary Institution Post-UTME Screening',
    emoji: '🏛️',
    color: 'bg-purple-500/10 text-purple-600 dark:text-purple-400',
    border: 'hover:border-purple-300 dark:hover:border-purple-500/60',
  },
] as const;

export default function PracticeRootPage() {
  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Practice', url: 'https://renance.app/practice/' },
  ]);

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(breadcrumbSchema) }}
      />

      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
        <div className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">

          {/* ── Hero ── */}
          <header className="mb-10 text-center">
            <h1 className="text-3xl font-bold text-on-surface sm:text-4xl">
              Past Questions Practice
            </h1>
            <p className="mt-3 text-sm text-on-surface-variant max-w-lg mx-auto leading-relaxed">
              290,000+ free past questions across JAMB, WAEC, NECO and Post UTME.
              Full explanations, CBT timer, instant grading - built for Nigerian students.
            </p>
            <div className="mt-4 flex flex-wrap items-center justify-center gap-3 text-xs text-on-surface-variant">
              <span className="flex items-center gap-1">
                <span className="material-symbols-outlined text-[14px] text-primary">check_circle</span>
                290,000+ questions
              </span>
              <span className="flex items-center gap-1">
                <span className="material-symbols-outlined text-[14px] text-primary">check_circle</span>
                Full explanations
              </span>
              <span className="flex items-center gap-1">
                <span className="material-symbols-outlined text-[14px] text-primary">check_circle</span>
                100% free
              </span>
            </div>
          </header>

          {/* ── Exam body cards ── */}
          <section aria-label="Exam bodies">
            <h2 className="mb-4 text-base font-semibold text-on-surface">
              Choose Your Exam
            </h2>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              {EXAM_BODIES.map((body) => (
                <Link
                  key={body.slug}
                  href={`/practice/${body.slug}/`}
                  className={`group flex items-start gap-4 rounded-2xl border border-outline-variant bg-card p-5 transition ${body.border} hover:bg-primary/5 active:scale-[0.98]`}
                >
                  <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl text-2xl ${body.color}`}>
                    {body.emoji}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-on-surface group-hover:text-primary">
                      {body.title}
                    </p>
                    <p className="mt-0.5 text-xs text-on-surface-variant leading-snug">
                      {body.subtitle}
                    </p>
                  </div>
                  <span className="material-symbols-outlined mt-0.5 shrink-0 text-[20px] text-on-surface-variant group-hover:text-primary">
                    chevron_right
                  </span>
                </Link>
              ))}
            </div>
          </section>

          {/* ── Quick study CTA ── */}
          <div className="mt-10 rounded-2xl border border-outline-variant bg-card p-5 flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="flex-1">
              <p className="text-sm font-semibold text-on-surface">
                Want to jump straight into CBT mode?
              </p>
              <p className="mt-0.5 text-xs text-on-surface-variant">
                Choose your exam pack and start a full timed mock in seconds.
              </p>
            </div>
            <Link
              href="/study-past-questions/"
              className="inline-flex h-10 shrink-0 items-center justify-center rounded-xl bg-primary px-5 text-sm font-semibold text-on-primary transition active:scale-[0.98]"
            >
              <span className="material-symbols-outlined mr-1.5 text-[16px]">bolt</span>
              Quick Study
            </Link>
          </div>
        </div>
      </main>
    </>
  );
}
