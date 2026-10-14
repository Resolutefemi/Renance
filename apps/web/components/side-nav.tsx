'use client';

/**
 * SideNav: the desktop (md+) chrome, the base navbar stood up on the
 * LHS as a vertical rail. The header is a Menu toggle (hamburger): it
 * hides or opens the menu list, collapsing the rail to an icon strip.
 * State persists in localStorage and drives the --rail-w variable the
 * pages offset their content with. Hidden below md where BottomNav
 * takes over.
 *
 * 2026-10-13 founder pass ("navbar size like the supreme own, renance
 * in complete small letters, in green"): the header carries the 3D R
 * keycap + the lowercase green wordmark, exactly like supreme.git's
 * sidebar; nav rows are Supreme-sized (min-h 48, rounded-2xl, small
 * black uppercase labels) and the ACTIVE row wears the light-macaw
 * pill with the blue ring - the same treatment as the Supreme
 * sidebar. Everything reads a notch calmer than the old rail.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { RenanceMark } from '@/components/renance-logo';
import { subscribeNotifications, unreadCount } from '@/lib/notifications';

const RAIL_KEY = 'renance.rail.v1';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  { icon: 'menu_book', label: 'Course', href: '/courses', match: '/courses' },
  { icon: 'trophy', label: 'Leagues', href: '/league', match: '/league' },
  { icon: 'newspaper', label: 'Feed', href: '/feed', match: '/feed' },
  { icon: 'target', label: 'Quests', href: '/quests', match: '/quests' },
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

  // Supreme sidebar row: 48px min height, rounded-2xl, small black
  // uppercase label; active = light-macaw pill + blue ring + blue text.
  const rowCls = (active: boolean) =>
    `relative flex items-center rounded-2xl text-[13px] font-extrabold uppercase tracking-wide transition-colors ${
      open ? 'gap-3 px-3 py-2.5' : 'h-12 w-12 justify-center self-center p-0'
    } ${
      active
        ? 'bg-macaw-light text-macaw-dark ring-2 ring-macaw-ring'
        : 'text-wolf hover:bg-polar hover:text-on-surface'
    }`;

  return (
    <nav
      className={`fixed left-0 top-0 z-50 hidden h-dvh flex-col border-r-2 border-outline-variant bg-surface md:flex ${
        open ? 'w-60' : 'w-[4.25rem]'
      }`}
    >
      {/* Header: hamburger + the brand wordmark (lowercase, green -
          the supreme.git signature the founder asked for). */}
      <div
        className={`flex h-14 shrink-0 items-center border-b-2 border-outline-variant ${
          open ? 'gap-2.5 px-4' : 'justify-center'
        }`}
      >
        <button
          type="button"
          onClick={toggle}
          aria-expanded={open}
          aria-label={open ? 'Hide the menu' : 'Open the menu'}
          className="flex h-9 w-9 items-center justify-center rounded-xl text-on-surface transition-colors hover:bg-polar"
        >
          <span className="material-symbols-outlined text-[22px]">menu</span>
        </button>
        {open && (
          <Link href="/dashboard" aria-label="Renance home" className="flex min-w-0 items-center gap-2">
            <RenanceMark size={30} />
            <span className="truncate text-[19px] font-black lowercase tracking-tight text-primary">
              renance
            </span>
          </Link>
        )}
      </div>

      {/* Primary destinations */}
      <div className={`flex flex-1 flex-col ${open ? 'gap-1 overflow-y-auto p-3' : 'gap-2 p-2.5'}`}>
        {TABS.map((tab) => {
          const active = pathname.startsWith(tab.match);
          return (
            <Link
              key={tab.label}
              href={tab.href}
              title={open ? undefined : tab.label}
              aria-current={active ? 'page' : undefined}
              className={rowCls(active)}
            >
              <span className="material-symbols-outlined text-[24px]">{tab.icon}</span>
              {open && tab.label}
            </Link>
          );
        })}

        {/* Utility shelf */}
        <div className={`mt-2 border-t-2 border-outline-variant/60 pt-2 ${open ? '' : 'flex flex-col gap-2'}`}>
          <Link
            href="/notifications"
            title={open ? undefined : 'Notifications'}
            aria-current={pathname === '/notifications' ? 'page' : undefined}
            className={rowCls(pathname === '/notifications')}
          >
            <span className="material-symbols-outlined text-[24px]">notifications</span>
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
              <span className="absolute left-5 top-2.5 h-2 w-2 rounded-full bg-error" />
            )}
          </Link>
          <Link
            href="/settings"
            title={open ? undefined : 'Settings'}
            aria-current={pathname === '/settings' ? 'page' : undefined}
            className={rowCls(pathname === '/settings')}
          >
            <span className="material-symbols-outlined text-[24px]">settings</span>
            {open && <span className="flex-1">Settings</span>}
          </Link>
        </div>
      </div>

      {/* Footnote */}
      {open && (
        <p className="shrink-0 border-t-2 border-outline-variant/60 px-4 py-3 text-[10px] font-bold uppercase tracking-widest text-hare">
          renance · educational app
        </p>
      )}
    </nav>
  );
}
