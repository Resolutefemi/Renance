'use client';

/**
 * Feed - the Renance social feed (founder directive 2026-10-14: "the
 * major update feeds just like Duolingo feeds that people interact
 * with"). THE PLATFORM'S VOICE ONLY (founder directive 2026-10-14,
 * second pass: "remove post from the feed, users should not be able
 * to write post themselves" - exactly how the real Duolingo feed
 * works, stories are written BY the app, never by scholars):
 *
 *   · MILESTONE posts the platform writes on the student's behalf -
 *     "just hit a 400-day streak 🔥", "scored 360 in JAMB 🎯", "reached
 *     the Platinum League 🏆", "won an arena duel ⚔️" - each written
 *     once, ever, by the study-api's milestone hooks.
 *
 * Every story is interactive: hearts (likes), comments, and a Share
 * action that fires the native share sheet (or copies a link) so a
 * moment can travel to friends on social media like a card. Author
 * rows open the scholar's public profile at /u/{username}.
 *
 * No Retry button anywhere: when the connection drops the feed shows
 * its friendly empty face and quietly re-syncs itself a few seconds
 * later (founder: "remove retry").
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import BlueTick from '@/components/blue-tick';
import { getStoredUser } from '@/lib/session';
import {
  type SocialComment,
  type SocialPost,
  addComment,
  fetchComments,
  fetchConnections,
  fetchFeed,
  milestoneVisual,
  timeAgo,
  toggleFollow,
  toggleLike,
} from '@/lib/social';

export default function FeedPage() {
  const router = useRouter();
  const [posts, setPosts] = useState<SocialPost[] | null>(null);
  // Follow state for the feed's author chips (founder 2026-10-17):
  // seeded from the connections list, flipped optimistically.
  const [followed, setFollowed] = useState<Set<string>>(new Set());
  const [followBusy, setFollowBusy] = useState<string | null>(null);

  const flipFollow = useCallback(async (username: string) => {
    setFollowBusy(username);
    const wasFollowing = followed.has(username);
    // Optimistic flip; the API is the truth on settle.
    setFollowed((prev) => {
      const next = new Set(prev);
      if (wasFollowing) next.delete(username);
      else next.add(username);
      return next;
    });
    try {
      const res = await toggleFollow(username);
      setFollowed((prev) => {
        const next = new Set(prev);
        if (res.following) next.add(username);
        else next.delete(username);
        return next;
      });
    } catch {
      setFollowed((prev) => {
        const next = new Set(prev);
        if (wasFollowing) next.add(username);
        else next.delete(username);
        return next;
      });
    } finally {
      setFollowBusy(null);
    }
  }, [followed]);
  const [offline, setOffline] = useState(false);
  const [busy, setBusy] = useState('');
  const [commentsFor, setCommentsFor] = useState<number | null>(null);
  const [comments, setComments] = useState<SocialComment[]>([]);
  const [commentDraft, setCommentDraft] = useState('');
  const [toast, setToast] = useState('');
  const sentinel = useRef<HTMLDivElement | null>(null);

  const load = useCallback(() => {
    fetchFeed()
      .then((r) => {
        setPosts(r.posts);
        setOffline(false);
      })
      .catch(() => {
        // No dead-end error card (founder: "remove retry"): keep
        // whatever is on screen, mark the feed as offline and let the
        // quiet re-sync below bring it back.
        setPosts((cur) => cur ?? []);
        setOffline(true);
      });
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/feed');
      return;
    }
    load();
    // Seed the follow chips with who I already follow.
    fetchConnections()
      .then((c) => setFollowed(new Set(c.following.map((f) => f.username))))
      .catch(() => undefined);
  }, [load, router]);

  // The quiet re-sync: while offline, poll every 8s until the feed
  // answers. No button to press - the page heals itself.
  useEffect(() => {
    if (!offline) return;
    const t = window.setInterval(load, 8000);
    return () => window.clearInterval(t);
  }, [offline, load]);

  // Infinite scroll: one more page whenever the sentinel enters view.
  useEffect(() => {
    if (!posts || posts.length < 25) return;
    const el = sentinel.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (!entries[0].isIntersecting) return;
        const oldest = posts[posts.length - 1];
        if (!oldest) return;
        fetchFeed(oldest.id)
          .then((r) => {
            if (r.posts.length === 0) return;
            const seen = new Set(posts.map((p) => p.id));
            setPosts((cur) => [...(cur ?? []), ...r.posts.filter((p) => !seen.has(p.id))]);
          })
          .catch(() => {});
      },
      { rootMargin: '400px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [posts]);

  function flash(msg: string) {
    setToast(msg);
    window.setTimeout(() => setToast(''), 2200);
  }

  async function like(post: SocialPost) {
    setBusy(`like-${post.id}`);
    // Optimistic flip; the server count wins on return.
    setPosts((cur) =>
      (cur ?? []).map((p) =>
        p.id === post.id
          ? { ...p, likedByMe: !p.likedByMe, likes: p.likes + (p.likedByMe ? -1 : 1) }
          : p,
      ),
    );
    try {
      const r = await toggleLike(post.id);
      setPosts((cur) =>
        (cur ?? []).map((p) => (p.id === post.id ? { ...p, likes: r.likes, likedByMe: r.liked } : p)),
      );
    } catch {
      /* keep the optimistic state; next pull reconciles */
    } finally {
      setBusy('');
    }
  }

  async function openComments(post: SocialPost) {
    if (commentsFor === post.id) {
      setCommentsFor(null);
      return;
    }
    setCommentsFor(post.id);
    setComments([]);
    setCommentDraft('');
    try {
      const r = await fetchComments(post.id);
      setComments(r.comments);
    } catch {
      setComments([]);
    }
  }

  async function submitComment(post: SocialPost) {
    const body = commentDraft.trim();
    if (!body) return;
    setCommentDraft('');
    try {
      const r = await addComment(post.id, body);
      setComments(r.comments);
      setPosts((cur) =>
        (cur ?? []).map((p) => (p.id === post.id ? { ...p, comments: r.comments.length } : p)),
      );
    } catch {
      flash('Could not comment');
    }
  }

  async function share(post: SocialPost) {
    const name = post.author?.name ?? 'A scholar';
    const text = `${name} ${post.body} - via Renance`;
    const url = typeof window !== 'undefined' ? window.location.origin + '/feed' : '';
    try {
      if (typeof navigator !== 'undefined' && navigator.share) {
        await navigator.share({ title: 'Renance', text, url });
        return;
      }
      await navigator.clipboard?.writeText(`${text} ${url}`);
      flash('Link copied - share it anywhere');
    } catch {
      /* the sheet was dismissed */
    }
  }

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      {toast && (
        <div className="pointer-events-none fixed inset-x-0 top-16 z-[70] mx-auto w-fit max-w-[90vw] rounded-xl bg-primary px-4 py-2 text-[13px] font-extrabold text-on-primary learn-toast-shadow">
          {toast}
        </div>
      )}
      <PageBar title="Feed" backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        {/* Load state -------------------------------------------------- */}
        {!posts && (
          <div className="flex justify-center py-10"><LogoActivityIndicator /></div>
        )}

        {/* The feed ---------------------------------------------------- */}
        {posts && posts.length === 0 && (
          <div className="learn-tile mt-4 flex flex-col items-center gap-2 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-12 text-center">
            <span className="material-symbols-outlined text-[36px] text-primary">newspaper</span>
            <p className="text-[15px] font-black text-on-surface">
              {offline ? 'Finding your feed…' : 'The feed is waiting for its first story'}
            </p>
            <p className="max-w-xs text-[12.5px] font-bold text-on-surface-variant">
              Streaks, big scores, league promotions and arena wins show up here automatically as you study.
            </p>
          </div>
        )}

        {posts?.map((post) => {
          const mv = post.kind === 'milestone' ? milestoneVisual(post) : null;
          const author = post.author;
          return (
            <article key={post.id} className="learn-tile mt-4 overflow-hidden rounded-2xl border-2 border-outline-variant bg-card">
              {mv && (
                <div className="flex items-center gap-2 px-4 pt-3" style={{ color: mv.tint }}>
                  <span className="material-symbols-outlined text-[17px]">{mv.icon}</span>
                  <span className="text-[11px] font-black uppercase tracking-widest">{mv.label}</span>
                </div>
              )}
              <div className="flex items-center gap-3 px-4 pt-3">
                {author ? (
                  <Link
                    href={`/profile/view/?u=${encodeURIComponent(author.username)}`}
                    aria-label={`${author.name} on their profile`}
                    className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-container-high text-[15px] font-bold text-on-surface transition hover:ring-2 hover:ring-primary"
                  >
                    {author.name.slice(0, 1).toUpperCase()}
                  </Link>
                ) : (
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary text-[15px] font-bold text-on-primary">R</span>
                )}
                <div className="min-w-0 flex-1">
                  {author ? (
                    <Link
                      href={`/profile/view/?u=${encodeURIComponent(author.username)}`}
                      className="flex items-center gap-1.5 text-[14.5px] font-extrabold text-on-surface hover:underline"
                    >
                      <span className="min-w-0 truncate">{author.name}</span>
                      {author.premium && <BlueTick size={15} />}
                    </Link>
                  ) : (
                    <p className="text-[14.5px] font-extrabold text-on-surface">You</p>
                  )}
                  <p className="text-[11.5px] font-bold text-on-surface-variant">{timeAgo(post.createdAtMs)}</p>
                </div>
                {/* Founder directive (2026-10-17): follow straight from
                    the feed - the complete follow/unfollow loop without
                    detouring through the profile. */}
                {author && (
                  <FollowChip
                    username={author.username}
                    followedSet={followed}
                    onToggle={flipFollow}
                    busy={followBusy === author.username}
                  />
                )}
              </div>
              <p className="whitespace-pre-wrap px-4 py-3 text-[15px] font-semibold leading-relaxed text-on-surface">
                {post.body}
              </p>
              <div className="flex items-center gap-1 border-t-2 border-outline-variant/40 px-2 py-1.5">
                <button
                  type="button"
                  onClick={() => void like(post)}
                  disabled={busy === `like-${post.id}`}
                  aria-pressed={post.likedByMe}
                  className={`flex flex-1 items-center justify-center gap-1.5 rounded-xl py-2 text-[12.5px] font-extrabold transition active:translate-y-[1px] ${
                    post.likedByMe ? 'text-error' : 'text-on-surface-variant hover:bg-surface-container'
                  }`}
                >
                  <span className={`material-symbols-outlined text-[19px] ${post.likedByMe ? 'fill-current' : ''}`}>
                    {post.likedByMe ? 'favorite' : 'favorite_border'}
                  </span>
                  {post.likes > 0 ? post.likes : 'Love'}
                </button>
                <button
                  type="button"
                  onClick={() => void openComments(post)}
                  className="flex flex-1 items-center justify-center gap-1.5 rounded-xl py-2 text-[12.5px] font-extrabold text-on-surface-variant transition hover:bg-surface-container active:translate-y-[1px]"
                >
                  <span className="material-symbols-outlined text-[19px]">chat_bubble</span>
                  {post.comments > 0 ? post.comments : 'Comment'}
                </button>
                <button
                  type="button"
                  onClick={() => void share(post)}
                  className="flex flex-1 items-center justify-center gap-1.5 rounded-xl py-2 text-[12.5px] font-extrabold text-on-surface-variant transition hover:bg-surface-container active:translate-y-[1px]"
                >
                  <span className="material-symbols-outlined text-[19px]">ios_share</span>
                  Share
                </button>
              </div>
              {commentsFor === post.id && (
                <div className="border-t-2 border-outline-variant/40 bg-surface-container-lowest px-4 py-3">
                  {comments.length === 0 && (
                    <p className="py-2 text-[12.5px] font-bold text-on-surface-variant">No comments yet - cheer them on.</p>
                  )}
                  {comments.map((c) => (
                    <div key={c.id} className="flex items-start gap-2.5 py-2">
                      <Link
                        href={`/profile/view/?u=${encodeURIComponent(c.author.username)}`}
                        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-surface-container-high text-[12.5px] font-bold text-on-surface"
                      >
                        {c.author.name.slice(0, 1).toUpperCase()}
                      </Link>
                      <div className="min-w-0 flex-1 rounded-xl bg-surface-container px-3 py-2">
                        <p className="text-[12.5px] font-extrabold text-on-surface">
                          {c.author.name}
                          <span className="ml-1.5 font-bold text-on-surface-variant">{timeAgo(c.createdAtMs)}</span>
                        </p>
                        <p className="whitespace-pre-wrap text-[13.5px] font-medium text-on-surface">{c.body}</p>
                      </div>
                    </div>
                  ))}
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      void submitComment(post);
                    }}
                    className="mt-1 flex items-center gap-2"
                  >
                    <input
                      value={commentDraft}
                      onChange={(e) => setCommentDraft(e.target.value.slice(0, 300))}
                      placeholder="Add a comment…"
                      className="h-10 flex-1 rounded-full bg-surface-container px-4 text-[13.5px] text-on-surface placeholder:text-outline focus:outline-none focus:ring-2 focus:ring-primary/40"
                    />
                    <button
                      type="submit"
                      disabled={!commentDraft.trim()}
                      className="key-btn bg-primary px-4 text-[12.5px] text-on-primary disabled:opacity-40"
                    >
                      Send
                    </button>
                  </form>
                </div>
              )}
            </article>
          );
        })}
        <div ref={sentinel} aria-hidden />
      </main>
      <BottomNav />
    </div>
  );
}

/** Compact follow/unfollow chip on a feed post's author row. */
function FollowChip({
  username, followedSet, onToggle, busy,
}: {
  username: string;
  followedSet: Set<string>;
  onToggle: (username: string) => void;
  busy: boolean;
}) {
  const isFollowing = followedSet.has(username);
  return (
    <button
      type="button"
      onClick={() => onToggle(username)}
      disabled={busy}
      aria-pressed={isFollowing}
      className={`flex h-8 shrink-0 items-center rounded-full px-3.5 text-[12px] font-extrabold transition disabled:opacity-60 ${
        isFollowing
          ? 'border-2 border-outline-variant bg-card text-on-surface-variant'
          : 'bg-primary text-on-primary'
      }`}
    >
      {isFollowing ? 'Following' : 'Follow'}
    </button>
  );
}
