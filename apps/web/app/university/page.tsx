'use client';

/**
 * /university — the school gate of the university desk.
 *
 * Every Nigerian tertiary institution lives here (universities,
 * polytechnics, colleges of education). Schools with a live question
 * library open straight into their course desk; the rest show honestly
 * that content is not wrapped yet. One interface, per-school content.
 */

import { useMemo, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { SCHOOLS, storeSchoolSlug, type School } from '@/lib/university';

const TYPE_LABELS: Record<School['type'], string> = {
  university: 'University',
  polytechnic: 'Polytechnic',
  'college-of-education': 'College of Education',
};

const TYPE_ICONS: Record<School['type'], string> = {
  university: 'account_balance',
  polytechnic: 'precision_manufacturing',
  'college-of-education': 'history_edu',
};

export default function UniversityPage() {
  const [query, setQuery] = useState('');

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return SCHOOLS;
    return SCHOOLS.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        s.short.toLowerCase().includes(q) ||
        s.state.toLowerCase().includes(q),
    );
  }, [query]);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-60">
      <PageBar title="University Desk" backHref="/dashboard" />
      <div className="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">
        <div className="flex flex-col gap-1">
          <h2 className="text-2xl font-bold tracking-tight text-on-surface">
            Which school are you in?
          </h2>
          <p className="text-sm text-on-surface-variant">
            Pick your institution — {SCHOOLS.length} Nigerian universities, polytechnics and
            colleges of education. Your desk wraps each school&apos;s own courses, question banks
            and PDF materials.
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

        <ul className="mt-5 grid gap-2 sm:grid-cols-2">
          {results.map((s) => (
            <li key={s.slug}>
              <SchoolRow school={s} />
            </li>
          ))}
        </ul>

        {results.length === 0 && (
          <p className="mt-10 text-center text-sm text-on-surface-variant">
            No school matches &ldquo;{query}&rdquo;. Try a short code like FUTA or a state name.
          </p>
        )}

        <p className="mt-8 rounded-xl bg-surface-container-low px-4 py-3 text-xs text-on-surface-variant">
          Your school not wrapped yet? The desk ships one interface for every school — question
          banks and course PDFs are added per school as they are harvested. Students of any school
          can already use the JAMB, WAEC and NECO desks today.
        </p>
      </div>
      <SideNav />
      <BottomNav />
    </main>
  );
}

function SchoolRow({ school: s }: { school: School }) {
  const inner = (
    <>
      <div
        className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${
          s.live ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
        }`}
      >
        <span className="material-symbols-outlined text-[20px]">{TYPE_ICONS[s.type]}</span>
      </div>
      <div className="min-w-0 flex-1">
        <p className="flex items-center gap-2 truncate text-sm font-semibold text-on-surface">
          {s.name}
          {s.live && (
            <span className="shrink-0 rounded-full bg-primary/10 px-2 py-0.5 font-mono text-[10px] font-bold uppercase text-primary">
              live
            </span>
          )}
        </p>
        <p className="truncate text-xs text-on-surface-variant">
          {TYPE_LABELS[s.type]} · {s.state}
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
