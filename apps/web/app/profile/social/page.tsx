'use client';

/**
 * /profile/social — the follower + following lists (founder directive
 * 2026-10-14: "add the followers and following to profile"). Rows link
 * to the scholar's public profile; following rows offer an inline
 * unfollow, follower rows a follow-back. Contact-list friend finding
 * is deliberately PAUSED on web (founder call — it ships in the mobile
 * app later); the invite-friends card on the profile covers growth for
 * now.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import BlueTick from '@/components/blue-tick';
import { getStoredUser } from '@/lib/session';
import { type Connections, type FollowRow, fetchConnections, toggleFollow } from '@/lib/social';

type Tab = 'followers' | 'following';

export default function ProfileSocialPage() {
  const router = useRouter();
  const [conn, setConn] = useState<Connections | null>(null);
  const [error, setError] = useState('');
  const [tab, setTab] = useState<Tab>('followers');
  const [busy, setBusy] = useState('');

  const load = useCallback(() => {
    setError('');
    fetchConnections()
      .then(setConn)
      .catch(() => setError('Your people could not load. Check your connection, then retry.'));
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/profile/social');
      return;
    }
    load();
  }, [load, router]);

  async function flip(row: FollowRow) {
    if (busy) return;
    setBusy(row.username);
    try {
      const r = await toggleFollow(row.username);
      setConn((cur) => {
        if (!cur) return cur;
        const setRow = (list: FollowRow[]) =>
          list.map((x) => (x.username === row.username ? { ...x, following: r.following } : x));
        return { followers: setRow(cur.followers), following: setRow(cur.following) };
      });
    } catch {
      /* leave the state as it was */
    } finally {
      setBusy('');
    }
  }

  const rows = conn ? (tab === 'followers' ? conn.followers : conn.following) : [];

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <PageBar title="Your people" backHref="/profile" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        {/* Tabs */}
        <div className="learn-tile grid grid-cols-2 gap-2 rounded-2xl border-2 border-outline-variant bg-card p-2">
          {(['followers', 'following'] as Tab[]).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTab(t)}
              className={`key-btn flex items-center justify-center gap-1.5 py-2.5 text-[13px] ${
                tab === t ? 'bg-primary text-white' : 'bg-surface-container text-on-surface-variant'
              }`}
            >
              {t === 'followers' ? (
                <span className="material-symbols-outlined text-[18px]">group</span>
              ) : (
                <span className="material-symbols-outlined text-[18px]">person_add</span>
              )}
              {t === 'followers' ? `Followers (${conn?.followers.length ?? 0})` : `Following (${conn?.following.length ?? 0})`}
            </button>
          ))}
        </div>

        {error && (
          <div className="learn-tile mt-4 flex flex-col items-center gap-3 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-10 text-center">
            <span className="material-symbols-outlined text-[34px] text-on-surface-variant">wifi_off</span>
            <p className="text-[13.5px] font-bold text-on-surface-variant">{error}</p>
            <button type="button" onClick={load} className="key-btn bg-primary text-white">Retry</button>
          </div>
        )}
        {!conn && !error && (
          <div className="mt-6 flex justify-center"><LogoActivityIndicator /></div>
        )}

        {conn && rows.length === 0 && (
          <div className="learn-tile mt-4 flex flex-col items-center gap-2 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-12 text-center">
            <span className="material-symbols-outlined text-[36px] text-primary">diversity_3</span>
            <p className="text-[15px] font-black text-on-surface">
              {tab === 'followers' ? 'No followers yet' : 'Not following anyone yet'}
            </p>
            <p className="max-w-xs text-[12.5px] font-bold text-on-surface-variant">
              {tab === 'followers'
                ? 'Post your wins on the feed and share your invite link — they will come.'
                : 'Tap any name on the feed, the boards or the arena and follow them from their profile.'}
            </p>
          </div>
        )}

        <ul className="mt-3">
          {rows.map((row) => (
            <li key={`${tab}-${row.username}`} className="learn-tile mt-2 flex items-center gap-3 rounded-2xl border-2 border-outline-variant bg-card p-3">
              <Link
                href={`/profile/view/?u=${encodeURIComponent(row.username)}`}
                aria-label={`${row.name} on their profile`}
                className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-container-high text-[16px] font-bold text-on-surface transition hover:ring-2 hover:ring-primary"
              >
                {row.name.slice(0, 1).toUpperCase()}
              </Link>
              <div className="min-w-0 flex-1">
                <Link href={`/profile/view/?u=${encodeURIComponent(row.username)}`} className="flex items-center gap-1.5">
                  <span className="min-w-0 truncate text-[14.5px] font-extrabold text-on-surface hover:underline">{row.name}</span>
                  {row.premium && <BlueTick size={15} />}
                </Link>
                <p className="text-[12px] font-bold text-on-surface-variant">
                  @{row.username}
                  {row.followsYou && <span className="ml-2 rounded-full bg-surface-container px-2 py-0.5 text-[10.5px]">Follows you</span>}
                </p>
              </div>
              <button
                type="button"
                onClick={() => void flip(row)}
                disabled={busy === row.username}
                className={`key-btn shrink-0 px-4 text-[12.5px] text-white disabled:opacity-50 ${
                  row.following ? 'bg-on-surface-variant' : 'bg-primary'
                }`}
              >
                {row.following ? 'Following' : row.followsYou ? 'Follow back' : 'Follow'}
              </button>
            </li>
          ))}
        </ul>
      </main>
      <BottomNav />
    </div>
  );
}
