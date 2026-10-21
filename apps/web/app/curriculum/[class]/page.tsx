import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import {
  getAvailableCurriculumClassParams,
  getCurriculumSubjectsForClass,
} from '@/lib/seo-data';
import { buildBreadcrumbSchema, serializeJsonLd } from '@/lib/seo-schema';

/**
 * /curriculum/[class]
 *
 * Subject list for a specific NERDC class level.
 * e.g., /curriculum/sss1/ lists all SS1 subjects (English, Math, Physics, etc.).
 */

export const dynamic = 'force-static';

const CLASS_TITLE_MAP: Record<string, string> = {
  pry1: 'Primary 1',
  pry2: 'Primary 2',
  pry4: 'Primary 4',
  pry5: 'Primary 5',
  jss1: 'Junior Secondary 1',
  jss2: 'Junior Secondary 2',
  sss1: 'Senior Secondary 1',
  sss2: 'Senior Secondary 2',
  sss3: 'Senior Secondary 3',
};

export function generateStaticParams() {
  return getAvailableCurriculumClassParams().map((c) => ({ class: c.classLevel }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ class: string }>;
}): Promise<Metadata> {
  const { class: classLevel } = await params;
  const classTitle = CLASS_TITLE_MAP[classLevel] ?? classLevel.toUpperCase();

  const title = `${classTitle} Scheme of Work & NERDC Curriculum`;
  const description =
    `Official NERDC approved ${classTitle} scheme of work for all subjects. ` +
    `Week-by-week topic breakdown for 1st Term, 2nd Term, and 3rd Term. Free on Renance.`;

  return {
    title,
    description,
    keywords: [
      `${classTitle} scheme of work`,
      `${classTitle} curriculum Nigeria`,
      `${classTitle} NERDC syllabus`,
      `${classTitle} subjects term breakdown`,
    ],
    alternates: { canonical: `https://renance.app/curriculum/${classLevel}/` },
    openGraph: {
      type: 'website',
      title,
      description,
      url: `https://renance.app/curriculum/${classLevel}/`,
      images: [...OG_IMAGES],
    },
  };
}

export default async function ClassCurriculumPage({
  params,
}: {
  params: Promise<{ class: string }>;
}) {
  const { class: classLevel } = await params;
  const classTitle = CLASS_TITLE_MAP[classLevel] ?? classLevel.toUpperCase();
  const subjects = getCurriculumSubjectsForClass(classLevel);

  const breadcrumbSchema = buildBreadcrumbSchema([
    { name: 'Home', url: 'https://renance.app/' },
    { name: 'Curriculum', url: 'https://renance.app/curriculum/' },
    { name: classTitle, url: `https://renance.app/curriculum/${classLevel}/` },
  ]);

  if (subjects.length === 0) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <p className="text-sm text-on-surface-variant">Class curriculum not found.</p>
      </main>
    );
  }

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
            <Link href="/curriculum/" className="hover:text-primary transition-colors">Curriculum</Link>
            <span>/</span>
            <span className="text-on-surface font-medium">{classTitle}</span>
          </nav>

          {/* ── Header ── */}
          <header className="mb-8">
            <span className="mb-2 inline-flex h-7 items-center rounded-full bg-primary/10 px-3 text-xs font-semibold text-primary uppercase tracking-wider">
              NERDC Approved
            </span>
            <h1 className="text-2xl font-bold text-on-surface sm:text-3xl">
              {classTitle} Scheme of Work
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant">
              Explore weekly lesson plans and statutory topics across {subjects.length} subjects for {classTitle}.
            </p>
          </header>

          {/* ── Subject Grid ── */}
          <section aria-label={`${classTitle} subjects`}>
            <h2 className="mb-4 text-base font-semibold text-on-surface">
              Choose a Subject
            </h2>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              {subjects.map((sub) => (
                <Link
                  key={sub.subjectSlug}
                  href={`/curriculum/${classLevel}/${sub.subjectSlug}/first-term/`}
                  className="group flex items-center justify-between rounded-2xl border border-outline-variant bg-card p-4 transition hover:border-primary hover:bg-primary/5 active:scale-[0.98]"
                >
                  <div className="flex-1 min-w-0 pr-2">
                    <p className="font-semibold text-sm text-on-surface group-hover:text-primary truncate">
                      {sub.subjectTitle}
                    </p>
                    <p className="mt-0.5 text-xs text-on-surface-variant">
                      1st, 2nd & 3rd Term
                    </p>
                  </div>
                  <span className="material-symbols-outlined text-[18px] text-on-surface-variant group-hover:text-primary shrink-0">
                    chevron_right
                  </span>
                </Link>
              ))}
            </div>
          </section>
        </div>
      </main>
    </>
  );
}
