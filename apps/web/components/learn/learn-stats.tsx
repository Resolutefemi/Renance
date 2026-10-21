'use client';

/**
 * LearnStats - the top-bar gamification counters (founder directive
 * 2026-10-14): the Supreme gem chip on the Renance header, live from
 * GET /learn/profile. The founder's 2026-10-14 evening pass moved the
 * HEART chip out of the top navbar ("remove the profile icon, and
 * heart from the top navbar") - hearts now read on the profile page,
 * where the shop lives too. The heart readout shows the REAL number
 * ("remove that infinite symbol replace with real data") - the ∞ is
 * retired everywhere. The last known stats are cached in localStorage
 * and rendered immediately - zeros on a brand-new device - then
 * refreshed live whenever the API answers.
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
  institutionType: '',
  department: '',
  departmentName: '',
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

/**
 * The top navbar chip: GEMS ONLY (founder 2026-10-14 evening pass -
 * the heart left the top bar). Founder 2026-10-22: the shop is a full
 * page again - the chip opens /shop directly.
 */
export function LearnStatChips({ stats }: { stats: LearnProfile | null }) {
  const s = stats ?? FALLBACK;
  return (
    <Link
      href="/shop"
      aria-label={`Gems: ${s.gems}`}
      title="Gems - open the shop"
      className="flex h-8 min-w-[54px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 transition active:translate-y-[2px]"
    >
      <GemIcon size={17} />
      <span className="font-mono text-[12.5px] font-bold text-on-surface">{s.gems.toLocaleString()}</span>
    </Link>
  );
}

/**
 * The heart readout - real data, never ∞ (founder rule). Lives on the
 * profile page next to the shop; taps scroll to the shop panel.
 */
export function HeartChip({ hearts, superActive }: { hearts: number; superActive?: boolean }) {
  return (
    <Link
      href="/profile#shop"
      aria-label={`Hearts: ${hearts}`}
      title={superActive ? 'Super active - hearts refill instantly' : 'Hearts - refill in the shop'}
      className="flex h-8 min-w-[46px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 transition active:translate-y-[2px]"
    >
      <HeartIcon size={16} />
      <span className="font-mono text-[12.5px] font-bold text-on-surface">{hearts}</span>
    </Link>
  );
}
