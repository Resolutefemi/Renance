'use client';

/**
 * Feed - the Renance social feed, rebuilt to the founder's 2026-10-22
 * screenshots (the real Duolingo feed): CELEBRATE + the party/clap/angry
 * reaction pills with counts, the big milestone artwork (streak flame
 * with the scholar's face inside, league medal, exam target),
 * ANNOUNCEMENT cards with illustration + CTA, the "Liked by {name} and
 * others" line, and the friends-shaped empty state that ends in FIND
 * FRIENDS. Stories are written BY the platform: milestone posts the
 * study-api writes on the scholar's behalf, plus the founder's
 * announcements. Every story is interactive: hearts, reactions,
 * comments, share; author rows open /profile/view/?u={username}.
 *
 * No Retry button anywhere: when the connection drops the feed shows
 * its friendly empty face and quietly re-syncs itself a few seconds
 * later (founder: "remove retry").
 */

import { Suspense, useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import BlueTick from '@/components/blue-tick';
import { PersonAvatar } from '@/components/person-avatar';
import {
  type ReactionKind,
  type ReactionState,
  type SocialComment,
  type SocialPost,
  addComment,
  fetchComments,
  fetchConnections,
  fetchFeed,
  bigCount,
  milestoneVisual,
  timeAgo,
  toggleFollow,
  toggleLike,
  toggleReaction,
} from '@/lib/social';
import { getStoredUser } from '@/lib/session';

export default function FeedPage() {
  return (
    <Suspense fallback={null}>
      <FeedInner />
    </Suspense>
  );
}

function FeedInner() {
  const router = useRouter();
  const search = useSearchParams();
  const [ready, setReady] = useState(false);
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
    setReady(true);
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

  async function react(post: SocialPost, kind: ReactionKind) {
    setBusy(`react-${post.id}`);
    // Optimistic pill flip, reconciled by the server summary.
    const before = post.reactions ?? {};
    const mineNow = before[kind]?.mine ?? false;
    const optimistic: Record<string, ReactionState> = { ...before };
    optimistic[kind] = {
      count: Math.max(0, (before[kind]?.count ?? 0) + (mineNow ? -1 : 1)),
      mine: !mineNow,
    };
    setPosts((cur) => (cur ?? []).map((p) => (p.id === post.id ? { ...p, reactions: optimistic } : p)));
    try {
      const r = await toggleReaction(post.id, kind);
      setPosts((cur) => (cur ?? []).map((p) => (p.id === post.id ? { ...p, reactions: r.reactions } : p)));
    } catch {
      setPosts((cur) => (cur ?? []).map((p) => (p.id === post.id ? { ...p, reactions: before } : p)));
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

  const pillTotal = (post: SocialPost): number => {
    const r = post.reactions ?? {};
    return (r.party?.count ?? 0) + (r.clap?.count ?? 0) + (r.angry?.count ?? 0);
  };

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
        {!ready && (
          <div className="flex justify-center py-10"><LogoActivityIndicator /></div>
        )}

        {/* The empty state - the friends invitation (founder screenshots,
            the real Duolingo "Add friends" face) ----------------------- */}
        {posts && posts.length === 0 && (
          <div className="learn-tile mt-4 flex flex-col items-center rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-10 text-center">
            <FeedEmptyArt />
            <p className="mt-4 max-w-xs text-[15.5px] font-extrabold leading-snug text-on-surface">
              <Link href="/profile/search" className="text-macaw hover:underline">Add friends</Link>
              {' '}to track and celebrate progress together!
            </p>
            <Link
              href="/profile/search"
              className="key-btn mt-5 w-full max-w-xs justify-center bg-macaw py-3 text-[13px] text-white"
            >
              FIND FRIENDS
            </Link>
          </div>
        )}

        {posts?.map((post) => {
          const isAnnouncement = post.kind === 'announcement';
          const meta = (post.meta ?? {}) as {
            streak?: number;
            league?: string;
            score?: number;
            exam?: string;
            label?: string;
            image?: string;
            ctaText?: string;
            ctaUrl?: string;
          };
          const author = post.author;
          const reactions = post.reactions ?? {};
          return (
            <article key={post.id} className="learn-tile mt-4 overflow-hidden rounded-2xl border-2 border-outline-variant bg-card">
              {/* ── Announcement artwork ─────────────────────────────── */}
              {isAnnouncement && meta.image && (
                <div
                  className="h-44 w-full bg-surface-container"
                  style={{
                    backgroundImage: meta.image.startsWith('http')
                      ? `url(${meta.image})`
                      : `url(${meta.image})`,
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                  }}
                  role="img"
                  aria-label="Announcement artwork"
                />
              )}

              <div className="flex items-center gap-3 px-4 pt-3">
                {author ? (
                  <Link
                    href={`/profile/view/?u=${encodeURIComponent(author.username)}`}
                    aria-label={`${author.name} on their profile`}
                    className="shrink-0"
                  >
                    <PersonAvatar
                      person={{ avatar: author.avatar, photo: author.photo, name: author.name, username: author.username }}
                      size={40}
                    />
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
                    <p className="text-[14.5px] font-extrabold text-on-surface">Renance</p>
                  )}
                  <p className="flex items-center gap-1.5 text-[11.5px] font-bold text-on-surface-variant">
                    {isAnnouncement && (
                      <span className="rounded-md bg-[#FFEFC3] px-1.5 py-0.5 text-[10px] font-black uppercase tracking-wider text-[#8a6d1a]">
                        Announcement
                      </span>
                    )}
                    {timeAgo(post.createdAtMs)}
                  </p>
                </div>
                {/* Founder directive (2026-10-17): follow straight from
                    the feed. Announcements are the platform's voice - no
                    follow chip there. */}
                {author && !isAnnouncement && (
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

              {/* ── Milestone artwork (the Duolingo badge art) ───────── */}
              {post.kind === 'milestone' && <MilestoneArt post={post} />}

              {/* Announcement CTA */}
              {isAnnouncement && meta.ctaText && meta.ctaUrl && (
                <div className="px-4 pb-3">
                  <a
                    href={meta.ctaUrl}
                    className="key-btn inline-flex bg-surface-container-high px-4 py-2.5 text-[12.5px] font-extrabold uppercase tracking-wide text-on-surface"
                  >
                    {meta.ctaText}
                  </a>
                </div>
              )}

              {/* ── The reaction row: CELEBRATE + pills (screenshots) ── */}
              {!isAnnouncement && (
                <div className="flex items-center gap-1.5 px-3 pb-1">
                  <button
                    type="button"
                    onClick={() => void react(post, 'party')}
                    disabled={busy === `react-${post.id}`}
                    aria-pressed={reactions.party?.mine ?? false}
                    className={`flex h-10 items-center gap-2 rounded-full border-2 px-4 text-[12.5px] font-extrabold uppercase tracking-wide transition active:translate-y-[1px] disabled:opacity-60 ${
                      reactions.party?.mine
                        ? 'border-primary bg-selection-blue text-primary-ink'
                        : 'border-outline-variant bg-card text-on-surface-variant hover:border-primary/50'
                    }`}
                  >
                    <span className="text-[16px]" aria-hidden>🎉</span>
                    Celebrate
                  </button>
                  <ReactionPill post={post} kind="clap" emoji="👏" onReact={react} busy={busy === `react-${post.id}`} />
                  <ReactionPill post={post} kind="angry" emoji="😤" onReact={react} busy={busy === `react-${post.id}`} />
                  {pillTotal(post) > 0 && (
                    <span className="ml-auto pr-1.5 text-[12px] font-extrabold text-on-surface-variant">
                      {bigCount(pillTotal(post))}
                    </span>
                  )}
                </div>
              )}

              {/* ── The like row + liked-by line (screenshots) ───────── */}
              <div className="flex items-center gap-1 border-t-2 border-outline-variant/40 px-2 py-1.5">
                <button
                  type="button"
                  onClick={() => void like(post)}
                  disabled={busy === `like-${post.id}`}
                  aria-pressed={post.likedByMe}
                  className={`flex items-center gap-1.5 rounded-full border-2 px-3.5 py-1.5 text-[12.5px] font-extrabold transition active:translate-y-[1px] disabled:opacity-60 ${
                    post.likedByMe
                      ? 'border-error/40 bg-error-container text-error'
                      : 'border-outline-variant/60 bg-card text-on-surface-variant hover:border-error/30'
                  }`}
                >
                  <span className={`material-symbols-outlined text-[17px] ${post.likedByMe ? 'fill-current' : ''}`}>
                    {post.likedByMe ? 'favorite' : 'favorite_border'}
                  </span>
                  {post.likes > 0 ? bigCount(post.likes) : 'Love'}
                </button>
                <button
                  type="button"
                  onClick={() => void openComments(post)}
                  className="flex items-center gap-1.5 rounded-xl px-3 py-2 text-[12.5px] font-extrabold text-on-surface-variant transition hover:bg-surface-container active:translate-y-[1px]"
                >
                  <span className="material-symbols-outlined text-[19px]">chat_bubble</span>
                  {post.comments > 0 ? post.comments : 'Comment'}
                </button>
                <button
                  type="button"
                  onClick={() => void share(post)}
                  className="flex items-center gap-1.5 rounded-xl px-3 py-2 text-[12.5px] font-extrabold text-on-surface-variant transition hover:bg-surface-container active:translate-y-[1px]"
                >
                  <span className="material-symbols-outlined text-[19px]">ios_share</span>
                  Share
                </button>
              </div>
              {post.likes > 0 && post.likedBy && (
                <div className="flex items-center gap-1.5 px-4 pb-2.5 text-[11.5px] font-bold text-on-surface-variant">
                  <LikedByStack post={post} />
                  Liked by <span className="font-extrabold text-on-surface">{post.likedBy}</span>
                  {post.likes > 1 ? ' and others' : ''}
                </div>
              )}
              {commentsFor === post.id && (
                <div className="border-t-2 border-outline-variant/40 bg-surface-container-lowest px-4 py-3">
                  {comments.length === 0 && (
                    <p className="py-2 text-[12.5px] font-bold text-on-surface-variant">No comments yet - cheer them on.</p>
                  )}
                  {comments.map((c) => (
                    <div key={c.id} className="flex items-start gap-2.5 py-2">
                      <Link
                        href={`/profile/view/?u=${encodeURIComponent(c.author.username)}`}
                        className="shrink-0"
                      >
                        <PersonAvatar
                          person={{ avatar: c.author.avatar, photo: c.author.photo, name: c.author.name, username: c.author.username }}
                          size={32}
                        />
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

/** One circular reaction pill (clap/angry) with its count. */
function ReactionPill({
  post,
  kind,
  emoji,
  onReact,
  busy,
}: {
  post: SocialPost;
  kind: ReactionKind;
  emoji: string;
  onReact: (post: SocialPost, kind: ReactionKind) => void;
  busy: boolean;
}) {
  const state = post.reactions?.[kind];
  return (
    <button
      type="button"
      onClick={() => onReact(post, kind)}
      disabled={busy}
      aria-pressed={state?.mine ?? false}
      className={`flex h-10 items-center gap-1 rounded-full border-2 px-2.5 text-[15px] transition active:translate-y-[1px] disabled:opacity-60 ${
        state?.mine ? 'border-primary bg-selection-blue' : 'border-outline-variant bg-card hover:border-primary/50'
      }`}
      aria-label={`React ${kind}`}
    >
      <span aria-hidden>{emoji}</span>
      {(state?.count ?? 0) > 0 && (
        <span className="pr-0.5 text-[11.5px] font-extrabold text-on-surface-variant">{bigCount(state!.count)}</span>
      )}
    </button>
  );
}

/** Tiny stacked faces in front of the liked-by line. */
function LikedByStack({ post }: { post: SocialPost }) {
  const face = post.author;
  return (
    <span className="flex -space-x-1.5">
      {[0, 1].map((i) => (
        <span
          key={i}
          className="flex h-4.5 w-4.5 h-[18px] w-[18px] items-center justify-center overflow-hidden rounded-full border border-card bg-surface-container-high text-[9px] font-black text-on-surface"
        >
          {i === 0 && face ? (
            <PersonAvatar person={{ avatar: face.avatar, photo: face.photo, name: face.name }} size={18} />
          ) : (
            '…'
          )}
        </span>
      ))}
    </span>
  );
}

/**
 * MilestoneArt - the big badge art on a milestone story, matched to the
 * founder's screenshots: streaks wear the orange FLAME with the
 * scholar's face inside it, league promotions wear the GOLD MEDAL,
 * exam scores wear the blue target, everything else the green laurel.
 */
function MilestoneArt({ post }: { post: SocialPost }) {
  const meta = (post.meta ?? {}) as { streak?: number; league?: string; score?: number; exam?: string; top3?: boolean };
  const face = post.author;

  if (meta.streak) {
    return (
      <div className="flex justify-center pb-3">
        <div className="relative">
          {/* The flame */}
          <svg width="168" height="150" viewBox="0 0 168 150" aria-label={`${meta.streak} day streak flame`}>
            <defs>
              <linearGradient id="flameOuter" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#FFAB00" />
                <stop offset="100%" stopColor="#FF9600" />
              </linearGradient>
              <linearGradient id="flameInner" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#FFC800" />
                <stop offset="100%" stopColor="#FFAB00" />
              </linearGradient>
            </defs>
            <path
              d="M84 6 C96 30 128 42 128 82 C128 116 108 138 84 138 C60 138 40 116 40 82 C40 58 52 44 60 30 C66 44 74 48 78 44 C82 38 78 22 84 6 Z"
              fill="url(#flameOuter)"
            />
            <path
              d="M84 46 C92 62 108 70 108 92 C108 112 97 124 84 124 C71 124 60 112 60 92 C60 76 68 68 74 58 C78 66 84 68 86 62 C88 56 82 54 84 46 Z"
              fill="url(#flameInner)"
            />
          </svg>
          {/* The scholar's face inside the flame */}
          <div className="absolute left-1/2 top-[86px] -translate-x-1/2 -translate-y-1/2">
            <span className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-full border-[3px] border-white bg-surface-container-high text-[17px] font-black text-on-surface">
              <PersonAvatar person={{ avatar: face?.avatar, photo: face?.photo, name: face?.name }} size={46} />
            </span>
          </div>
          <span className="absolute left-1/2 top-1 -translate-x-1/2 rounded-full bg-white/90 px-2 py-0.5 font-mono text-[10px] font-black text-[#a05a00]">
            {meta.streak} days
          </span>
        </div>
      </div>
    );
  }

  if (meta.league) {
    return (
      <div className="flex justify-center pb-3">
        <div className="relative">
          <svg width="150" height="150" viewBox="0 0 150 150" aria-label={`${meta.league} league medal`}>
            <defs>
              <linearGradient id="medalGold" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#FFD84D" />
                <stop offset="100%" stopColor="#FFC800" />
              </linearGradient>
            </defs>
            <polygon points="52,4 75,44 98,4 98,52 52,52" fill="#2B70C9" />
            <polygon points="52,4 63,22 52,40 40,30" fill="#1B4F93" opacity="0.5" />
            <circle cx="75" cy="92" r="46" fill="url(#medalGold)" />
            <circle cx="75" cy="92" r="36" fill="#FFB020" />
            <text x="75" y="106" textAnchor="middle" fontSize="40" fontWeight="900" fill="#8a5800" fontFamily="inherit">1</text>
          </svg>
          <span className="absolute bottom-1 left-1/2 -translate-x-1/2 rounded-full bg-white/90 px-2 py-0.5 font-mono text-[10px] font-black text-[#a05a00]">
            {meta.league} League
          </span>
        </div>
      </div>
    );
  }

  if (meta.score != null && meta.exam) {
    return (
      <div className="flex justify-center pb-3">
        <div className="relative">
          <svg width="140" height="140" viewBox="0 0 140 140" aria-label={`${meta.exam} score target`}>
            <circle cx="70" cy="70" r="58" fill="#E5F4FF" />
            <circle cx="70" cy="70" r="46" fill="#84D8FF" />
            <circle cx="70" cy="70" r="32" fill="#1CB0F6" />
            <circle cx="70" cy="70" r="18" fill="#FFFFFF" />
            <circle cx="70" cy="70" r="8" fill="#1CB0F6" />
          </svg>
          <span className="absolute left-1/2 top-1/2 -translate-x-1/2 translate-y-[26px] rounded-full bg-white/90 px-2 py-0.5 font-mono text-[11px] font-black text-[#0b5e8f]">
            {meta.score} {meta.exam}
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="flex justify-center pb-3">
      <div className="relative">
        <svg width="130" height="130" viewBox="0 0 130 130" aria-label="Milestone badge">
          <circle cx="65" cy="65" r="52" fill="#D7FFB8" />
          <circle cx="65" cy="65" r="40" fill="#58CC02" />
          <path d="M65 38 L72 56 L92 56 L76 68 L82 88 L65 76 L48 88 L54 68 L38 56 L58 56 Z" fill="#FFFFFF" />
        </svg>
      </div>
    </div>
  );
}

/** The friends-shaped empty state illustration (pure SVG, no assets). */
function FeedEmptyArt() {
  return (
    <svg width="220" height="150" viewBox="0 0 220 150" aria-hidden>
      {/* the phone */}
      <rect x="70" y="10" width="80" height="130" rx="12" fill="#131F24" />
      <rect x="76" y="16" width="68" height="118" rx="8" fill="#FFFFFF" />
      <rect x="84" y="30" width="36" height="8" rx="4" fill="#E5E5E5" />
      <rect x="84" y="46" width="52" height="8" rx="4" fill="#E5E5E5" />
      <rect x="84" y="62" width="44" height="8" rx="4" fill="#E5E5E5" />
      {/* confetti dots */}
      <circle cx="60" cy="24" r="4" fill="#CE82FF" />
      <circle cx="164" cy="30" r="4" fill="#58CC02" />
      <circle cx="158" cy="118" r="4" fill="#FFC800" />
      <circle cx="52" cy="112" r="4" fill="#FF4B4B" />
      {/* character left: waving scholar */}
      <circle cx="42" cy="70" r="14" fill="#8D5524" />
      <path d="M28 66 Q34 52 46 56 Q56 60 54 68 Q48 62 40 62 Q32 62 28 66 Z" fill="#131F24" />
      <circle cx="38" cy="70" r="1.8" fill="#131F24" />
      <circle cx="47" cy="70" r="1.8" fill="#131F24" />
      <path d="M39 76 q4 3 8 0" stroke="#131F24" strokeWidth="1.6" fill="none" strokeLinecap="round" />
      <path d="M30 88 Q42 82 54 88 L54 118 Q42 124 30 118 Z" fill="#1CB0F6" />
      <path d="M52 92 L66 82" stroke="#8D5524" strokeWidth="6" strokeLinecap="round" />
      {/* character right: cheering scholar */}
      <circle cx="180" cy="76" r="14" fill="#F2C19B" />
      <path d="M166 74 Q168 58 182 60 Q194 62 194 74 Q188 66 178 66 Q170 66 166 74 Z" fill="#B23A2F" />
      <circle cx="176" cy="76" r="1.8" fill="#131F24" />
      <circle cx="185" cy="76" r="1.8" fill="#131F24" />
      <path d="M177 82 q4 4 8 0" stroke="#131F24" strokeWidth="1.6" fill="none" strokeLinecap="round" />
      <path d="M168 94 Q180 88 192 94 L192 122 Q180 128 168 122 Z" fill="#CE82FF" />
      <path d="M170 92 L158 80" stroke="#F2C19B" strokeWidth="6" strokeLinecap="round" />
      {/* hearts */}
      <path d="M206 52 c3-4 9-2 9 2 c0 3-4 6-9 9 c-5-3-9-6-9-9 c0-4 6-6 9-2 Z" fill="#FF4B4B" />
      <path d="M16 48 c2.4-3.2 7.2-1.6 7.2 1.6 c0 2.4-3.2 4.8-7.2 7.2 c-4-2.4-7.2-4.8-7.2-7.2 c0-3.2 4.8-4.8 7.2-1.6 Z" fill="#FF4B4B" />
    </svg>
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
