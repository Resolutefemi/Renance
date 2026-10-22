'use client';

/**
 * lib/social.ts - the client for the Renance social layer (founder
 * directive 2026-10-14): the Duolingo-style feed of milestone + user
 * posts, likes, comments, the follow graph and the public profiles
 * every board opens. All calls ride the shared api() helper (Bearer
 * token, 401 bounce).
 */

import { api, API_BASE } from '@/lib/api';
import { getToken } from '@/lib/session';

// ─── Types (server contract, internal/social) ─────────────────────────────

export interface SocialAuthor {
  id: string;
  username: string;
  name: string;
  premium: boolean;
  avatar?: string;
  /** R2 key under the profile-picture/ folder - renders through
   *  photoUrl() and wins over the avatar key whenever set. */
  photo?: string;
}

/** The public URL of one of the 50 baked-in avatars. */
export function avatarUrl(key?: string): string | null {
  return key ? `/avatars/${key}.svg` : null;
}

/** The public URL of an uploaded profile photo (the R2
 *  profile-picture/ folder, founder 2026-10-22). */
export function photoUrl(key?: string): string | null {
  return key ? `${API_BASE}/media/profile-picture/${key}` : null;
}

/** The best face for one person: their photo, else their avatar, else
 *  null (the caller renders the initial letter). */
export function faceUrl(person: { avatar?: string; photo?: string }): string | null {
  return photoUrl(person.photo) ?? avatarUrl(person.avatar);
}

/** One reaction pill's aggregated state on a post. */
export interface ReactionState {
  count: number;
  mine: boolean;
}

export type ReactionKind = 'party' | 'clap' | 'angry';

export interface SocialPost {
  id: number;
  author: SocialAuthor;
  kind: 'user' | 'milestone' | string;
  body: string;
  meta?: {
    streak?: number;
    league?: string;
    score?: number;
    exam?: string;
    matchId?: string;
    body?: string;
    [k: string]: unknown;
  } | null;
  likes: number;
  comments: number;
  likedByMe: boolean;
  /** One real liker's name for the "Liked by {name} and others" line. */
  likedBy?: string;
  mine: boolean;
  createdAtMs: number;
  /** The CELEBRATE pill row (founder 2026-10-22): {party:{count,mine},
   *  clap:…, angry:…}. Missing kinds carry zero reactions. */
  reactions?: Record<string, ReactionState>;
}

export interface SocialComment {
  id: number;
  author: SocialAuthor;
  body: string;
  mine: boolean;
  createdAtMs: number;
}

export interface CoursePulse {
  title: string;
  body: string;
  topics: number;
  done: number;
  percent: number;
}

export interface PublicProfile {
  id: string;
  username: string;
  name: string;
  premium: boolean;
  avatar?: string;
  photo?: string;
  level: number;
  xp: number;
  streak: number;
  league: string;
  topicsDone: number;
  perfectCount: number;
  followers: number;
  following: number;
  isFollowing: boolean;
  /** They already follow the viewer - the button reads "Follow back". */
  followsYou?: boolean;
  isSelf: boolean;
  joinedMs: number;
  courses: CoursePulse[] | null;
  /** The scholar's school + grade level (founder 2026-10-22: the
   *  profile wears the whole identity, school included). */
  institution?: string;
  gradeLevel?: string;
}

export interface FollowRow {
  id: string;
  username: string;
  name: string;
  premium: boolean;
  avatar?: string;
  photo?: string;
  followsYou: boolean;
  following: boolean;
}

export interface Connections {
  followers: FollowRow[];
  following: FollowRow[];
}

// ─── Endpoints ────────────────────────────────────────────────────────────

export async function fetchFeed(before = 0, limit = 25): Promise<{ posts: SocialPost[] }> {
  return api(`/social/feed?before=${before}&limit=${limit}`);
}

export async function createPost(body: string): Promise<{ id: number }> {
  return api('/social/feed', { method: 'POST', body: { body } });
}

export async function deletePost(id: number): Promise<void> {
  await api(`/social/posts/${id}`, { method: 'DELETE' });
}

export async function toggleLike(id: number): Promise<{ likes: number; liked: boolean }> {
  return api(`/social/posts/${id}/like`, { method: 'POST' });
}

export async function fetchComments(id: number): Promise<{ comments: SocialComment[] }> {
  return api(`/social/posts/${id}/comments`);
}

export async function addComment(id: number, body: string): Promise<{ comments: SocialComment[] }> {
  return api(`/social/posts/${id}/comments`, { method: 'POST', body: { body } });
}

export async function toggleFollow(username: string): Promise<{ following: boolean }> {
  return api(`/social/users/${encodeURIComponent(username)}/follow`, { method: 'POST' });
}

export async function fetchPublicProfile(
  username: string,
): Promise<{ profile: PublicProfile; posts: SocialPost[] }> {
  return api(`/social/users/${encodeURIComponent(username)}`);
}

export async function fetchConnections(): Promise<Connections> {
  return api('/social/connections');
}

/** Find scholars by username OR display name (the find-friends box). */
export async function fetchUserSearch(q: string, limit = 20): Promise<{ users: FollowRow[] }> {
  return api(`/social/search?q=${encodeURIComponent(q)}&limit=${limit}`);
}

/** The profile page's Friend suggestions strip (follow-backs first). */
export async function fetchSuggestions(limit = 10): Promise<{ users: FollowRow[] }> {
  return api(`/social/suggestions?limit=${limit}`);
}

/** Toggle one reaction pill; the response carries the post's full
 *  pill summary so the row repaints from one payload. */
export async function toggleReaction(
  id: number,
  kind: ReactionKind,
): Promise<{ reactions: Record<string, ReactionState> }> {
  return api(`/social/posts/${id}/react`, { method: 'POST', body: { kind } });
}

/** Upload the caller's profile photo to R2 (the profile-picture/
 *  folder). Multipart, so it rides fetch directly with the Bearer
 *  token; the response's avatarPhoto key renders through photoUrl(). */
export async function uploadAvatarPhoto(file: File): Promise<{ avatarPhoto: string }> {
  const token = getToken();
  const form = new FormData();
  form.append('file', file);
  const res = await fetch(`${API_BASE}/me/avatar/photo`, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    body: form,
  });
  const data = (await res.json().catch(() => ({}))) as {
    avatarPhoto?: string;
    message?: string;
  };
  if (!res.ok || !data.avatarPhoto) {
    throw new Error(data.message || 'Could not upload the photo');
  }
  return { avatarPhoto: data.avatarPhoto };
}

/** Clear the uploaded photo (falls back to the avatar key). */
export async function deleteAvatarPhoto(): Promise<void> {
  await api('/me/avatar/photo', { method: 'DELETE' });
}

// ─── Local helpers ────────────────────────────────────────────────────────

/** "2h", "3d", "just now" - the feed's relative clock. */
export function timeAgo(ms: number): string {
  const s = Math.max(1, Math.floor((Date.now() - ms) / 1000));
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d`;
  const w = Math.floor(d / 7);
  if (w < 5) return `${w}w`;
  return new Date(ms).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

/** The milestone glyph + tint per meta shape (the card's left rail). */
export function milestoneVisual(post: SocialPost): { icon: string; tint: string; label: string } {
  const meta = post.meta ?? {};
  if (meta.streak) return { icon: 'local_fire_department', tint: '#ff9600', label: 'Streak' };
  if (meta.league) return { icon: 'trophy', tint: '#ce82ff', label: `${meta.league} League` };
  if (meta.score != null && meta.exam) return { icon: 'target', tint: '#1cb0f6', label: `${meta.exam} score` };
  if (meta.matchId) return { icon: 'swords', tint: '#ff4b4b', label: 'Arena' };
  return { icon: 'military_tech', tint: '#10da11', label: 'Milestone' };
}

/** Humanize a big reaction/like count the way the Duolingo feed does:
 *  136949 -> "136.9k" under a million, 1.2M above it. */
export function bigCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 100_000) return `${Math.round(n / 1000)}k`;
  if (n >= 10_000) return `${(n / 1000).toFixed(1)}k`;
  return n.toLocaleString();
}
