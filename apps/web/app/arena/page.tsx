'use client';

/**
 * Arena lobby, the Stitch arena_lobby_light screen — now on real data:
 * the Global Rank board comes from GET /leaderboard/arena (server-side
 * ranks, honest empty state when nobody has queued yet) and the Daily
 * Tournament row rides the real daily challenge. The Find a Match CTA
 * opens the live matchmaking flow (the WS arena hub).
 * Founder rule: no purple anywhere, accents are ink.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { api } from '@/lib/api';

interface ArenaBoard {
  entries: Array<{ rank: number; username: string; points: number; wins: number }>;
  me: { rank: number; username: string; points: number } | null;
  period: string;
}

export default function ArenaLobbyPage() {
  const router = useRouter();
  const [board, setBoard] = useState<ArenaBoard | null>(null);
  const [boardErr, setBoardErr] = useState(false);

  useEffect(() => {
    let alive = true;
    api<ArenaBoard>('/leaderboard/arena')
      .then((b) => alive && setBoard(b))
      .catch(() => alive && setBoardErr(true));
    return () => {
      alive = false;
    };
  }, []);

  const rows: Array<{ rank: number | string; name: string; points: number | string; you?: boolean }> =
    board?.entries.slice(0, 5).map((e) => ({
      rank: e.rank,
      name: e.username,
      points: e.points,
    })) ?? [];
  if (board?.me && !rows.some((r) => r.you)) {
    rows.push({ rank: board.me.rank, name: board.me.username, points: board.me.points, you: true });
  }

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Arena" />
      </div>

      {/* dark hero */}
      <section className="renance-rise mt-4 rounded-2xl bg-gradient-to-tl from-[#0E2230] to-[#131B2E] p-6">
        <h2 className="text-xl font-semibold text-dark-text-primary">Arena</h2>
        <p className="mt-2.5 text-base leading-6 text-dark-text-primary/70">
          Head-to-head quizzes · 5 questions · first to answer scores
        </p>
        <button
          onClick={() => router.push('/arena/match')}
          className="mt-6 flex h-[52px] w-full items-center justify-center gap-2 rounded-xl bg-card text-[15px] font-semibold text-on-surface transition-all hover:shadow-md active:scale-[0.98]"
        >
          <span className="material-symbols-outlined text-[20px]">shuffle</span>
          Find a Match
        </button>
      </section>

      {/* Game Modes */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Game Modes</h2>
      <div className="mt-3.5 grid grid-cols-2 gap-3">
        <div className="relative h-[170px] overflow-hidden rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <span className="absolute -right-7 -top-7 h-[84px] w-[84px] rounded-full bg-amber-tint" />
          <span className="relative flex h-12 w-12 items-center justify-center rounded-full bg-amber-tint">
            <span className="material-symbols-outlined text-[24px] text-accent-amber">timer</span>
          </span>
          <p className="absolute bottom-4 left-4 text-lg font-semibold text-on-surface">Rapid</p>
          <p className="absolute bottom-4 left-[4.5rem] text-[15px] text-on-surface-variant">
            15s / question
          </p>
        </div>
        <div className="relative h-[170px] overflow-hidden rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <span className="absolute -right-7 -top-7 h-[84px] w-[84px] rounded-full bg-surface-container-high" />
          <span className="relative flex h-12 w-12 items-center justify-center rounded-full bg-surface-container-high">
            <span className="material-symbols-outlined text-[24px] text-accent-ink">bolt</span>
          </span>
          <p className="absolute bottom-4 left-4 text-lg font-semibold text-on-surface">Blitz</p>
          <p className="absolute bottom-4 left-[4.5rem] text-[15px] text-on-surface-variant">
            5 questions
          </p>
        </div>
      </div>

      {/* Daily Tournament — the real daily challenge, one tap away */}
      <Link
        href="/dashboard"
        className="mt-3 flex w-full items-center gap-3.5 rounded-2xl bg-card p-4 text-left shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition active:scale-[0.99]"
      >
        <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-full bg-emerald-tint">
          <span className="material-symbols-outlined text-[26px] text-accent-emerald">emoji_events</span>
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-[17px] font-semibold text-on-surface">Daily Challenge</span>
          <span className="block text-[15px] text-on-surface-variant">
            Today&apos;s sprint is on your dashboard
          </span>
        </span>
        <span className="material-symbols-outlined text-[24px] text-on-surface-variant">chevron_right</span>
      </Link>

      {/* Global Rank — the live arena board */}
      <div className="mt-7 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight text-on-surface">Global Rank</h2>
        <span className="rounded-full bg-surface-container-low px-3 py-1 text-[12px] text-on-surface-variant">
          This week
        </span>
      </div>
      <div className="mt-3.5 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        {boardErr && (
          <p className="px-4 py-5 text-center text-[14px] text-on-surface-variant">
            Could not load the board — check your connection.
          </p>
        )}
        {board && rows.length === 0 && (
          <p className="px-4 py-5 text-center text-[14px] text-on-surface-variant">
            No arena matches scored yet — be the first on the board. Find a Match above.
          </p>
        )}
        {rows.map((r) => (
          <div key={`${r.rank}-${r.name}`} className={`flex items-center gap-3 py-3 ${r.you ? 'bg-surface-container-low' : ''}`}>
            {r.you && <span className="h-16 w-1 shrink-0 self-center bg-primary" />}
            <span className={`w-12 shrink-0 text-center text-base text-on-surface ${r.you ? 'w-11' : ''}`}>{r.rank}</span>
            <span className={`flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full ${r.you ? 'bg-card' : 'bg-surface-container-low'}`}>
              {r.you ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/renance-mark.png`} alt="You" className="h-7 w-7" />
              ) : (
                <span className="material-symbols-outlined text-[22px] text-on-surface-variant">person</span>
              )}
            </span>
            <span className="min-w-0 flex-1 truncate text-base font-semibold text-on-surface">{r.name}</span>
            <span className={`pr-5 text-base font-bold ${r.you ? 'text-accent-emerald' : 'text-on-surface'}`}>
              {typeof r.points === 'number' ? r.points.toLocaleString() : r.points}
            </span>
          </div>
        ))}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
