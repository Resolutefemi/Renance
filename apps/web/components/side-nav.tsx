'use client';

/**
 * SideNav: the desktop (md+) chrome, the base navbar stood up on the
 * LHS as a vertical rail. The header is a Menu toggle (hamburger): it
 * hides or opens the menu list, collapsing the rail to an icon strip.
 * State persists in localStorage and drives the --rail-w variable the
 * pages offset their content with. Hidden below md where BottomNav
 * takes over.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { subscribeNotifications, unreadCount } from '@/lib/notifications';

const RAIL_KEY = 'renance.rail.v1';

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
  // Server render matches the default (open) rail; the stored pick is
  // applied after mount so hydration stays clean.
  const [open, setOpen] = useState(true);

  useEffect(() => {
    let stored: string | null = null;
    try {
      stored = window.localStorage.getItem(RAIL_KEY);
    } catch {
      /* private mode: default open */
    }
    if (stored === 'collapsed') setOpen(false);
    const read = () => setUnread(unreadCount());
    read();
    return subscribeNotifications(read);
  }, []);

  useEffect(() => {
    document.documentElement.dataset.rail = open ? 'open' : 'collapsed';
  }, [open]);

  const toggle = () => {
    setOpen((cur) => {
      const next = !cur;
      try {
        window.localStorage.setItem(RAIL_KEY, next ? 'open' : 'collapsed');
      } catch {
        /* private mode: rail still toggles for this visit */
      }
      return next;
    });
  };

  const rowCls = (active: boolean) =>
    `relative flex items-center rounded-xl text-[14px] transition-colors ${
      open ? 'gap-3 px-3.5 py-2.5' : 'h-11 w-11 justify-center self-center p-0'
    } ${
      active
        ? 'bg-surface-container-high font-semibold text-on-surface'
        : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
    }`;

  return (
    <nav
      className={`fixed left-0 top-0 z-50 hidden h-dvh flex-col border-r border-outline-variant/40 bg-surface/95 backdrop-blur-xl md:flex ${
        open ? 'w-60' : 'w-16'
      }`}
    >
      {/* Menu toggle, the hamburger the founder asked for. No brand
          imagery here: the button itself is the header. */}
      <button
        type="button"
        onClick={toggle}
        aria-expanded={open}
        aria-label={open ? 'Hide the menu' : 'Open the menu'}
        className={`flex h-16 shrink-0 items-center border-b border-outline-variant/40 text-on-surface transition-colors hover:bg-surface-container-low ${
          open ? 'gap-2.5 px-5' : 'justify-center'
        }`}
      >
        <span className="material-symbols-outlined text-[24px]">menu</span>
        {open && <span className="text-[15px] font-bold tracking-tight">Menu</span>}
      </button>

      {/* Primary destinations */}
      <div className={`flex flex-1 flex-col ${open ? 'gap-1 overflow-y-auto p-3' : 'gap-2 p-2'}`}>
        {TABS.map((tab) => {
          const active = tab.match != null && pathname === tab.match;
          return (
            <Link
              key={tab.label}
              href={tab.href}
              title={open ? undefined : tab.label}
              aria-current={active ? 'page' : undefined}
              className={rowCls(active)}
            >
              <span className={`material-symbols-outlined text-[20px] ${active ? 'fill-current' : ''}`}>
                {tab.icon}
              </span>
              {open && tab.label}
            </Link>
          );
        })}

        {/* Utility shelf */}
        <div className={`mt-2 border-t border-outline-variant/40 pt-2 ${open ? '' : 'flex flex-col gap-2'}`}>
          <Link
            href="/notifications"
            title={open ? undefined : 'Notifications'}
            aria-current={pathname === '/notifications' ? 'page' : undefined}
            className={rowCls(pathname === '/notifications')}
          >
            <span className="material-symbols-outlined text-[20px]">notifications</span>
            {open && (
              <>
                <span className="flex-1">Notifications</span>
                {unread > 0 && (
                  <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-error px-1.5 font-mono text-[10px] font-bold text-on-error">
                    {unread > 9 ? '9+' : unread}
                  </span>
                )}
              </>
            )}
            {!open && unread > 0 && (
              <span className="absolute left-5 top-2 h-2 w-2 rounded-full bg-error" />
            )}
          </Link>
          <Link
            href="/settings"
            title={open ? undefined : 'Settings'}
            aria-current={pathname === '/settings' ? 'page' : undefined}
            className={rowCls(pathname === '/settings')}
          >
            <span className="material-symbols-outlined text-[20px]">settings</span>
            {open && <span className="flex-1">Settings</span>}
          </Link>
        </div>
      </div>

      {/* Footnote */}
      {open && (
        <p className="shrink-0 border-t border-outline-variant/40 px-5 py-3 font-mono text-[10px] uppercase tracking-wider text-outline">
          Renance · Study OS
        </p>
      )}
    </nav>
  );
}
