'use client';

/**
 * Celebrations - the three reward moments of the deep-content pass
 * (founder directive 2026-10-16):
 *
 *   1. ChestOpening  - finishing a topic opens a reward chest: the
 *      chest shakes, bursts open, spins, and the reward pops out
 *      (streak freezes, gems capped at 30, or a 2x XP boost).
 *   2. StreakCelebration - the Duolingo-style streak popup: a full
 *      screen flame celebration that fires whenever the daily streak
 *      count moves up, with the day count animating.
 *   3. MilestoneCelebration - the achievement card: 7/14/30/50/100+
 *      day streaks, full course completions and league promotions,
 *      shareable straight to the Renance feed or out to other apps.
 *
 * All three are pure presentation: the server already decided and paid
 * the rewards before the overlay shows.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ChestDrop, MilestoneInfo } from '@/lib/learn';
import { ConfettiBurst } from '@/components/learn/bits';

// ─── 1. The chest ─────────────────────────────────────────────────────────

const CHEST_STAGES = ['shake', 'open', 'spin', 'reward'] as const;
type ChestStage = (typeof CHEST_STAGES)[number];

export function ChestOpening({ drop, onDone }: { drop: ChestDrop; onDone?: () => void }) {
  const [stage, setStage] = useState<ChestStage>('shake');

  useEffect(() => {
    const timers = [
      window.setTimeout(() => setStage('open'), 900),
      window.setTimeout(() => setStage('spin'), 1500),
      window.setTimeout(() => setStage('reward'), 2600),
      window.setTimeout(() => onDone?.(), 4200),
    ];
    return () => timers.forEach((t) => window.clearTimeout(t));
  }, [onDone]);

  const rewardTone =
    drop.kind === 'gems'
      ? { bg: 'bg-macaw-light', ring: 'border-macaw-ring', ink: 'text-macaw-dark' }
      : drop.kind === 'freeze'
        ? { bg: 'bg-[#e3f2fd]', ring: 'border-[#89c7f2]', ink: 'text-[#1565c0]' }
        : { bg: 'bg-[#fff4e0]', ring: 'border-accent-amber', ink: 'text-accent-amber' };

  return (
    <div className="fixed inset-0 z-[95] flex flex-col items-center justify-center bg-black/60 px-6 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Reward chest">
      <div className={`learn-chest-stage stage-${stage}`}>
        {/* The chest: lid + body, pure CSS, spins once open. */}
        <div className={`learn-chest ${stage === 'shake' ? 'learn-chest-shake' : ''} ${stage === 'spin' ? 'learn-chest-spin' : ''}`}>
          <div className="learn-chest-lid" />
          <div className="learn-chest-body">
            <div className="learn-chest-lock" />
          </div>
        </div>
        {/* The reward burst that pops out of the open lid. */}
        {(stage === 'reward' || stage === 'spin') && (
          <div className={`learn-chest-reward flex h-16 w-16 items-center justify-center rounded-2xl border-2 ${rewardTone.bg} ${rewardTone.ring}`}>
            <span className={`material-symbols-outlined text-[32px] ${rewardTone.ink}`}>{drop.icon}</span>
          </div>
        )}
      </div>

      {stage === 'reward' ? (
        <div className="mt-6 flex flex-col items-center gap-2 text-center">
          <p className="text-[13px] font-black uppercase tracking-[0.14em] text-white/80">Chest reward</p>
          <p className="text-[26px] font-black text-white">{drop.label}</p>
          {drop.kind === 'gems' && <p className="text-[12.5px] font-bold text-white/70">Added to your gem wallet</p>}
          {drop.kind === 'freeze' && <p className="text-[12.5px] font-bold text-white/70">Saves your streak on a rest day</p>}
          {drop.kind === 'boost' && <p className="text-[12.5px] font-bold text-white/70">Every correct answer pays double</p>}
        </div>
      ) : (
        <p className="mt-6 animate-pulse text-[14px] font-extrabold text-white/90">Your chest is opening…</p>
      )}
      <ConfettiBurst fire={stage === 'reward' ? 1 : 0} />
    </div>
  );
}

// ─── 2. The streak celebration ────────────────────────────────────────────

/** Count-up flame number (Duolingo's day-counter feel). */
function StreakCount({ to }: { to: number }) {
  const [n, setN] = useState(Math.max(0, to - 5));
  useEffect(() => {
    if (n >= to) return;
    const t = window.setTimeout(() => setN((v) => Math.min(to, v + 1)), 90);
    return () => window.clearTimeout(t);
  }, [n, to]);
  return <span className="tabular-nums">{n}</span>;
}

export function StreakCelebration({ streak, onDone }: { streak: number; onDone?: () => void }) {
  useEffect(() => {
    const t = window.setTimeout(() => onDone?.(), 5200);
    return () => window.clearTimeout(t);
  }, [onDone]);
  return (
    <div className="fixed inset-0 z-[96] flex flex-col items-center justify-center bg-black/70 px-6 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Streak celebration">
      <ConfettiBurst fire={1} />
      <div className="learn-streak-flame flex h-28 w-28 items-center justify-center rounded-full bg-gradient-to-b from-[#ff9600] to-[#ff4b4b] shadow-[0_0_60px_rgba(255,150,0,0.55)]">
        <span className="material-symbols-outlined text-[64px] text-white">local_fire_department</span>
      </div>
      <p className="mt-6 text-[15px] font-black uppercase tracking-[0.16em] text-white/85">
        {streak >= 2 ? 'Streak extended' : 'Streak started'}
      </p>
      <p className="mt-1 flex items-baseline gap-2 text-[56px] font-black leading-none text-white">
        <StreakCount to={streak} />
        <span className="text-[22px] font-extrabold text-white/85">day{streak === 1 ? '' : 's'}</span>
      </p>
      <p className="mt-3 max-w-xs text-center text-[13px] font-bold leading-relaxed text-white/75">
        You studied today - that is how streaks survive. Miss a day and a Streak Freeze saves it for you.
      </p>
      <button
        type="button"
        onClick={() => onDone?.()}
        className="key-btn mt-7 w-56 bg-primary text-on-primary"
      >
        Keep going
      </button>
    </div>
  );
}

// ─── 3. The milestone achievement ─────────────────────────────────────────

function milestoneIcon(code: string): string {
  if (code.startsWith('streak')) return 'local_fire_department';
  if (code.startsWith('course')) return 'school';
  if (code.startsWith('league')) return 'emoji_events';
  return 'military_tech';
}

export function MilestoneCelebration({ milestone, onDone }: { milestone: MilestoneInfo; onDone?: () => void }) {
  const [shared, setShared] = useState(false);

  const share = async () => {
    const text = `I just earned "${milestone.label}" on Renance - my study streak lives on renance.app 🎓🔥`;
    try {
      if (typeof navigator !== 'undefined' && navigator.share) {
        await navigator.share({ title: 'Renance achievement', text, url: 'https://renance.app/feed' });
        setShared(true);
      } else {
        await navigator.clipboard.writeText(`${text} https://renance.app/feed`);
        setShared(true);
      }
    } catch {
      /* the student dismissed the sheet - keep the card open */
    }
  };

  return (
    <div className="fixed inset-0 z-[96] flex flex-col items-center justify-center bg-black/70 px-6 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Achievement unlocked">
      <ConfettiBurst fire={1} />
      <div className="w-full max-w-sm rounded-3xl border-2 border-primary/50 bg-surface p-6 text-center shadow-2xl">
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/15">
          <span className="material-symbols-outlined text-[36px] text-primary-ink">{milestoneIcon(milestone.code)}</span>
        </div>
        <p className="mt-4 text-[12px] font-black uppercase tracking-[0.16em] text-primary-ink">Achievement unlocked</p>
        <h2 className="mt-1 text-[21px] font-black leading-snug text-on-surface">{milestone.label}</h2>
        <p className="mt-2 text-[12.5px] font-bold leading-relaxed text-on-surface-variant">
          This milestone just posted to the Renance feed for your followers to see.
        </p>
        <div className="mt-5 flex flex-col gap-2">
          <button type="button" onClick={() => void share()} className="key-btn w-full bg-primary text-on-primary">
            {shared ? 'Shared!' : 'Share this achievement'}
          </button>
          <Link href="/feed" className="key-btn w-full bg-card text-on-surface">
            View it in the feed
          </Link>
          <button
            type="button"
            onClick={() => onDone?.()}
            className="mx-auto rounded-xl px-4 py-2 text-[12.5px] font-extrabold text-on-surface-variant"
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  );
}
