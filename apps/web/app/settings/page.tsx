'use client';

/**
 * Settings, the Stitch settings_light screen, 1:1, with the founder's
 * three-tier Appearance control fully functional: Light, Mixed (dark
 * hero chrome on the light body) and Dark (full-dark tier). The choice
 * persists in localStorage and the root layout bootstraps it before
 * first paint, so a reload never flashes the wrong tier.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { clearSession, getToken } from '@/lib/session';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

type Theme = 'light' | 'mixed' | 'dark';

const THEME_OPTIONS: Array<{ value: Theme; icon: string; label: string }> = [
  { value: 'light', icon: 'light_mode', label: 'Light' },
  { value: 'mixed', icon: 'contrast', label: 'Mixed' },
  { value: 'dark', icon: 'dark_mode', label: 'Dark' },
];

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: { fullName: string; institution: string; gradeLevel: string } | null;
}

function readTheme(): Theme {
  if (typeof window === 'undefined') return 'light';
  const t = window.localStorage.getItem('renance.theme');
  return t === 'mixed' || t === 'dark' ? t : 'light';
}

export default function SettingsPage() {
  const router = useRouter();
  const [theme, setTheme] = useState<Theme>('light');
  const [me, setMe] = useState<MeResponse | null>(null);
  const [cleared, setCleared] = useState(false);

  useEffect(() => {
    setTheme(readTheme());
    if (getToken()) {
      api<MeResponse>('/me').then(setMe).catch(() => setMe(null));
    }
  }, []);

  function pickTheme(t: Theme) {
    setTheme(t);
    window.localStorage.setItem('renance.theme', t);
    document.documentElement.dataset.theme = t;
  }

  function clearCache() {
    const keep = window.localStorage.getItem('renance.theme');
    window.localStorage.clear();
    if (keep) window.localStorage.setItem('renance.theme', keep);
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
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Settings" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Settings
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          Tune how Renance looks, syncs and reminds you.
        </p>

        {/* Appearance: the Light / Mixed / Dark segmented control -------- */}
        <section className="mt-6 flex flex-col gap-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center gap-3">
            <span className="material-symbols-outlined text-on-surface-variant">
              brightness_medium
            </span>
            <div>
              <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
                App Theme
              </h2>
              <p className="text-[13px] text-on-surface-variant">Appearance</p>
            </div>
          </div>
          <div className="flex gap-2">
            {THEME_OPTIONS.map((o) => {
              const selected = theme === o.value;
              return (
                <button
                  key={o.value}
                  type="button"
                  onClick={() => pickTheme(o.value)}
                  aria-pressed={selected}
                  className={`flex flex-1 flex-col items-center gap-1.5 rounded-[10px] border px-2 py-3 transition ${
                    selected
                      ? 'border-on-surface bg-selection-blue text-on-surface'
                      : 'border-outline-variant bg-surface-container-lowest text-on-surface-variant hover:border-outline'
                  }`}
                >
                  <span className="material-symbols-outlined text-[22px]">{o.icon}</span>
                  <span className="text-[13px] font-semibold">{o.label}</span>
                </button>
              );
            })}
          </div>
          <p className="text-[13px] leading-5 text-on-surface-variant">
            Mixed keeps your pages light and turns the header cards dark, the
            same treatment the exam player uses. Dark is the full dark tier.
          </p>
        </section>

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

        {/* Data & offline ------------------------------------------------- */}
        <section className="mt-4 overflow-hidden rounded-[12px] bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
          <div className="flex items-center gap-3 border-b border-outline-variant/50 px-5 py-4">
            <span className="material-symbols-outlined text-on-surface-variant">wifi_off</span>
            <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
              Data &amp; Offline
            </h2>
          </div>
          <div className="flex items-center gap-3 border-b border-outline-variant/50 px-5 py-4">
            <div className="flex-1">
              <p className="text-[15px] font-semibold text-on-surface">Offline Mode</p>
              <p className="text-[13px] text-on-surface-variant">
                Download assets for offline use
              </p>
            </div>
            <span className="material-symbols-outlined text-outline">chevron_right</span>
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
                  ? 'Cached packs cleared, re-sync to restore.'
                  : 'Frees space used by downloaded packs'}
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

      <BottomNav />
    </main>
  );
}
