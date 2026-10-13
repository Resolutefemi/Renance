'use client';

/**
 * lib/learn.ts — the client for the merged Supreme learn module
 * (founder directive 2026-10-14): gamified course paths, quests, shop,
 * league and hearts/gems economy, all served by the study-api's
 * /learn/* routes on the REAL Renance account. Every call rides the
 * shared api() helper (Bearer token, 401 bounce).
 */

import { api } from '@/lib/api';

// ─── Types (server contract, internal/learn) ──────────────────────────────

export interface LearnProfile {
  hearts: number;
  unlimitedHearts: boolean;
  nextHeartInMs: number | null;
  gems: number;
  xp: number;
  streak: number;
  dailyGoal: number;
  todayXp: number;
  superActive: boolean;
  boostActive: boolean;
  freezeCount: number;
  league: string;
  courseCount: number;
  topicsDone: number;
  perfectCount: number;
}

export interface CatalogItem {
  id: string;
  title: string;
  faculty: string;
  institutionType: string;
  body: string;
  topicCount: number;
  inList: boolean;
  learnerCount: number;
}

export interface MyCourse {
  id: string;
  title: string;
  body: string;
  topicCount: number;
  completedTopics: number;
  bestScoreSum: number;
  active: boolean;
}

export interface TopicNode {
  id: string;
  title: string;
  category: string;
  orderIndex: number;
  unit: number;
  status: 'completed' | 'current' | 'locked';
  bestScore: number;
}

export interface UnitNode {
  index: number;
  name: string;
  from: number;
  to: number;
  hasChest: boolean;
  chestOpened: boolean;
  reviewReady: boolean;
}

export interface CoursePath {
  id: string;
  title: string;
  body: string;
  institutionType: string;
  faculty: string;
  department: string;
  topics: TopicNode[];
  units: UnitNode[];
  completedPercent: number;
}

export interface LearnNote {
  heading: string;
  body: string;
  image?: string;
  imageAlt?: string;
}

export interface LearnQuizQ {
  id: string;
  type: 'mcq' | 'true_false' | 'fill_blank' | 'word_bank' | 'match_pairs' | 'order_steps' | 'listen_type';
  stem: string;
  options?: Record<string, string>;
  answer: string;
  explanation?: string;
  year?: number;
  fromBank?: boolean;
}

export interface LearnDrawing {
  id: string;
  title: string;
  svg: string;
}

export interface LessonDoc {
  topicId: string;
  courseId: string;
  course: string;
  title: string;
  summary: string;
  notes: LearnNote[];
  keyPoints: string[];
  quiz: LearnQuizQ[];
  drawings: LearnDrawing[];
  source: string;
  cached: boolean;
}

export interface QuestDef {
  key: string;
  title: string;
  target: number;
  gems: number;
  kind: string;
  icon: string;
  period: string;
  progress: number;
  claimed: boolean;
  complete: boolean;
}

export interface QuestsResponse {
  daily: QuestDef[];
  weekly: QuestDef;
  monthly: QuestDef;
}

export interface ShopItem {
  key: string;
  title: string;
  desc: string;
  gems: number;
  icon: string;
  owned: number;
  max: number;
  soldOut: boolean;
}

export interface ShopResponse {
  gems: number;
  items: ShopItem[];
  superTrial: ShopItem;
}

export interface LeagueEntry {
  name: string;
  xp: number;
  color: string;
  isYou: boolean;
}

export interface LeagueBoard {
  league: string;
  leagueIndex: number;
  entries: LeagueEntry[];
  endsInMs: number;
  promotedCut: number;
  demotedFrom: number;
  promotedLastWeek: boolean;
  demotedLastWeek: boolean;
  yourRank: number;
}

export interface CompleteResult {
  xpEarned: number;
  gemsEarned: number;
  perfect: boolean;
  firstClear: boolean;
  comboBonus: number;
  boosted: boolean;
  streak: number;
  hearts: number;
  unlimitedHearts: boolean;
  gems: number;
  xp: number;
  completedPercent: number;
}

export interface PracticeQuestion {
  id: string;
  type: LearnQuizQ['type'];
  stem: string;
  options?: Record<string, string>;
  answer: string;
  explanation?: string;
  topicId?: string;
}

// ─── Endpoints ────────────────────────────────────────────────────────────

export async function fetchLearnProfile(): Promise<LearnProfile> {
  return api<LearnProfile>('/learn/profile');
}

export async function patchLearnProfile(body: { dailyGoal?: number }): Promise<LearnProfile> {
  return api<LearnProfile>('/learn/profile', { method: 'PATCH', body: JSON.stringify(body) });
}

export async function resetLearnProgress(): Promise<void> {
  await api<{ ok: boolean }>('/learn/profile', { method: 'DELETE' });
}

export async function fetchCatalog(params: {
  body?: string; q?: string; faculty?: string; itype?: string; page?: number; pageSize?: number;
}): Promise<{ items: CatalogItem[]; total: number }> {
  const sp = new URLSearchParams();
  if (params.body) sp.set('body', params.body);
  if (params.q) sp.set('q', params.q);
  if (params.faculty) sp.set('faculty', params.faculty);
  if (params.itype) sp.set('itype', params.itype);
  sp.set('page', String(params.page ?? 1));
  sp.set('pageSize', String(params.pageSize ?? 24));
  return api(`/learn/catalog?${sp.toString()}`);
}

export async function fetchMyCourses(): Promise<{ courses: MyCourse[] }> {
  return api<{ courses: MyCourse[] }>('/learn/my-courses');
}

export async function setMyCourses(courseIds: string[]): Promise<{ courses: MyCourse[] }> {
  return api<{ courses: MyCourse[] }>('/learn/my-courses', {
    method: 'POST',
    body: JSON.stringify({ courseIds }),
  });
}

export async function setActiveCourse(courseId: string): Promise<void> {
  await api('/learn/active-course', { method: 'POST', body: JSON.stringify({ courseId }) });
}

export async function fetchCoursePath(courseId: string): Promise<CoursePath> {
  return api<CoursePath>(`/learn/courses/${encodeURIComponent(courseId)}`);
}

export async function fetchLesson(topicId: string, wait = true): Promise<LessonDoc> {
  return api<LessonDoc>(`/learn/topics/${encodeURIComponent(topicId)}/content${wait ? '?wait=1' : ''}`);
}

export async function postProgress(body: {
  topicId: string;
  correct: number;
  total: number;
  maxCombo: number;
  mistakes: Array<{
    id: string; stem: string; type: string; options?: Record<string, string>;
    answer: string; explanation?: string; userAnswer?: unknown; year?: number;
  }>;
  abandoned: boolean;
}): Promise<CompleteResult> {
  return api<CompleteResult>('/learn/progress', { method: 'POST', body: JSON.stringify(body) });
}

export async function fetchQuests(): Promise<QuestsResponse> {
  return api<QuestsResponse>('/learn/quests');
}

export async function claimQuest(questKey: string): Promise<{ gems: number }> {
  return api<{ gems: number }>('/learn/quests', { method: 'POST', body: JSON.stringify({ questKey }) });
}

export async function fetchShop(): Promise<ShopResponse> {
  return api<ShopResponse>('/learn/shop');
}

export async function buyShopItem(item: string): Promise<ShopResponse> {
  return api<ShopResponse>('/learn/shop', { method: 'POST', body: JSON.stringify({ item }) });
}

export async function fetchLeague(): Promise<LeagueBoard> {
  return api<LeagueBoard>('/learn/leaderboard');
}

export async function openChest(chestKey: string): Promise<{ chestKey: string; gems: number; gemsTotal: number }> {
  return api(`/learn/chests`, { method: 'POST', body: JSON.stringify({ chestKey }) });
}

export async function fetchPractice(): Promise<{ questions: PracticeQuestion[] }> {
  return api('/learn/practice');
}

export async function gradePractice(body: {
  correct: number; total: number; resolvedIds: string[];
}): Promise<CompleteResult> {
  return api('/learn/practice', { method: 'POST', body: JSON.stringify(body) });
}

export async function fetchReview(courseId: string, unit: number): Promise<{ questions: PracticeQuestion[] }> {
  return api(`/learn/review?courseId=${encodeURIComponent(courseId)}&unit=${unit}`);
}

// ─── Local helpers ────────────────────────────────────────────────────────

/** Focus body for the desk: jamb | waec | neco | post-utme | tertiary. */
export function learnBodyFromExams(exams: string[] | undefined): string {
  const first = (exams && exams[0] ? exams[0] : '').toLowerCase();
  if (first.includes('university')) return 'tertiary';
  if (first.includes('post-utme') || first.includes('post utme')) return 'post-utme';
  if (first.includes('waec')) return 'waec';
  if (first.includes('neco')) return 'neco';
  return 'jamb';
}

/** The exam-body label shown on course headers. */
export function learnBodyLabel(body: string): string {
  switch (body) {
    case 'jamb': return 'JAMB';
    case 'waec': return 'WAEC';
    case 'neco': return 'NECO';
    case 'post-utme': return 'Post-UTME';
    case 'tertiary': return 'University';
    default: return body;
  }
}

/** ms countdown → "2d 14h" style league reset chip. */
export function formatCountdown(ms: number): string {
  if (ms < 0) ms = 0;
  const h = Math.floor(ms / 3600000);
  const d = Math.floor(h / 24);
  if (d > 0) return `${d}d ${h % 24}h`;
  const m = Math.floor((ms % 3600000) / 60000);
  return `${h}h ${m}m`;
}
