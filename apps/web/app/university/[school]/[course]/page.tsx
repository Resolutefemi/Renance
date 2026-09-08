import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { loadCatalog, loadSchool, loadSchools } from '@/lib/university-data';
import { CoursePractice } from './course-practice';

/**
 * /university/[school]/[course] — one course's practice desk, baked at
 * build time for every course that ships a question bank. Mirrors the
 * school's CBT portal logic: Part chunks of 50 questions in original
 * order, Random Mode shuffles, count + timer picks and the course PDF.
 */

export const dynamic = 'force-static';

export function generateStaticParams() {
  const params: Array<{ school: string; course: string }> = [];
  for (const school of loadSchools()) {
    const catalog = loadCatalog(school.slug);
    for (const course of catalog?.courses ?? []) {
      if (course.bank) params.push({ school: school.slug, course: course.slug });
    }
  }
  return params;
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ school: string; course: string }>;
}): Promise<Metadata> {
  const { school: schoolSlug, course: courseSlug } = await params;
  const school = loadSchool(schoolSlug);
  const course = loadCatalog(schoolSlug)?.courses.find((c) => c.slug === courseSlug);
  if (!school || !course) return { title: 'Course not found | Renance' };
  const label = course.title ? `${course.code} — ${course.title}` : course.code;
  return {
    title: `${school.short} ${label} past questions`,
    description: `Practice ${school.short} ${label} with ${course.questionCount.toLocaleString()} real past questions: Part chunks, random mode, instant grading and explanations.`,
    alternates: { canonical: `/university/${school.slug}/${course.slug}/` },
  };
}

export default async function CoursePage({
  params,
}: {
  params: Promise<{ school: string; course: string }>;
}) {
  const { school: schoolSlug, course: courseSlug } = await params;
  const school = loadSchool(schoolSlug);
  const course = loadCatalog(schoolSlug)?.courses.find((c) => c.slug === courseSlug);
  if (!school || !course || !course.bank) notFound();
  return <CoursePractice school={school} course={course} />;
}
