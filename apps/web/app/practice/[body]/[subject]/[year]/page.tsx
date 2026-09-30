import type { Metadata } from 'next';
import Link from 'next/link';

import {
  getAvailableSEOExamParams,
  loadSEOExamPaper,
} from '@/lib/seo-data';
import {
  buildBreadcrumbSchema,
  buildExamFAQSchema,
  buildQuizSchema,
  serializeJsonLd,
} from '@/lib/seo-schema';
import type { ExamBodySlug } from '@/lib/seo-types';
import InteractiveQuiz from './interactive-quiz';

/**
 * /practice/[body]/[subject]/[year]
 *
 * Static exam-paper page - one page per (exam body × subject × year) triple.
 * Baked entirely at build time via generateStaticParams() from the data vault.
 *
 * Structured data injected:
 *   • schema.org/Quiz         → Google "Practice problems" rich result
 *   • schema.org/BreadcrumbList → SERP breadcrumb trail
 *   • schema.org/FAQPage       → FAQ rich result (long-tail queries)
 */

export const dynamic = 'force-static';

// ─── Static param generation ──────────────────────────────────────────────────

export function generateStaticParams() {
  return getAvailableSEOExamParams();
}

// ─── Metadata ─────────────────────────────────────────────────────────────────

export async function generateMetadata({
  params,
}: {
  params: Promise<{ body: string; subject: string; year: string }>;
}): Promise<Metadata> {
  const { body, subject, year } = await params;
  const paper = loadSEOExamPaper(body as ExamBodySlug, subject, Number(year));

  if (!paper) {
    return { title: 'Past Questions | Renance' };
  }

  const title = `${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} Past Questions`;
  const description =
    `Practice all ${paper.totalQuestions} ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} past questions ` +
    `with full explanations, instant marking, and CBT mode. Free on Renance.`;

  return {
    title,
    description,
    keywords: [
      `${paper.bodyTitle} ${paper.subjectTitle} past questions`,
      `${paper.bodyTitle} ${paper.subjectTitle} ${paper.year}`,
      `${paper.subjectTitle} ${paper.year} answers`,
      `${paper.bodyTitle} past questions Nigeria`,
      `free ${paper.bodyTitle} practice`,
    ],
    alternates: { canonical: paper.canonicalUrl },
    openGraph: {
      type: 'website',
      title,
      description,
      url: paper.canonicalUrl,
    },
    twitter: {
      card: 'summary',
      title,
      description,
    },
  };
}

// ─── Page component ───────────────────────────────────────────────────────────

export default async function ExamPaperPage({
  params,
}: {
  params: Promise<{ body: string; subject: string; year: string }>;
}) {
  const { body, subject, year } = await params;
  const paper = loadSEOExamPaper(body as ExamBodySlug, subject, Number(year));

  if (!paper) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <p className="text-sm text-on-surface-variant">Paper not found.</p>
      </main>
    );
  }

  const quizSchema = buildQuizSchema(paper);
  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Practice', url: 'https://renance.app/practice/' },
    { name: paper.bodyTitle, url: `https://renance.app/practice/${paper.body}/` },
    {
      name: paper.subjectTitle,
      url: `https://renance.app/practice/${paper.body}/${paper.subjectSlug}/`,
    },
    { name: String(paper.year), url: paper.canonicalUrl },
  ]);
  const faqSchema = buildExamFAQSchema(paper);

  // The existing CBT runner lives at /exams/[code]; deep-link into it.
  const examCode = `${paper.body}-${paper.subjectSlug}-bank`;

  return (
    <>
      {/* ── JSON-LD structured data ── */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(quizSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(breadcrumbSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: serializeJsonLd(faqSchema) }}
      />

      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
        <div className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">

          {/* ── Breadcrumb ── */}
          <nav aria-label="Breadcrumb" className="mb-6 flex flex-wrap items-center gap-1 text-xs text-on-surface-variant">
            <Link href="/practice/" className="hover:text-primary transition-colors">Practice</Link>
            <span>/</span>
            <Link href={`/practice/${paper.body}/`} className="hover:text-primary transition-colors capitalize">{paper.bodyTitle}</Link>
            <span>/</span>
            <Link href={`/practice/${paper.body}/${paper.subjectSlug}/`} className="hover:text-primary transition-colors">{paper.subjectTitle}</Link>
            <span>/</span>
            <span className="text-on-surface font-medium">{paper.year}</span>
          </nav>

          {/* ── Hero header ── */}
          <header className="mb-8">
            <div className="flex items-center gap-2 mb-3">
              <span className="inline-flex h-7 items-center rounded-full bg-primary/10 px-3 text-xs font-semibold text-primary uppercase tracking-wider">
                {paper.bodyTitle}
              </span>
              <span className="inline-flex h-7 items-center rounded-full bg-surface-container px-3 text-xs font-medium text-on-surface-variant">
                {paper.year}
              </span>
            </div>
            <h1 className="text-2xl font-bold text-on-surface sm:text-3xl">
              {paper.bodyTitle} {paper.subjectTitle} {paper.year} Past Questions
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant leading-relaxed">
              {paper.totalQuestions} questions · {paper.durationMinutes} minutes · Full explanations included
            </p>
          </header>

          {/* ── Interactive Quiz Runner (0-login required) ── */}
          <InteractiveQuiz
            questions={paper.sampleQuestions}
            totalQuestions={paper.totalQuestions}
            bodyTitle={paper.bodyTitle}
            subjectTitle={paper.subjectTitle}
            year={paper.year}
            subjectSlug={paper.subjectSlug}
            body={paper.body}
          />

          {/* ── "See all years" footer ── */}
          <div className="mt-10 rounded-2xl border border-outline-variant bg-card p-5 text-center">
            <p className="text-sm text-on-surface-variant mb-3">
              Want past questions from other years?
            </p>
            <Link
              href={`/practice/${paper.body}/${paper.subjectSlug}/`}
              className="inline-flex h-10 items-center justify-center rounded-xl border border-outline-variant bg-surface-container px-5 text-sm font-medium text-on-surface transition hover:bg-surface-container-high active:scale-[0.98]"
            >
              All {paper.bodyTitle} {paper.subjectTitle} Years →
            </Link>
          </div>
        </div>
      </main>
    </>
  );
}
