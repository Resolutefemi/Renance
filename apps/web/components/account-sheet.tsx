'use client';

/**
 * AccountSheet - the school app's account display, Renance edition.
 *
 * Tapping the dashboard header's avatar (top right-hand side) slides
 * this sheet up: the avatar row (initials circle, full name, @username,
 * the X), then the menu - Dashboard, Performance Analysis, Exam
 * History, Saved Questions, App Settings, and the red
 * Logout row - the way Myschool displays the account at the top-RHS of
 * home, rebuilt in Renance's white & black.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { clearSession, getStoredUser, type StoredUser } from '@/lib/session';

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: { fullName?: string; institution?: string } | null;
}

const ROWS = [
  { icon: 'dashboard', label: 'Dashboard', href: '/dashboard' },
  { icon: 'insights', label: 'Performance Analysis', href: '/performance' },
  { icon: 'history_edu', label: 'Exam History', href: '/review' },
  { icon: 'bookmark', label: 'Saved Questions', href: '/saved' },
  { icon: 'settings', label: 'App Settings', href: '/settings' },
] as const;

export default function AccountSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const [me, setMe] = useState<MeResponse | null>(null);
  const [fallback, setFallback] = useState<StoredUser | null>(null);

  // Name/username come live from /me; the stored session user covers the
  // sheet while the request is in flight (and when the API is asleep).
  useEffect(() => {
    if (!open) return;
    setFallback(getStoredUser());
    api<MeResponse>('/me', { noRedirect: true })
      .then((r) => setMe(r))
      .catch(() => {});
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  if (!open) return null;

  const name = me?.profile?.fullName?.trim() || fallback?.username || me?.user.username || 'Scholar';
  const username = me?.user.username ?? fallback?.username ?? 'renance';

  function go(href: string) {
    onClose();
    router.push(href);
  }

  async function logout() {
    onClose();
    // Best-effort server sign-out; the local session dies either way.
    try {
      await api('/auth/logout', { method: 'POST', noRedirect: true });
    } catch {
      /* offline logout still logs out */
    }
    clearSession();
    router.replace('/login');
  }

  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center">
      <button aria-label="Close account menu" onClick={onClose} className="absolute inset-0 bg-accent-ink/45 backdrop-blur-[2px]" />
      <div className="relative w-full overflow-hidden rounded-t-[20px] bg-surface-container-lowest shadow-2xl sm:mb-6 sm:max-w-md sm:rounded-[20px]">
        {/* drag handle */}
        <div className="mx-auto mt-2.5 h-1 w-10 rounded-full bg-outline-light" />

        {/* identity row - avatar + name + @username + X */}
        <div className="flex items-center gap-3.5 px-4 pb-3 pt-3.5">
          <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-full bg-primary text-lg font-bold text-on-primary">
            {name.slice(0, 1).toUpperCase()}
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[17px] font-medium tracking-[0.02em] text-on-surface">
              {name.toUpperCase()}
            </span>
            <span className="mt-0.5 block truncate text-[14px] text-on-surface-variant">@{username}</span>
          </span>
          <button
            onClick={onClose}
            aria-label="Close"
            className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-full bg-surface-container-low text-on-surface transition hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-[18px]">close</span>
          </button>
        </div>

        <div className="border-t border-outline-variant/40" />

        {/* menu - Dashboard → Logout, the school app's order */}
        <nav className="pb-2" aria-label="Account">
          {ROWS.map((row) => (
            <button
              key={row.label}
              onClick={() => go(row.href)}
              className="flex w-full items-center gap-4 px-5 py-[15px] text-left transition hover:bg-surface-container-low"
            >
              <span className="material-symbols-outlined text-[21px] text-on-surface">{row.icon}</span>
              <span className="flex-1 text-[15.5px] text-on-surface">{row.label}</span>
              <span className="material-symbols-outlined text-[19px] text-outline-light">chevron_right</span>
            </button>
          ))}
          <button
            onClick={() => void logout()}
            className="flex w-full items-center gap-4 px-5 py-[15px] text-left transition hover:bg-error-container/30"
          >
            <span className="material-symbols-outlined text-[21px] text-error">logout</span>
            <span className="flex-1 text-[15.5px] text-error">Logout</span>
          </button>
        </nav>
      </div>
    </div>
  );
}
