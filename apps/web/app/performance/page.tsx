'use client';

/**
 * Performance Analysis — the school app's beautiful performance page,
 * Renance cut.
 *
 *   · the General Overview card (papers graded, average score, best
 *     streak, total XP)
 *   · time-window chips (7 / 30 / 90 days · all time)
 *   · the score line across the window's graded papers
 *   · tinted per-body cards (JAMB · University · WAEC · NECO · Daily
 *     Challenge) with attempt counts and averages
 *   · per-topic bars, aggregated from the most recent graded reviews
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { LogoActivityIndicator } from '@/components/renance-logo';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';

interface AttemptRow {
  attemptId: string;
  code: string;
  status: string;
  score?: number;
  total?: number;
  submittedAt?: string;
}

interface TopicRow {
  topic: string;
  correct: number;
  total: number;
}

type WindowKey = '7' | '30' | '90' | 'all';

const WINDOW_LABEL: Record<WindowKey, string> = {
  '7': '7 days',
  '30': '30 days',
  '90': '90 days',
  all: 'All time',
};

/** Attempt code prefix → exam body the way the desk groups packs. */
function bodyOf(code: string): string {
  if (code.startsWith('jamb-mock-')) return 'JAMB Mock';
  if (code.startsWith('jamb-custom-') || code.startsWith('jamb-pick-')) return 'JAMB Practice';
  if (code.startsWith('jamb-')) return 'JAMB';
  if (code.startsWith('waec-')) return 'WAEC';
  if (code.startsWith('neco-')) return 'NECO';
  if (code.startsWith('daily-')) return 'Daily Challenge';
  return 'University';
}

const BODY_TINT: Record<string, string> = {
  JAMB: 'bg-accent-ink/8 border-accent-ink/20',
  'JAMB Mock': 'bg-accent-ink/8 border-accent-ink/20',
  'JAMB Practice': 'bg-accent-ink/8 border-accent-ink/20',
  WAEC: 'bg-accent-emerald/8 border-accent-emerald/25',
  NECO: 'bg-accent-amber/10 border-accent-amber/25',
  University: 'bg-secondary-container/60 border-outline-variant/40',
  'Daily Challenge': 'bg-accent-amber/10 border-accent-amber/25',
};

export default function PerformancePage() {
  const [attempts, setAttempts] = useState<AttemptRow[] | null>(null);
  const [gam, setGam] = useState<{ state: { currentStreak: number; bestStreak: number; totalXp: number } } | null>(null);
  const [topicRows, setTopicRows] = useState<TopicRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [win, setWin] = useState<WindowKey>('30');

  useEffect(() => {
    let alive = true;
    api<{ attempts: AttemptRow[] }>('/me/attempts', { noRedirect: true })
      .then((a) => alive && setAttempts(a.attempts))
      .catch((e: unknown) => alive && setError(e instanceof Error ? e.message : 'Could not load your attempts'));
    api<{ state: { currentStreak: number; bestStreak: number; totalXp: number } }>('/me/gamification', { noRedirect: true })
      .then((g) => alive && setGam(g))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  // Per-topic bars: aggregate the topic rows of the 6 most recent
  // graded papers (the same honest window the app draws from).
  useEffect(() => {
    if (!attempts) return;
    const graded = attempts.filter((a) => a.status === 'graded' && a.score != null).slice(0, 6);
    if (graded.length === 0) {
      setTopicRows([]);
      return;
    }
    let alive = true;
    setTopicRows(null);
    (async () => {
      const merged = new Map<string, TopicRow>();
      for (const a of graded) {
        try {
          const r = await api<{ questions: Array<{ topic?: string; correctly: boolean }> }>(
            `/attempts/${a.attemptId}/review`,
            { noRedirect: true },
          );
          const counts = new Map<string, { c: number; t: number }>();
          for (const q of r.questions) {
            const key = q.topic?.trim() || 'General';
            const row = counts.get(key) ?? { c: 0, t: 0 };
            row.t += 1;
            if (q.correctly) row.c += 1;
            counts.set(key, row);
          }
          for (const [topic, { c, t }] of counts) {
            const cur = merged.get(topic) ?? { topic, correct: 0, total: 0 };
            cur.correct += c;
            cur.total += t;
            merged.set(topic, cur);
          }
        } catch {
          /* one cold review must not sink the page */
        }
        if (!alive) return;
      }
      if (!alive) return;
      setTopicRows(
        [...merged.values()].sort((a, b) => b.total / Math.max(b.total - b.correct, 1) - a.total / Math.max(a.total - a.correct, 1)).slice(0, 8),
      );
    })();
    return () => {
      alive = false;
    };
  }, [attempts]);

  const graded = useMemo(
    () =>
      (attempts ?? [])
        .filter((a) => a.status === 'graded' && a.score != null && a.total)
        .sort((a, b) => new Date(a.submittedAt ?? 0).getTime() - new Date(b.submittedAt ?? 0).getTime()),
    [attempts],
  );

  const windowed = useMemo(() => {
    if (win === 'all') return graded;
    const days = Number(win);
    const cut = Date.now() - days * 86_400_000;
    return graded.filter((a) => new Date(a.submittedAt ?? 0).getTime() >= cut);
  }, [graded, win]);

  const avgPct = useMemo(() => {
    if (windowed.length === 0) return null;
    const score = windowed.reduce((s, a) => s + ((a.score! * 100) / a.total!), 0);
    return Math.round(score / windowed.length);
  }, [windowed]);

  const byBody = useMemo(() => {
    const map = new Map<string, { count: number; pctSum: number }>();
    for (const a of windowed) {
      const key = bodyOf(a.code);
      const row = map.get(key) ?? { count: 0, pctSum: 0 };
      row.count += 1;
      row.pctSum += (a.score! * 100) / a.total!;
      map.set(key, row);
    }
    return [...map.entries()]
      .map(([body, { count, pctSum }]) => ({ body, count, avg: Math.round(pctSum / count) }))
      .sort((a, b) => b.count - a.count);
  }, [windowed]);

  if (error) {
    return (
      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
        <HeadBar />
        <div className="mx-auto max-w-2xl px-4 pt-8 sm:px-6">
          <p className="rounded-xl bg-error-container px-4 py-3 text-sm text-on-error-container">{error}</p>
        </div>
      </main>
    );
  }

  if (!attempts) {
    return (
      <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
        <HeadBar />
        <div className="mx-auto flex max-w-2xl justify-center px-4 pt-14 sm:px-6">
          <LogoActivityIndicator state="busy" label="Crunching your results…" />
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <HeadBar />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-4 sm:px-6">
        {/* ---- General Overview ------------------------------------ */}
        <section className="rounded-[14px] bg-hero p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-hero-muted">General Overview</p>
          <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Stat label="Papers graded" value={windowed.length.toLocaleString()} />
            <Stat label="Average score" value={avgPct == null ? '—' : `${avgPct}%`} />
            <Stat label="Best streak" value={`${gam?.state.bestStreak ?? 0}d`} />
            <Stat label="Total XP" value={(gam?.state.totalXp ?? 0).toLocaleString()} />
          </div>
        </section>

        {/* ---- time-window chips ------------------------------------ */}
        <div className="mt-4 flex flex-wrap gap-2">
          {(Object.keys(WINDOW_LABEL) as WindowKey[]).map((k) => (
            <button
              key={k}
              onClick={() => setWin(k)}
              className={`rounded-full px-4 py-1.5 font-mono text-xs transition ${
                win === k
                  ? 'bg-selection-blue font-semibold text-on-surface'
                  : 'bg-surface-container-low text-on-surface-variant hover:text-on-surface'
              }`}
            >
              {WINDOW_LABEL[k]}
            </button>
          ))}
        </div>

        {/* ---- the score line --------------------------------------- */}
        <section className="mt-4 rounded-[14px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          <div className="flex items-baseline justify-between">
            <h2 className="text-[15px] font-bold text-on-surface">Score trend</h2>
            <span className="font-mono text-[11px] text-on-surface-variant">{WINDOW_LABEL[win]}</span>
          </div>
          <ScoreChart points={windowed.slice(-14).map((a) => Math.round((a.score! * 100) / a.total!))} />
        </section>

        {/* ---- per-body cards --------------------------------------- */}
        <h2 className="mt-6 px-1 text-[15px] font-bold text-on-surface">By exam body</h2>
        <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
          {byBody.length === 0 && (
            <p className="rounded-xl bg-card p-5 text-sm text-on-surface-variant sm:col-span-2">
              No graded papers in this window yet — sit a mock and your numbers land here.
            </p>
          )}
          {byBody.map((row) => (
            <div key={row.body} className={`rounded-[14px] border p-4 ${BODY_TINT[row.body] ?? 'border-outline-variant/40 bg-card'}`}>
              <div className="flex items-center justify-between">
                <p className="text-[14.5px] font-bold text-on-surface">{row.body}</p>
                <span className="font-mono text-[12px] text-on-surface-variant">{row.count} papers</span>
              </div>
              <div className="mt-2 flex items-end justify-between">
                <p className="text-2xl font-bold tracking-tight text-on-surface">{row.avg}%</p>
                <div className="h-2 w-28 overflow-hidden rounded-full bg-surface-container">
                  <div
                    className={`h-full rounded-full ${row.avg >= 75 ? 'bg-accent-emerald' : row.avg >= 50 ? 'bg-accent-amber' : 'bg-error'}`}
                    style={{ width: `${row.avg}%` }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* ---- per-topic bars --------------------------------------- */}
        <h2 className="mt-6 px-1 text-[15px] font-bold text-on-surface">Topic mastery</h2>
        <p className="mt-1 px-1 text-[12.5px] text-on-surface-variant">
          Aggregated from your six most recent graded papers.
        </p>
        <div className="mt-3 rounded-[14px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          {topicRows === null && <p className="py-2 text-sm text-on-surface-variant">Reading the marked papers…</p>}
          {topicRows?.length === 0 && (
            <p className="py-2 text-sm text-on-surface-variant">Grade a paper and its topics line up here.</p>
          )}
          {(topicRows ?? []).map((row) => {
            const pct = row.total > 0 ? Math.round((row.correct * 100) / row.total) : 0;
            return (
              <div key={row.topic} className="py-2">
                <div className="flex items-baseline justify-between">
                  <span className="truncate pr-3 text-[14px] font-semibold text-on-surface">{row.topic}</span>
                  <span className="shrink-0 font-mono text-[12px] text-on-surface-variant">
                    {pct}% · {row.correct}/{row.total}
                  </span>
                </div>
                <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-surface-container">
                  <div
                    className={`h-full rounded-full ${pct >= 80 ? 'bg-accent-emerald' : pct >= 50 ? 'bg-accent-amber' : 'bg-error'}`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>

        {/* where the numbers come from */}
        <p className="mt-5 rounded-[12px] bg-surface-container-low p-4 text-[13px] leading-relaxed text-on-surface-variant">
          These numbers are computed from your graded papers on this account. The spaced review queue at{' '}
          <Link href="/review" className="font-semibold text-primary underline-offset-2 hover:underline">
            Review
          </Link>{' '}
          schedules the weak topics automatically.
        </p>
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}

function HeadBar() {
  return (
    <div className="sticky top-0 z-40 border-b border-outline-variant/40 bg-surface/80 backdrop-blur-xl">
      <div className="mx-auto flex h-14 w-full max-w-2xl items-center gap-2 px-4 sm:px-6 md:h-16">
        <Link
          href="/dashboard"
          aria-label="Back to dashboard"
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
        >
          <span className="material-symbols-outlined text-[22px]">arrow_back</span>
        </Link>
        <h1 className="min-w-0 flex-1 text-[15px] font-semibold text-on-surface md:text-[17px]">Performance Analysis</h1>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-on-hero/8 px-3 py-2.5">
      <p className="text-xl font-bold tracking-tight text-on-hero">{value}</p>
      <p className="mt-0.5 font-mono text-[10.5px] uppercase tracking-wider text-hero-muted">{label}</p>
    </div>
  );
}

/** The hand-drawn score line: a single SVG polyline with dot caps. */
function ScoreChart({ points }: { points: number[] }) {
  if (points.length === 0) {
    return <p className="mt-3 text-sm text-on-surface-variant">No graded papers in this window yet.</p>;
  }
  if (points.length === 1) {
    return (
      <p className="mt-3 text-sm text-on-surface-variant">
        One paper so far: <span className="font-bold text-on-surface">{points[0]}%</span>. Sit another to draw the line.
      </p>
    );
  }
  const W = 560;
  const H = 150;
  const PAD = 14;
  const step = (W - PAD * 2) / (points.length - 1);
  const y = (pct: number) => H - PAD - (Math.max(0, Math.min(100, pct)) / 100) * (H - PAD * 2);
  const path = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${(PAD + i * step).toFixed(1)},${y(p).toFixed(1)}`).join(' ');
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="mt-3 w-full" role="img" aria-label="Score trend line chart">
      {[0, 25, 50, 75, 100].map((tick) => (
        <line key={tick} x1={PAD} x2={W - PAD} y1={y(tick)} y2={y(tick)} stroke="var(--color-outline-variant)" strokeWidth="1" strokeDasharray="3 5" opacity="0.5" />
      ))}
      <path d={path} fill="none" stroke="var(--color-primary)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      {points.map((p, i) => (
        <circle
          key={i}
          cx={PAD + i * step}
          cy={y(p)}
          r="3.5"
          fill={p >= 75 ? 'var(--color-accent-emerald)' : p >= 50 ? 'var(--color-accent-amber)' : 'var(--color-error)'}
        />
      ))}
    </svg>
  );
}
