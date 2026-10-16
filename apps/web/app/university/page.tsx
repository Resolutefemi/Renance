'use client';

/**
 * /university, the school gate of the School Desk (the university desk,
 * renamed). Every Nigerian tertiary institution lives here
 * (universities, polytechnics, colleges of education). Schools with a
 * live course library open straight into their course desk; schools
 * whose only banked past questions are Post-UTME wait in the
 * unavailable list (their content lives on the Post UTME desk); the
 * rest show honestly that content is not wrapped yet. One interface,
 * per-school content.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { api } from '@/lib/api';
import { fetchManifest, type ExamMeta } from '@/lib/exams';
import {
  LIVE_SCHOOLS,
  OTHERS_SCHOOL,
  SCHOOLS,
  storedSchoolSlug,
  storeSchoolSlug,
  type School,
} from '@/lib/university';

const TYPE_LABELS: Record<School['type'], string> = {
  university: 'University',
  polytechnic: 'Polytechnic',
  'college-of-education': 'College of Education',
  'college-of-nursing': 'College of Nursing / Health',
};

const TYPE_ICONS: Record<School['type'], string> = {
  university: 'account_balance',
  polytechnic: 'precision_manufacturing',
  'college-of-education': 'history_edu',
  'college-of-nursing': 'medical_services',
};

export default function UniversityPage() {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const [postUtmeOnly, setPostUtmeOnly] = useState<Set<string>>(new Set());

  // Schools whose banked past questions are Post-UTME only (uni-<slug>-pq-*
  // packs but no course bank): they never pose as School Desk candidates.
  useEffect(() => {
    let alive = true;
    fetchManifest()
      .then((m) => {
        if (!alive) return;
        const pq = new Set<string>();
        for (const e of m.exams as ExamMeta[]) {
          const match = /^uni-([a-z0-9-]+)-pq-/.exec(e.code);
          if (match) pq.add(match[1]);
        }
        setPostUtmeOnly(pq);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  // School Desk scoping (founder directive 2026-10-04): a student who
  // already picked a school lands straight on THEIR course desk, never
  // on the all-schools gate. The founder account keeps the gate (his
  // switch-school right).
  useEffect(() => {
    const slug = storedSchoolSlug();
    if (!slug) return;
    const school = SCHOOLS.find((s) => s.slug === slug);
    if (!school?.live) return;
    let alive = true;
    api<{ email?: string }>('/me')
      .then((me) => {
        if (!alive) return;
        const founder = (me?.email ?? '').trim().toLowerCase() === 'ariyooluwafemi487@gmail.com';
        if (!founder) router.replace(`/university/${slug}`);
      })
      .catch(() => {
        // Signed out or the API hiccuped: still honour the pick.
        if (alive) router.replace(`/university/${slug}`);
      });
    return () => {
      alive = false;
    };
  }, [router]);

  // Selection list (founder directive 2026-10-04): ONLY schools with
  // available past questions are listed - the locked "not wrapped yet"
  // rows are gone. Students whose school is not on the list pick
  // "Other Schools", the merged general-course desk (every school's
  // BIO 101 questions become one generic BIO 101), pinned last.
  const listed = useMemo(
    () => LIVE_SCHOOLS.filter((s) => s.slug !== 'others'),
    [],
  );
  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    const base = q
      ? listed.filter(
          (s) =>
            s.name.toLowerCase().includes(q) ||
            s.short.toLowerCase().includes(q) ||
            s.state.toLowerCase().includes(q),
        )
      : listed;
    // Others is the fallback for every unlisted school: always pinned
    // last, searching never hides it.
    return [...base, OTHERS_SCHOOL];
  }, [listed, query]);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="School Desk" backHref="/dashboard" />
      <div className="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">
        <div className="flex flex-col gap-1">
          <h2 className="text-2xl font-bold tracking-tight text-on-surface">
            Which school are you in?
          </h2>
          <p className="text-sm text-on-surface-variant">
            Pick your institution: {listed.length} Nigerian schools with banked past questions,
            plus <span className="font-semibold text-on-surface">Other Schools</span> for everyone
            else. Your desk wraps each school&apos;s own courses and question banks. This pick
            sticks: it can be changed later only from your profile.
          </p>
        </div>

        <label className="mt-5 flex items-center gap-2 rounded-xl border border-outline-variant bg-surface-container-lowest px-4 py-3 focus-within:ring-2 focus-within:ring-primary">
          <span className="material-symbols-outlined text-on-surface-variant">search</span>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search school, short code or state…"
            className="w-full bg-transparent text-sm text-on-surface placeholder:text-outline focus:outline-none"
          />
        </label>

        {results.length === 1 && query.trim() && (
          <p className="mt-5 text-sm text-on-surface-variant">
            No school matches &ldquo;{query}&rdquo;. Your school&apos;s past questions are not
            wrapped yet - pick <b>Other Schools</b> to practise the general course banks
            every school shares.
          </p>
        )}

        <ul className="mt-5 grid gap-2 sm:grid-cols-2">
          {results.map((s) => (
            <li key={s.slug} className={`min-w-0 ${s.slug === 'others' ? 'sm:col-span-2' : ''}`}>
              <SchoolRow school={s} postUtmeOnly={postUtmeOnly.has(s.slug) && !s.live} />
            </li>
          ))}
        </ul>

        <p className="mt-8 rounded-xl bg-surface-container-low px-4 py-3 text-xs text-on-surface-variant">
          Your school not on the list? Pick <b>Other Schools</b>: its desk gathers the general
          courses (GST, MTH 101, BIO 101, CHM 101, PHY 101 &hellip;) of every banked school into
          one merged library, so you practise real past questions even before your school gets
          its own desk. Students of listed schools can also use the JAMB, WAEC and NECO desks,
          and Post-UTME candidates have their own desk.
        </p>
      </div>
      <SideNav />
      <BottomNav />
    </main>
  );
}

function SchoolRow({ school: s, postUtmeOnly }: { school: School; postUtmeOnly: boolean }) {
  const isOthers = s.slug === 'others';
  const inner = (
    <>
      <div
        className={`flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-xl ${
          s.live ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
        }`}
      >
        {/* Founder bug 2026-10-16: fixed square tile, glyph clipped to
            the rounded box - the fallback row uses the standard school
            building mark like every other row, so no stretched or
            off-centre icon can appear even if a glyph is missing. */}
        <span className="material-symbols-outlined text-[20px] leading-none">
          {isOthers ? 'diversity_3' : TYPE_ICONS[s.type]}
        </span>
      </div>
      <div className="min-w-0 flex-1">
        {/* Founder bug 2026-10-16: long school names may wrap (two
            lines) instead of being cut early; the live badge stays
            pinned beside the first line. */}
        <p className="flex flex-wrap items-center gap-x-2 text-sm font-semibold text-on-surface">
          <span className="break-words leading-snug">{s.name}</span>
          {s.live && !isOthers && (
            <span className="shrink-0 rounded-full bg-primary/10 px-2 py-0.5 font-mono text-[10px] font-bold uppercase text-primary">
              live
            </span>
          )}
        </p>
        <p className="truncate text-xs text-on-surface-variant">
          {isOthers
            ? 'Every school not on the list · merged general course banks (BIO 101, GST 111, MTH 101 …)'
            : s.live
              ? `${TYPE_LABELS[s.type]} · ${s.state}`
              : postUtmeOnly
                ? 'Post-UTME past questions only · see the Post UTME desk'
                : `${TYPE_LABELS[s.type]} · ${s.state}`}
        </p>
      </div>
      <span className="material-symbols-outlined text-on-surface-variant">
        {s.live ? 'chevron_right' : 'lock'}
      </span>
    </>
  );
  const cls = `flex items-center gap-3 rounded-xl border p-3 text-left transition ${
    s.live
      ? 'border-outline-variant bg-card hover:border-outline'
      : 'border-outline-variant/60 bg-surface-container-lowest opacity-70'
  }`;
  if (s.live) {
    return (
      <Link href={`/university/${s.slug}`} onClick={() => storeSchoolSlug(s.slug)} className={cls}>
        {inner}
      </Link>
    );
  }
  return (
    <div className={cls} aria-disabled title="Content not wrapped for this school yet">
      {inner}
    </div>
  );
}
