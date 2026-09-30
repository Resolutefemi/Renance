import type { Metadata } from 'next';
import Link from 'next/link';

import { getAvailableSEOSubjectParams } from '@/lib/seo-data';
import { buildBreadcrumbSchema, serializeJsonLd } from '@/lib/seo-schema';
import type { ExamBodySlug } from '@/lib/seo-types';

/**
 * /practice/[body]
 *
 * Exam-body index page - lists all subjects available for JAMB, WAEC, NECO, etc.
 * One page per exam body. Baked at build time.
 *
 * Structured data:
 *   • schema.org/BreadcrumbList
 */

export const dynamic = 'force-static';

// ─── Statics ──────────────────────────────────────────────────────────────────

const BODY_META: Record<
  ExamBodySlug,
  { title: string; description: string; emoji: string }
> = {
  jamb: {
    title: 'JAMB',
    emoji: '🎓',
    description:
      'Free JAMB past questions across all subjects with full explanations and CBT mode. ' +
      'UTME prep that actually works - Nigeria\'s largest JAMB practice bank.',
  },
  waec: {
    title: 'WAEC',
    emoji: '📚',
    description:
      'Free WAEC past questions across all subjects with step-by-step explanations. ' +
      'Practice in real exam format with instant grading.',
  },
  neco: {
    title: 'NECO',
    emoji: '✏️',
    description:
      'Free NECO past questions with full explanations. Practice all NECO subjects ' +
      'in CBT mode with instant scoring.',
  },
  'post-utme': {
    title: 'Post UTME',
    emoji: '🏛️',
    description:
      'Free Post UTME past questions from top Nigerian universities. ' +
      'Practice with full explanations and CBT mode.',
  },
};

// ─── Static param generation ──────────────────────────────────────────────────

export function generateStaticParams() {
  const bodies = new Set(getAvailableSEOSubjectParams().map((p) => p.body));
  return Array.from(bodies).map((body) => ({ body }));
}

// ─── Metadata ─────────────────────────────────────────────────────────────────

export async function generateMetadata({
  params,
}: {
  params: Promise<{ body: string }>;
}): Promise<Metadata> {
  const { body } = await params;
  const meta = BODY_META[body as ExamBodySlug];
  if (!meta) return { title: 'Past Questions | Renance' };

  const title = `${meta.title} Past Questions - All Subjects | Renance`;
  return {
    title,
    description: meta.description,
    keywords: [
      `${meta.title} past questions`,
      `${meta.title} past questions Nigeria`,
      `free ${meta.title} practice`,
      `${meta.title} CBT`,
    ],
    alternates: { canonical: `https://renance.app/practice/${body}/` },
    openGraph: {
      type: 'website',
      title,
      description: meta.description,
      url: `https://renance.app/practice/${body}/`,
    },
  };
}

// ─── Page component ───────────────────────────────────────────────────────────

export default async function BodyIndexPage({
  params,
}: {
  params: Promise<{ body: string }>;
}) {
  const { body } = await params;
  const meta = BODY_META[body as ExamBodySlug];

  // Gather unique subjects for this body
  const allParams = getAvailableSEOSubjectParams();
  const subjects = allParams
    .filter((p) => p.body === body)
    .map((p) => p.subject)
    .sort();

  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Practice', url: 'https://renance.app/practice/' },
    { name: meta?.title ?? body.toUpperCase(), url: `https://renance.app/practice/${body}/` },
  ]);

  if (!meta || subjects.length === 0) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <p className="text-sm text-on-surface-variant">Exam body not found.</p>
      </main>
    );
  }

  /** Title-cases a slug like "further-mathematics" → "Further Mathematics" */
  const slugToTitle = (slug: string) =>
    slug.split('-').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');

  return (
    <>
      {/* ── JSON-LD ── */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(breadcrumbSchema) }}
      />

      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
        <div className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">

          {/* ── Breadcrumb ── */}
          <nav aria-label="Breadcrumb" className="mb-6 flex flex-wrap items-center gap-1 text-xs text-on-surface-variant">
            <Link href="/practice/" className="hover:text-primary transition-colors">Practice</Link>
            <span>/</span>
            <span className="text-on-surface font-medium">{meta.title}</span>
          </nav>

          {/* ── Hero ── */}
          <header className="mb-8">
            <div className="mb-3 text-4xl">{meta.emoji}</div>
            <h1 className="text-2xl font-bold text-on-surface sm:text-3xl">
              {meta.title} Past Questions
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant leading-relaxed max-w-xl">
              {meta.description}
            </p>
          </header>

          {/* ── Subject grid ── */}
          <section aria-label={`${meta.title} subjects`}>
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-base font-semibold text-on-surface">
                Choose a Subject
              </h2>
              <span className="text-xs text-on-surface-variant">{subjects.length} subjects</span>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              {subjects.map((subject) => (
                <Link
                  key={subject}
                  href={`/practice/${body}/${subject}/`}
                  className="group flex items-center justify-between rounded-2xl border border-outline-variant bg-card px-4 py-3.5 transition hover:border-primary hover:bg-primary/5 active:scale-[0.98]"
                >
                  <span className="text-sm font-medium text-on-surface group-hover:text-primary">
                    {slugToTitle(subject)}
                  </span>
                  <span className="material-symbols-outlined text-[18px] text-on-surface-variant group-hover:text-primary">
                    chevron_right
                  </span>
                </Link>
              ))}
            </div>
          </section>

          {/* ── Footer note ── */}
          <p className="mt-8 text-center text-xs text-on-surface-variant">
            All questions are free · Full explanations · CBT mode included
          </p>
        </div>
      </main>
    </>
  );
}
