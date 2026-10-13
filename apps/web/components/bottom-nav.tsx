'use client';

/**
 * BottomNav: the base tab bar (Home / Practice / Review / Profile) for
 * phone-width viewports. Hidden from md up, where the SideNav takes
 * over.
 *
 * 2026-10-13 founder pass ("make the icons in the base navbar be like
 * the supreme own"): rebuilt 1:1 on the supreme.git NavButton - a white
 * bar over a hard 2px swan top rule, compact rounded-xl tab buttons,
 * and the signature ACTIVE STATE: a light-macaw (#ddf4ff) pill with a
 * darker macaw icon (#1899d6), gray idle tabs, chunky 10px black
 * labels. The old dot indicator + fill-on-active treatment is retired.
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const TABS = [
  { icon: 'home', label: 'Home', href: '/dashboard', match: '/dashboard' },
  // /packs: the old /dashboard#packs anchor died with the home pack cards.
  { icon: 'edit_note', label: 'Practice', href: '/packs', match: null },
  { icon: 'history_edu', label: 'Review', href: '/review', match: '/review' },
  { icon: 'person', label: 'Profile', href: '/profile', match: '/profile' },
] as const;

export default function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t-2 border-outline-variant bg-card md:hidden">
      <div className="mx-auto flex w-full max-w-lg items-center justify-between px-2 py-1.5">
        {TABS.map((tab) => {
          const active = tab.match != null && pathname === tab.match;
          return (
            <Link
              key={tab.label}
              href={tab.href}
              aria-current={active ? 'page' : undefined}
              className={`flex min-h-[48px] min-w-[56px] flex-1 flex-col items-center justify-center gap-0.5 rounded-xl px-1.5 py-1 transition-colors ${
                active
                  ? 'bg-macaw-light text-macaw-dark'
                  : 'text-hare hover:text-wolf'
              }`}
            >
              <span className="material-symbols-outlined text-[24px]">{tab.icon}</span>
              <span className="text-[10px] font-extrabold leading-none">{tab.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
