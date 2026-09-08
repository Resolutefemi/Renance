'use client';

/**
 * Notifications — the Stitch notifications_light / notifications_full_dark
 * screen, fed by the local notification engine (lib/notifications.ts).
 * Today / Yesterday / Older bands, unread rows carry the violet accent
 * bar and the tinted surface; "Mark all read" clears the whole ledger.
 * Tapping a row marks it read and walks its deep link.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import {
  clearNotifications,
  dayGroup,
  getNotifications,
  markAllRead,
  markRead,
  relativeTime,
  subscribeNotifications,
  type NotificationTone,
  type RenanceNotification,
} from '@/lib/notifications';

const TONE_STYLES: Record<NotificationTone, { chip: string; icon: string }> = {
  error: { chip: 'bg-error-container', icon: 'text-error' },
  emerald: { chip: 'bg-accent-emerald/15', icon: 'text-accent-emerald' },
  blue: { chip: 'bg-selection-blue', icon: 'text-primary' },
  violet: { chip: 'bg-secondary-container', icon: 'text-secondary' },
  amber: { chip: 'bg-accent-amber/15', icon: 'text-accent-amber' },
  neutral: { chip: 'bg-surface-container-highest', icon: 'text-on-surface-variant' },
};

export default function NotificationsPage() {
  const router = useRouter();
  const [items, setItems] = useState<RenanceNotification[] | null>(null);

  useEffect(() => {
    const read = () => setItems(getNotifications());
    read();
    return subscribeNotifications(read);
  }, []);

  const unread = items?.filter((n) => !n.read).length ?? 0;

  // Group in band order, preserving recency inside each band.
  const bands: Array<'Today' | 'Yesterday' | 'Older'> = ['Today', 'Yesterday', 'Older'];
  const grouped = bands
    .map((band) => ({ band, rows: (items ?? []).filter((n) => dayGroup(n.at) === band) }))
    .filter((g) => g.rows.length > 0);

  function open(n: RenanceNotification) {
    markRead(n.id);
    if (n.href) router.push(n.href);
  }

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-60">
      <PageBar title="Notifications" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <div className="flex items-center justify-between">
          <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
            Notifications
          </h1>
          {unread > 0 && (
            <button
              type="button"
              onClick={markAllRead}
              className="text-[14px] font-semibold text-primary transition-opacity hover:opacity-70"
            >
              Mark all read
            </button>
          )}
        </div>
        <p className="mt-1 text-[14px] text-on-surface-variant">
          Signals from your own study desk — streaks, reviews, papers and badges.
        </p>

        {items === null && (
          <p className="mt-10 text-center text-[14px] text-on-surface-variant">Loading…</p>
        )}

        {items !== null && items.length === 0 && (
          <div className="mt-14 flex flex-col items-center gap-3 text-center">
            <span className="flex h-16 w-16 items-center justify-center rounded-full bg-surface-container-low">
              <span className="material-symbols-outlined text-[28px] text-outline">
                notifications_off
              </span>
            </span>
            <p className="text-[15px] font-semibold text-on-surface">Nothing yet</p>
            <p className="max-w-xs text-[13px] text-on-surface-variant">
              Practice a paper, keep a streak or queue a review — your desk will speak up here.
            </p>
          </div>
        )}

        <div className="mt-6 flex flex-col gap-6">
          {grouped.map(({ band, rows }) => (
            <section key={band}>
              <h2 className="px-1 text-[15px] font-semibold text-on-surface-variant">{band}</h2>
              <ul className="mt-3 flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                {rows.map((n, i) => {
                  const tone = TONE_STYLES[n.tone];
                  return (
                    <li key={n.id}>
                      {i > 0 && <div className="h-px w-full bg-surface-container" />}
                      <button
                        type="button"
                        onClick={() => open(n)}
                        className={`relative flex w-full items-start gap-4 p-4 text-left transition-colors ${
                          n.read ? 'hover:bg-surface-container-low/40' : 'bg-surface-container-low hover:bg-surface-container'
                        }`}
                      >
                        {!n.read && (
                          <span className="absolute bottom-0 left-0 top-0 w-1 rounded-r-full bg-secondary" />
                        )}
                        <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${tone.chip}`}>
                          <span className={`material-symbols-outlined fill-current text-[20px] ${tone.icon}`}>
                            {n.icon}
                          </span>
                        </span>
                        <span className="flex min-w-0 flex-1 flex-col">
                          <span className="flex items-baseline justify-between gap-2">
                            <span className="truncate text-[15px] font-semibold text-on-surface">{n.title}</span>
                            <span className="shrink-0 text-[12px] text-on-surface-variant">
                              {relativeTime(n.at)}
                            </span>
                          </span>
                          <span className="mt-0.5 line-clamp-2 text-[14px] leading-5 text-on-surface-variant">
                            {n.body}
                          </span>
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}
        </div>

        {items !== null && items.length > 0 && (
          <button
            type="button"
            onClick={() => {
              if (window.confirm('Clear the whole notification ledger?')) clearNotifications();
            }}
            className="mx-auto mt-8 block rounded-full px-4 py-2 text-[13px] text-on-surface-variant transition-colors hover:bg-surface-container-low"
          >
            Clear all notifications
          </button>
        )}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
