'use client';

/**
 * Progress, the gamification hub (design: gamification_hub_light /
 * gamification_hub_full_dark). Streak hero with 7-day dots, level card with
 * XP progress, badge grid (earned vs locked) and the recent-awards ledger.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { getToken } from '@/lib/session';
import {
  BADGES,
  comma,
  holds,
  relativeAgo,
  weekDots,
  type BadgeSpec,
  type GamificationSummary,
} from '@/lib/progress';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

export default function ProgressPage() {
  const router = useRouter();
  const [data, setData] = useState<GamificationSummary | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setData(await api<GamificationSummary>('/me/gamification'));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load progress');
    }
  }, []);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    void load();
  }, [router, load]);

  if (!data && !error) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-background">
        <LogoActivityIndicator state="busy" label="Loading your progress…" />
      </main>
    );
  }

  if (error) {
    return (
      <main className="flex min-h-dvh flex-col items-center justify-center gap-5 bg-background px-8 text-center">
        <span className="material-symbols-outlined text-4xl text-error">
          cloud_off
        </span>
        <p className="text-sm text-on-surface-variant">{error}</p>
        <button
          onClick={() => void load()}
          className="rounded-[10px] bg-primary px-6 py-3 text-sm font-semibold text-on-primary transition hover:opacity-90"
        >
          Try again
        </button>
      </main>
    );
  }

  const s = data!.state;
  const earned = BADGES.filter((b) => holds(data!, b.code));
  const locked = BADGES.filter((b) => !holds(data!, b.code));
  const dots = weekDots(s);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16">
      <PageBar title="Progress" />
      <div className="mx-auto w-full max-w-xl px-4 pt-6 sm:px-6">
      {/* header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <RenanceMark size={40} />
          <h1 className="text-lg font-semibold tracking-tight text-on-surface">
            Progress
          </h1>
          {s.currentStreak > 0 && (
            <span className="flex items-center gap-1 rounded-full bg-surface-container-low px-2.5 py-1 text-xs font-bold text-on-surface">
              <span className="material-symbols-outlined fill-current text-[16px] text-accent-amber">
                local_fire_department
              </span>
              {s.currentStreak}
            </span>
          )}
        </div>
        <Link
          href="/dashboard"
          className="rounded-lg border border-outline-variant px-3 py-1.5 text-xs text-on-surface-variant transition hover:border-outline hover:text-on-surface"
        >
          Back to desk
        </Link>
      </div>

      {/* streak hero */}
      <section className="mt-6 rounded-xl border border-outline-variant/40 bg-surface-container-lowest p-6 shadow-[0_1px_3px_rgba(20,28,45,0.10)]">
        <div className="flex items-center justify-center gap-2">
          <span className="material-symbols-outlined fill-current text-[22px] text-accent-amber">
            local_fire_department
          </span>
          <h2 className="text-sm font-semibold text-on-surface">
            Current Streak
          </h2>
        </div>
        <div className="mt-1 flex items-baseline justify-center gap-1.5">
          <span className="text-5xl font-bold tracking-tight text-on-surface">
            {s.currentStreak}
          </span>
          <span className="text-sm text-on-surface-variant">Days</span>
        </div>
        <p className="mt-1 text-center text-xs text-on-surface-variant">
          Best Streak: {s.bestStreak}
        </p>

        {/* 7-day dots */}
        <div className="mx-auto mt-6 flex max-w-[300px] items-start justify-between">
          {dots.map((d, i) => (
            <div key={i} className="flex flex-col items-center gap-1.5">
              <span
                className={`text-[11px] ${
                  d.isToday
                    ? 'font-bold text-on-surface'
                    : 'text-on-surface-variant'
                }`}
              >
                {d.label}
              </span>
              <DayCircle dot={d} />
            </div>
          ))}
        </div>
      </section>

      {/* level card */}
      <section className="mt-4 rounded-xl border border-outline-variant/40 bg-surface-container-lowest p-5 shadow-[0_1px_3px_rgba(20,28,45,0.10)]">
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-base font-bold text-on-surface">
                Level {s.level}
              </h2>
              <span className="material-symbols-outlined text-[18px] text-accent-emerald">
                verified
              </span>
            </div>
            <p className="mt-0.5 text-xs text-on-surface-variant">
              {s.totalCorrect} correct · {s.attempts} papers
            </p>
          </div>
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-container text-lg font-bold text-white">
            {s.level}
          </div>
        </div>
        <div className="mt-4">
          <div className="mb-2 flex justify-between text-[11px] text-on-surface-variant">
            <span>{comma(s.totalXp)} XP</span>
            <span>{comma(s.level * 500)} XP</span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-surface-container-high">
            <div
              className="h-full rounded-full bg-primary transition-[width] duration-500"
              style={{ width: `${Math.min(100, (s.totalXp % 500) / 5)}%` }}
            />
          </div>
        </div>
      </section>

      {/* badges */}
      <h2 className="mt-8 px-1 text-xs font-semibold uppercase tracking-[1.2px] text-on-surface-variant">
        Badges
      </h2>
      <div className="mt-3 grid grid-cols-3 gap-3">
        {[...earned, ...locked].map((b) => (
          <BadgeTile key={b.code} badge={b} earned={holds(data!, b.code)} />
        ))}
      </div>

      {/* recent awards */}
      {data!.awards.length > 0 && (
        <>
          <h2 className="mt-8 px-1 text-xs font-semibold uppercase tracking-[1.2px] text-on-surface-variant">
            Recent Awards
          </h2>
          <div className="mt-3 space-y-2">
            {data!.awards.slice(0, 5).map((a) => {
              const spec =
                BADGES.find((b) => b.code === a.code) ??
                ({
                  label: 'Badge',
                  icon: 'emoji_events',
                  bgClass: 'bg-selection-blue',
                  fgClass: 'text-on-surface',
                } as BadgeSpec);
              return (
                <div
                  key={a.code + a.earnedAt}
                  className="flex items-center gap-4 rounded-xl bg-surface-container-lowest p-4 shadow-[0_1px_3px_rgba(20,28,45,0.10)]"
                >
                  <div
                    className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${spec.bgClass} ${spec.fgClass}`}
                  >
                    <span className="material-symbols-outlined fill-current text-[20px]">
                      {spec.icon}
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-on-surface">
                      {spec.label} Badge Earned
                    </p>
                    <p className="truncate text-xs text-on-surface-variant">
                      {spec.hint}
                    </p>
                  </div>
                  <span className="shrink-0 text-[11px] text-on-surface-variant">
                    {relativeAgo(a.earnedAt)}
                  </span>
                </div>
              );
            })}
          </div>
        </>
      )}
      </div>
      <BottomNav />
    </main>
  );
}

function DayCircle({ dot }: { dot: ReturnType<typeof weekDots>[number] }) {
  if (dot.isToday && !dot.practiced) {
    // today, not yet practiced, amber ring pending
    return <div className="h-8 w-8 rounded-full border-2 border-accent-amber" />;
  }
  const solid = dot.isToday && dot.practiced;
  return (
    <div
      className={`flex h-8 w-8 items-center justify-center rounded-full ${
        dot.practiced
          ? solid
            ? 'bg-accent-amber'
            : 'bg-amber-tint'
          : 'bg-surface-container-high'
      }`}
    >
      {dot.practiced && (
        <span
          className={`material-symbols-outlined fill-current text-[16px] ${
            solid ? 'text-white' : 'text-accent-amber'
          }`}
        >
          {solid ? 'local_fire_department' : 'check'}
        </span>
      )}
    </div>
  );
}

function BadgeTile({ badge, earned }: { badge: BadgeSpec; earned: boolean }) {
  return (
    <Link
      href={`/badges/${badge.code}`}
      className={`rounded-xl bg-surface-container-lowest p-3 text-center shadow-[0_1px_3px_rgba(20,28,45,0.10)] transition hover:shadow-md ${
        earned ? '' : 'opacity-50 grayscale'
      }`}
      title={earned ? badge.label : badge.hint}
    >
      <div className="relative mx-auto h-14 w-14">
        <div
          className={`flex h-14 w-14 items-center justify-center rounded-full ${
            earned
              ? `${badge.bgClass} ${badge.fgClass}`
              : 'bg-surface-container-high text-on-surface-variant'
          }`}
        >
          <span className="material-symbols-outlined fill-current text-[30px]">
            {badge.icon}
          </span>
        </div>
        {earned ? (
          <span className="absolute -bottom-0.5 -right-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-surface-container-lowest shadow-sm">
            <span className="material-symbols-outlined fill-current text-[14px] text-accent-emerald">
              check_circle
            </span>
          </span>
        ) : (
          <span className="absolute inset-0 flex items-center justify-center rounded-full bg-background/50">
            <span className="material-symbols-outlined text-[18px] text-on-surface-variant">
              lock
            </span>
          </span>
        )}
      </div>
      <p
        className={`mt-2 truncate text-[11px] font-semibold uppercase tracking-wider ${
          earned ? 'text-on-surface' : 'text-on-surface-variant'
        }`}
      >
        {badge.label}
      </p>
    </Link>
  );
}
