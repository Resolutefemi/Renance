import type { Metadata } from 'next';
import Link from 'next/link';

import {
  getAvailableSEOSubjectParams,
  loadSEOSubjectPillar,
} from '@/lib/seo-data';
import {
  buildBreadcrumbSchema,
  buildFAQSchema,
  serializeJsonLd,
} from '@/lib/seo-schema';
import type { ExamBodySlug } from '@/lib/seo-types';
import { STORE_CONFIG } from '@/lib/store-links';

function PlayStoreIcon({ className = 'h-4 w-4 shrink-0' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1z" fill="#EA4335" />
      <path d="M47 38.8c-3.5 7.1-5.6 15.3-5.6 24.1v386.2c0 8.8 2.1 17 5.6 24.1l226.7-226.7L47 38.8z" fill="#4285F4" />
      <path d="M325.3 277.7l60.1 60.1L104.6 499l220.7-221.3z" fill="#34A853" />
      <path d="M459.7 238.3l-74.3-42.7-60.1 60.1 60.1 60.1 74.3-42.7c16.9-9.7 26.6-24.4 26.6-34.8 0-10.4-9.7-25.1-26.6-34.8z" fill="#FBBC04" />
    </svg>
  );
}

/**
 * /practice/[body]/[subject]
 *
 * Subject pillar page — one per (exam body × subject).
 * Lists every available year as a link to its exam-paper page.
 *
 * Structured data:
 *   • schema.org/BreadcrumbList
 *   • schema.org/FAQPage (subject-level long-tail SEO)
 */

export const dynamic = 'force-static';

// ─── Static param generation ──────────────────────────────────────────────────

export function generateStaticParams() {
  return getAvailableSEOSubjectParams();
}

// ─── Metadata ─────────────────────────────────────────────────────────────────

export async function generateMetadata({
  params,
}: {
  params: Promise<{ body: string; subject: string }>;
}): Promise<Metadata> {
  const { body, subject } = await params;
  const pillar = loadSEOSubjectPillar(body as ExamBodySlug, subject);

  if (!pillar) return { title: 'Past Questions | Renance' };

  const yearRangeText =
    pillar.availableYears.length > 0
      ? `(${pillar.availableYears.at(-1)}–${pillar.availableYears[0]})`
      : '';

  const title = `${pillar.bodyTitle} ${pillar.subjectTitle} Past Questions — All Years`;
  const description =
    `${pillar.totalBankedQuestions.toLocaleString()} ${pillar.bodyTitle} ${pillar.subjectTitle} past questions ` +
    `across ${pillar.availableYears.length} years ${yearRangeText}. ` +
    `Full explanations, CBT mode, instant grading. Free on Renance.`;

  return {
    title,
    description,
    keywords: [
      `${pillar.bodyTitle} ${pillar.subjectTitle} past questions`,
      `${pillar.bodyTitle} ${pillar.subjectTitle} all years`,
      `${pillar.subjectTitle} past questions Nigeria`,
      `free ${pillar.bodyTitle} ${pillar.subjectTitle}`,
    ],
    alternates: { canonical: pillar.canonicalUrl },
    openGraph: {
      type: 'website',
      title,
      description,
      url: pillar.canonicalUrl,
    },
  };
}

// ─── Page component ───────────────────────────────────────────────────────────

export default async function SubjectPillarPage({
  params,
}: {
  params: Promise<{ body: string; subject: string }>;
}) {
  const { body, subject } = await params;
  const pillar = loadSEOSubjectPillar(body as ExamBodySlug, subject);

  if (!pillar) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <p className="text-sm text-on-surface-variant">Subject not found.</p>
      </main>
    );
  }

  const playStoreUrl = STORE_CONFIG.getTrackedPlayStoreUrl(
    'seo_pillar',
    pillar.body,
    pillar.subjectSlug,
  );

  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Practice', url: 'https://renance.app/practice/' },
    { name: pillar.bodyTitle, url: `https://renance.app/practice/${pillar.body}/` },
    { name: pillar.subjectTitle, url: pillar.canonicalUrl },
  ]);

  const yearRangeDisplay =
    pillar.availableYears.length > 0
      ? `from ${pillar.availableYears.at(-1)} to ${pillar.availableYears[0]}`
      : 'recently updated';

  const faqSchema = buildFAQSchema([
    {
      q: `How many ${pillar.bodyTitle} ${pillar.subjectTitle} past questions are on Renance?`,
      a: `Renance has ${pillar.totalBankedQuestions.toLocaleString()} ${pillar.bodyTitle} ${pillar.subjectTitle} past questions spanning ${pillar.availableYears.length} years — all free with full explanations.`,
    },
    {
      q: `What years of ${pillar.bodyTitle} ${pillar.subjectTitle} past questions are available?`,
      a: `Renance covers ${pillar.bodyTitle} ${pillar.subjectTitle} past questions ${yearRangeDisplay}.`,
    },
    {
      q: `Is ${pillar.bodyTitle} ${pillar.subjectTitle} hard?`,
      a: `Consistent practice with past questions is the most reliable way to prepare. Renance gives you all ${pillar.totalBankedQuestions.toLocaleString()} questions in an interactive CBT environment with instant feedback — completely free.`,
    },
  ]);

  // The newest three years get a "Popular" badge
  const recentYears = new Set(pillar.availableYears.slice(0, 3));

  return (
    <>
      {/* ── JSON-LD ── */}
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
            <Link href={`/practice/${pillar.body}/`} className="hover:text-primary transition-colors capitalize">{pillar.bodyTitle}</Link>
            <span>/</span>
            <span className="text-on-surface font-medium">{pillar.subjectTitle}</span>
          </nav>

          {/* ── Hero ── */}
          <header className="mb-8">
            <span className="mb-3 inline-flex h-7 items-center rounded-full bg-primary/10 px-3 text-xs font-semibold text-primary uppercase tracking-wider">
              {pillar.bodyTitle}
            </span>
            <h1 className="text-2xl font-bold text-on-surface sm:text-3xl">
              {pillar.bodyTitle} {pillar.subjectTitle} Past Questions
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant">
              {pillar.totalBankedQuestions.toLocaleString()} questions ·{' '}
              {pillar.availableYears.length} years
              {pillar.availableYears.length > 0
                ? ` · ${pillar.availableYears.at(-1)}–${pillar.availableYears[0]}`
                : ''}
            </p>
          </header>

          {/* ── Stats row ── */}
          <div className="mb-8 grid grid-cols-3 gap-3">
            {[
              { label: 'Total Questions', value: pillar.totalBankedQuestions.toLocaleString() },
              { label: 'Years Covered', value: pillar.availableYears.length },
              { label: 'Free Access', value: '100%' },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-2xl border border-outline-variant bg-card p-4 text-center">
                <p className="text-xl font-bold text-on-surface">{value}</p>
                <p className="mt-0.5 text-[11px] text-on-surface-variant">{label}</p>
              </div>
            ))}
          </div>

          {/* ── Year grid ── */}
          <section aria-label="Available years">
            <h2 className="mb-4 text-base font-semibold text-on-surface">
              Select a Year
            </h2>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              {pillar.availableYears.map((year) => (
                <Link
                  key={year}
                  href={`/practice/${pillar.body}/${pillar.subjectSlug}/${year}/`}
                  className="group relative flex items-center justify-between rounded-2xl border border-outline-variant bg-card px-4 py-3.5 transition hover:border-primary hover:bg-primary/5 active:scale-[0.98]"
                >
                  <span className="text-sm font-semibold text-on-surface group-hover:text-primary">
                    {year}
                  </span>
                  {recentYears.has(year) && (
                    <span className="rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-bold text-primary">
                      Popular
                    </span>
                  )}
                  <span className="material-symbols-outlined ml-2 text-[16px] text-on-surface-variant group-hover:text-primary">
                    chevron_right
                  </span>
                </Link>
              ))}
            </div>
          </section>

          {/* ── Syllabus themes ── */}
          {pillar.syllabusThemes.length > 0 && (
            <section aria-label="Syllabus topics" className="mt-10">
              <h2 className="mb-3 text-base font-semibold text-on-surface">
                Topics Covered
              </h2>
              <div className="flex flex-wrap gap-2">
                {pillar.syllabusThemes.map((theme) => (
                  <span
                    key={theme}
                    className="rounded-full border border-outline-variant bg-surface-container px-3 py-1 text-xs text-on-surface-variant"
                  >
                    {theme}
                  </span>
                ))}
              </div>
            </section>
          )}

          {/* ── Dual Platform Footer CTA (Web + Play Store) ── */}
          <div className="mt-10 rounded-2xl border border-outline-variant bg-card p-6 text-center">
            <p className="text-base font-bold text-on-surface mb-1">
              Ready to practice all {pillar.totalBankedQuestions.toLocaleString()} questions?
            </p>
            <p className="text-xs text-on-surface-variant mb-5 max-w-md mx-auto">
              Access the complete bank with step-by-step explanations on the <strong>Web App</strong> right now, or download the <strong>Android App</strong> for offline study.
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3">
              <Link
                href={`/study-past-questions/reader?body=${pillar.body}&subject=${pillar.subjectSlug}&bank=${pillar.body}-${pillar.subjectSlug}-bank`}
                className="inline-flex h-11 items-center justify-center rounded-xl bg-primary px-6 text-sm font-semibold text-on-primary shadow-sm transition hover:opacity-95 active:scale-[0.98]"
              >
                <span className="material-symbols-outlined mr-2 text-[18px]">laptop_mac</span>
                Practice on Web (Free)
              </Link>
              <a
                href={playStoreUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex h-11 items-center justify-center rounded-xl border border-outline-variant bg-card px-5 text-sm font-medium text-on-surface transition hover:bg-surface-container active:scale-[0.98]"
              >
                <PlayStoreIcon className="mr-2 h-4 w-4 shrink-0" />
                Get Android App (Offline)
              </a>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
