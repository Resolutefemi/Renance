'use client';

/**
 * SideNav: the desktop (md+) chrome — the base navbar stood up on the
 * LHS as a vertical rail. Brand on top, the five destinations as full
 * rows, then the utility shelf (Notifications bell with the live
 * unread badge, Settings). Hidden below md where BottomNav takes over.
 * Pages offset their content with md:pl-60.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { RenanceMark } from './renance-logo';
import { subscribeNotifications, unreadCount } from '@/lib/notifications';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  { icon: 'edit_note', label: 'Practice', href: '/packs', match: null },
  { icon: 'history_edu', label: 'Review', href: '/review', match: '/review' },
  { icon: 'leaderboard', label: 'Progress', href: '/progress', match: '/progress' },
  { icon: 'person', label: 'Profile', href: '/profile', match: '/profile' },
] as const;

export default function SideNav() {
  const pathname = usePathname();
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    const read = () => setUnread(unreadCount());
    read();
    return subscribeNotifications(read);
  }, []);

  return (
    <nav className="fixed left-0 top-0 z-50 hidden h-dvh w-60 flex-col border-r border-outline-variant/40 bg-surface/95 backdrop-blur-xl md:flex">
      {/* Brand */}
      <Link
        href="/dashboard"
        className="flex h-16 shrink-0 items-center gap-2.5 border-b border-outline-variant/40 px-5"
        aria-label="Renance home"
      >
        <RenanceMark size={26} />
        <span className="text-[15px] font-bold tracking-tight text-on-surface">Renance</span>
      </Link>

      {/* Primary destinations */}
      <div className="flex flex-1 flex-col gap-1 overflow-y-auto p-3">
        {TABS.map((tab) => {
          const active = tab.match != null && pathname === tab.match;
          return (
            <Link
              key={tab.label}
              href={tab.href}
              aria-current={active ? 'page' : undefined}
              className={`flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-[14px] transition-colors ${
                active
                  ? 'bg-surface-container-high font-semibold text-on-surface'
                  : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
              }`}
            >
              <span className={`material-symbols-outlined text-[20px] ${active ? 'fill-current' : ''}`}>
                {tab.icon}
              </span>
              {tab.label}
            </Link>
          );
        })}

        {/* Utility shelf */}
        <div className="mt-2 border-t border-outline-variant/40 pt-2">
          <Link
            href="/notifications"
            aria-current={pathname === '/notifications' ? 'page' : undefined}
            className={`flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-[14px] transition-colors ${
              pathname === '/notifications'
                ? 'bg-surface-container-high font-semibold text-on-surface'
                : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
            }`}
          >
            <span className="material-symbols-outlined text-[20px]">notifications</span>
            <span className="flex-1">Notifications</span>
            {unread > 0 && (
              <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-error px-1.5 font-mono text-[10px] font-bold text-on-error">
                {unread > 9 ? '9+' : unread}
              </span>
            )}
          </Link>
          <Link
            href="/downloads"
            aria-current={pathname === '/downloads' ? 'page' : undefined}
            className={`flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-[14px] transition-colors ${
              pathname === '/downloads'
                ? 'bg-surface-container-high font-semibold text-on-surface'
                : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
            }`}
          >
            <span className="material-symbols-outlined text-[20px]">download</span>
            <span className="flex-1">Downloads</span>
          </Link>
          <Link
            href="/settings"
            aria-current={pathname === '/settings' ? 'page' : undefined}
            className={`flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-[14px] transition-colors ${
              pathname === '/settings'
                ? 'bg-surface-container-high font-semibold text-on-surface'
                : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
            }`}
          >
            <span className="material-symbols-outlined text-[20px]">settings</span>
            <span className="flex-1">Settings</span>
          </Link>
        </div>
      </div>

      {/* Footnote */}
      <p className="shrink-0 border-t border-outline-variant/40 px-5 py-3 font-mono text-[10px] uppercase tracking-wider text-outline">
        Renance · Study OS
      </p>
    </nav>
  );
}
