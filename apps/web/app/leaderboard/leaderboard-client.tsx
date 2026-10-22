'use client';

/**
 * Leaderboards, rebuilt around the focuses students actually chase:
 * the JAMB ladder ranked on the
 * official UTME aggregate out of 400, the WAEC and NECO ladders ranked
 * on best paper percentage, the streak ladder for the students still
 * showing up, and the daily challenge board. Every board returns the
 * caller's own row as "me" even when it sits outside the top 25, so a
 * student always learns exactly where they stand. (Schools are not
 * ranked - founder directive 2026-09-30.)
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import BlueTick from '@/components/blue-tick';
import { PersonAvatar } from '@/components/person-avatar';
import { api } from '@/lib/api';

interface FocusEntry {
  rank: number;
  username: string;
  avatar?: string;
  photo?: string;
  bestScore: number;
  scoreOutOf: number;
  papers: number;
  premium?: boolean;
}

interface StreakEntry {
  rank: number;
  username: string;
  avatar?: string;
  photo?: string;
  currentStreak: number;
  bestStreak: number;
  attempts: number;
  premium?: boolean;
}

interface DailyEntry {
  rank: number;
  username: string;
  avatar?: string;
  photo?: string;
  score: number;
  total: number;
  durationMs?: number | null;
  premium?: boolean;
}

type Tab = 'jamb' | 'waec' | 'neco' | 'streak' | 'gems' | 'daily';

const TABS: Array<{ id: Tab; icon: string; label: string }> = [
  // Arena retired (founder 2026-10-22).
  { id: 'jamb', icon: 'school', label: 'JAMB' },
  { id: 'waec', icon: 'menu_book', label: 'WAEC' },
  { id: 'neco', icon: 'history_edu', label: 'NECO' },
  { id: 'streak', icon: 'local_fire_department', label: 'Streak' },
  { id: 'gems', icon: 'diamond', label: 'Diamonds' },
  { id: 'daily', icon: 'event_repeat', label: "Today's Challenge" },
];

interface GemsEntry {
  rank: number;
  userId: string;
  username: string;
  gems: number;
  xp: number;
  streak: number;
  premium?: boolean;
  avatar?: string;
  photo?: string;
}

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
  const initialTab = (searchParams.get('tab') as Tab) || 'gems';
  const [tab, setTab] = useState<Tab>(
    TABS.some((t) => t.id === initialTab) ? initialTab : 'gems',
  );

  const [focus, setFocus] = useState<{ entries: FocusEntry[]; me: FocusEntry | null } | null>(null);
  const [streak, setStreak] = useState<{ entries: StreakEntry[]; me: StreakEntry | null } | null>(null);
  const [gems, setGems] = useState<{ entries: GemsEntry[]; me: GemsEntry | null } | null>(null);
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
      if (tab === 'jamb' || tab === 'waec' || tab === 'neco') {
        setFocus(await api(`/leaderboard/focus?focus=${tab}`));
      } else if (tab === 'streak') {
        setStreak(await api('/leaderboard/streak'));
      } else if (tab === 'gems') {
        setGems(await api('/leaderboard/gems'));
      } else {
        setDaily(await api('/daily/jamb/leaderboard'));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load the board');
    }
  }, [tab]);

  useEffect(() => {
    void load();
  }, [load]);

  const isFocus = tab === 'jamb' || tab === 'waec' || tab === 'neco';
  const hasMe = isFocus || tab === 'streak' || tab === 'gems' || tab === 'daily';
  const me = hasMe
    ? isFocus
        ? focus?.me
        : tab === 'streak'
          ? streak?.me
          : tab === 'gems'
            ? gems?.me
            : daily?.me
    : null;

  const emptyHint =
    tab === 'daily'
      ? 'Nobody has played today yet, be the first seat on the board.'
      : tab === 'jamb'
          ? 'No official UTME mock graded yet. Take one and claim the first seat.'
          : tab === 'waec' || tab === 'neco'
            ? 'No graded paper in this focus yet. Be the first on the board.'
            : tab === 'streak'
              ? 'No streaks yet. Study today and start yours.'
              : tab === 'gems'
                ? 'No gems banked yet. Clear a topic to earn your first diamonds.'
                : 'Nobody has played today yet, be the first seat on the board.';

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

        {/* the one-line explanation each board deserves */}
        <p className="mt-3 text-[13px] text-on-surface-variant">
          {tab === 'jamb' && 'Your best official UTME aggregate out of 400. The sealed subject ledger decides, no percentages.'}
          {tab === 'waec' && 'Your best WAEC paper, graded on the server against the sealed keys.'}
          {tab === 'neco' && 'Your best NECO paper, graded on the server against the sealed keys.'}
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
          {(isFocus && !focus) ||
            (tab === 'streak' && !streak) ||
            (tab === 'gems' && !gems) ||
            (tab === 'daily' && !daily) &&
            !error && (
              <p className="px-4 py-10 text-center text-sm text-on-surface-variant">Loading the board…</p>
            )}
          {isFocus && focus && focus.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {tab === 'streak' && streak && streak.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {tab === 'gems' && gems && gems.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}
          {tab === 'daily' && daily && daily.entries.length === 0 && (
            <p className="px-4 py-10 text-center text-sm text-on-surface-variant">{emptyHint}</p>
          )}

                    {isFocus &&
            focus?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <Link
                  href={`/profile/view/?u=${encodeURIComponent(entry.username)}`}
                  key={`${entry.rank}-${entry.username}`}
                  title={`${entry.username} on their profile`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 transition last:border-b-0 hover:bg-surface-container-low ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <PersonAvatar
                    person={{ avatar: entry.avatar, photo: entry.photo, name: entry.username, username: entry.username }}
                    size={32}
                  />
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
                </Link>
              );
            })}

          {tab === 'streak' &&
            streak?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <Link
                  href={`/profile/view/?u=${encodeURIComponent(entry.username)}`}
                  key={`${entry.rank}-${entry.username}`}
                  title={`${entry.username} on their profile`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 transition last:border-b-0 hover:bg-surface-container-low ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <PersonAvatar
                    person={{ avatar: entry.avatar, photo: entry.photo, name: entry.username, username: entry.username }}
                    size={32}
                  />
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
                </Link>
              );
            })}

          {tab === 'gems' &&
            gems?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              return (
                <Link
                  href={`/profile/view/?u=${encodeURIComponent(entry.username)}`}
                  key={`${entry.rank}-${entry.username}`}
                  title={`${entry.username} on their profile`}
                  className={`flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 transition last:border-b-0 hover:bg-surface-container-low ${
                    highlight ? 'bg-selection-blue/30' : ''
                  }`}
                >
                  <RankPill rank={entry.rank} />
                  <PersonAvatar
                    person={{ avatar: entry.avatar, photo: entry.photo, name: entry.username, username: entry.username }}
                    size={32}
                  />
                  <p className="flex min-w-0 flex-1 items-center gap-1.5 text-[15px] font-medium text-on-surface">
                    <span className="min-w-0 truncate">{entry.username}</span>
                    {entry.premium && <BlueTick size={15} />}
                  </p>
                  <div className="text-right font-mono text-[12px] leading-4 text-on-surface-variant">
                    <p className="text-sm font-bold text-on-surface">
                      {'\u25C6'} {entry.gems.toLocaleString()}
                    </p>
                    <p>
                      {entry.xp.toLocaleString()} xp{entry.streak > 0 ? ` · ${entry.streak}d` : ''}
                    </p>
                  </div>
                </Link>
              );
            })}

          {tab === 'daily' &&
            daily?.entries.map((entry) => {
              const highlight = me != null && entry.rank === me.rank;
              // Founder 2026-10-16: every board row opens the player's
              // profile - the daily board was the last one that didn't.
              const row = (
                <>
                  <RankPill rank={entry.rank} />
                  <PersonAvatar
                    person={{ avatar: entry.avatar, photo: entry.photo, name: entry.username, username: entry.username }}
                    size={32}
                  />
                  <p className="flex min-w-0 flex-1 items-center gap-1.5 text-[15px] font-medium text-on-surface">
                    <span className="min-w-0 truncate">{entry.username}</span>
                    {entry.premium && <BlueTick size={15} />}
                  </p>
                  <p className="text-right font-mono text-sm font-bold text-on-surface">
                    {entry.score}/{entry.total}
                  </p>
                </>
              );
              const cls = `flex items-center gap-3 border-b border-outline-variant/30 px-4 py-3 last:border-b-0 ${
                highlight ? 'bg-selection-blue/30' : ''
              }`;
              return highlight ? (
                <div key={`${entry.rank}-${entry.username}`} className={cls}>{row}</div>
              ) : (
                <Link
                  key={`${entry.rank}-${entry.username}`}
                  href={`/profile/view/?u=${encodeURIComponent(entry.username)}`}
                  className={`${cls} transition active:bg-surface-container`}
                >
                  {row}
                </Link>
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
