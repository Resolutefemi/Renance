import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';

import {
  getAvailableSEOExamParams,
  loadSEOExamPaper,
} from '@/lib/seo-data';
import {
  buildBreadcrumbSchema,
  buildExamFAQSchema,
  serializeJsonLd,
} from '@/lib/seo-schema';
import type { ExamBodySlug } from '@/lib/seo-types';
import { bankCode } from '@/lib/bank-code';

/**
 * /practice/[body]/[subject]/[year]
 *
 * Static exam-paper page - one page per (exam body × subject × year) triple.
 * Baked entirely at build time via generateStaticParams() from the data vault.
 *
 * Founder directive (2026-09-30): the interactive 0-login quiz runner was
 * REMOVED - questions, live scoring and worked explanations are the
 * product, and giving them away without an account undercut the app and
 * the web desk. The page stays as the SEO landing it was built to be:
 * the paper's facts, a conversion card into the (free-account) web
 * reader and the Android app, and the all-years hop.
 *
 * Structured data injected:
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
    return { title: 'Past Questions' };
  }

  const title = `${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} Past Questions and Answers - Free`;
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
    images: [...OG_IMAGES],
    },
    twitter: {
      card: 'summary_large_image',
      images: [...OG_IMAGES],
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

  // The CBT runner lives at /exams/[code]; deep-link into it.
  const examCode = bankCode(paper.body, paper.subjectSlug);
  const webReaderUrl = `/study-past-questions/reader?body=${paper.body}&subject=${paper.subjectSlug}&bank=${examCode}&year=${paper.year}`;

  return (
    <>
      {/* ── JSON-LD structured data ── */}
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

          {/* ── Conversion card: take the paper inside Renance ── */}
          <section aria-label="Take this paper on Renance" className="mt-2">
            <div className="rounded-2xl border border-outline-variant bg-card p-6 shadow-sm sm:p-8">
              <div className="flex items-start gap-4">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                  <span className="material-symbols-outlined text-[24px]">quiz</span>
                </span>
                <div className="min-w-0">
                  <h2 className="text-lg font-bold text-on-surface">
                    Take this {paper.year} paper on Renance
                  </h2>
                  <p className="mt-1.5 text-sm leading-relaxed text-on-surface-variant">
                    All {paper.totalQuestions} questions, CBT timing, instant marking and a
                    step-by-step explanation for every answer - free with a Renance account.
                  </p>
                </div>
              </div>

              <ul className="mt-5 grid gap-2.5 sm:grid-cols-2">
                {[
                  ['timer', 'Real CBT mode', `Timed like the real ${paper.bodyTitle} exam (${paper.durationMinutes} minutes).`],
                  ['fact_check', 'Worked explanations', 'Every question carries a step-by-step solution.'],
                  ['insights', 'Performance forensics', 'Time-per-question and topic breakdowns after marking.'],
                  ['offline_bolt', 'Works offline on Android', 'Download the paper once, study anywhere.'],
                ].map(([icon, title, copy]) => (
                  <li key={title} className="flex items-start gap-3 rounded-xl bg-surface-container/60 p-3.5">
                    <span className="material-symbols-outlined mt-0.5 shrink-0 text-[20px] text-primary">{icon}</span>
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-on-surface">{title}</p>
                      <p className="mt-0.5 text-xs leading-relaxed text-on-surface-variant">{copy}</p>
                    </div>
                  </li>
                ))}
              </ul>

              <div className="mt-6 flex flex-col gap-3 sm:flex-row">
                <Link
                  href={webReaderUrl}
                  className="inline-flex h-11 flex-1 items-center justify-center rounded-xl bg-primary px-6 text-sm font-semibold text-on-primary shadow-sm transition hover:opacity-95 active:scale-[0.98]"
                >
                  <span className="material-symbols-outlined mr-2 text-[18px]">laptop_mac</span>
                  Practice free on web
                </Link>
                <Link
                  href="/register"
                  className="inline-flex h-11 flex-1 items-center justify-center rounded-xl border border-outline-variant bg-surface-container px-5 text-sm font-medium text-on-surface transition hover:bg-surface-container-high active:scale-[0.98]"
                >
                  <span className="material-symbols-outlined mr-2 text-[18px]">person_add</span>
                  Create a free account
                </Link>
              </div>
              <p className="mt-4 text-center text-[11.5px] text-on-surface-variant">
                Already have an account?{' '}
                <Link href="/login" className="font-semibold text-primary hover:underline">Sign in</Link>
              </p>
            </div>
          </section>

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
