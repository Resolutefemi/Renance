'use client';

/**
 * PageBar: the back affordance on every page. Sits at the very top
 * LHS: a round back button, the page title, and an optional right
 * slot. Sticky, blurred.
 *
 * 2026-10-13 founder pass ("the top navbar is too big, make it normal
 * and moderate just like supreme.git"): one compact 48px bar at every
 * breakpoint (was 56/64px), a hard 2px swan rule like the Supreme top
 * bar, a 36px back key and a calm 15px title.
 */

import { ReactNode } from 'react';
import { useRouter } from 'next/navigation';

export default function PageBar({
  title,
  right,
  backHref = '/dashboard',
}: {
  title: string;
  right?: ReactNode;
  /** Fallback when there is no in-app history to go back to. */
  backHref?: string;
}) {
  const router = useRouter();

  function goBack() {
    if (typeof window !== 'undefined') {
      // Next.js keeps `idx` in the history state: the index of the
      // current entry in the app's own history stack. idx > 0 means
      // there is an in-app page behind us, so a real history back is
      // safe and lands where the student actually came from (the desk,
      // the course grid…). document.referrer alone was wrong here:
      // SPA navigation never updates it, so every back used to fall
      // through to the hard-coded backHref (the school-selection page).
      const state = window.history.state as { idx?: number } | null;
      if (window.history.length > 1 && (state?.idx ?? 0) > 0) {
        router.back();
        return;
      }
    }
    router.push(backHref);
  }

  return (
    <div className="sticky top-0 z-40 w-full border-b-2 border-outline-variant bg-surface/90 backdrop-blur-xl">
      <div className="mx-auto flex h-12 w-full max-w-5xl items-center gap-1 px-2 sm:px-4">
        <button
          type="button"
          onClick={goBack}
          aria-label="Go back"
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-on-surface transition hover:bg-polar"
        >
          <span className="material-symbols-outlined text-[22px]">arrow_back</span>
        </button>
        <h1 className="min-w-0 flex-1 truncate text-[15px] font-extrabold tracking-tight text-on-surface">{title}</h1>
        {right}
      </div>
    </div>
  );
}
