'use client';

/**
 * BottomNav: the base tab bar for phone-width viewports. Hidden from
 * md up, where the SideNav takes over.
 *
 * 2026-10-14 evening pass (founder): the base navbar now reads
 * Home · Course · Leagues · FEED · Quests · Profile. The feed takes
 * the old Quests slot, Quests slides into the old Shop slot, and the
 * Shop left the bar entirely - it lives on the profile page now, next
 * to the heart readout. Practice and Review stay off the bar.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  { icon: 'menu_book', label: 'Course', href: '/courses', match: '/courses' },
  { icon: 'trophy', label: 'Leagues', href: '/league', match: '/league' },
  { icon: 'newspaper', label: 'Feed', href: '/feed', match: '/feed' },
  { icon: 'target', label: 'Quests', href: '/quests', match: '/quests' },
  { icon: 'person', label: 'Profile', href: '/profile', match: '/profile' },
] as const;

export default function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t-2 border-outline-variant bg-card md:hidden">
      <div className="mx-auto flex w-full max-w-lg items-stretch justify-between px-1 py-1.5">
        {TABS.map((tab) => {
          const active = pathname.startsWith(tab.match);
          return (
            <Link
              key={tab.label}
              href={tab.href}
              aria-current={active ? 'page' : undefined}
              className={`flex min-h-[48px] min-w-0 flex-1 flex-col items-center justify-center gap-0.5 rounded-xl px-0.5 py-1 transition-colors ${
                active
                  ? 'nav-pill bg-macaw-light text-macaw-dark'
                  : 'text-hare hover:text-wolf'
              }`}
            >
              <span className="material-symbols-outlined text-[22px]">{tab.icon}</span>
              <span className="text-[9.5px] font-extrabold leading-none">{tab.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
