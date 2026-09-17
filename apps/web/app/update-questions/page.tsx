'use client';

/**
 * Select & Update Questions — the school app's updater, Renance cut.
 *
 * The student picks the exam bodies to refresh (per-body cards with
 * the pack count, a checkbox and the black Update pill), Select All +
 * search included, then runs the update: the live manifest is
 * re-fetched (cache-busted) and every selected pack re-downloads into
 * the IndexedDB shelf, progress shown honestly per pack. The last
 * update lands in `renance.lastQuestionUpdate` and is stamped on the
 * page.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { fetchManifest, migrateBundleCache, prefetchAll, type ExamMeta } from '@/lib/exams';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';

const LAST_KEY = 'renance.lastQuestionUpdate';

interface BodyGroup {
  key: string;
  label: string;
  icon: string;
  tint: string;
  exams: ExamMeta[];
}

const GROUPS: Array<{ key: string; label: string; icon: string; tint: string; match: (e: ExamMeta) => boolean }> = [
  { key: 'jamb', label: 'JAMB', icon: 'school', tint: 'bg-accent-ink/10 text-accent-ink', match: (e) => e.code.startsWith('jamb-') },
  { key: 'waec', label: 'WAEC', icon: 'history_edu', tint: 'bg-accent-emerald/10 text-on-surface', match: (e) => e.code.startsWith('waec-') },
  { key: 'neco', label: 'NECO', icon: 'grade', tint: 'bg-accent-amber/10 text-on-surface', match: (e) => e.code.startsWith('neco-') },
  {
    key: 'university',
    label: 'University Modules',
    icon: 'account_balance',
    tint: 'bg-secondary-container text-on-surface',
    match: (e) => e.code.startsWith('uni-') || e.code.startsWith('post_utme-'),
  },
];

export default function UpdateQuestionsPage() {
  const [exams, setExams] = useState<ExamMeta[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set(GROUPS.map((g) => g.key)));
  const [search, setSearch] = useState('');
  const [updating, setUpdating] = useState(false);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [lastUpdate, setLastUpdate] = useState<string | null>(null);
  const [summary, setSummary] = useState<string | null>(null);

  useEffect(() => {
    migrateBundleCache();
    try {
      const raw = window.localStorage.getItem(LAST_KEY);
      if (raw) setLastUpdate(new Date(Number(raw)).toLocaleString());
    } catch {
      /* private mode: stamp simply stays absent */
    }
    let alive = true;
    fetchManifest()
      .then((m) => alive && setExams(m.exams))
      .catch(() => alive && setError('Could not reach the question manifest. Check your connection.'));
    return () => {
      alive = false;
    };
  }, []);

  const groups: BodyGroup[] = useMemo(() => {
    if (!exams) return [];
    return GROUPS.map((g) => ({
      key: g.key,
      label: g.label,
      icon: g.icon,
      tint: g.tint,
      exams: exams.filter(g.match),
    })).filter((g) => g.exams.length > 0);
  }, [exams]);

  const visibleGroups = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return groups;
    return groups
      .map((g) => ({ ...g, exams: g.exams.filter((e) => e.title.toLowerCase().includes(needle) || e.code.includes(needle)) }))
      .filter((g) => g.exams.length > 0);
  }, [groups, search]);

  function toggle(key: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  const selectedPacks = groups.filter((g) => selected.has(g.key)).flatMap((g) => g.exams);

  async function runUpdate() {
    if (updating || selectedPacks.length === 0) return;
    setUpdating(true);
    setError(null);
    setSummary(null);
    setProgress({ done: 0, total: selectedPacks.length });
    try {
      // Fresh manifest first — a newly shipped pack joins the sweep and
      // retired packs drop out — then the patient re-download.
      const manifest = await fetchManifest();
      const fresh = manifest.exams.filter((e) => selectedPacks.some((p) => p.code === e.code));
      const done = await prefetchAll({ ...manifest, exams: fresh }, (d, t) => setProgress({ done: d, total: t }));
      const stamp = Date.now();
      try {
        window.localStorage.setItem(LAST_KEY, String(stamp));
      } catch {
        /* private mode */
      }
      setLastUpdate(new Date(stamp).toLocaleString());
      setSummary(`${done} of ${fresh.length} packs refreshed on this device.`);
    } catch {
      setError('The update hit a network wall. Your downloaded packs are untouched, try again.');
    } finally {
      setUpdating(false);
      setProgress(null);
    }
  }

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <div className="sticky top-0 z-40 border-b border-outline-variant/40 bg-surface/80 backdrop-blur-xl">
        <div className="mx-auto flex h-14 w-full max-w-2xl items-center gap-2 px-4 sm:px-6 md:h-16">
          <Link
            href="/dashboard"
            aria-label="Back to dashboard"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-[22px]">arrow_back</span>
          </Link>
          <h1 className="min-w-0 flex-1 text-[15px] font-semibold text-on-surface md:text-[17px]">
            Select &amp; Update Questions
          </h1>
        </div>
      </div>

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-4 sm:px-6">
        <p className="text-[14px] leading-relaxed text-on-surface-variant">
          Tick the exam bodies to refresh, then run the update, the latest questions, answers, explanations and
          corrections download onto this device.
        </p>
        {lastUpdate && (
          <p className="mt-1.5 flex items-center gap-1.5 px-1 font-mono text-[12px] text-on-surface-variant">
            <span className="material-symbols-outlined text-[14px]">schedule</span>
            Last updated {lastUpdate}
          </p>
        )}

        {/* Select All + search */}
        <div className="mt-4 flex items-center gap-2.5">
          <button
            onClick={() =>
              setSelected((prev) => (prev.size === groups.length ? new Set() : new Set(groups.map((g) => g.key))))
            }
            className="flex h-10 items-center gap-1.5 rounded-full border border-outline-variant bg-card px-4 text-[13px] font-semibold text-on-surface transition hover:bg-surface-container-low"
          >
            <span className="material-symbols-outlined text-[17px]">
              {selected.size === groups.length && groups.length > 0 ? 'check_box' : 'check_box_outline_blank'}
            </span>
            Select All
          </button>
          <div className="relative flex-1">
            <span className="material-symbols-outlined pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[18px] text-outline">
              search
            </span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search subjects…"
              className="h-10 w-full rounded-full border border-outline-variant bg-card pl-9 pr-3 text-[13.5px] text-on-surface outline-none transition placeholder:text-outline focus:border-primary"
            />
          </div>
        </div>

        {error && (
          <p className="mt-3 rounded-xl bg-error-container px-4 py-3 text-[13px] text-on-error-container">{error}</p>
        )}
        {summary && (
          <p className="mt-3 rounded-xl bg-accent-emerald/10 px-4 py-3 text-[13px] font-medium text-on-surface">
            {summary}
          </p>
        )}

        {/* per-body cards */}
        <div className="mt-4 space-y-3">
          {!exams && <p className="rounded-xl bg-card p-6 text-center text-sm text-on-surface-variant">Loading the shelf…</p>}
          {exams && visibleGroups.length === 0 && (
            <p className="rounded-xl bg-card p-6 text-center text-sm text-on-surface-variant">Nothing matches that search.</p>
          )}
          {visibleGroups.map((g) => {
            const on = selected.has(g.key);
            const questions = g.exams.reduce((s, e) => s + (e.questionCount ?? 0), 0);
            return (
              <section
                key={g.key}
                className={`rounded-[14px] border bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] transition ${
                  on ? 'border-primary/50' : 'border-outline-variant/50'
                }`}
              >
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => toggle(g.key)}
                    role="checkbox"
                    aria-checked={on}
                    aria-label={`Select ${g.label}`}
                    className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-[7px] border transition ${
                      on ? 'border-primary bg-primary text-on-primary' : 'border-outline bg-card'
                    }`}
                  >
                    {on && <span className="material-symbols-outlined text-[16px]">check</span>}
                  </button>
                  <span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${g.tint}`}>
                    <span className="material-symbols-outlined text-[22px]">{g.icon}</span>
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[15.5px] font-bold text-on-surface">{g.label}</p>
                    <p className="font-mono text-[12px] text-on-surface-variant">
                      {g.exams.length.toLocaleString()} packs · {questions.toLocaleString()} questions
                    </p>
                  </div>
                  <button
                    onClick={() => toggle(g.key)}
                    className="shrink-0 rounded-full bg-accent-ink px-4 py-2 text-[12.5px] font-bold text-white transition hover:opacity-90 active:scale-[0.97]"
                  >
                    {on ? 'Selected' : 'Update'}
                  </button>
                </div>
              </section>
            );
          })}
        </div>

        {/* the update action */}
        <button
          onClick={() => void runUpdate()}
          disabled={updating || selectedPacks.length === 0}
          className="mt-6 flex h-[54px] w-full items-center justify-center gap-2 rounded-[12px] bg-primary text-[15px] font-bold text-on-primary shadow-md transition hover:shadow-lg active:scale-[0.99] disabled:opacity-50"
        >
          {updating ? (
            <>
              <span className="material-symbols-outlined animate-spin text-[20px]">progress_activity</span>
              Updating… {progress ? `${progress.done}/${progress.total}` : ''}
            </>
          ) : (
            <>
              <span className="material-symbols-outlined text-[20px]">sync</span>
              Update {selectedPacks.length.toLocaleString()} packs
            </>
          )}
        </button>
        {progress && (
          <div className="mt-2.5 h-1.5 w-full overflow-hidden rounded-full bg-surface-container">
            <div
              className="h-full rounded-full bg-gradient-to-r from-primary to-accent-emerald transition-all"
              style={{ width: `${(progress.done / Math.max(progress.total, 1)) * 100}%` }}
            />
          </div>
        )}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
