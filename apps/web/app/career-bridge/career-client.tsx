'use client';

/**
 * Career bridge client, the Stitch career_bridge_light screen, 1:1.
 * The data comes baked from data/career/*.json at build time (the same
 * files GET /career serves the app). Signed-in visitors also get the
 * hero question personalised to their weakest syllabus subject. Signed
 * out, the exact Stitch copy stands.
 */

import { useEffect, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { api } from '@/lib/api';
import { getToken } from '@/lib/session';
import type { SyllabusTree } from '@/lib/syllabus';
import type { CareerData } from '@/lib/site-data';

/** The Stitch demo rows, kept verbatim for the signed-out render. */
const STITCH_SCHOLARSHIPS = [
  { icon: 'school', title: 'National STEM Grant', meta: 'Closes in 12 days • $5,000', urgent: true },
  { icon: 'biotech', title: 'Future Biotech Leaders', meta: 'Nov 15 Deadline • Full Tuition', urgent: false },
  { icon: 'eco', title: 'Conservation Initiative', meta: 'Dec 01 Deadline • $2,500', urgent: false },
] as const;

const STITCH_FILTERS = ['Health', 'Research', 'Ecology'] as const;

const FIELD_ICONS: Record<string, string> = {
  Health: 'healing',
  Research: 'biotech',
  Ecology: 'eco',
  Engineering: 'precision_manufacturing',
  Tech: 'computer',
  Business: 'trending_up',
};

const LEVEL_LABELS: Record<string, string> = {
  undergraduate: 'Undergraduate',
  postgraduate: 'Postgraduate',
  both: 'Undergrad & postgrad',
};

interface MeResponse {
  profile: { exams?: string[] } | null;
}

function bodySlugOf(exams: string[] | undefined): string {
  const exam = exams?.[0] ?? '';
  if (exam.includes('WAEC')) return 'waec';
  if (exam.includes('University')) return 'university-modules';
  return 'jamb';
}

export default function CareerClient({ data }: { data: CareerData | null }) {
  const hasData = data != null && data.paths.length > 0;
  const [filters, setFilters] = useState<string[]>(['Health']);
  const [search, setSearch] = useState('');
  const [subject, setSubject] = useState<string | null>(null);

  // Fields come from the baked paths, the Stitch demo set when absent.
  const filterOptions = hasData
    ? Array.from(new Set(data.paths.map((p) => p.field)))
    : [...STITCH_FILTERS];

  useEffect(() => {
    // Keep the Stitch default selection where the data supports it.
    setFilters((cur) => cur.filter((f) => filterOptions.includes(f)));
  }, [filterOptions]);

  useEffect(() => {
    // Hero question personalisation, token-gated like the study plan.
    if (!getToken()) return;
    let alive = true;
    (async () => {
      const me = await api<MeResponse>('/me').catch(() => null);
      if (!alive || !me) return;
      const tree = await api<SyllabusTree>(
        `/syllabus/${bodySlugOf(me.profile?.exams)}`,
      ).catch(() => null);
      if (!alive || !tree || tree.weakest.length === 0) return;
      const topic = tree.weakest[0].topic;
      for (const s of tree.subjects) {
        for (const sec of s.sections) {
          if (sec.topics.some((t) => t.topic === topic)) {
            setSubject(s.subject);
            return;
          }
        }
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  const toggle = (f: string) =>
    setFilters((cur) => (cur.includes(f) ? cur.filter((x) => x !== f) : [...cur, f]));

  const q = search.trim().toLowerCase();
  const visiblePaths = hasData
    ? data.paths.filter(
        (p) =>
          (filters.length === 0 || filters.includes(p.field)) &&
          (q === '' ||
            p.course.toLowerCase().includes(q) ||
            p.universities.some((u) => u.toLowerCase().includes(q))),
      )
    : [];

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Career Bridge" />
      </div>

      {/* hero */}
      <section className="mt-4 flex min-h-[190px] flex-col rounded-2xl bg-gradient-to-br from-[#EAF1FE] via-[#D8E3FB] to-[#C7D9F7] p-5">
        <p className="font-mono text-[11px] uppercase tracking-[1.2px] text-on-surface-variant">
          Career Bridge
        </p>
        <h1 className="mt-auto text-2xl font-bold tracking-tight text-on-surface">
          {subject ? `Where can ${subject} take you?` : 'Where can Biology take you?'}
        </h1>
        <p className="mt-2 text-[15px] text-on-surface-variant">
          Explore pathways and funding
        </p>
      </section>

      {/* Scholarships open now */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Scholarships open now</h2>
      <div className="mt-3.5 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        {hasData
          ? data.scholarships.map((s) => (
              <a
                key={s.id}
                href={s.url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex w-full items-center gap-3.5 p-4 text-left transition hover:bg-surface-container-low/50"
              >
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-surface-container-high">
                  <span className="material-symbols-outlined text-[24px] text-accent-ink">
                    {FIELD_ICONS[s.tags[0]] ?? 'school'}
                  </span>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <span className="truncate text-[17px] font-semibold text-on-surface">{s.name}</span>
                  </span>
                  <span className="mt-0.5 block text-[15px] text-on-surface-variant">
                    {LEVEL_LABELS[s.level] ?? s.level} • {s.coverage}
                  </span>
                  <span className="mt-0.5 block text-[13px] text-on-surface-variant">{s.window}</span>
                </span>
                <span className="material-symbols-outlined text-[24px] text-on-surface-variant">open_in_new</span>
              </a>
            ))
          : STITCH_SCHOLARSHIPS.map((s) => (
              <button
                key={s.title}
                className="flex w-full items-center gap-3.5 p-4 text-left transition hover:bg-surface-container-low/50"
              >
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-surface-container-high">
                  <span className="material-symbols-outlined text-[24px] text-accent-ink">{s.icon}</span>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <span className="truncate text-[17px] font-semibold text-on-surface">{s.title}</span>
                    {s.urgent && (
                      <span className="shrink-0 rounded-full bg-error-container px-2.5 py-1 font-mono text-[12px] font-bold tracking-wide text-error">
                        URGENT
                      </span>
                    )}
                  </span>
                  <span className="mt-0.5 block text-[15px] text-on-surface-variant">{s.meta}</span>
                </span>
                <span className="material-symbols-outlined text-[24px] text-on-surface-variant">chevron_right</span>
              </button>
            ))}
      </div>

      {/* Course cut-off explorer */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Course cut-off explorer</h2>
      <div className="mt-3.5 rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        <label className="flex items-center gap-2 rounded-xl bg-surface-container-low px-4 py-3.5">
          <span className="material-symbols-outlined text-[22px] text-on-surface-variant">search</span>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search degrees (e.g. B.Sc Marine Biology)"
            className="w-full bg-transparent text-[15px] text-on-surface outline-none placeholder:text-on-surface-variant"
          />
        </label>
        <div className="mt-3.5 flex flex-wrap gap-2">
          {filterOptions.map((f) => (
            <button
              key={f}
              onClick={() => toggle(f)}
              className={`rounded-full px-4 py-2.5 text-[15px] transition ${
                filters.includes(f)
                  ? 'bg-selection-blue font-semibold text-on-surface'
                  : 'bg-surface-container-low text-on-surface-variant'
              }`}
            >
              {f}
            </button>
          ))}
        </div>
        {hasData && (
          <div className="mt-1">
            {visiblePaths.map((p) => (
              <div
                key={p.id}
                className="flex items-start gap-3.5 rounded-xl px-1 py-3"
              >
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-surface-container-high">
                  <span className="material-symbols-outlined text-[24px] text-accent-ink">
                    {FIELD_ICONS[p.field] ?? 'trending_up'}
                  </span>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <span className="truncate text-[17px] font-semibold text-on-surface">{p.course}</span>
                    <span className="shrink-0 rounded-full bg-selection-blue px-2.5 py-1 text-[12px] font-bold text-on-surface">
                      {p.cutoff}
                    </span>
                  </span>
                  <span className="mt-0.5 block truncate text-[15px] text-on-surface-variant">
                    {p.subjects.join(' • ')}
                  </span>
                  <span className="mt-0.5 block truncate text-[13px] text-on-surface-variant">
                    {p.universities.join(' • ')}
                  </span>
                </span>
              </div>
            ))}
            {visiblePaths.length === 0 && (
              <p className="py-4 text-center text-[15px] text-on-surface-variant">
                No course matches that search yet.
              </p>
            )}
          </div>
        )}
      </div>

      <BottomNav />
    </main>
  );
}
