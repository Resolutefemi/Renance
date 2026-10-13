'use client';

/**
 * LearnStats — the top-bar gamification counters (founder directive
 * 2026-10-14): the Supreme gem + heart chips on the Renance header,
 * live from GET /learn/profile. Gems and hearts both open the Shop.
 * Hearts read ∞ while the unlimited launch flag is on; the streak
 * flame keeps its existing pill next to them. Search was removed from
 * this row by the same directive.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { GemIcon, HeartIcon } from '@/components/learn/bits';
import { LearnProfile, fetchLearnProfile } from '@/lib/learn';

export function useLearnStats(enabled: boolean) {
  const [stats, setStats] = useState<LearnProfile | null>(null);
  useEffect(() => {
    if (!enabled) return;
    let live = true;
    fetchLearnProfile()
      .then((p) => live && setStats(p))
      .catch(() => { /* the chips stay hidden on failure */ });
    return () => { live = false; };
  }, [enabled]);
  return stats;
}

export function LearnStatChips({ stats }: { stats: LearnProfile | null }) {
  if (!stats) return null;
  return (
    <>
      <Link
        href="/shop"
        aria-label={`Gems: ${stats.gems}`}
        title="Gems — open the Shop"
        className="flex h-8 min-w-[54px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 transition active:translate-y-[2px]"
      >
        <GemIcon size={17} />
        <span className="font-mono text-[12.5px] font-bold text-on-surface">{stats.gems.toLocaleString()}</span>
      </Link>
      <Link
        href="/shop"
        aria-label={stats.unlimitedHearts ? 'Hearts: unlimited' : `Hearts: ${stats.hearts}`}
        title={stats.unlimitedHearts ? 'Unlimited hearts at launch' : 'Hearts — open the Shop'}
        className="flex h-8 min-w-[46px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 transition active:translate-y-[2px]"
      >
        <HeartIcon size={16} />
        <span className="font-mono text-[12.5px] font-bold text-on-surface">
          {stats.unlimitedHearts ? '∞' : stats.hearts}
        </span>
      </Link>
    </>
  );
}
