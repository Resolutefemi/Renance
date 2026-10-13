'use client';

/**
 * The interactive public profile, mounted at /profile/view/?u={username}
 * (founder directive 2026-10-14: "real interactive profile for people
 * once they click on their name on leaderboard, or feed or on league
 * leaderboard or arena"). Level, XP, streak, league,
 * followers/following, the courses they are taking with progress, and
 * their posts. Follow/unfollow inline; your own handle redirects to
 * /profile.
 *
 * The web ships as a STATIC export, so the route is a plain static page
 * reading the handle from the query string (the same pattern as the
 * leaderboard's ?tab=). Pretty /u/{username} URLs keep working on the
 * live Vercel deployment through a vercel.json rewrite onto this page.
 */

import { Suspense, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import BlueTick from '@/components/blue-tick';
import { LeagueBadge, ProgressBar } from '@/components/learn/bits';
import { getStoredUser } from '@/lib/session';
import {
  type PublicProfile,
  type SocialPost,
  fetchPublicProfile,
  milestoneVisual,
  timeAgo,
  toggleFollow,
} from '@/lib/social';
import { learnBodyLabel } from '@/lib/learn';

export default function ProfileViewRoute() {
  return (
    <Suspense fallback={null}>
      <PublicProfileView />
    </Suspense>
  );
}

function PublicProfileView() {
  const router = useRouter();
  const search = useSearchParams();
  const [profile, setProfile] = useState<PublicProfile | null>(null);
  const [posts, setPosts] = useState<SocialPost[]>([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const raw = search.get('u') ?? '';
  const username = decodeURIComponent(raw);

  const load = useCallback(() => {
    setError('');
    fetchPublicProfile(username)
      .then((r) => {
        setProfile(r.profile);
        setPosts(r.posts ?? []);
      })
      .catch(() => setError('This scholar could not be found.'));
  }, [username]);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace(`/login?next=/profile/view/?u=${encodeURIComponent(username)}`);
      return;
    }
    load();
  }, [load, router, username]);

  async function follow() {
    if (!profile || busy) return;
    setBusy(true);
    try {
      const r = await toggleFollow(profile.username);
      setProfile({ ...profile, isFollowing: r.following, followers: profile.followers + (r.following ? 1 : -1) });
    } catch {
      /* leave the state as it was */
    } finally {
      setBusy(false);
    }
  }

  if (error) {
    return (
      <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
        <SideNav />
        <PageBar title="Profile" backHref="/dashboard" />
        <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-6 text-center">
          <span className="material-symbols-outlined text-[38px] text-on-surface-variant">person_off</span>
          <p className="mt-2 text-[14px] font-bold text-on-surface-variant">{error}</p>
          <Link href="/dashboard" className="key-btn mt-4 inline-flex bg-primary text-white">Back to the desk</Link>
        </main>
      </div>
    );
  }
  if (!profile) {
    return (
      <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
        <SideNav />
        <PageBar title="Profile" backHref="/dashboard" />
        <main className="flex justify-center pb-28 pt-16"><LogoActivityIndicator /></main>
      </div>
    );
  }
  if (profile.isSelf) {
    router.replace('/profile');
    return null;
  }

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <PageBar title={profile.name} backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        <div className="flex flex-col gap-4">
          {/* Header -------------------------------------------------- */}
          <section className="learn-tile flex flex-col items-center gap-3 rounded-2xl border-2 border-outline-variant bg-card px-4 py-6 text-center">
            <div className="relative">
              <span className="flex h-20 w-20 items-center justify-center rounded-full bg-primary text-[30px] font-black text-on-primary">
                {profile.name.slice(0, 1).toUpperCase()}
              </span>
              <span className="absolute -bottom-1 -right-1 rounded-full border-2 border-card bg-primary px-2 py-0.5 font-mono text-[11px] font-bold text-on-primary">
                Lvl {profile.level}
              </span>
            </div>
            <div>
              <h2 className="flex items-center justify-center gap-1.5 text-[22px] font-black tracking-tight text-on-surface">
                {profile.name}
                {profile.premium && <BlueTick size={17} />}
              </h2>
              <p className="text-[14px] font-bold text-on-surface-variant">@{profile.username}</p>
            </div>
            <div className="flex items-center gap-2">
              <LeagueBadge name={profile.league} size={34} />
              <span className="text-[13px] font-extrabold text-on-surface">{profile.league} League</span>
            </div>
            <button
              type="button"
              onClick={() => void follow()}
              disabled={busy}
              className={`key-btn px-8 text-[14px] text-white ${profile.isFollowing ? 'bg-on-surface-variant' : 'bg-primary'} disabled:opacity-50`}
            >
              {profile.isFollowing ? 'Following ✓' : 'Follow'}
            </button>
            <p className="text-[11.5px] font-bold text-on-surface-variant">
              On Renance since {new Date(profile.joinedMs).toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}
            </p>
          </section>

          {/* Stat strip ---------------------------------------------- */}
          <section className="learn-tile rounded-2xl border-2 border-outline-variant bg-card p-3">
            <div className="flex items-stretch justify-between text-center">
              <div className="flex-1">
                <p className="text-[11px] font-bold uppercase tracking-wide text-on-surface-variant">Followers</p>
                <p className="text-[19px] font-black text-on-surface">{profile.followers}</p>
              </div>
              <div className="w-px bg-outline-variant/40" />
              <div className="flex-1">
                <p className="text-[11px] font-bold uppercase tracking-wide text-on-surface-variant">Following</p>
                <p className="text-[19px] font-black text-on-surface">{profile.following}</p>
              </div>
              <div className="w-px bg-outline-variant/40" />
              <div className="flex-1">
                <p className="text-[11px] font-bold uppercase tracking-wide text-on-surface-variant">Streak</p>
                <p className="text-[19px] font-black text-accent-amber">🔥 {profile.streak}</p>
              </div>
              <div className="w-px bg-outline-variant/40" />
              <div className="flex-1">
                <p className="text-[11px] font-bold uppercase tracking-wide text-on-surface-variant">XP</p>
                <p className="text-[19px] font-black text-on-surface">{profile.xp.toLocaleString()}</p>
              </div>
            </div>
            <div className="mt-2 flex items-center justify-between rounded-xl bg-surface-container px-3 py-2 text-[12px] font-bold text-on-surface-variant">
              <span>{profile.topicsDone} topics done</span>
              <span>{profile.perfectCount} perfect runs</span>
            </div>
          </section>

          {/* Courses ------------------------------------------------- */}
          <section className="learn-tile rounded-2xl border-2 border-outline-variant bg-card p-4">
            <h3 className="text-[13px] font-black uppercase tracking-widest text-on-surface-variant">Taking</h3>
            {!profile.courses?.length && (
              <p className="mt-2 text-[13px] font-bold text-on-surface-variant">No courses on their desk yet.</p>
            )}
            <div className="mt-3 flex flex-col gap-3">
              {profile.courses?.map((c) => (
                <div key={c.title}>
                  <div className="mb-1 flex items-baseline justify-between gap-2">
                    <p className="min-w-0 truncate text-[13.5px] font-extrabold text-on-surface">{c.title}</p>
                    <p className="shrink-0 font-mono text-[11px] font-bold text-on-surface-variant">
                      {learnBodyLabel(c.body)} · {c.done}/{c.topics}
                    </p>
                  </div>
                  <ProgressBar value={c.percent} tone={c.percent >= 100 ? 'gold' : 'green'} />
                </div>
              ))}
            </div>
          </section>

          {/* Their posts --------------------------------------------- */}
          <section>
            <h3 className="mb-2 mt-1 text-[13px] font-black uppercase tracking-widest text-on-surface-variant">Posts</h3>
            {posts.length === 0 && (
              <p className="learn-tile rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-8 text-center text-[13px] font-bold text-on-surface-variant">
                Nothing posted yet.
              </p>
            )}
            {posts.map((post) => {
              const mv = post.kind === 'milestone' ? milestoneVisual(post) : null;
              return (
                <article key={post.id} className="learn-tile mt-3 overflow-hidden rounded-2xl border-2 border-outline-variant bg-card">
                  {mv && (
                    <div className="flex items-center gap-2 px-4 pt-3" style={{ color: mv.tint }}>
                      <span className="material-symbols-outlined text-[17px]">{mv.icon}</span>
                      <span className="text-[11px] font-black uppercase tracking-widest">{mv.label}</span>
                    </div>
                  )}
                  <p className="whitespace-pre-wrap px-4 py-3 text-[14.5px] font-semibold leading-relaxed text-on-surface">{post.body}</p>
                  <div className="flex items-center gap-4 border-t-2 border-outline-variant/40 px-4 py-2 text-[12px] font-bold text-on-surface-variant">
                    <span className="flex items-center gap-1">
                      <span className={`material-symbols-outlined text-[16px] ${post.likedByMe ? 'fill-current text-error' : ''}`}>favorite</span>
                      {post.likes}
                    </span>
                    <span className="flex items-center gap-1">
                      <span className="material-symbols-outlined text-[16px]">chat_bubble</span>
                      {post.comments}
                    </span>
                    <span className="ml-auto">{timeAgo(post.createdAtMs)}</span>
                  </div>
                </article>
              );
            })}
          </section>
        </div>
      </main>
      <BottomNav />
    </div>
  );
}
