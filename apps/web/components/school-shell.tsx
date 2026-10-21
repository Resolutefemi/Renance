'use client';

// Guard + shell for the school workspace. Verifies the session token,
// resolves the active school membership and renders the portal chrome:
// a fixed left rail (desktop) / slide-in drawer (mobile) with the
// school logo, grouped navigation and the role chip. The whole portal
// is wrapped in .school-ggsa (founder directive 2026-10-04): the exact
// God Generals Standard Academy look - deep-purple rail, gold CTA
// accents, cream paper - so the student side's theme never leaks in.
// .school-bw (strict black & white) remains available for pure-B&W
// surfaces.

import { useEffect, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { getActiveSchool, schoolMe, chooseSchool, switchSchool, clearActiveSchool, fetchSchoolProfile, type ActiveSchool, type SchoolContext } from '@/lib/school';

interface NavItem {
  href: string;
  label: string;
  icon: string;
  managementOnly?: boolean;
}

const NAV_GROUPS: { label: string; items: NavItem[] }[] = [
  { label: '', items: [{ href: '/school', label: 'Home', icon: 'home' }] },
  {
    label: 'Academics',
    items: [
      { href: '/school/syllabus', label: 'Syllabus & Notes', icon: 'auto_stories' },
      { href: '/school/curriculum', label: 'Curriculum Bank', icon: 'account_balance' },
      { href: '/school/attendance', label: 'Attendance', icon: 'fact_check' },
      { href: '/school/timetable', label: 'Timetable', icon: 'calendar_month' },
      { href: '/school/exams', label: 'Exam Bank', icon: 'quiz' },
    ],
  },
  {
    label: 'People',
    items: [
      { href: '/school/teachers', label: 'Teachers & Classes', icon: 'co_present', managementOnly: true },
      { href: '/school/students', label: 'Students', icon: 'groups' },
    ],
  },
  {
    label: 'Results',
    items: [{ href: '/school/results', label: 'Results', icon: 'workspace_premium' }],
  },
  {
    label: 'Operations',
    items: [
      { href: '/school/fees', label: 'Fees', icon: 'payments' },
      { href: '/school/idcards', label: 'ID Cards', icon: 'badge', managementOnly: true },
    ],
  },
  {
    label: 'Administration',
    items: [
      { href: '/school/setup', label: 'School Setup', icon: 'settings', managementOnly: true },
      { href: '/school/subscription', label: 'Subscription', icon: 'workspace_premium', managementOnly: true },
    ],
  },
];

export function SchoolShell({ children, title }: { children: ReactNode; title: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [memberships, setMemberships] = useState<SchoolContext[]>([]);
  const [logoUrl, setLogoUrl] = useState('');
  const [drawer, setDrawer] = useState(false);
  const [state, setState] = useState<'loading' | 'ready' | 'denied'>('loading');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const token = localStorage.getItem('renance.token');
      if (!token) {
        router.replace('/login');
        return;
      }
      let a = getActiveSchool();
      try {
        const me = await schoolMe();
        const schools = me.schools ?? [];
        if (schools.length === 0) {
          if (!cancelled) setState('denied');
          return;
        }
        a = chooseSchool(schools, a?.schoolId) ?? a;
        if (!cancelled) setMemberships(schools);
      } catch {
        if (!a) {
          // 401s redirect via api(); network errors keep the cached pick.
          if (!cancelled) setState('denied');
          return;
        }
      }
      if (cancelled || !a) return;
      setActive(a);
      setState('ready');
      // Logo + fresh name for the chrome (best effort).
      fetchSchoolProfile(a.schoolId)
        .then((res) => setLogoUrl(res.school?.logoUrl ?? ''))
        .catch(() => undefined);
    })();
    return () => {
      cancelled = true;
    };
  }, [router]);

  // Close the drawer whenever the route changes.
  useEffect(() => {
    setDrawer(false);
  }, [pathname]);

  if (state === 'loading') {
    return (
      <main className="school-ggsa flex min-h-dvh items-center justify-center bg-surface-container">
        <p className="text-sm text-on-surface-variant">Opening your school workspace…</p>
      </main>
    );
  }

  if (state === 'denied' || !active) {
    return (
      <main className="school-ggsa flex min-h-dvh flex-col items-center justify-center gap-3 bg-surface-container px-4 text-center">
        <h1 className="text-xl font-semibold text-on-surface">No school workspace on this account</h1>
        <p className="max-w-sm text-sm text-on-surface-variant">
          Register your school from the sign-up page (For Schools), or ask your school management to
          create a teacher account for you.
        </p>
        <div className="flex gap-3">
          <Link href="/register" className="rounded-full bg-primary px-5 py-2.5 text-sm font-medium text-on-primary">
            Register a school
          </Link>
          <button
            onClick={() => {
              clearActiveSchool();
              router.replace('/dashboard');
            }}
            className="rounded-full border border-outline px-5 py-2.5 text-sm text-on-surface"
          >
            Go to student home
          </button>
        </div>
      </main>
    );
  }

  const isManagement = active.role === 'management';

  const rail = (
    <div className="flex h-full flex-col">
      {/* identity */}
      <Link href="/school" className="flex items-center gap-3 px-4 pb-4 pt-5 no-underline">
        {logoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={logoUrl} alt="" className="h-10 w-10 rounded-lg border border-brand-300 bg-white object-cover" />
        ) : (
          <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-amber-400 text-purple-900">
            <span className="material-symbols-outlined text-[22px]">school</span>
          </span>
        )}
        <span className="min-w-0">
          <span className="school-title block truncate text-[15px] font-bold leading-tight text-white">
            {active.schoolName}
          </span>
          <span className="block text-xs text-brand-200">
            {isManagement ? 'Management portal' : 'Teacher portal'}
          </span>
        </span>
      </Link>

      <nav className="flex-1 overflow-y-auto pb-4">
        {NAV_GROUPS.map((group) => {
          const items = group.items.filter((n) => !n.managementOnly || isManagement);
          if (items.length === 0) return null;
          return (
            <div key={group.label || 'root'}>
              {group.label && <p className="school-rail-label">{group.label}</p>}
              <div className="px-3">
                {items.map((n) => (
                  <Link
                    key={n.href}
                    href={n.href}
                    data-active={pathname === n.href}
                    className="school-rail-link no-underline"
                  >
                    <span className="material-symbols-outlined">{n.icon}</span>
                    {n.label}
                  </Link>
                ))}
              </div>
            </div>
          );
        })}
      </nav>

      {/* footer of the rail */}
      <div className="border-t border-brand-950/60 px-3 py-4">
        <div className="mb-2 flex items-center gap-2 px-3">
          <span className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-400 text-xs font-bold text-purple-900">
            {(active.fullName || '?').slice(0, 1).toUpperCase()}
          </span>
          <span className="min-w-0">
            <span className="block truncate text-sm font-medium text-white">{active.fullName}</span>
            <span className="block text-xs text-brand-200">{isManagement ? 'Management' : 'Teacher'}</span>
          </span>
        </div>
        {memberships.length > 1 && (
          <div className="px-3 pb-2">
            <label className="school-rail-label" htmlFor="school-switcher">
              Switch school
            </label>
            <select
              id="school-switcher"
              value={active.schoolId}
              onChange={(e) => {
                const next = switchSchool(memberships, e.target.value);
                if (next) window.location.reload();
              }}
              className="h-9 w-full rounded-lg border border-brand-600 bg-brand-950 px-2 text-sm text-white"
            >
              {memberships.map((m) => (
                <option key={m.school.id} value={m.school.id}>
                  {m.school.name}
                </option>
              ))}
            </select>
          </div>
        )}
        <Link
          href="/dashboard"
          className="school-rail-link no-underline"
          onClick={() => setDrawer(false)}
        >
          <span className="material-symbols-outlined">person</span>
          Student site
        </Link>
        <button
          onClick={() => {
            clearActiveSchool();
            localStorage.removeItem('renance.token');
            router.replace('/login');
          }}
          className="school-rail-link w-full border-0 bg-transparent text-left"
        >
          <span className="material-symbols-outlined">logout</span>
          Sign out
        </button>
      </div>
    </div>
  );

  return (
    <div className="school-ggsa min-h-dvh bg-surface-container">
      {/* mobile top bar */}
      <header className="sticky top-0 z-30 border-b border-brand-950 bg-gradient-to-r from-brand-900 to-brand-800 text-white lg:hidden">
        <div className="flex items-center gap-3 px-4 py-3">
          <button
            aria-label="Open menu"
            onClick={() => setDrawer(true)}
            className="flex h-10 w-10 items-center justify-center rounded-lg border border-brand-400 text-white"
          >
            <span className="material-symbols-outlined">menu</span>
          </button>
          {logoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={logoUrl} alt="" className="h-8 w-8 rounded-md border border-brand-300 bg-white object-cover" />
          ) : (
            <span className="flex h-8 w-8 items-center justify-center rounded-md bg-amber-400 text-purple-900">
              <span className="material-symbols-outlined text-[18px]">school</span>
            </span>
          )}
          <span className="min-w-0 flex-1">
            <span className="school-title block truncate text-sm font-bold text-white">{active.schoolName}</span>
            <span className="block text-xs text-brand-200">{title}</span>
          </span>
        </div>
      </header>

      {/* desktop rail */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-brand-950 bg-gradient-to-b from-brand-900 to-brand-800 lg:block">
        {rail}
      </aside>

      {/* mobile drawer */}
      {drawer && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-brand-950/60" onClick={() => setDrawer(false)} />
          <aside className="absolute inset-y-0 left-0 w-72 border-r border-brand-950 bg-gradient-to-b from-brand-900 to-brand-800 shadow-xl">{rail}</aside>
        </div>
      )}

      <main className="px-4 py-6 lg:ml-64 lg:px-10 lg:py-9">
        <div className="mx-auto max-w-6xl">{children}</div>
      </main>
    </div>
  );
}

export function SchoolHeading({ title, sub, actions }: { title: string; sub?: string; actions?: ReactNode }) {
  return (
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-[22px] font-bold tracking-tight text-ggsa-purple">{title}</h1>
        {sub && <p className="mt-1 max-w-2xl text-sm leading-relaxed text-on-surface-variant">{sub}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

// The shared control styles keep the portal consistent. GGSA palette:
// deep purple (#4c1d95) for the primary action, purple hairline
// outlines for the rest, gold for the hero CTA accent.
export const selectCls =
  'h-11 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary';
export const inputCls =
  'h-11 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary';
export const btnPrimary =
  'flex h-11 items-center justify-center gap-2 rounded-lg bg-ggsa-purple px-5 text-sm font-medium text-white transition-all hover:bg-brand-800 active:scale-[0.98] disabled:opacity-50';
export const btnGhost =
  'flex h-11 items-center justify-center gap-2 rounded-lg border border-brand-300 px-4 text-sm text-brand-900 transition-colors hover:bg-brand-50';
export const btnSmall =
  'flex h-9 items-center justify-center gap-1.5 rounded-lg border border-brand-200 px-3 text-xs font-medium text-brand-900 transition-colors hover:bg-brand-50';
// Gold CTA (GGSA landing accent): amber-400 fill on deep purple.
export const btnGold =
  'flex h-11 items-center justify-center gap-2 rounded-lg bg-amber-400 px-5 text-sm font-semibold text-purple-900 transition-all hover:bg-amber-300 active:scale-[0.98] disabled:opacity-50';

// Card: the standard white panel every section sits in. min-w-0 keeps
// the grid item shrinkable on phones, so a wide table (min-w-[560px])
// scrolls inside its overflow-x wrapper instead of stretching the whole
// card past the viewport (the mobile setup-page overflow bug).
export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <section className={`school-shell-card min-w-0 p-5 sm:p-6 ${className}`}>{children}</section>;
}

export function CardTitle({ children, hint }: { children: ReactNode; hint?: string }) {
  return (
    <div className="mb-4">
      <h2 className="text-base font-semibold text-on-surface">{children}</h2>
      {hint && <p className="mt-0.5 text-[13px] text-on-surface-variant">{hint}</p>}
    </div>
  );
}
