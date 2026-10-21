'use client';

/**
 * Landing motion kit - RETIRED in the Round 8 Duolingo-style redesign
 * (Task 4-d, founder: "make the Renance landing page the same as
 * theirs"). The new landing (app/page.tsx) is a fully static server
 * component in the duolingo.com/log-in mold: no aurora field, no glass
 * pill nav, no reveals, no count-ups, no floating cards, no marquee.
 *
 * The old exports (MotionPrefs, useReducedMotion, Reveal, CountUp,
 * AuroraField, LandingNav, FloatingCard, MarqueeRail) were trimmed
 * after a repo-wide grep confirmed app/page.tsx was their only
 * importer; they live on in git history. This module stays as an
 * intentional empty module so any future stray import fails loudly at
 * build time instead of silently shipping dead code.
 */
export {};
