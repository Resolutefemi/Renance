'use client';

/**
 * AiFloatingButton: the floating Renance AI entry point (founder
 * directive, 2026-09-30). Bottom-right corner of the home desk ONLY -
 * not a global chrome piece - so the studio stays one tap away without
 * crowding every page. Uses the house AiSparkle glyph (the curved
 * four-point star), never a clip-arty robot.
 *
 * Founder directive (2026-10-02): the pill follows the theme colour -
 * bg-primary / text-on-primary, like the R tile - instead of the old
 * hardcoded near-black that ignored the Chrome-style seed.
 *
 * Mobile: floats above the bottom nav. Desktop: floats at the content
 * edge above the fold.
 */

import Link from 'next/link';
import AiSparkle from './ai-sparkle';

export default function AiFloatingButton() {
  return (
    <Link
      href="/ai"
      aria-label="Renance AI Studio - chat, quizzes, notes, notebooks"
      className="group fixed bottom-[calc(6rem+env(safe-area-inset-bottom))] right-4 z-30 flex h-14 w-14 items-center justify-center rounded-full bg-primary text-on-primary shadow-[0_6px_20px_rgba(16,20,24,0.35)] ring-1 ring-black/10 transition-transform duration-150 hover:scale-105 active:scale-95 md:bottom-6 md:right-6 md:h-16 md:w-16"
    >
      <AiSparkle className="h-7 w-7 md:h-8 md:w-8" />
      {/* Desktop hover flourish: the studio is one tap away */}
      <span className="pointer-events-none absolute right-full mr-3 hidden whitespace-nowrap rounded-lg bg-primary px-3 py-1.5 text-[12px] font-semibold text-on-primary opacity-0 shadow-lg transition-opacity duration-150 group-hover:opacity-100 md:block">
        Renance AI Studio
      </span>
    </Link>
  );
}
