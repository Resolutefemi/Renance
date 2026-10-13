'use client';

/**
 * LearnStats — the top-bar gamification counters (founder directive
 * 2026-10-14): the Supreme gem + heart chips on the Renance header,
 * live from GET /learn/profile. Gems and hearts both open the Shop.
 * Hearts read ∞ while the unlimited launch flag is on; the streak
 * flame keeps its existing pill next to them. Search was removed from
 * this row by the same directive.
 *
 * Founder fix (2026-10-14, "add the diamond count, the heart too to
 * the top navbar"): the chips must ALWAYS be visible. They used to
 * return null whenever /learn/profile failed (cold backend, offline,
 * deploy lag), so the counters silently vanished from the header.
 * The last known stats are cached in localStorage and rendered
 * immediately — zeros on a brand-new device — then refreshed live
 * whenever the API answers.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { GemIcon, HeartIcon } from '@/components/learn/bits';
import { LearnProfile, fetchLearnProfile } from '@/lib/learn';

const CACHE_KEY = 'renance.learnStats';

/** The launch-posture defaults shown before the first API answer. */
const FALLBACK: LearnProfile = {
  hearts: 5,
  unlimitedHearts: true,
  nextHeartInMs: null,
  gems: 0,
  xp: 0,
  streak: 0,
  dailyGoal: 50,
  todayXp: 0,
  superActive: false,
  boostActive: false,
  freezeCount: 0,
  league: 'Bronze',
  courseCount: 0,
  topicsDone: 0,
  perfectCount: 0,
};

function readCache(): LearnProfile {
  if (typeof window === 'undefined') return FALLBACK;
  try {
    const raw = window.localStorage.getItem(CACHE_KEY);
    if (!raw) return FALLBACK;
    const parsed = JSON.parse(raw) as Partial<LearnProfile>;
    // Merge over the fallback so an older cache shape can never crash
    // the header chips on a new deploy.
    return { ...FALLBACK, ...parsed };
  } catch {
    return FALLBACK;
  }
}

export function useLearnStats(enabled: boolean) {
  const [stats, setStats] = useState<LearnProfile>(FALLBACK);
  useEffect(() => {
    // Hydrate from the cache first (same tick, no flash of zeros).
    setStats(readCache());
    if (!enabled) return;
    let live = true;
    fetchLearnProfile()
      .then((p) => {
        if (!live) return;
        setStats(p);
        try {
          window.localStorage.setItem(CACHE_KEY, JSON.stringify(p));
        } catch {
          /* private mode: chips still show this visit's values */
        }
      })
      .catch(() => {
        /* cached chips stay up; retry happens on the next page view */
      });
    return () => {
      live = false;
    };
  }, [enabled]);
  return stats;
}

export function LearnStatChips({ stats }: { stats: LearnProfile | null }) {
  const s = stats ?? FALLBACK;
  return (
    <>
      <Link
        href="/shop"
        aria-label={`Gems: ${s.gems}`}
        title="Gems — open the Shop"
        className="flex h-8 min-w-[54px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 transition active:translate-y-[2px]"
      >
        <GemIcon size={17} />
        <span className="font-mono text-[12.5px] font-bold text-on-surface">{s.gems.toLocaleString()}</span>
      </Link>
      <Link
        href="/shop"
        aria-label={s.unlimitedHearts ? 'Hearts: unlimited' : `Hearts: ${s.hearts}`}
        title={s.unlimitedHearts ? 'Unlimited hearts at launch' : 'Hearts — open the Shop'}
        className="flex h-8 min-w-[46px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 transition active:translate-y-[2px]"
      >
        <HeartIcon size={16} />
        <span className="font-mono text-[12.5px] font-bold text-on-surface">
          {s.unlimitedHearts ? '∞' : s.hearts}
        </span>
      </Link>
    </>
  );
}
