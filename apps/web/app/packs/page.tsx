'use client';

/**
 * Question Pack, the small launcher behind the packs — focus-aware
 * (founder directive, 2026-09): a student sees THEIR exam's packs, not
 * the whole archive. The WAEC candidate's bank is the WAEC shelf, the
 * university student lands on their own school's courses, and the
 * JAMBite sees the UTME shelf. Learning focus lives on the Profile
 * screen and the packs page follows it.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import { fetchManifest, type ExamMeta } from '@/lib/exams';
import { api } from '@/lib/api';
import { SCHOOLS, findSchoolByName, storedSchoolSlug, type School } from '@/lib/university';

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: { exams: string[]; institution?: string } | null;
}

interface PackGroup {
  key: string;
  label: string;
  packs: ExamMeta[];
}

function focusOf(profile: MeResponse['profile']): string | null {
  const exam = profile?.exams?.[0];
  if (!exam) return null;
  if (/jamb/i.test(exam)) return 'JAMB';
  if (/waec/i.test(exam)) return 'WAEC';
  if (/neco/i.test(exam)) return 'NECO';
  if (/university/i.test(exam)) return 'University Modules';
  return exam;
}

/** School slug encoded in a university pack code (uni-<school>-…, <school>-post-utme…). */
function schoolSlugOf(code: string): string | null {
  if (code.startsWith('uni-')) {
    const stem = code.slice(4).replace(/-bank$/, '');
    const dash = stem.indexOf('-');
    return dash > 0 ? stem.slice(0, dash) : stem || null;
  }
  if (code.includes('-post-utme')) {
    return code.split('-post-utme')[0] || null;
  }
  return null;
}

export default function PacksPage() {
  const [exams, setExams] = useState<ExamMeta[] | null>(null);
  const [focus, setFocus] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const [manifest, me] = await Promise.all([
          fetchManifest(),
          api<MeResponse>('/me').catch(() => null),
        ]);
        if (!alive) return;
        setExams(manifest.exams);
        setFocus(focusOf(me?.profile ?? null));
      } catch {
        if (alive) setFailed(true);
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  // The student's school for university desks: stored pick → profile
  // institution match (same resolution the dashboard uses).
  const [uniSchool, setUniSchool] = useState<School | null>(null);
  useEffect(() => {
    if (focus !== 'University Modules') return;
    let alive = true;
    (async () => {
      const slug = storedSchoolSlug();
      if (slug) {
        const hit = SCHOOLS.find((s) => s.slug === slug);
        if (hit && alive) {
          setUniSchool(hit);
          return;
        }
      }
      try {
        const me = await api<MeResponse>('/me');
        const matched = me.profile?.institution ? findSchoolByName(me.profile.institution) : null;
        if (alive) setUniSchool(matched);
      } catch {
        /* anonymous: no school pin */
      }
    })();
    return () => {
      alive = false;
    };
  }, [focus, exams]);

  const groups = useMemo<PackGroup[]>(() => {
    if (!exams) return [];
    const isUni = focus === 'University Modules';
    const bodyOf = (e: ExamMeta) => e.body ?? 'University Modules';
    const pool = focus ? exams.filter((e) => bodyOf(e) === focus) : exams;

    if (!isUni) {
      // One shelf: the focus body's packs, manifest order preserved.
      if (!pool.length) return [];
      return [{ key: focus ?? 'all', label: focus ?? 'All packs', packs: pool }];
    }

    // University: group by school, the student's school pinned first.
    const bySchool = new Map<string, ExamMeta[]>();
    for (const e of pool) {
      const slug = schoolSlugOf(e.code) ?? 'other';
      if (!bySchool.has(slug)) bySchool.set(slug, []);
      bySchool.get(slug)!.push(e);
    }
    const order = [...bySchool.keys()].sort((a, b) => a.localeCompare(b));
    if (uniSchool) {
      const i = order.indexOf(uniSchool.slug);
      if (i > 0) {
        order.splice(i, 1);
        order.unshift(uniSchool.slug);
      }
    }
    return order.map((slug) => {
      const school = SCHOOLS.find((s) => s.slug === slug);
      return {
        key: slug,
        label: school ? `${school.name} (${school.short})` : slug,
        packs: bySchool.get(slug)!,
      };
    });
  }, [exams, focus, uniSchool]);

  const focusLabel =
    focus === 'University Modules'
      ? uniSchool
        ? `${uniSchool.name} (${uniSchool.short})`
        : 'your university'
      : focus;

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-60">
      <PageBar title="Question Pack" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Question Pack
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          {focus
            ? `Your ${focusLabel} past questions, ready to practice.`
            : 'Every past question pack on this device, ready to practice.'}
        </p>
        {focus && (
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Following your learning focus ·{' '}
            <Link href="/profile" className="font-semibold text-primary hover:underline">
              change focus in Profile
            </Link>
          </p>
        )}

        {failed && (
          <p className="mt-6 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
            Could not reach Renance servers. Check your connection and try again.
          </p>
        )}

        {!exams && !failed && (
          <div className="flex justify-center py-16">
            <LogoActivityIndicator state="busy" label="Loading your question packs…" />
          </div>
        )}

        {exams && exams.length === 0 && (
          <p className="mt-8 text-center text-[15px] text-on-surface-variant">
            No packs yet. Set your target exam and sync to get your first pack.
          </p>
        )}

        {exams && groups.length === 0 && focus && (
          <p className="mt-8 rounded-xl bg-card p-4 text-center text-[15px] text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            No {focusLabel} packs are on this device yet.
          </p>
        )}

        {groups.length > 0 && (
          <div className="mt-6 flex flex-col gap-6">
            {groups.map((group) => (
              <section key={group.key}>
                <div className="flex items-center justify-between gap-2">
                  <h2 className="truncate font-mono text-xs uppercase tracking-widest text-on-surface-variant">
                    {group.label} · {group.packs.reduce((n, p) => n + p.questionCount, 0)} questions
                  </h2>
                  {/* Each body's customise desk — compose a paper from its banks. */}
                  {focus === 'JAMB' && (
                    <a
                      href="/exams/setup"
                      className="flex shrink-0 items-center gap-1 rounded-full bg-surface-container px-2.5 py-1 text-[11px] font-semibold text-on-surface transition hover:bg-surface-container-high"
                    >
                      <span className="material-symbols-outlined text-[14px]">tune</span>
                      Customise
                    </a>
                  )}
                  {(focus === 'WAEC' || focus === 'NECO') && (
                    <a
                      href={`/exams/setup?body=${focus.toLowerCase()}`}
                      className="flex shrink-0 items-center gap-1 rounded-full bg-surface-container px-2.5 py-1 text-[11px] font-semibold text-on-surface transition hover:bg-surface-container-high"
                    >
                      <span className="material-symbols-outlined text-[14px]">tune</span>
                      Customise
                    </a>
                  )}
                </div>
                <ul className="mt-3 flex flex-col gap-3">
                  {group.packs.map((exam) => (
                    <li key={exam.code}>
                      <a
                        href={`/exams/practice?pack=${encodeURIComponent(exam.code)}`}
                        className="flex items-center gap-4 rounded-[12px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] transition hover:shadow-md"
                      >
                        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[12px] bg-surface-container-high text-on-surface">
                          <span className="material-symbols-outlined fill-current text-[24px]">
                            inventory_2
                          </span>
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[15px] font-semibold text-on-surface">
                            {exam.title}
                          </p>
                          <p className="mt-0.5 font-mono text-[12px] text-on-surface-variant">
                            {exam.questionCount} Q
                            {exam.durationMinutes ? ` · ${exam.durationMinutes} min` : ''} ·{' '}
                            {exam.totalMarks} marks
                          </p>
                        </div>
                        <span className="material-symbols-outlined text-[20px] text-outline">
                          chevron_right
                        </span>
                      </a>
                    </li>
                  ))}
                </ul>
              </section>
            ))}
          </div>
        )}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
