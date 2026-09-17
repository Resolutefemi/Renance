'use client';

/**
 * /post-utme, the gate of the Post UTME desk, Renance's fourth focus
 * entity beside JAMB, WAEC, NECO and the School Desk.
 *
 * The desk carries the school's own Post-UTME prep banks (the manifest's
 * `uni-<school>-pq-*` packs) plus the general Post-UTME practice banks.
 * Schools whose banked past questions are Post-UTME only sit with the
 * available schools here; every other school waits in the unavailable
 * list exactly like the School Desk picker.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { fetchManifest, type ExamMeta } from '@/lib/exams';
import {
  SCHOOLS,
  storePostUtmeSchoolSlug,
  storedPostUtmeSchoolSlug,
  type School,
} from '@/lib/university';

export default function PostUtmePage() {
  const [query, setQuery] = useState('');
  const [schoolSlug, setSchoolSlug] = useState<string | null>(null);
  const [exams, setExams] = useState<ExamMeta[]>([]);

  useEffect(() => {
    setSchoolSlug(storedPostUtmeSchoolSlug());
    let alive = true;
    fetchManifest()
      .then((m) => alive && setExams(m.exams))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  /** Schools with banked Post-UTME past questions, with pack counts. */
  const banked = useMemo(() => {
    const counts = new Map<string, number>();
    for (const e of exams) {
      const m = /^uni-([a-z0-9-]+)-pq-/.exec(e.code);
      if (m) counts.set(m[1], (counts.get(m[1]) ?? 0) + 1);
    }
    return counts;
  }, [exams]);

  const school = SCHOOLS.find((s) => s.slug === schoolSlug) ?? null;
  const ownPacks = schoolSlug
    ? exams.filter((e) => e.code.startsWith(`uni-${schoolSlug}-pq-`))
    : [];
  const general = exams.filter((e) => e.body === 'POST-UTME');

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
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="Post UTME Desk" backHref="/dashboard" />
      <div className="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">
        {/* Desk hero --------------------------------------------------- */}
        <section className="relative overflow-hidden rounded-xl bg-hero p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] sm:p-6">
          <div className="absolute -right-14 -top-14 h-36 w-36 rounded-full bg-on-hero/10" />
          <p className="relative z-10 font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-hero-muted">
            Post UTME Desk
          </p>
          <h2 className="relative z-10 mt-1 text-2xl font-bold tracking-tight text-on-hero sm:text-3xl">
            {school?.name ?? 'Pick your school'}
          </h2>
          <p className="relative z-10 mt-2 text-sm font-semibold text-hero-muted">
            {ownPacks.length > 0
              ? `${ownPacks.length} school prep packs · ${general.length} general banks`
              : `${banked.size} schools banked · ${general.length} general practice banks`}
          </p>
        </section>

        <div className="mt-6 flex flex-col gap-1">
          <h2 className="text-2xl font-bold tracking-tight text-on-surface">
            Which school are you writing for?
          </h2>
          <p className="text-sm text-on-surface-variant">
            Pick the school whose Post-UTME past questions you want. Your pick feeds the desk
            on the home page and the Study Past Questions picker.
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
              <PostUtmeSchoolRow
                school={s}
                packs={banked.get(s.slug) ?? 0}
                active={s.slug === schoolSlug}
              />
            </li>
          ))}
        </ul>

        {results.length === 0 && (
          <p className="mt-10 text-center text-sm text-on-surface-variant">
            No school matches &ldquo;{query}&rdquo;. Try a short code like UNILAG or a state name.
          </p>
        )}

        <p className="mt-8 rounded-xl bg-surface-container-low px-4 py-3 text-xs text-on-surface-variant">
          Schools without banked Post-UTME questions wait in the unavailable list; the general
          practice banks below are open to every candidate today.
        </p>

        {/* General practice banks -------------------------------------- */}
        {general.length > 0 && (
          <section className="mt-8">
            <h3 className="text-sm font-semibold text-on-surface">General practice banks</h3>
            <div className="mt-3 grid gap-2 sm:grid-cols-2">
              {general.map((e) => (
                <Link
                  key={e.code}
                  href={`/exams/practice?pack=${encodeURIComponent(e.code)}`}
                  className="flex items-center gap-3 rounded-xl border border-outline-variant bg-card p-3 transition hover:border-outline"
                >
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-selection-blue text-on-surface">
                    <span className="material-symbols-outlined text-[20px]">description</span>
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-on-surface">
                      {e.title ?? e.code}
                    </span>
                    <span className="block text-xs text-on-surface-variant">
                      {e.questionCount} questions
                    </span>
                  </span>
                  <span className="material-symbols-outlined text-on-surface-variant">chevron_right</span>
                </Link>
              ))}
            </div>
          </section>
        )}
      </div>
      <SideNav />
      <BottomNav />
    </main>
  );
}

function PostUtmeSchoolRow({
  school: s,
  packs,
  active,
}: {
  school: School;
  packs: number;
  active: boolean;
}) {
  const available = packs > 0;
  const inner = (
    <>
      <div
        className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${
          available ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
        }`}
      >
        <span className="material-symbols-outlined text-[20px]">account_balance</span>
      </div>
      <div className="min-w-0 flex-1">
        <p className="flex items-center gap-2 truncate text-sm font-semibold text-on-surface">
          {s.name}
          {active && (
            <span className="shrink-0 rounded-full bg-primary/10 px-2 py-0.5 font-mono text-[10px] font-bold uppercase text-primary">
              picked
            </span>
          )}
        </p>
        <p className="truncate text-xs text-on-surface-variant">
          {available ? `${packs} Post-UTME packs` : 'Post-UTME questions not banked yet'}
        </p>
      </div>
      <span className="material-symbols-outlined text-on-surface-variant">
        {available ? 'chevron_right' : 'lock'}
      </span>
    </>
  );
  const cls = `flex items-center gap-3 rounded-xl border p-3 text-left transition ${
    available
      ? 'border-outline-variant bg-card hover:border-outline'
      : 'border-outline-variant/60 bg-surface-container-lowest opacity-70'
  } ${active ? 'ring-1 ring-primary' : ''}`;
  if (available) {
    return (
      <Link
        href="/dashboard"
        onClick={() => storePostUtmeSchoolSlug(s.slug)}
        className={cls}
      >
        {inner}
      </Link>
    );
  }
  return (
    <div className={cls} aria-disabled title="Post-UTME questions not banked for this school yet">
      {inner}
    </div>
  );
}
