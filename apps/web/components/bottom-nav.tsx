'use client';

/**
 * BottomNav: the Stitch tab bar (Home / Practice / Review / [GPA] /
 * Profile) for phone-width viewports. Hidden from md up, where the PC
 * layout takes over. Active tab fills its icon and grows the 4px dot,
 * exactly like the app and the Stitch export.
 *
 * The GPA entry only exists on a tertiary desk (founder call: the GPA
 * calculator never shows on JAMB / WAEC / NECO interfaces); the flag is
 * unknown until the dashboard or profile editor has run, and hidden is
 * the safe default.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { useTertiaryFocus } from '@/lib/use-focus';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  // /packs: the old /dashboard#packs anchor died with the home pack cards.
  { icon: 'edit_note', label: 'Practice', href: '/packs', match: null },
  { icon: 'history_edu', label: 'Review', href: '/review', match: '/review' },
  { icon: 'calculate', label: 'GPA', href: '/gpa', match: '/gpa', tertiary: true },
  { icon: 'person', label: 'Profile', href: '/profile', match: '/profile' },
] as const;

export default function BottomNav() {
  const pathname = usePathname();
  const focus = useTertiaryFocus();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 rounded-t-xl bg-card/90 shadow-[0_-1px_8px_rgba(0,0,0,0.04)] backdrop-blur-xl md:hidden">
      <div className="flex h-16 items-center justify-between px-4">
        {TABS.filter((tab) => !('tertiary' in tab && tab.tertiary) || focus === 'tertiary').map((tab) => {
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
