'use client';

/**
 * NotesClient, the personal notes shelf. The school/exam scope comes
 * from the signed-in profile (university students get their school's
 * course PDFs, exam candidates get their body's notes), so a FUTA
 * student never sees another school's materials and vice versa.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { api, withBase } from '@/lib/api';
import { clientCatalog, resolveSchoolSlug, SCHOOLS } from '@/lib/university';
import type { UniversityCourse } from '@/lib/university-data';

interface LessonCard {
  slug: string;
  title: string;
  subject: string;
  body: string;
  summary: string;
  minutes: number;
}

interface Profile {
  fullName: string;
  institution: string;
  gradeLevel: string;
  exams: string[];
  targetYear?: number;
  completed: boolean;
}

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: Profile | null;
}

export function NotesClient({ lessons }: { lessons: LessonCard[] }) {
  const [scope, setScope] = useState<string | null>(null);
  const [schoolSlug, setSchoolSlug] = useState<string>('futa');

  useEffect(() => {
    let alive = true;
    api<MeResponse>('/me')
      .then((me) => {
        if (!alive) return;
        const target = me.profile?.exams?.[0] ?? null;
        setScope(target);
        if (target === 'University Modules') {
          const stored = resolveSchoolSlug();
          setSchoolSlug(stored);
        }
      })
      .catch(() => {
        /* signed out: the exam shelf below still renders */
      });
    return () => {
      alive = false;
    };
  }, []);

  const isUniversity = scope === 'University Modules';
  const school = useMemo(() => SCHOOLS.find((s) => s.slug === schoolSlug) ?? null, [schoolSlug]);
  const catalog = useMemo(() => clientCatalog(schoolSlug), [schoolSlug]);
  const pdfCourses: UniversityCourse[] = useMemo(
    () => catalog?.courses.filter((c) => c.pdf) ?? [],
    [catalog],
  );
  const bankedNoPdf: UniversityCourse[] = useMemo(
    () => catalog?.courses.filter((c) => c.bank && !c.pdf) ?? [],
    [catalog],
  );

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="Notes" />

      <div className="mx-auto w-full max-w-3xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          {isUniversity ? `${school?.short ?? 'Your school'} notes` : 'Exam notes'}
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          {isUniversity
            ? `Course materials and study notes for ${school?.name ?? 'your school'} courses, matched to the course quizzes on your desk.`
            : 'Exam-focused notes for your subjects: the definitions, lists and key points that score marks.'}
        </p>

        {/* University shelf: the school's own course PDFs ------------------ */}
        {isUniversity && (
          <section className="mt-6">
            <h2 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
              Course materials · {school?.short}
            </h2>
            {pdfCourses.length > 0 ? (
              <ul className="mt-3 grid gap-2 sm:grid-cols-2">
                {pdfCourses.map((c) => (
                  <li key={c.slug}>
                    <a
                      href={withBase(c.pdf!)}
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
                          {c.title ? ` · ${c.title}` : ''}
                        </p>
                        <p className="text-xs text-on-surface-variant">Study notes (PDF)</p>
                      </div>
                      <span className="material-symbols-outlined text-on-surface-variant">open_in_new</span>
                    </a>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-3 rounded-xl bg-card p-5 text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                No course PDFs have shipped for {school?.short ?? 'your school'} yet. When they
                land they appear here, scoped to your school only.
              </p>
            )}

            {bankedNoPdf.length > 0 && (
              <>
                <h3 className="mt-6 text-sm font-semibold text-on-surface">
                  Courses waiting on notes
                </h3>
                <p className="text-xs text-on-surface-variant">
                  The quizzes are live; the PDFs are being typeset.
                </p>
                <div className="mt-3 flex flex-wrap gap-2">
                  {bankedNoPdf.map((c) => (
                    <Link
                      key={c.slug}
                      href={`/university/${schoolSlug}/${c.slug}/`}
                      className="rounded-full bg-surface-container px-3 py-1.5 font-mono text-[11px] text-on-surface-variant transition hover:bg-surface-container-high hover:text-on-surface"
                    >
                      {c.code}
                    </Link>
                  ))}
                </div>
              </>
            )}
          </section>
        )}

        {/* Exam shelf: subject notes -------------------------------------- */}
        {!isUniversity && (
          <section className="mt-6">
            <h2 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
              {scope ? `${scope} · subject notes` : 'Subject notes'}
            </h2>
            <div className="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2">
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
                  <h3 className="mt-3 text-lg font-semibold leading-snug text-on-surface group-hover:underline">
                    {les.title}
                  </h3>
                  <p className="mt-2 line-clamp-3 text-[13px] leading-relaxed text-on-surface-variant">
                    {les.summary}
                  </p>
                  <span className="mt-auto pt-4 font-mono text-xs text-on-surface-variant">
                    {les.minutes} min read →
                  </span>
                </Link>
              ))}
            </div>
            {lessons.length === 0 && (
              <p className="mt-3 rounded-xl bg-card p-5 text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                Notes are being typeset. Check back shortly.
              </p>
            )}
            <p className="mt-4 text-sm text-on-surface-variant">
              The full public library lives at{' '}
              <Link href="/lessons/" className="font-semibold text-on-surface underline underline-offset-4">
                Lessons
              </Link>
              .
            </p>
          </section>
        )}

        {/* Signed-out hint: point at the desk instead of selling ---------- */}
        {!scope && (
          <p className="mt-8 text-sm text-on-surface-variant">
            Set your target exam in your profile and this shelf re-scopes to your school or exam
            body automatically.
          </p>
        )}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
