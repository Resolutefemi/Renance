'use client';

/**
 * PracticeGate - the sign-up-first wall on every practice surface.
 *
 * Founder directive (2026-10-01): questions, live scoring and worked
 * explanations are the product - a visitor who clicks any year to
 * practise (or opens the CBT player / mock setup / past-questions
 * reader) must land on "create a free account" unless a Renance
 * session already exists in localStorage.
 *
 * Client-only by necessity: the site is a static export, so the gate
 * renders after mount (the SEO pages that link here stay fully
 * indexable). While the session is being read the gate renders
 * nothing - one frame, no flash of gated content.
 *
 * The gate passes the current URL (path + query) as ?next= to
 * /register and /login, and both send the student straight back to
 * the paper they came for after auth.
 */

import { useEffect, useState, type ReactNode } from 'react';
import Link from 'next/link';
import { getToken } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';

export default function PracticeGate({
  heading,
  children,
}: {
  /** What the student came to practise, e.g. "JAMB English 2024". */
  heading?: string;
  children: ReactNode;
}) {
  // null = session not read yet; false = guest; true = signed in.
  const [authed, setAuthed] = useState<boolean | null>(null);

  useEffect(() => {
    setAuthed(!!getToken());
  }, []);

  if (authed === null) return null;
  if (authed) return <>{children}</>;

  const next = encodeURIComponent(
    typeof window === 'undefined' ? '/' : window.location.pathname + window.location.search,
  );

  return (
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4">
      <div className="my-auto flex w-full max-w-sm min-w-0 flex-col items-center">
        <div className="mb-8 flex min-w-0 flex-col items-center">
          <div className="mb-4">
            <RenanceMark size={64} />
          </div>
          <h1 className="break-words text-center text-2xl font-semibold tracking-tight text-on-surface">
            Create a free account to practise
          </h1>
          <p className="mt-1 break-words text-center text-sm text-on-surface-variant">
            {heading ? (
              <>
                <span className="font-medium text-on-surface">{heading}</span> is ready and
                waiting - a free Renance account unlocks it.
              </>
            ) : (
              'Every paper on Renance is free with an account.'
            )}
          </p>
        </div>

        <div className="flex w-full flex-col gap-4 rounded-xl bg-surface-container-lowest p-6 shadow-sm">
          <ul className="flex flex-col gap-3">
            {[
              ['library_books', '235,110+ real past questions', 'JAMB, WAEC, NECO, Post-UTME and tertiary institution banks.'],
              ['fact_check', 'Worked explanations', 'A step-by-step reason for every option, on every question.'],
              ['timer', 'Real CBT mode', 'Server-graded mocks timed exactly like the exam hall.'],
              ['bolt', 'Free forever', 'Creating an account takes seconds - email and password.'],
            ].map(([icon, title, copy]) => (
              <li key={title} className="flex items-start gap-3">
                <span className="material-symbols-outlined mt-0.5 shrink-0 text-[20px] text-primary">
                  {icon}
                </span>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-on-surface">{title}</p>
                  <p className="mt-0.5 text-xs leading-relaxed text-on-surface-variant">{copy}</p>
                </div>
              </li>
            ))}
          </ul>

          <Link
            href={`/register/?next=${next}`}
            className="mt-1 flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-primary text-on-primary transition-all hover:bg-on-background hover:shadow-md active:scale-[0.98]"
          >
            <span className="material-symbols-outlined text-[20px]">person_add</span>
            Create free account
          </Link>
          <Link
            href={`/login/?next=${next}`}
            className="flex h-12 w-full items-center justify-center rounded-lg border border-outline-variant bg-surface-container-low text-sm font-medium text-on-surface transition-colors hover:bg-surface-container active:scale-[0.98]"
          >
            Sign in
          </Link>
        </div>

        <p className="mt-10 text-center text-xs leading-relaxed text-on-surface-variant">
          Accounts keep your scores, streaks and spaced-review plan in sync across the app and the
          web - that is why practice lives behind a free sign-up.
        </p>
      </div>
    </main>
  );
}
