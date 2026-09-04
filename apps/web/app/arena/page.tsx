'use client';

/**
 * Arena lobby, the Stitch arena_lobby_light screen.
 * Dark hero with the Find a Match CTA, the Rapid / Blitz game mode cards,
 * the Daily Tournament row and the Global Rank board (Stitch copy).
 * Founder rule: no purple anywhere, accents are ink.
 */

import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const RANKS: ReadonlyArray<{ rank: string; name: string; points: string; you?: boolean }> = [
  { rank: '1', name: 'Alex Chen', points: '2,450' },
  { rank: '2', name: 'Sam Rivera', points: '2,390' },
  { rank: '214', name: 'You', points: '1,820', you: true },
];

export default function ArenaLobbyPage() {
  const router = useRouter();

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Arena" />
      </div>

      {/* dark hero */}
      <section className="renance-rise mt-4 rounded-2xl bg-gradient-to-tl from-[#0E2230] to-[#131B2E] p-6">
        <h2 className="text-xl font-semibold text-dark-text-primary">Arena</h2>
        <p className="mt-2.5 text-base leading-6 text-dark-text-primary/70">
          Head-to-head quizzes · 5 questions · 60 seconds
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
          <p className="absolute bottom-4 left-[4.5rem] text-[15px] text-on-surface-variant">3 mins</p>
        </div>
        <div className="relative h-[170px] overflow-hidden rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <span className="absolute -right-7 -top-7 h-[84px] w-[84px] rounded-full bg-surface-container-high" />
          <span className="relative flex h-12 w-12 items-center justify-center rounded-full bg-surface-container-high">
            <span className="material-symbols-outlined text-[24px] text-accent-ink">bolt</span>
          </span>
          <p className="absolute bottom-4 left-4 text-lg font-semibold text-on-surface">Blitz</p>
          <p className="absolute bottom-4 left-[4.5rem] text-[15px] text-on-surface-variant">60 secs</p>
        </div>
      </div>

      {/* Daily Tournament */}
      <button className="mt-3 flex w-full items-center gap-3.5 rounded-2xl bg-card p-4 text-left shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition active:scale-[0.99]">
        <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-full bg-emerald-tint">
          <span className="material-symbols-outlined text-[26px] text-accent-emerald">emoji_events</span>
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-[17px] font-semibold text-on-surface">Daily Tournament</span>
          <span className="block text-[15px] text-on-surface-variant">Ends in 4h 12m</span>
        </span>
        <span className="material-symbols-outlined text-[24px] text-on-surface-variant">chevron_right</span>
      </button>

      {/* Global Rank */}
      <div className="mt-7 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight text-on-surface">Global Rank</h2>
        <button className="rounded px-1 py-0.5 text-[15px] font-semibold text-on-surface">View All</button>
      </div>
      <div className="mt-3.5 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        {RANKS.map((r) => (
          <div key={r.rank} className={`flex items-center gap-3 py-3 ${r.you ? 'bg-surface-container-low' : ''}`}>
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
            <span className={`pr-5 text-base font-bold ${r.you ? 'text-on-surface' : 'text-accent-emerald'}`}>
              {r.points}
            </span>
          </div>
        ))}
      </div>

      <BottomNav />
    </main>
  );
}
