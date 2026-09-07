'use client';

/**
 * Leaderboards — the standings the backend already keeps, finally on
 * the web: the arena board (weekly / all-time), the all-time XP board
 * and the daily challenge board for today's JAMB sprint. Every board
 * returns the caller's own row as "me" even when it sits outside the
 * top 25, so a student always learns exactly where they stand.
 */

import { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { api } from '@/lib/api';

interface ArenaEntry {
  rank: number;
  username: string;
  wins: number;
  matches: number;
  points: number;
  correct: number;
}

interface StudyEntry {
  rank: number;
  username: string;
  xp: number;
  bestStreak: number;
  currentStreak: number;
  attempts: number;
}

interface DailyEntry {
  rank: number;
  username: string;
  score: number;
  total: number;
  durationMs?: number | null;
}

type Tab = 'arena' | 'xp' | 'daily';

const TABS: Array<{ id: Tab; icon: string; label: string }> = [
  { id: 'arena', icon: 'sports_esports', label: 'Arena' },
  { id: 'xp', icon: 'bolt', label: 'XP' },
  { id: 'daily', icon: 'event_repeat', label: "Today's Challenge" },
];

function medal(rank: number): string {
  if (rank === 1) return '🥇';
  if (rank === 2) return '🥈';
  if (rank === 3) return '🥉';
  return String(rank);
}

function initial(username: string): string {
  return username.slice(0, 1).toUpperCase();
}

export default function LeaderboardClient() {
  const searchParams = useSearchParams();
  const initialTab = (searchParams.get('tab') as Tab) || 'arena';
  const [tab, setTab] = useState<Tab>(
    TABS.some((t) => t.id === initialTab) ? initialTab : 'arena',
  );
  const [period, setPeriod] = useState<'week' | 'all'>('week');

  const [arena, setArena] = useState<{ entries: ArenaEntry[]; me: ArenaEntry | null } | null>(null);
  const [xp, setXp] = useState<{ entries: StudyEntry[]; me: StudyEntry | null } | null>(null);
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
      } else if (tab === 'xp') {
        setXp(await api('/leaderboard/xp'));
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

  const board = tab === 'arena' ? arena : tab === 'xp' ? xp : daily;
  const me = tab === 'arena' ? arena?.me : tab === 'xp' ? xp?.me : daily?.me;

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

        {tab === 'daily' && daily && (
          <p className="mt-3 text-[13px] text-on-surface-variant">
            {daily.title} · {daily.day} — one sprint, everyone worldwide, first-write-wins.
          </p>
        )}

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
              <p className="font-mono text-[11px] text-on-surface-variant">
                rank {me.rank} · <span className="uppercase">{tab === 'daily' ? "today's challenge" : tab}</span>
              </p>
            </div>
            {tab === 'arena' && me && 'points' in me && (
              <p className="text-right font-mono text-sm font-bold text-on-surface">
                {me.points} <span className="text-[11px] font-normal text-on-surface-variant">pts</span>
              </p>
            )}
            {tab === 'xp' && me && 'xp' in me && (
              <p className="text-right font-mono text-sm font-bold text-on-surface">
                {me.xp} <span className="text-[11px] font-normal text-on-surface-variant">XP</span>
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
          {!board && !error && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">Loading the board…</p>
          )}
          {board && 'entries' in board && board.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">
              {tab === 'daily'
                ? 'Nobody has played today yet — be the first seat on the board.'
                : 'No entries yet — play a paper or a match to appear here.'}
            </p>
          )}
          {board &&
            'entries' in board &&
            board.entries.map((entry) => {
              const highlight =
                me != null && entry.rank === (me as { rank: number }).rank;
              return (
                <div
                  key={`${entry.rank}-${entry.username}`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0 ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <span
                    className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full font-mono text-[13px] font-bold ${
                      entry.rank <= 3
                        ? 'bg-accent-amber/15 text-accent-ink'
                        : 'bg-surface-container text-on-surface-variant'
                    }`}
                  >
                    {medal(entry.rank)}
                  </span>
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent-ink/10 text-[13px] font-bold text-accent-ink">
                    {initial(entry.username)}
                  </span>
                  <p className="min-w-0 flex-1 truncate text-[15px] font-medium text-on-surface">
                    {entry.username}
                  </p>
                  {'points' in entry && (
                    <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                      <p className="text-sm font-bold text-on-surface">{entry.points} pts</p>
                      <p>
                        {entry.wins}W · {entry.matches}m
                      </p>
                    </div>
                  )}
                  {'xp' in entry && (
                    <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                      <p className="text-sm font-bold text-on-surface">{entry.xp} XP</p>
                      <p>
                        {entry.attempts} papers · {entry.bestStreak}d best
                      </p>
                    </div>
                  )}
                  {'score' in entry && (
                    <p className="text-right font-mono text-sm font-bold text-on-surface">
                      {entry.score}/{entry.total}
                    </p>
                  )}
                </div>
              );
            })}
        </section>

        <p className="mt-3 text-center text-[11px] text-outline">
          Boards are graded on the server against the sealed keys — no browser tricks count.
        </p>
      </div>

      <BottomNav />
    </main>
  );
}
