'use client';

/**
 * BlueTick - RETIRED (founder directive 2026-10-17: "remove that blue
 * tick for all users - when we introduce premium subscription we can
 * implement it later for paid users"). The component now renders
 * nothing, which kills the badge at every call site at once
 * (leaderboard, feed, social, profile view, pricing). When premium
 * ships, restore the old SVG body and gate it on the paid entitlement.
 */

interface Props {
  /** Size in px for the badge glyph. */
  size?: number;
  className?: string;
}

export default function BlueTick({ className = '' }: Props) {
  return <span className={className} hidden aria-hidden data-retired="blue-tick" />;
}
