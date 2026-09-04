import type { Metadata } from 'next';
import Link from 'next/link';
import { loadSyllabi } from '@/lib/site-data';

/**
 * /subjects, the public syllabus index: every exam body we support, its
 * subjects and topic counts. This is the crawlable directory that tells
 * search engines (and students) exactly what Renance covers.
 */

export const dynamic = 'force-static';

import { SITE_URL } from '@/lib/site-url';

export const metadata: Metadata = {
  title: 'Subjects & syllabus coverage | JAMB, WAEC, NECO & university modules',
  description:
    'Every subject and topic Renance covers for JAMB, WAEC, NECO and university modules. Browse the syllabus trees, then practise each topic with server-graded CBT papers in the Renance app.',
  alternates: { canonical: '/subjects/' },
  openGraph: {
    title: 'Subjects & syllabus coverage · Renance',
    description:
      'Every subject and topic Renance covers for JAMB, WAEC, NECO and university modules.',
    url: `${SITE_URL}/subjects/`,
  },
};

export default function SubjectsPage() {
  const syllabi = loadSyllabi();
  return (
    <main className="mx-auto w-full max-w-5xl px-4 pb-20 pt-10 sm:px-6">
      <header className="max-w-2xl">
        <p className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
          Renance coverage
        </p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight text-on-surface sm:text-4xl">
          Subjects &amp; syllabus coverage
        </h1>
        <p className="mt-3 text-[15px] leading-relaxed text-on-surface-variant">
          Renance maps every mock paper to the official syllabus, topic by topic.
          Practise a paper and the app shows exactly which syllabus topics your
          answers touched, and which ones need another pass.
        </p>
      </header>

      <div className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-2">
        {syllabi.map((syl) => {
          const topicCount = syl.subjects.reduce(
            (n, s) => n + s.sections.reduce((m, sec) => m + sec.topics.length, 0),
            0,
          );
          return (
            <section
              key={syl.body}
              className="rounded-xl bg-card p-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
            >
              <div className="flex items-baseline justify-between gap-3">
                <h2 className="text-2xl font-bold tracking-tight text-on-surface">{syl.body}</h2>
                <span className="font-mono text-xs text-on-surface-variant">
                  {syl.subjects.length} subjects · {topicCount} topics
                </span>
              </div>
              <ul className="mt-4 space-y-2.5">
                {syl.subjects.map((s) => (
                  <li key={s.subject} className="text-[15px] text-on-surface">
                    <span className="font-medium">{s.subject}</span>
                    <span className="ml-2 font-mono text-xs text-on-surface-variant">
                      {s.sections.length} sections ·{' '}
                      {s.sections.reduce((m, sec) => m + sec.topics.length, 0)} topics
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          );
        })}
      </div>

      <footer className="mt-12 rounded-xl bg-surface-container-low p-6 text-center">
        <p className="text-sm text-on-surface-variant">
          Every topic above can appear in your mock papers and your review queue.
        </p>
        <div className="mt-4 flex flex-wrap items-center justify-center gap-3">
          <Link
            href="/lessons/"
            className="inline-flex h-12 items-center justify-center rounded-[10px] bg-primary px-8 text-sm font-semibold text-on-primary transition hover:opacity-90"
          >
            Browse lessons
          </Link>
          <Link
            href="/register/"
            className="inline-flex h-12 items-center justify-center rounded-[10px] bg-surface-container-high px-8 text-sm font-semibold text-on-surface transition hover:opacity-90"
          >
            Start practising free
          </Link>
        </div>
      </footer>
    </main>
  );
}
