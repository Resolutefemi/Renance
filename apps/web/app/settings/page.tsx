'use client';

/**
 * Settings - the Stitch settings screen with the founder's Appearance
 * control fully functional: Mode (Light / Mixed / Dark) plus the
 * Chrome-style Seed Colour picker that re-tints every ink surface in
 * the product (lib/theme.ts). The choice persists in localStorage and
 * the root layout bootstraps it before first paint, so a reload never
 * flashes the wrong tier.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { clearSession, getToken } from '@/lib/session';
import { readSeedColor, setSeedColor, type ThemeMode } from '@/lib/theme';
import AppearancePanel from '@/components/appearance-panel';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: { fullName: string; institution: string; gradeLevel: string } | null;
}

function readTheme(): ThemeMode {
  if (typeof window === 'undefined') return 'light';
  const t = window.localStorage.getItem('renance.theme');
  return t === 'mixed' || t === 'dark' ? t : 'light';
}

export default function SettingsPage() {
  const router = useRouter();
  const [theme, setTheme] = useState<ThemeMode>('light');
  const [seed, setSeed] = useState<string | null>(null);
  const [me, setMe] = useState<MeResponse | null>(null);
  const [cleared, setCleared] = useState(false);

  useEffect(() => {
    setTheme(readTheme());
    setSeed(readSeedColor());
    if (getToken()) {
      api<MeResponse>('/me').then(setMe).catch(() => setMe(null));
    }
  }, []);

  function pickSeed(next: string | null) {
    setSeed(next);
    setSeedColor(next, theme);
  }

  function clearCache() {
    const keepTheme = window.localStorage.getItem('renance.theme');
    const keepSeed = window.localStorage.getItem('renance.seed');
    const keepSeedVars = window.localStorage.getItem('renance.seedVars');
    window.localStorage.clear();
    for (const [k, v] of [
      ['renance.theme', keepTheme],
      ['renance.seed', keepSeed],
      ['renance.seedVars', keepSeedVars],
    ] as const) {
      if (v != null) window.localStorage.setItem(k, v);
    }
    setCleared(true);
    setTimeout(() => setCleared(false), 2400);
  }

  function signOut() {
    clearSession();
    // Respect the Pages base path when redirecting to the sign-in screen.
    const base = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
    router.push(`${base}/login`);
  }

  const displayName =
    me?.profile?.fullName || me?.user?.username || 'Renance student';
  const displayEmail = me ? `${me.user.username}@renance.app` : 'student@renance.app';

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="Settings" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Settings
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          Tune how Renance looks, syncs and reminds you.
        </p>

        {/* Appearance: Mode + the Chrome-style Seed Colour picker ------- */}
        <AppearancePanel mode={theme} onMode={setTheme} />
        {seed && (
          <p className="mt-3 px-1 text-[13px] leading-5 text-on-surface-variant">
            Seed <span className="font-mono font-semibold text-on-surface">{seed.toUpperCase()}</span> is live:{' '}
            buttons, tiles, headers and surfaces are tinted with it across the app. Open Seed Color above to change or
            reset it.
          </p>
        )}

        {/* Learning ------------------------------------------------------- */}
        <section className="mt-4 overflow-hidden rounded-[12px] bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center gap-3 border-b border-outline-variant/50 px-5 py-4">
            <span className="material-symbols-outlined text-on-surface-variant">auto_stories</span>
            <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
              Learning
            </h2>
          </div>
          <div className="flex items-center gap-3 border-b border-outline-variant/50 px-5 py-4">
            <span className="material-symbols-outlined text-on-surface-variant">flag</span>
            <div className="flex-1">
              <p className="text-[15px] font-semibold text-on-surface">Daily Goals</p>
              <p className="text-[13px] text-on-surface-variant">20 questions a day</p>
            </div>
            <span className="material-symbols-outlined text-outline">chevron_right</span>
          </div>
          <div className="flex items-center gap-3 px-5 py-4">
            <span className="material-symbols-outlined text-on-surface-variant">
              notifications_active
            </span>
            <div className="flex-1">
              <p className="text-[15px] font-semibold text-on-surface">Study Reminders</p>
              <p className="text-[13px] text-on-surface-variant">Daily at 8:00 PM</p>
            </div>
            <span className="material-symbols-outlined text-outline">chevron_right</span>
          </div>
        </section>

        {/* Data & storage -------------------------------------------------- */}
        <section className="mt-4 overflow-hidden rounded-[12px] bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center gap-3 border-b border-outline-variant/50 px-5 py-4">
            <span className="material-symbols-outlined text-on-surface-variant">storage</span>
            <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
              Data &amp; Storage
            </h2>
          </div>
          <button
            type="button"
            onClick={clearCache}
            className="flex w-full items-center gap-3 px-5 py-4 text-left"
          >
            <span className="material-symbols-outlined text-on-surface-variant">
              delete_sweep
            </span>
            <div className="flex-1">
              <p className="text-[15px] font-semibold text-on-surface">Clear Cache</p>
              <p className="text-[13px] text-on-surface-variant">
                {cleared
                  ? 'Cached question banks cleared, they reload on next open.'
                  : 'Frees space used by cached question banks'}
              </p>
            </div>
          </button>
        </section>

        {/* Account -------------------------------------------------------- */}
        <section className="mt-4 overflow-hidden rounded-[12px] bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center gap-3 border-b border-outline-variant/50 px-5 py-4">
            <span className="material-symbols-outlined text-on-surface-variant">
              account_circle
            </span>
            <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
              Account
            </h2>
          </div>
          <div className="flex items-center gap-3 px-5 py-4">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-selection-blue text-[16px] font-bold text-on-surface">
              {displayName.slice(0, 1).toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[15px] font-semibold text-on-surface">
                {displayName}
              </p>
              <p className="truncate text-[13px] text-on-surface-variant">{displayEmail}</p>
            </div>
          </div>
          <button
            type="button"
            onClick={signOut}
            className="flex w-full items-center gap-3 border-t border-outline-variant/50 px-5 py-4 text-left"
          >
            <span className="material-symbols-outlined text-error">logout</span>
            <span className="flex-1 text-[15px] font-semibold text-error">Sign Out</span>
          </button>
        </section>

        <p className="mt-6 text-center font-mono text-[11px] uppercase tracking-[0.2em] text-on-surface-variant">
          Renance OS v2.4.1
        </p>
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
