'use client';

/**
 * Badge detail, the Stitch badge_detail_light screen, 1:1.
 *
 * The orbiting dashed-circle hero with the badge medallion, the
 * "Rare · 4% of students" rarity pill, title + how-to-earn subtitle,
 * the progress card (current/target with the amber shimmering rail and
 * the "Keep it up, you're closer than you think!" caption), the
 * Related Badges rail (unlocked coloured, locked dimmed + lock chip)
 * and the black Share Achievement button. Progress numbers are real
 * where the badge code carries a threshold (streak_X, xp_X).
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { BADGES, type BadgeSpec, type GamificationSummary, holds } from '@/lib/progress';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

export default function BadgeDetailClient({ code }: { code: string }) {
  const router = useRouter();
  const [summary, setSummary] = useState<GamificationSummary | null>(null);

  useEffect(() => {
    api<GamificationSummary>('/me/gamification')
      .then(setSummary)
      .catch(() => {});
  }, []);

  const spec: BadgeSpec = BADGES.find((b) => b.code === code) ?? BADGES[0];
  const earned = summary ? holds(summary, spec.code) : false;
  const related = BADGES.filter((b) => b.code !== spec.code).slice(0, 3);

  // Progress numbers: streak_X -> current streak / X; xp_X -> total XP / X.
  const streak = summary?.state.currentStreak ?? 0;
  const xp = summary?.state.totalXp ?? 0;
  let metricLabel = 'Progress';
  let current = earned ? 1 : 0;
  let target = 1;
  if (spec.code.startsWith('streak_')) {
    const t = Number(spec.code.split('_')[1]);
    if (Number.isFinite(t) && t > 0) {
      metricLabel = 'Current streak';
      target = t;
      current = Math.min(streak, t);
    }
  } else if (spec.code.startsWith('xp_')) {
    const t = Number(spec.code.split('_')[1]);
    if (Number.isFinite(t) && t > 0) {
      metricLabel = 'Total XP';
      target = t;
      current = Math.min(xp, t);
    }
  }
  const fill = target <= 0 ? 0 : Math.min(1, current / target);

  return (
    <main className="min-h-dvh bg-background pb-28 md:pb-16">
      <PageBar title={spec.label} backHref="/progress" />

      <div className="mx-auto flex w-full max-w-5xl flex-col px-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl pb-8">
          {/* Hero ------------------------------------------------------ */}
          <div className="relative mb-4 mt-6 flex flex-col items-center justify-center gap-4">
            <div className="absolute inset-0 -z-10 flex items-center justify-center opacity-30" aria-hidden>
              <svg
                className="h-[240px] w-[240px] animate-[renance-orbit_20s_linear_infinite]"
                fill="none"
                viewBox="0 0 240 240"
              >
                <circle cx="120" cy="120" r="118" stroke="#D8E3FB" strokeDasharray="10 15" strokeWidth="2" />
                <circle cx="120" cy="120" r="90" stroke="#E7EEFF" strokeDasharray="20 10" strokeWidth="4" />
              </svg>
            </div>
            <div className="relative flex h-48 w-48 items-center justify-center rounded-full bg-surface-container shadow-[0_4px_24px_rgba(35,0,92,0.1)] transition-transform duration-500 hover:scale-105">
              <div className="absolute inset-2 rounded-full border border-surface-container-highest opacity-50" />
              <span
                className={`material-symbols-outlined z-10 text-[96px] drop-shadow-xl ${earned ? `fill-current ${spec.fgClass}` : 'text-outline-light'}`}
              >
                {spec.icon}
              </span>
            </div>
            <div className="flex flex-col items-center gap-1 px-4 text-center">
              <div className="inline-flex items-center gap-1 rounded-full bg-secondary-container px-2 py-1">
                <span
                  className={`material-symbols-outlined fill-current text-[16px] ${earned ? 'text-secondary' : 'text-outline'}`}
                >
                  {earned ? 'star' : 'lock'}
                </span>
                <span className="font-mono text-[11px] font-bold uppercase tracking-wider text-secondary">
                  {earned ? 'Rare · 4% of students' : 'Locked'}
                </span>
              </div>
              <h1 className="mt-2 text-2xl font-bold leading-8 tracking-[-0.01em] text-on-surface">
                {spec.label}
              </h1>
              <p className="text-[15px] text-on-surface-variant">{spec.hint}</p>
            </div>
          </div>

          {/* Progress card ---------------------------------------------- */}
          <section className="flex flex-col gap-2 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="mb-1 flex items-end justify-between">
              <div className="flex flex-col">
                <span className="mb-1 font-mono text-[11px] font-bold uppercase tracking-wider text-on-surface-variant">
                  {metricLabel}
                </span>
                <span className="text-2xl font-bold leading-7 tracking-[-0.02em] text-on-surface">
                  {current}
                  <span className="text-lg text-on-surface-variant">/{target}</span>
                </span>
              </div>
              <span className="material-symbols-outlined mb-1 fill-current text-[20px] text-accent-amber">
                local_fire_department
              </span>
            </div>
            <div className="h-3 w-full overflow-hidden rounded-full bg-surface-container-low">
              <div
                className="relative h-full overflow-hidden rounded-full bg-accent-amber transition-all duration-1000 ease-out"
                style={{ width: `${Math.round(fill * 100)}%` }}
              >
                <div className="absolute inset-0 animate-[renance-shimmer_2s_infinite] bg-white/30" />
              </div>
            </div>
            <p className="mt-1 text-center text-[13px] text-on-surface-variant">
              Keep it up, you&apos;re closer than you think!
            </p>
          </section>

          {/* Related Badges ---------------------------------------------- */}
          <div className="mt-6 flex flex-col gap-3">
            <div className="flex items-center justify-between px-1">
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                Related Badges
              </h2>
              <button
                type="button"
                onClick={() => router.push('/progress')}
                className="flex items-center text-sm font-semibold text-violet-deep"
              >
                View all
                <span className="material-symbols-outlined text-[18px]">chevron_right</span>
              </button>
            </div>
            <div className="flex gap-4 overflow-x-auto pb-2">
              {related.map((r) => {
                const rEarned = summary ? holds(summary, r.code) : false;
                return (
                  <div
                    key={r.code}
                    className={`flex w-36 shrink-0 snap-start flex-col items-center gap-1 rounded-xl bg-card p-2 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition-colors hover:border-surface-container ${
                      rEarned ? '' : 'opacity-60'
                    }`}
                  >
                    <div className="relative mb-1">
                      <div
                        className={`flex h-16 w-16 items-center justify-center rounded-full ${
                          rEarned ? 'bg-surface-container-low' : 'bg-surface-container-lowest shadow-inner'
                        }`}
                      >
                        <span
                          className={`material-symbols-outlined text-[32px] ${rEarned ? `fill-current ${r.fgClass}` : 'text-outline-light'}`}
                        >
                          {r.icon}
                        </span>
                      </div>
                      {!rEarned && (
                        <div className="absolute -bottom-2 -right-2 rounded-full border border-white bg-surface-container px-2 py-0.5">
                          <span className="material-symbols-outlined text-[14px] text-on-surface-variant">
                            lock
                          </span>
                        </div>
                      )}
                    </div>
                    <h3
                      className={`text-[15px] font-semibold leading-tight ${rEarned ? 'text-on-surface' : 'text-outline'}`}
                    >
                      {r.label}
                    </h3>
                    <p
                      className={`text-[11px] leading-tight ${rEarned ? 'text-on-surface-variant' : 'text-outline-light'}`}
                    >
                      {r.hint}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Share Achievement ------------------------------------------- */}
          <button
            type="button"
            onClick={() => {
              if (typeof navigator !== 'undefined' && navigator.share) {
                navigator
                  .share({ title: spec.label, text: `I earned the ${spec.label} badge on Renance!` })
                  .catch(() => {});
              } else if (typeof navigator !== 'undefined' && navigator.clipboard) {
                navigator.clipboard
                  .writeText(`I earned the ${spec.label} badge on Renance!`)
                  .then(() => window.alert('Copied to clipboard'))
                  .catch(() => {});
              }
            }}
            className="mt-8 flex h-[52px] w-full items-center justify-center rounded-[10px] bg-primary text-[15px] font-semibold text-on-primary shadow-[0_4px_12px_rgba(0,0,0,0.1)] transition-transform active:scale-95"
          >
            Share Achievement
          </button>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}
