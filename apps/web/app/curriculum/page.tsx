import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import { getAvailableCurriculumClasses } from '@/lib/seo-data';
import { buildBreadcrumbSchema, serializeJsonLd } from '@/lib/seo-schema';

/**
 * /curriculum
 *
 * NERDC Curriculum & Scheme of Work Hub.
 * Pre-renders entry points for all classes (Primary 1 to SSS 2).
 */

export const dynamic = 'force-static';

export const metadata: Metadata = {
  title: 'NERDC Curriculum & Schemes of Work - Primary to Senior Secondary',
  description:
    'Free official Nigerian NERDC curriculum and approved schemes of work for Primary, JSS, and SSS classes. ' +
    'Week-by-week lesson topics, learning objectives, and curriculum breakdown on Renance.',
  keywords: [
    'NERDC curriculum Nigeria',
    'scheme of work Nigeria',
    'SSS scheme of work',
    'JSS scheme of work',
    'Primary school scheme of work Nigeria',
    'NERDC approved syllabus',
  ],
  alternates: { canonical: 'https://renance.app/curriculum/' },
  openGraph: {
    type: 'website',
    title: 'NERDC Curriculum & Schemes of Work',
    description:
      'Official Nigerian educational curriculum and week-by-week approved schemes of work for teachers and students.',
    url: 'https://renance.app/curriculum/',
    images: [...OG_IMAGES],
  },
};

export default function CurriculumHubPage() {
  const classes = getAvailableCurriculumClasses();

  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Curriculum', url: 'https://renance.app/curriculum/' },
  ]);

  return (
    <>
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
            <span className="text-on-surface font-medium">Curriculum & Schemes</span>
          </nav>

          {/* ── Hero ── */}
          <header className="mb-10 text-center">
            <div className="mb-3 text-4xl">📖</div>
            <h1 className="text-3xl font-bold text-on-surface sm:text-4xl">
              NERDC Curriculum & Schemes of Work
            </h1>
            <p className="mt-3 text-sm text-on-surface-variant max-w-lg mx-auto leading-relaxed">
              Official statutory Nigerian educational curriculum from Primary 1 to Senior Secondary 2.
              Access week-by-week schemes of work, learning themes, and topic guides approved by NERDC.
            </p>
          </header>

          {/* ── Class Grid ── */}
          <section aria-label="Class levels">
            <h2 className="mb-4 text-base font-semibold text-on-surface">
              Select Your Class Level
            </h2>

            <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-2">
              {classes.map((c) => (
                <Link
                  key={c.classLevel}
                  href={`/curriculum/${c.classLevel}/`}
                  className="group flex items-center justify-between rounded-2xl border border-outline-variant bg-card p-4 transition hover:border-primary hover:bg-primary/5 active:scale-[0.98]"
                >
                  <div>
                    <p className="font-semibold text-on-surface group-hover:text-primary">
                      {c.classTitle}
                    </p>
                    <p className="mt-0.5 text-xs text-on-surface-variant">
                      {c.documentCount} statutory subjects
                    </p>
                  </div>
                  <span className="material-symbols-outlined text-[20px] text-on-surface-variant group-hover:text-primary">
                    chevron_right
                  </span>
                </Link>
              ))}
            </div>
          </section>

          {/* ── Context for teachers & students ── */}
          <div className="mt-10 rounded-2xl border border-outline-variant bg-card p-5">
            <div className="flex items-start gap-3">
              <span className="material-symbols-outlined text-primary text-[24px]">verified</span>
              <div>
                <h3 className="text-sm font-semibold text-on-surface">
                  Statutory Educational Standard
                </h3>
                <p className="mt-1 text-xs text-on-surface-variant leading-relaxed">
                  All schemes of work on Renance are sourced directly from the Nigerian Educational Research and Development Council (NERDC). 
                  Teachers and school administrators can use these schemes for academic planning and term breakdown.
                </p>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
