'use client';

/**
 * League - the weekly XP league of the merged learn module (founder
 * directive 2026-10-14). Your real week's XP from XPEvents stands next
 * to every REAL member seated in this week's league - the synthetic
 * rival rows are retired (founder directive 2026-10-14: "remove those
 * mock students") - top 7 promote (+50 gems), ranks 26+ demote.
 * Countdown resets every Lagos Monday.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LeagueBadge } from '@/components/learn/bits';
import { getStoredUser } from '@/lib/session';
import { useRouter } from 'next/navigation';
import { LeagueBoard, fetchLeague, formatCountdown } from '@/lib/learn';

export default function LeaguePage() {
  const router = useRouter();
  const [board, setBoard] = useState<LeagueBoard | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    fetchLeague()
      .then(setBoard)
      .catch(() => {
        // No dead-end error card (founder: "remove retry"): the page
        // keeps its syncing face and the quiet poll below heals it.
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/league');
      return;
    }
    load();
  }, [load, router]);

  // The quiet re-sync: until the board answers, poll every 8s. The
  // page heals itself - nothing for the scholar to press.
  useEffect(() => {
    if (board) return;
    const t = window.setInterval(load, 8000);
    return () => window.clearInterval(t);
  }, [board, load]);

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <PageBar title="Leagues" backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        {loading && <div className="h-64 animate-pulse rounded-2xl bg-surface-container" aria-hidden />}

        {!loading && !board && (
          <div className="learn-tile flex flex-col items-center gap-2 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-12 text-center">
            <span className="material-symbols-outlined text-[36px] text-primary">trophy</span>
            <p className="text-[15px] font-black text-on-surface">The league table is syncing…</p>
            <p className="max-w-xs text-[12.5px] font-bold text-on-surface-variant">
              Your weekly standings appear the moment the connection is back.
            </p>
          </div>
        )}

        {board && (
          <div className="flex flex-col gap-4">
            {/* Header */}
            <header className="learn-tile flex flex-col items-center gap-2 rounded-2xl border-2 border-outline-variant bg-card px-4 py-6 text-center">
              <LeagueBadge name={board.league} size={64} />
              <h2 className="text-[20px] font-black text-on-surface">{board.league} League</h2>
              <p className="text-[12.5px] font-extrabold text-on-surface-variant">
                Resets in {formatCountdown(board.endsInMs)}
              </p>
              {(board.promotedLastWeek || board.demotedLastWeek) && (
                <p className={`rounded-full border-2 px-3 py-1 text-[12px] font-black ${
                  board.promotedLastWeek
                    ? 'border-primary bg-primary/10 text-primary-ink'
                    : 'border-error bg-error/10 text-error'
                }`}>
                  {board.promotedLastWeek ? 'Promoted last week - +50 gems!' : 'Demoted last week'}
                </p>
              )}
            </header>

            {/* Zones legend (demotion only renders when the board is
                actually big enough to have a demote zone) */}
            <div className="flex items-center justify-center gap-4 text-[11.5px] font-extrabold text-on-surface-variant">
              <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-primary" /> promotion zone (top {board.promotedCut})</span>
              {board.entries.length >= board.demotedFrom && (
                <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-error" /> demotion (rank {board.demotedFrom}+)</span>
              )}
            </div>

            {/* Board */}
            <ol className="overflow-hidden rounded-2xl border-2 border-outline-variant bg-card">
              {board.entries.map((e, i) => {
                const rank = i + 1;
                const zone = rank <= board.promotedCut ? 'bg-primary' : rank >= board.demotedFrom ? 'bg-error' : 'bg-transparent';
                // Every row is a real account: each one opens the
                // member's public profile.
                const body = (
                  <>
                    <span className={`absolute inset-y-0 left-0 w-1 ${zone}`} aria-hidden />
                    <span className="w-6 text-center font-mono text-[12.5px] font-black text-on-surface-variant">{rank}</span>
                    {e.isYou ? (
                      <span className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-primary bg-primary text-[13px] font-black text-on-primary">Y</span>
                    ) : (
                      <span className="flex h-8 w-8 items-center justify-center rounded-full text-[13px] font-black text-white" style={{ background: e.color || 'var(--color-on-surface-variant)' }}>
                        {e.name.slice(0, 1)}
                      </span>
                    )}
                    <span className={`min-w-0 flex-1 truncate text-[14px] font-extrabold ${e.isYou ? 'text-primary-ink' : 'text-on-surface'}`}>
                      {e.name}{e.isYou ? ' (You)' : ''}
                    </span>
                    <span className="font-mono text-[12.5px] font-black text-on-surface">{e.xp.toLocaleString()} XP</span>
                  </>
                );
                if (e.username && !e.isYou) {
                  return (
                    <li key={`${e.name}-${i}`} className="border-b-2 border-outline-variant last:border-b-0">
                      <Link
                        href={`/profile/view/?u=${encodeURIComponent(e.username)}`}
                        title={`${e.name} on their profile`}
                        className="relative flex items-center gap-3 px-3.5 py-2.5 transition hover:bg-surface-container-low"
                      >
                        {body}
                      </Link>
                    </li>
                  );
                }
                return (
                  <li key={`${e.name}-${i}`} className={`relative flex items-center gap-3 border-b-2 border-outline-variant px-3.5 py-2.5 last:border-b-0 ${e.isYou ? 'bg-primary/10' : ''}`}>
                    {body}
                  </li>
                );
              })}
            </ol>

            <p className="px-1 text-center text-[12px] font-bold text-on-surface-variant">
              Only lessons, reviews and practice earn league XP - win streaks do not count.
            </p>
          </div>
        )}
      </main>
      <BottomNav />
    </div>
  );
}
