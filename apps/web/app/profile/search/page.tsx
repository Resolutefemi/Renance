'use client';

/**
 * Find friends - user search, founder directive 2026-10-22: "add
 * search for users features with username or name". Debounced query
 * against /social/search; every row wears the scholar's face (R2 photo
 * first), the Follows-you chip and an inline follow toggle, and opens
 * the scholar's public profile on tap.
 */

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import { PersonAvatar } from '@/components/person-avatar';
import { getStoredUser } from '@/lib/session';
import {
  type FollowRow,
  fetchConnections,
  fetchSuggestions,
  fetchUserSearch,
  toggleFollow,
} from '@/lib/social';

export default function UserSearchRoute() {
  return (
    <Suspense fallback={null}>
      <UserSearch />
    </Suspense>
  );
}

function UserSearch() {
  const router = useRouter();
  const search = useSearchParams();
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState(search.get('q') ?? '');
  const [results, setResults] = useState<FollowRow[] | null>(null);
  const [suggested, setSuggested] = useState<FollowRow[]>([]);
  const [searching, setSearching] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [followed, setFollowed] = useState<Set<string>>(new Set());
  const timer = useRef<number | null>(null);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/profile/search');
      return;
    }
    setReady(true);
    fetchConnections()
      .then((c) => setFollowed(new Set(c.following.map((f) => f.username))))
      .catch(() => undefined);
    fetchSuggestions(10)
      .then((r) => setSuggested(r.users))
      .catch(() => undefined);
  }, [router]);

  const runSearch = useCallback((q: string) => {
    const trimmed = q.trim();
    if (!trimmed) {
      setResults(null);
      setSearching(false);
      return;
    }
    setSearching(true);
    fetchUserSearch(trimmed, 30)
      .then((r) => setResults(r.users))
      .catch(() => setResults([]))
      .finally(() => setSearching(false));
  }, []);

  // Debounced live search: 300ms after the last keystroke.
  useEffect(() => {
    if (!ready) return;
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => runSearch(query), 300);
    return () => {
      if (timer.current) window.clearTimeout(timer.current);
    };
  }, [query, ready, runSearch]);

  const shown = useMemo(() => {
    if (results !== null) return results;
    return suggested;
  }, [results, suggested]);

  async function follow(row: FollowRow) {
    setBusy(row.username);
    const wasFollowing = followed.has(row.username);
    setFollowed((prev) => {
      const next = new Set(prev);
      if (wasFollowing) next.delete(row.username);
      else next.add(row.username);
      return next;
    });
    try {
      const res = await toggleFollow(row.username);
      setFollowed((prev) => {
        const next = new Set(prev);
        if (res.following) next.add(row.username);
        else next.delete(row.username);
        return next;
      });
    } catch {
      setFollowed((prev) => {
        const next = new Set(prev);
        if (wasFollowing) next.add(row.username);
        else next.delete(row.username);
        return next;
      });
    } finally {
      setBusy(null);
    }
  }

  if (!ready) {
    return (
      <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
        <SideNav />
        <PageBar title="Find friends" backHref="/profile" />
        <main className="flex justify-center pb-28 pt-16"><LogoActivityIndicator /></main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <PageBar title="Find friends" backHref="/profile" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        {/* The search box */}
        <div className="flex items-center gap-2 rounded-xl border-2 border-outline-variant/70 bg-card px-4 py-3 transition-colors focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/30">
          <span className="material-symbols-outlined text-[20px] text-on-surface-variant">search</span>
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value.slice(0, 60))}
            placeholder="Search a name or @username…"
            className="w-full bg-transparent text-[14.5px] font-semibold text-on-surface placeholder:text-outline focus:outline-none"
            enterKeyHint="search"
            autoComplete="off"
          />
          {query && (
            <button
              type="button"
              aria-label="Clear"
              onClick={() => setQuery('')}
              className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container"
            >
              <span className="material-symbols-outlined text-[16px]">close</span>
            </button>
          )}
        </div>

        <p className="mt-2 px-1 text-[12px] font-bold text-on-surface-variant">
          {results === null
            ? 'Suggestions'
            : searching
              ? 'Searching…'
              : `${results.length} scholar${results.length === 1 ? '' : 's'}`}
        </p>

        {/* Rows */}
        <div className="mt-1 flex flex-col">
          {shown.length === 0 && results !== null && !searching && (
            <div className="learn-tile mt-3 flex flex-col items-center gap-1.5 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-10 text-center">
              <span className="material-symbols-outlined text-[34px] text-primary">person_search</span>
              <p className="text-[14px] font-black text-on-surface">No scholar matched “{query.trim()}”</p>
              <p className="max-w-xs text-[12.5px] font-bold text-on-surface-variant">
                Try the first name, the handle without the @, or a shorter piece of the name.
              </p>
            </div>
          )}
          {shown.map((row) => {
            const isFollowing = followed.has(row.username) || row.following;
            return (
              <div
                key={row.username}
                className="flex items-center gap-3 rounded-xl px-2 py-2.5 transition hover:bg-surface-container"
              >
                <Link href={`/profile/view/?u=${encodeURIComponent(row.username)}`} className="min-w-0 flex-1">
                  <div className="flex items-center gap-3">
                    <PersonAvatar
                      person={{ avatar: row.avatar, photo: row.photo, name: row.name, username: row.username }}
                      size={44}
                    />
                    <div className="min-w-0">
                      <p className="flex items-center gap-1.5 text-[14px] font-extrabold text-on-surface">
                        <span className="min-w-0 truncate">{row.name}</span>
                      </p>
                      <p className="truncate text-[12px] font-semibold text-on-surface-variant">
                        @{row.username}
                        {row.followsYou && <span className="ml-1.5 text-primary">· Follows you</span>}
                      </p>
                    </div>
                  </div>
                </Link>
                <button
                  type="button"
                  onClick={() => void follow(row)}
                  disabled={busy === row.username}
                  aria-pressed={isFollowing}
                  className={`h-9 shrink-0 rounded-full px-4 text-[12px] font-extrabold uppercase tracking-wide transition active:translate-y-[1px] disabled:opacity-60 ${
                    isFollowing
                      ? 'border-2 border-outline-variant bg-card text-on-surface-variant'
                      : 'bg-macaw text-white'
                  }`}
                >
                  {isFollowing ? 'Following' : 'Follow'}
                </button>
              </div>
            );
          })}
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
