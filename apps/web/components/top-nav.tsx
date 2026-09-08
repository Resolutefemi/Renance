'use client';

/**
 * TopNav: the desktop (md+) chrome that replaces the phone bottom bar.
 * Same five destinations, one horizontal strip: mark + wordmark left,
 * the tabs right. Hidden below md where BottomNav takes over.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { RenanceMark } from './renance-logo';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  { icon: 'edit_note', label: 'Practice', href: '/packs', match: null },
  { icon: 'history_edu', label: 'Review', href: '/review', match: '/review' },
  { icon: 'leaderboard', label: 'Progress', href: '/progress', match: '/progress' },
  { icon: 'person', label: 'Profile', href: '/profile', match: '/profile' },
] as const;

export default function TopNav() {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-50 hidden w-full border-b border-outline-variant/40 bg-surface/85 backdrop-blur-xl md:block">
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center justify-between gap-4 px-4 sm:px-6">
        <Link href="/dashboard" className="flex items-center gap-2.5" aria-label="Renance home">
          <RenanceMark size={26} />
          <span className="text-[15px] font-bold tracking-tight text-on-surface">Renance</span>
        </Link>
        <div className="flex items-center gap-1">
          {TABS.map((tab) => {
            const active = tab.match != null && pathname === tab.match;
            return (
              <Link
                key={tab.label}
                href={tab.href}
                aria-current={active ? 'page' : undefined}
                className={`flex items-center gap-1.5 rounded-full px-3.5 py-2 text-[13px] font-medium transition-colors ${
                  active
                    ? 'bg-surface-container-high font-semibold text-on-surface'
                    : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                }`}
              >
                <span className={`material-symbols-outlined text-[18px] ${active ? 'fill-current' : ''}`}>
                  {tab.icon}
                </span>
                {tab.label}
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
