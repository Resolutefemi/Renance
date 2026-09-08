'use client';

/**
 * UniversityCourseDesk — the school's course home (the FUTA student
 * interface). Black-and-white Renance language, course-based vocabulary
 * and its own icon set; every course card opens the practice desk that
 * mirrors the school's CBT portal: Part chunks of 50, Random Mode and
 * course PDF materials.
 */

import { useMemo, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import type { School, SchoolCatalog, UniversityCourse } from '@/lib/university-data';

export function UniversityCourseDesk({
  school,
  catalog,
}: {
  school: School;
  catalog: SchoolCatalog;
}) {
  const [semester, setSemester] = useState<1 | 2>(1);

  const courses = useMemo(
    () => catalog.courses.filter((c) => c.semester === semester),
    [catalog, semester],
  );
  const live = catalog.courses.filter((c) => c.bank);
  const totalQuestions = live.reduce((n, c) => n + c.questionCount, 0);
  const withPdfs = catalog.courses.filter((c) => c.pdf);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-60">
      <PageBar title={`${school.short} Desk`} backHref="/university" />

      <div className="mx-auto w-full max-w-5xl px-4 py-5 sm:px-6">
        {/* School hero ------------------------------------------------ */}
        <section className="relative overflow-hidden rounded-xl bg-hero p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] sm:p-6">
          <div className="absolute -right-14 -top-14 h-36 w-36 rounded-full bg-on-hero/10" />
          <p className="relative z-10 font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-hero-muted">
            {school.type === 'university'
              ? 'University Desk'
              : school.type === 'polytechnic'
                ? 'Polytechnic Desk'
                : 'College of Education Desk'}
          </p>
          <h2 className="relative z-10 mt-1 text-2xl font-bold tracking-tight text-on-hero sm:text-3xl">
            {school.name}
          </h2>
          <div className="relative z-10 mt-4 flex gap-6">
            <div>
              <p className="font-mono text-xl font-bold text-on-hero">{live.length}</p>
              <p className="text-xs text-hero-muted">Courses</p>
            </div>
            <div>
              <p className="font-mono text-xl font-bold text-on-hero">
                {totalQuestions.toLocaleString()}
              </p>
              <p className="text-xs text-hero-muted">Questions</p>
            </div>
            <div>
              <p className="font-mono text-xl font-bold text-on-hero">{withPdfs.length}</p>
              <p className="text-xs text-hero-muted">PDF Materials</p>
            </div>
          </div>
        </section>

        {/* Semester switch --------------------------------------------- */}
        <div className="mt-6 flex items-center gap-2">
          {([1, 2] as const).map((sem) => (
            <button
              key={sem}
              type="button"
              onClick={() => setSemester(sem)}
              className={`rounded-full px-5 py-2 text-sm transition ${
                semester === sem
                  ? 'bg-primary font-semibold text-on-primary shadow-sm'
                  : 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container'
              }`}
            >
              {sem === 1 ? 'First Semester' : 'Second Semester'}
            </button>
          ))}
        </div>

        {/* Course grid -------------------------------------------------- */}
        <h3 className="mt-5 text-sm font-semibold text-on-surface">Courses</h3>
        <ul className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {courses.map((c) => (
            <CourseCard key={c.slug} course={c} school={school} />
          ))}
        </ul>

        {/* PDF materials ------------------------------------------------ */}
        {withPdfs.length > 0 && (
          <>
            <h3 className="mt-8 text-sm font-semibold text-on-surface">Course Materials</h3>
            <p className="text-xs text-on-surface-variant">
              Study notes and lecture PDFs for {school.short} courses.
            </p>
            <ul className="mt-3 grid gap-2 sm:grid-cols-2">
              {withPdfs.map((c) => (
                <li key={c.slug}>
                  <a
                    href={c.pdf!}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 rounded-xl border border-outline-variant bg-card p-3 transition hover:border-outline"
                  >
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-surface-container text-on-surface">
                      <span className="material-symbols-outlined text-[20px]">picture_as_pdf</span>
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold text-on-surface">
                        {c.code}
                        {c.title ? ` — ${c.title}` : ''}
                      </p>
                      <p className="text-xs text-on-surface-variant">PDF · opens in a new tab</p>
                    </div>
                    <span className="material-symbols-outlined text-on-surface-variant">open_in_new</span>
                  </a>
                </li>
              ))}
            </ul>
          </>
        )}
      </div>
      <SideNav />
      <BottomNav />
    </main>
  );
}

function CourseCard({ course, school }: { course: UniversityCourse; school: School }) {
  const body = (
    <>
      <div
        className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ${
          course.bank ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
        }`}
      >
        <span className="material-symbols-outlined text-[22px]">{course.icon}</span>
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-bold text-on-surface">{course.code}</p>
        <p className="truncate text-xs text-on-surface-variant">
          {course.title ?? 'Course practice'}
        </p>
        <p className="mt-1 font-mono text-[11px] text-on-surface-variant">
          {course.bank ? `${course.questionCount.toLocaleString()} questions` : 'coming soon'}
        </p>
      </div>
      {course.bank ? (
        <span className="material-symbols-outlined text-on-surface-variant">chevron_right</span>
      ) : (
        <span className="material-symbols-outlined text-on-surface-variant">hourglass_empty</span>
      )}
    </>
  );
  const cls =
    'flex w-full items-center gap-3 rounded-xl border border-outline-variant bg-card p-3 text-left transition';
  if (course.bank) {
    return (
      <li>
        <Link
          href={`/university/${school.slug}/${course.slug}`}
          className={`${cls} hover:border-outline hover:shadow-sm`}
        >
          {body}
        </Link>
      </li>
    );
  }
  return (
    <li>
      <div className={`${cls} opacity-60`} aria-disabled>
        {body}
      </div>
    </li>
  );
}
