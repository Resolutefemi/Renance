'use client';

/**
 * BottomNav: the Stitch five-tab bar (Home / Practice / Review / Progress
 * / Profile) for phone-width viewports. Hidden from md up, where the PC
 * layout takes over. Active tab fills its icon and grows the 4px dot,
 * exactly like the app and the Stitch export.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  { icon: 'edit_note', label: 'Practice', href: '/dashboard#packs', match: null },
  { icon: 'history_edu', label: 'Review', href: '/review', match: '/review' },
  { icon: 'leaderboard', label: 'Progress', href: '/progress', match: '/progress' },
  { icon: 'person', label: 'Profile', href: '/profile', match: '/profile' },
] as const;

export default function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 rounded-t-xl bg-white/90 shadow-[0_-1px_8px_rgba(0,0,0,0.04)] backdrop-blur-xl md:hidden">
      <div className="flex h-16 items-center justify-between px-4">
        {TABS.map((tab) => {
          const active = tab.match != null && pathname === tab.match;
          return (
            <Link
              key={tab.label}
              href={tab.href}
              aria-current={active ? 'page' : undefined}
              className={`flex flex-1 flex-col items-center justify-center gap-1 transition-colors ${
                active ? 'text-primary' : 'text-on-surface-variant'
              }`}
            >
              <span
                className={`material-symbols-outlined ${active ? 'fill-current' : ''}`}
              >
                {tab.icon}
              </span>
              <span className="text-[13px] leading-none">{tab.label}</span>
              <span
                className={`h-1 w-1 rounded-full ${active ? 'bg-primary' : 'bg-transparent'}`}
              />
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
