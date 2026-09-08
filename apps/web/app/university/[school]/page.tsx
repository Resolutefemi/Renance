import type { Metadata } from 'next';
import Link from 'next/link';
import { loadCatalog, loadSchool, loadSchools } from '@/lib/university-data';
import { UniversityCourseDesk } from './course-desk';

/**
 * /university/[school] — one school's course desk, baked at build time.
 * Schools with a live library (FUTA today) render their full course
 * grid; every other school renders an honest "content not wrapped yet"
 * state, same interface, no fake content.
 */

export const dynamic = 'force-static';

export function generateStaticParams() {
  return loadSchools().map((s) => ({ school: s.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ school: string }>;
}): Promise<Metadata> {
  const { school: slug } = await params;
  const school = loadSchool(slug);
  if (!school) return { title: 'School not found | Renance' };
  return {
    title: `${school.name} — course practice desk`,
    description: `Practice ${school.short} courses with real past questions: CBT player, Part chunks, random mode, instant grading and course PDF materials on Renance.`,
    alternates: { canonical: `/university/${school.slug}/` },
  };
}

export default async function SchoolPage({
  params,
}: {
  params: Promise<{ school: string }>;
}) {
  const { school: slug } = await params;
  const school = loadSchool(slug);
  const catalog = loadCatalog(slug);

  if (!school) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container-lowest">
        <p className="text-sm text-on-surface-variant">School not found.</p>
      </main>
    );
  }

  if (!catalog || catalog.courses.every((c) => !c.bank)) {
    return (
      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-60">
        <div className="mx-auto w-full max-w-5xl px-4 py-14 sm:px-6">
          <div className="mx-auto max-w-md rounded-2xl border border-outline-variant bg-card p-8 text-center">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-container">
              <span className="material-symbols-outlined text-[28px] text-on-surface-variant">
                hourglass_empty
              </span>
            </div>
            <h1 className="mt-4 text-xl font-bold text-on-surface">{school.name}</h1>
            <p className="mt-2 text-sm text-on-surface-variant">
              The {school.short} desk is live in the app, but its course question banks and PDF
              materials are not wrapped yet. One interface for every school — content lands per
              school as it is harvested.
            </p>
            <Link
              href="/university"
              className="mt-6 inline-flex h-11 items-center justify-center rounded-xl bg-primary px-6 text-sm font-semibold text-on-primary transition active:scale-[0.98]"
            >
              Back to schools
            </Link>
          </div>
        </div>
      </main>
    );
  }

  return <UniversityCourseDesk school={school} catalog={catalog} />;
}
