import type { Metadata } from 'next';
import Link from 'next/link';
import { loadLessons } from '@/lib/site-data';
import { renderInline } from '@/lib/inline';

/**
 * /lessons, the public lesson library (ROADMAP #8). Fully static:
 * content comes from data/lessons/*.json at build time, so every lesson
 * is crawlable, cacheable and free to serve: the SEO backbone.
 */

export const dynamic = 'force-static';

import { SITE_URL } from '@/lib/site-url';

export const metadata: Metadata = {
  title: 'Lessons | exam-ready study notes for JAMB, WAEC & NECO',
  description:
    'Free, exam-focused lessons from Renance: biology, physics, English and more, written for Nigerian students preparing JAMB, WAEC and NECO, with the key points examiners actually test.',
  alternates: { canonical: '/lessons/' },
  openGraph: {
    title: 'Lessons | exam-ready study notes for JAMB, WAEC & NECO · Renance',
    description:
      'Free, exam-focused lessons written for Nigerian students preparing JAMB, WAEC and NECO.',
    url: `${SITE_URL}/lessons/`,
  },
};

export default function LessonsIndex() {
  const lessons = loadLessons();
  return (
    <main className="mx-auto w-full max-w-5xl px-4 pb-20 pt-6 sm:px-6">
      <Link
        href="/dashboard/"
        aria-label="Go back"
        className="mb-2 inline-flex h-10 w-10 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
      >
        <span className="material-symbols-outlined text-[22px]">arrow_back</span>
      </Link>
      <header className="max-w-2xl">
        <p className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
          Renance Lessons
        </p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight text-on-surface sm:text-4xl">
          Exam-ready notes, written the way examiners ask
        </h1>
        <p className="mt-3 text-[15px] leading-relaxed text-on-surface-variant">
          Every lesson distils one syllabus topic into the definitions, lists and
          key points that score marks. Read here in minutes, then practise the
          matching paper in the Renance app.
        </p>
      </header>

      <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {lessons.map((les) => (
          <Link
            key={les.slug}
            href={`/lessons/${les.slug}/`}
            className="group flex flex-col rounded-xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition hover:shadow-md"
          >
            <div className="flex items-center gap-2">
              {les.subject && (
                <span className="rounded-full bg-selection-blue px-2.5 py-0.5 text-[11px] font-medium text-on-surface">
                  {les.subject}
                </span>
              )}
              {les.body && (
                <span className="rounded-full bg-surface-container-low px-2.5 py-0.5 text-[11px] text-on-surface-variant">
                  {les.body}
                </span>
              )}
            </div>
            <h2 className="mt-3 text-lg font-semibold leading-snug text-on-surface group-hover:underline">
              {les.title}
            </h2>
            <p className="mt-2 line-clamp-3 text-[13px] leading-relaxed text-on-surface-variant">
              {renderInline(les.summary)}
            </p>
            <span className="mt-auto pt-4 font-mono text-xs text-on-surface-variant">
              {les.minutes} min read →
            </span>
          </Link>
        ))}
        {lessons.length === 0 && (
          <p className="col-span-full rounded-xl bg-card p-8 text-center text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            Lessons are being typeset, check back shortly.
          </p>
        )}
      </div>

      <footer className="mt-12 rounded-xl bg-surface-container-low p-6 text-center">
        <p className="text-sm text-on-surface-variant">
          Renance turns reading into marks: mock CBT papers, spaced review and an
          exam-technique tutor, free for students.
        </p>
        <Link
          href="/register/"
          className="mt-4 inline-flex h-12 items-center justify-center rounded-[10px] bg-primary px-8 text-sm font-semibold text-on-primary transition hover:opacity-90"
        >
          Create your free account
        </Link>
      </footer>
    </main>
  );
}
