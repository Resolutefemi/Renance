'use client';

/**
 * lib/social.ts - the client for the Renance social layer (founder
 * directive 2026-10-14): the Duolingo-style feed of milestone + user
 * posts, likes, comments, the follow graph and the public profiles
 * every board opens. All calls ride the shared api() helper (Bearer
 * token, 401 bounce).
 */

import { api } from '@/lib/api';

// ─── Types (server contract, internal/social) ─────────────────────────────

export interface SocialAuthor {
  id: string;
  username: string;
  name: string;
  premium: boolean;
  avatar?: string;
}

/** The public URL of one of the 50 baked-in avatars. */
export function avatarUrl(key?: string): string | null {
  return key ? `/avatars/${key}.svg` : null;
}

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
  mine: boolean;
  createdAtMs: number;
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
}

export interface FollowRow {
  id: string;
  username: string;
  name: string;
  premium: boolean;
  avatar?: string;
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
