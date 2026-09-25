'use client';

// Guard + shell for the school workspace. Verifies the session token,
// resolves the active school membership and renders the portal chrome:
// a fixed left rail (desktop) / slide-in drawer (mobile) with the
// school logo, grouped navigation and the role chip. The whole portal
// is wrapped in .school-bw so it stays strict black & white no matter
// what theme or accent the student side is set to.

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
      { href: '/curriculum', label: 'Curriculum Bank', icon: 'account_balance' },
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
    items: [{ href: '/school/setup', label: 'School Setup', icon: 'settings', managementOnly: true }],
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
      <main className="school-bw flex min-h-dvh items-center justify-center bg-surface-container">
        <p className="text-sm text-on-surface-variant">Opening your school workspace…</p>
      </main>
    );
  }

  if (state === 'denied' || !active) {
    return (
      <main className="school-bw flex min-h-dvh flex-col items-center justify-center gap-3 bg-surface-container px-4 text-center">
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
          <img src={logoUrl} alt="" className="h-10 w-10 rounded-lg border border-outline-variant object-cover" />
        ) : (
          <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary text-on-primary">
            <span className="material-symbols-outlined text-[22px]">school</span>
          </span>
        )}
        <span className="min-w-0">
          <span className="block truncate text-[15px] font-semibold leading-tight text-on-surface">
            {active.schoolName}
          </span>
          <span className="block text-xs text-on-surface-variant">
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
      <div className="border-t border-outline-variant px-3 py-4">
        <div className="mb-2 flex items-center gap-2 px-3">
          <span className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-container-high text-xs font-bold text-on-surface">
            {(active.fullName || '?').slice(0, 1).toUpperCase()}
          </span>
          <span className="min-w-0">
            <span className="block truncate text-sm font-medium text-on-surface">{active.fullName}</span>
            <span className="block text-xs text-on-surface-variant">{isManagement ? 'Management' : 'Teacher'}</span>
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
              className="h-9 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-2 text-sm text-on-surface"
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
    <div className="school-bw min-h-dvh bg-surface-container">
      {/* mobile top bar */}
      <header className="sticky top-0 z-30 border-b border-outline-variant bg-surface-container-lowest lg:hidden">
        <div className="flex items-center gap-3 px-4 py-3">
          <button
            aria-label="Open menu"
            onClick={() => setDrawer(true)}
            className="flex h-10 w-10 items-center justify-center rounded-lg border border-outline-variant text-on-surface"
          >
            <span className="material-symbols-outlined">menu</span>
          </button>
          {logoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={logoUrl} alt="" className="h-8 w-8 rounded-md border border-outline-variant object-cover" />
          ) : (
            <span className="flex h-8 w-8 items-center justify-center rounded-md bg-primary text-on-primary">
              <span className="material-symbols-outlined text-[18px]">school</span>
            </span>
          )}
          <span className="min-w-0 flex-1">
            <span className="block truncate text-sm font-semibold text-on-surface">{active.schoolName}</span>
            <span className="block text-xs text-on-surface-variant">{title}</span>
          </span>
        </div>
      </header>

      {/* desktop rail */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-outline-variant bg-surface-container-lowest lg:block">
        {rail}
      </aside>

      {/* mobile drawer */}
      {drawer && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-black/40" onClick={() => setDrawer(false)} />
          <aside className="absolute inset-y-0 left-0 w-72 bg-surface-container-lowest shadow-xl">{rail}</aside>
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
        <h1 className="text-[22px] font-bold tracking-tight text-on-surface">{title}</h1>
        {sub && <p className="mt-1 max-w-2xl text-sm leading-relaxed text-on-surface-variant">{sub}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

// The shared control styles keep the portal consistent. Pure black &
// white: black fill for the primary action, hairline outlines for the
// rest.
export const selectCls =
  'h-11 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary';
export const inputCls =
  'h-11 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary';
export const btnPrimary =
  'flex h-11 items-center justify-center gap-2 rounded-lg bg-primary px-5 text-sm font-medium text-on-primary transition-all hover:opacity-90 active:scale-[0.98] disabled:opacity-50';
export const btnGhost =
  'flex h-11 items-center justify-center gap-2 rounded-lg border border-outline px-4 text-sm text-on-surface transition-colors hover:bg-surface-container';
export const btnSmall =
  'flex h-9 items-center justify-center gap-1.5 rounded-lg border border-outline-variant px-3 text-xs font-medium text-on-surface transition-colors hover:bg-surface-container';

// Card: the standard white panel every section sits in.
export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <section className={`school-shell-card p-5 sm:p-6 ${className}`}>{children}</section>;
}

export function CardTitle({ children, hint }: { children: ReactNode; hint?: string }) {
  return (
    <div className="mb-4">
      <h2 className="text-base font-semibold text-on-surface">{children}</h2>
      {hint && <p className="mt-0.5 text-[13px] text-on-surface-variant">{hint}</p>}
    </div>
  );
}
