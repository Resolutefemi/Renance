'use client';

/**
 * PersonAvatar - one component for every human face in the app (the
 * founder's 2026-10-22 identity pass): an uploaded profile photo from
 * R2 wins, then one of the 50 baked-in avatar SVGs, then the classic
 * initial letter. Used by the feed, profiles, search, suggestions,
 * leaderboard and connections so a photo set in one place shows up
 * everywhere.
 */

import Link from 'next/link';
import { faceUrl } from '@/lib/social';

export function PersonAvatar({
  person,
  size = 40,
  href,
  alt = '',
  ring = false,
}: {
  person: { avatar?: string; photo?: string; name?: string; username?: string };
  size?: number;
  /** When set the avatar links to the scholar's public profile. */
  href?: string;
  alt?: string;
  ring?: boolean;
}) {
  const src = faceUrl(person);
  const initial = (person.name || person.username || '?').slice(0, 1).toUpperCase();
  const inner = (
    <span
      className={`flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-surface-container-high font-bold text-on-surface ${
        ring ? 'ring-2 ring-primary/50' : ''
      }`}
      style={{ width: size, height: size, fontSize: Math.max(11, size * 0.38) }}
    >
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt={alt} className="h-full w-full object-cover" loading="lazy" />
      ) : (
        initial
      )}
    </span>
  );
  if (href) {
    return (
      <Link href={href} aria-label={alt || 'Open profile'} className="shrink-0">
        {inner}
      </Link>
    );
  }
  return inner;
}
