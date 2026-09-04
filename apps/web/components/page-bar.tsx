'use client';

/**
 * PageBar: the back affordance the founder asked for on every page.
 * Sits at the very top LHS: a round back button, the page title, and an
 * optional right slot. Sticky, blurred, same header language as Stitch.
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
    if (typeof window !== 'undefined' && window.history.length > 1) {
      const ref = document.referrer || '';
      const sameApp = ref.includes(window.location.host);
      if (sameApp) {
        router.back();
        return;
      }
    }
    router.push(backHref);
  }

  return (
    <div className="sticky top-0 z-40 w-full border-b border-outline-variant/40 bg-surface/80 backdrop-blur-xl">
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center gap-1 px-2 sm:px-4">
        <button
          type="button"
          onClick={goBack}
          aria-label="Go back"
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
        >
          <span className="material-symbols-outlined text-[22px]">arrow_back</span>
        </button>
        <h1 className="min-w-0 flex-1 truncate text-[15px] font-semibold text-on-surface">{title}</h1>
        {right}
      </div>
    </div>
  );
}
