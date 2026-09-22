'use client';

// Guard + shell for the school workspace pages. Verifies there is a
// session token, resolves the active school membership (persisted in
// localStorage on login; re-fetched on demand), and renders the portal
// chrome: school name, role chip and the section nav.

import { useEffect, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { getActiveSchool, schoolMe, chooseSchool, clearActiveSchool, type ActiveSchool } from '@/lib/school';

const NAV = [
  { href: '/school', label: 'Overview' },
  { href: '/school/syllabus', label: 'Syllabus & Notes' },
  { href: '/school/teachers', label: 'Teachers & Classes', managementOnly: true },
  { href: '/school/students', label: 'Students', managementOnly: true },
  { href: '/school/results', label: 'Results' },
];

export function SchoolShell({ children, title }: { children: ReactNode; title: string }) {
  const router = useRouter();
  const [active, setActive] = useState<ActiveSchool | null>(null);
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
      } catch {
        if (!a) {
          // 401s redirect via api(); network errors keep the cached pick.
          if (!cancelled) setState('denied');
          return;
        }
      }
      if (!cancelled) {
        setActive(a);
        setState('ready');
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [router]);

  if (state === 'loading') {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-surface-container">
        <p className="text-sm text-on-surface-variant">Opening your school workspace…</p>
      </main>
    );
  }

  if (state === 'denied' || !active) {
    return (
      <main className="flex min-h-dvh flex-col items-center justify-center gap-3 bg-surface-container px-4 text-center">
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

  return (
    <div className="min-h-dvh bg-surface-container">
      <header className="border-b border-outline-variant bg-surface-container-lowest">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-4 py-4">
          <Link href="/school" className="flex flex-col">
            <span className="text-base font-semibold tracking-tight text-on-surface">{active.schoolName}</span>
            <span className="text-xs text-on-surface-variant">
              School workspace · {isManagement ? 'Management' : 'Teacher'}
            </span>
          </Link>
          <nav className="flex flex-wrap items-center gap-1 md:ml-auto">
            {NAV.filter((n) => !n.managementOnly || isManagement).map((n) => (
              <Link
                key={n.href}
                href={n.href}
                className={`rounded-full px-3.5 py-2 text-sm transition-colors ${
                  title === n.label
                    ? 'bg-primary text-on-primary'
                    : 'text-on-surface-variant hover:bg-surface-container hover:text-on-surface'
                }`}
              >
                {n.label}
              </Link>
            ))}
            <button
              onClick={() => {
                clearActiveSchool();
                localStorage.removeItem('renance.token');
                router.replace('/login');
              }}
              className="ml-2 rounded-full border border-outline px-3.5 py-2 text-sm text-on-surface-variant hover:text-on-surface"
            >
              Sign out
            </button>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
    </div>
  );
}

export function SchoolHeading({ title, sub }: { title: string; sub?: string }) {
  return (
    <div className="mb-6">
      <h1 className="text-xl font-semibold tracking-tight text-on-surface">{title}</h1>
      {sub && <p className="mt-1 text-sm text-on-surface-variant">{sub}</p>}
    </div>
  );
}

// The shared picker row styles keep the portal consistent.
export const selectCls =
  'h-11 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary';
export const inputCls =
  'h-11 w-full rounded-lg border border-outline-variant bg-surface-container-lowest px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary';
export const btnPrimary =
  'flex h-11 items-center justify-center gap-2 rounded-lg bg-primary px-5 text-sm font-medium text-on-primary transition-all hover:opacity-90 active:scale-[0.98] disabled:opacity-50';
export const btnGhost =
  'flex h-11 items-center justify-center rounded-lg border border-outline px-4 text-sm text-on-surface transition-colors hover:bg-surface-container';
