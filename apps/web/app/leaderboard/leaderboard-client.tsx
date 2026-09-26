'use client';

/**
 * Leaderboards, rebuilt around the focuses students actually chase:
 * the arena board (weekly / all-time), the JAMB ladder ranked on the
 * official UTME aggregate out of 400, the WAEC and NECO ladders ranked
 * on best paper percentage, the schools ladder ranked on finalized term
 * results, the streak ladder for the students still showing up, and the
 * daily challenge board. Every board returns the caller's own row as
 * "me" even when it sits outside the top 25, so a student always learns
 * exactly where they stand.
 */

import { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import BlueTick from '@/components/blue-tick';
import { api } from '@/lib/api';

interface ArenaEntry {
  rank: number;
  username: string;
  wins: number;
  matches: number;
  points: number;
  correct: number;
  premium?: boolean;
}

interface FocusEntry {
  rank: number;
  username: string;
  bestScore: number;
  scoreOutOf: number;
  papers: number;
  premium?: boolean;
}

interface StreakEntry {
  rank: number;
  username: string;
  currentStreak: number;
  bestStreak: number;
  attempts: number;
  premium?: boolean;
}

interface SchoolEntry {
  rank: number;
  school: string;
  students: number;
  results: number;
  avgScore: number;
  scoreOutOf: number;
}

interface DailyEntry {
  rank: number;
  username: string;
  score: number;
  total: number;
  durationMs?: number | null;
  premium?: boolean;
}

type Tab = 'arena' | 'jamb' | 'waec' | 'neco' | 'schools' | 'streak' | 'daily';

const TABS: Array<{ id: Tab; icon: string; label: string }> = [
  { id: 'arena', icon: 'sports_esports', label: 'Arena' },
  { id: 'jamb', icon: 'school', label: 'JAMB' },
  { id: 'waec', icon: 'menu_book', label: 'WAEC' },
  { id: 'neco', icon: 'history_edu', label: 'NECO' },
  { id: 'schools', icon: 'account_balance', label: 'Schools' },
  { id: 'streak', icon: 'local_fire_department', label: 'Streak' },
  { id: 'daily', icon: 'event_repeat', label: "Today's Challenge" },
];

function medal(rank: number): string {
  if (rank === 1) return '🥇';
  if (rank === 2) return '🥈';
  if (rank === 3) return '🥉';
  return String(rank);
}

function initial(name: string): string {
  return name.slice(0, 1).toUpperCase();
}

function fmtScore(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}

export default function LeaderboardClient() {
  const searchParams = useSearchParams();
  const initialTab = (searchParams.get('tab') as Tab) || 'arena';
  const [tab, setTab] = useState<Tab>(
    TABS.some((t) => t.id === initialTab) ? initialTab : 'arena',
  );
  const [period, setPeriod] = useState<'week' | 'all'>('week');

  const [arena, setArena] = useState<{ entries: ArenaEntry[]; me: ArenaEntry | null } | null>(null);
  const [focus, setFocus] = useState<{ entries: FocusEntry[]; me: FocusEntry | null } | null>(null);
  const [streak, setStreak] = useState<{ entries: StreakEntry[]; me: StreakEntry | null } | null>(null);
  const [schools, setSchools] = useState<{ entries: SchoolEntry[] } | null>(null);
  const [daily, setDaily] = useState<{
    day: string;
    title: string;
    entries: DailyEntry[];
    me: DailyEntry | null;
  } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      if (tab === 'arena') {
        setArena(await api(`/leaderboard/arena?period=${period}`));
      } else if (tab === 'jamb' || tab === 'waec' || tab === 'neco') {
        setFocus(await api(`/leaderboard/focus?focus=${tab}`));
      } else if (tab === 'streak') {
        setStreak(await api('/leaderboard/streak'));
      } else if (tab === 'schools') {
        setSchools(await api('/leaderboard/schools'));
      } else {
        setDaily(await api('/daily/jamb/leaderboard'));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load the board');
    }
  }, [tab, period]);

  useEffect(() => {
    void load();
  }, [load]);

  const isFocus = tab === 'jamb' || tab === 'waec' || tab === 'neco';
  const hasMe = tab === 'arena' || isFocus || tab === 'streak' || tab === 'daily';
  const me = hasMe
    ? tab === 'arena'
      ? arena?.me
      : isFocus
        ? focus?.me
        : tab === 'streak'
          ? streak?.me
          : daily?.me
    : null;

  const emptyHint =
    tab === 'daily'
      ? 'Nobody has played today yet, be the first seat on the board.'
      : tab === 'arena'
        ? 'No entries yet, play a match to appear here.'
        : tab === 'jamb'
          ? 'No official UTME mock graded yet. Take one and claim the first seat.'
          : tab === 'waec' || tab === 'neco'
            ? 'No graded paper in this focus yet. Be the first on the board.'
            : tab === 'streak'
              ? 'No streaks yet. Study today and start yours.'
              : 'No school results finalized yet.';

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16">
      <PageBar title="Leaderboard" />

      <div className="mx-auto flex w-full max-w-3xl flex-col px-4 sm:px-6">
        {/* tabs */}
        <div className="no-scrollbar mt-3 flex gap-2 overflow-x-auto pb-1">
          {TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => setTab(t.id)}
              className={`flex shrink-0 items-center gap-1.5 rounded-full px-4 py-2.5 text-sm transition ${
                tab === t.id
                  ? 'bg-primary font-semibold text-on-primary shadow-sm'
                  : 'bg-card text-on-surface-variant shadow-sm hover:bg-surface-container'
              }`}
            >
              <span className={`material-symbols-outlined text-[18px] ${tab === t.id ? 'fill-current' : ''}`}>
                {t.icon}
              </span>
              {t.label}
            </button>
          ))}
        </div>

        {/* arena period toggle */}
        {tab === 'arena' && (
          <div className="mt-3 flex w-fit rounded-lg bg-surface-container p-1">
            {(['week', 'all'] as const).map((p) => (
              <button
                key={p}
                type="button"
                onClick={() => setPeriod(p)}
                className={`rounded-md px-4 py-1.5 text-[13px] font-medium transition ${
                  period === p ? 'bg-card text-on-surface shadow-sm' : 'text-on-surface-variant'
                }`}
              >
                {p === 'week' ? 'This week' : 'All time'}
              </button>
            ))}
          </div>
        )}

        {/* the one-line explanation each board deserves */}
        <p className="mt-3 text-[13px] text-on-surface-variant">
          {tab === 'arena' && 'Head-to-head duels, weekly and all time. A win is a point.'}
          {tab === 'jamb' && 'Your best official UTME aggregate out of 400. The sealed subject ledger decides, no percentages.'}
          {tab === 'waec' && 'Your best WAEC paper, graded on the server against the sealed keys.'}
          {tab === 'neco' && 'Your best NECO paper, graded on the server against the sealed keys.'}
          {tab === 'schools' && 'Every school on Renance, ranked by the average its students hold on finalized term results.'}
          {tab === 'streak' && 'The students still showing up, day after day. Miss a day and the count resets.'}
          {tab === 'daily' && daily
            ? `${daily.title} · ${daily.day}, one sprint, everyone worldwide, first-write-wins.`
            : tab === 'daily'
              ? "Today's challenge, one sprint, everyone worldwide."
              : null}
        </p>

        {error && (
          <p className="mt-4 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
            {error}
          </p>
        )}

        {/* the caller's own row, pinned above the table */}
        {me && (
          <div className="mt-4 flex items-center gap-3 rounded-xl border-2 border-primary/30 bg-selection-blue/30 p-4 shadow-sm">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary font-mono text-[13px] font-bold text-on-primary">
              {me.rank}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[15px] font-semibold text-on-surface">You</p>
              <p className="font-mono text-[11px] uppercase text-on-surface-variant">
                rank {me.rank} · {tab}
              </p>
            </div>
            {tab === 'arena' && me && 'points' in me && (
              <p className="text-right font-mono text-sm font-bold text-on-surface">
                {me.points} <span className="text-[11px] font-normal text-on-surface-variant">pts</span>
              </p>
            )}
            {isFocus && me && 'bestScore' in me && (
              <p className="text-right font-mono text-sm font-bold text-on-surface">
                {fmtScore(me.bestScore)}
                <span className="text-[11px] font-normal text-on-surface-variant">/{me.scoreOutOf}</span>
              </p>
            )}
            {tab === 'streak' && me && 'currentStreak' in me && (
              <p className="text-right font-mono text-sm font-bold text-on-surface">
                🔥 {me.currentStreak} <span className="text-[11px] font-normal text-on-surface-variant">days</span>
              </p>
            )}
            {tab === 'daily' && me && 'score' in me && (
              <p className="text-right font-mono text-sm font-bold text-on-surface">
                {me.score}/{me.total}
              </p>
            )}
          </div>
        )}

        {/* the board */}
        <section className="mt-4 overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          {((tab === 'arena' && !arena) ||
            (isFocus && !focus) ||
            (tab === 'streak' && !streak) ||
            (tab === 'schools' && !schools) ||
            (tab === 'daily' && !daily)) &&
            !error && (
              <p className="px-4 py-10 text-center text-sm text-on-surface-variant">Loading the board…</p>
            )}
          {tab === 'arena' && arena && arena.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {isFocus && focus && focus.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {tab === 'streak' && streak && streak.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {tab === 'schools' && schools && schools.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {tab === 'daily' && daily && daily.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}

          {tab === 'arena' &&
            arena?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <div
                  key={`${entry.rank}-${entry.username}`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0 ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent-ink/10 text-[13px] font-bold text-accent-ink">
                    {initial(entry.username)}
                  </span>
                  <p className="flex min-w-0 flex-1 items-center gap-1.5 text-[15px] font-medium text-on-surface">
                    <span className="min-w-0 truncate">{entry.username}</span>
                    {entry.premium && <BlueTick size={15} />}
                  </p>
                  <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                    <p className="text-sm font-bold text-on-surface">{entry.points} pts</p>
                    <p>
                      {entry.wins}W · {entry.matches}m
                    </p>
                  </div>
                </div>
              );
            })}

          {isFocus &&
            focus?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <div
                  key={`${entry.rank}-${entry.username}`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0 ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent-ink/10 text-[13px] font-bold text-accent-ink">
                    {initial(entry.username)}
                  </span>
                  <p className="flex min-w-0 flex-1 items-center gap-1.5 text-[15px] font-medium text-on-surface">
                    <span className="min-w-0 truncate">{entry.username}</span>
                    {entry.premium && <BlueTick size={15} />}
                  </p>
                  <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                    <p className={`text-sm font-bold ${tab === 'jamb' ? 'text-accent-ink' : 'text-on-surface'}`}>
                      {fmtScore(entry.bestScore)}
                      <span className="text-[11px] font-normal text-on-surface-variant">/{entry.scoreOutOf}</span>
                    </p>
                    <p>
                      {entry.papers} {entry.papers === 1 ? 'paper' : 'papers'}
                    </p>
                  </div>
                </div>
              );
            })}

          {tab === 'streak' &&
            streak?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <div
                  key={`${entry.rank}-${entry.username}`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0 ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent-ink/10 text-[13px] font-bold text-accent-ink">
                    {initial(entry.username)}
                  </span>
                  <p className="flex min-w-0 flex-1 items-center gap-1.5 text-[15px] font-medium text-on-surface">
                    <span className="min-w-0 truncate">{entry.username}</span>
                    {entry.premium && <BlueTick size={15} />}
                  </p>
                  <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                    <p className="text-sm font-bold text-on-surface">
                      🔥 {entry.currentStreak} <span className="text-[11px] font-normal">days</span>
                    </p>
                    <p>best {entry.bestStreak}d</p>
                  </div>
                </div>
              );
            })}

          {tab === 'schools' &&
            schools?.entries.map((entry) => (
              <div
                key={`${entry.rank}-${entry.school}`}
                className="flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0"
              >
                <RankPill rank={entry.rank} />
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent-ink/10 text-accent-ink">
                  <span className="material-symbols-outlined text-[16px]">account_balance</span>
                </span>
                <p className="min-w-0 flex-1 truncate text-[15px] font-medium text-on-surface">{entry.school}</p>
                <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                  <p className="text-sm font-bold text-on-surface">{fmtScore(entry.avgScore)}%</p>
                  <p>
                    {entry.students} {entry.students === 1 ? 'student' : 'students'}
                  </p>
                </div>
              </div>
            ))}

          {tab === 'daily' &&
            daily?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <div
                  key={`${entry.rank}-${entry.username}`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0 ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent-ink/10 text-[13px] font-bold text-accent-ink">
                    {initial(entry.username)}
                  </span>
                  <p className="flex min-w-0 flex-1 items-center gap-1.5 text-[15px] font-medium text-on-surface">
                    <span className="min-w-0 truncate">{entry.username}</span>
                    {entry.premium && <BlueTick size={15} />}
                  </p>
                  <p className="text-right font-mono text-sm font-bold text-on-surface">
                    {entry.score}/{entry.total}
                  </p>
                </div>
              );
            })}
        </section>

        <p className="mt-3 text-center text-[11px] text-outline">
          Boards are graded on the server against the sealed keys, no browser tricks count.
        </p>
      </div>

      <BottomNav />
    </main>
  );
}

function RankPill({ rank }: { rank: number }) {
  return (
    <span
      className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full font-mono text-[13px] font-bold ${
        rank <= 3 ? 'bg-accent-amber/15 text-accent-ink' : 'bg-surface-container text-on-surface-variant'
      }`}
    >
      {medal(rank)}
    </span>
  );
}
