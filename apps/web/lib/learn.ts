'use client';

/**
 * lib/learn.ts - the client for the merged Supreme learn module
 * (founder directive 2026-10-14): gamified course paths, quests, shop,
 * league and hearts/gems economy, all served by the study-api's
 * /learn/* routes on the REAL Renance account. Every call rides the
 * shared api() helper (Bearer token, 401 bounce).
 */

import { api, ApiError } from '@/lib/api';

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
  institutionType: string;
  department: string;
  departmentName: string;
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
  /** The REAL heart count - the ∞ readout is retired (founder rule). */
  hearts: number;
  items: ShopItem[];
  superTrial: ShopItem;
}

export interface LeagueEntry {
  name: string;
  xp: number;
  color: string;
  isYou: boolean;
  /** Set on REAL members - every board row is a real account now, and
 *  links to /u/{username}. */
  username?: string;
  isReal: boolean;
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
  return api<LearnProfile>('/learn/profile', { method: 'PATCH', body });
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

// ─── The course desk (founder directive 2026-10-14: institution kind
// ─── gate, then department gate, general-first shelves, search, AI) ──────

export interface DeskCourse {
  id: string;
  code: string; // short dept code badge, no numbers
  title: string;
  department: string;
  topicCount: number;
  inList: boolean;
}

export interface DeskShelves {
  institutionType: string;
  department: string;
  departmentName: string;
  general: DeskCourse[];
  departmental: DeskCourse[];
}

export interface DeskDepartment {
  id: string;
  faculty: string;
  name: string;
  focus: string;
  courseCount: number;
}

export interface AIMatchLine {
  input: string;
  matches: DeskCourse[];
  picked?: string;
}

/** The institution-kind gate options (matches learn.departments.itype). */
export const DESK_INSTITUTIONS = ['University', 'Polytechnic', 'College of Education'] as const;

/** The student's saved desk (from the learn profile). */
export function fetchDeskProfile(): Promise<Pick<LearnProfile, 'institutionType' | 'department' | 'departmentName'>> {
  return api('/learn/profile');
}

/** Save the institution kind + department (real rows in learn.learners). */
export function saveDesk(institutionType: string, department: string): Promise<LearnProfile> {
  // The desk save is a full upsert of two columns: re-issuing it after
  // a cold-start timeout lands the same state, and the founder's
  // "not saved, try again" on every first pick was exactly this
  // mutation dying mid-wake-up.
  return api('/learn/profile', {
    method: 'PATCH',
    body: { setDesk: true, institutionType, department },
    idempotentRetry: true,
  });
}

/** Categorise a failed desk save the way the founder asked
 * (2026-10-15, "Could not save that - check your connection" even
 * while online): a server ANSWER (400/409/500…) surfaces the server's
 * own reason - e.g. "department does not belong to that institution
 * kind" - so the student gets an actionable message instead of a
 * false connection blame; only a genuine network failure / timeout
 * (status 0) keeps the connection wording. A 401 has already bounced
 * the session to /login inside api(), so it never reaches here as a
 * save error in practice. */
export function deskSaveError(err: unknown, fallback: string): string {
  if (err instanceof ApiError) {
    if (err.status === 0) {
      return 'The study service did not answer in time - tap your pick again.';
    }
    if (err.status === 401) {
      return 'Your session expired - sign in again and re-pick your department.';
    }
    const serverMsg = err.message || '';
    if (err.status >= 400 && err.status < 500 && serverMsg && !serverMsg.startsWith('Request failed')) {
      return `Could not save that: ${serverMsg}`;
    }
    return `Could not save that - the server answered ${err.status}. Please try again.`;
  }
  return fallback;
}

/** Departments of one institution kind, from the seeded curriculum. */
export function fetchDepartments(itype: string): Promise<{ departments: DeskDepartment[] }> {
  return api(`/learn/departments?itype=${encodeURIComponent(itype)}`);
}

/** The tertiary shelves: national general courses first, then the department. */
export function fetchCourseDesk(): Promise<DeskShelves> {
  return api('/learn/course-desk');
}

/** The rest of the catalogue: every tertiary course outside the
 *  student's department that is not on the general shelf - schools
 *  borrow courses across departments (founder directive 2026-10-15:
 *  "add the remaining 10,000 to the list"). One page at a time; the
 *  desk pagers through with Show-more. */
export function fetchDeskOthers(offset: number, limit = 100): Promise<{ items: DeskCourse[]; total: number }> {
  return api(`/learn/course-desk/others?offset=${offset}&limit=${limit}`);
}

/** Code / title / key-topic search over the tertiary tree. */
export function searchDeskCourses(q: string): Promise<{ items: DeskCourse[] }> {
  return api(`/learn/search?q=${encodeURIComponent(q)}`);
}

/** AI course finder: paste the registration slip, get grounded matches. */
export function aiMatchCourses(text: string): Promise<{ lines: AIMatchLine[] }> {
  return api('/learn/ai-match', { method: 'POST', body: { text } });
}

export async function setMyCourses(courseIds: string[]): Promise<{ courses: MyCourse[] }> {
  return api<{ courses: MyCourse[] }>('/learn/my-courses', {
    method: 'POST',
    body: { courseIds },
  });
}

export async function setActiveCourse(courseId: string): Promise<void> {
  await api('/learn/active-course', { method: 'POST', body: { courseId } });
}

export async function fetchCoursePath(courseId: string): Promise<CoursePath> {
  return api<CoursePath>(`/learn/courses/${encodeURIComponent(courseId)}`);
}

export async function fetchLesson(topicId: string, wait = true): Promise<LessonDoc> {
  // Lesson polling (founder report 2026-10-14: "the notes and questions
  // is not loading"): a first-open lesson is generated server-side (AI
  // notes + real past questions), which takes longer than one honest
  // request should stay open - the backend now answers 202
  // {status:"generating"} while a detached generator finishes, so this
  // client polls until the real doc arrives. The shared api() 12s guard
  // stays useful: every individual poll is a short request. `wait` is
  // kept for signature compatibility; the poll loop is strictly better
  // than holding one request open.
  void wait;
  const deadline = Date.now() + 110_000;
  for (;;) {
    const doc = await api<LessonDoc & { status?: string }>(
      `/learn/topics/${encodeURIComponent(topicId)}/content`,
    );
    if (!doc || (doc as { status?: string }).status !== 'generating') {
      return doc as LessonDoc;
    }
    if (Date.now() > deadline) {
      throw new Error('This lesson is still being written - hang on a moment.');
    }
    await new Promise((r) => setTimeout(r, 3000));
  }
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
  return api<CompleteResult>('/learn/progress', { method: 'POST', body });
}

export async function fetchQuests(): Promise<QuestsResponse> {
  return api<QuestsResponse>('/learn/quests');
}

export async function claimQuest(questKey: string): Promise<{ gems: number }> {
  // PK-guarded server side (quest_claims): a retry after a lost
  // connection re-answers "already claimed", never double-pays.
  return api<{ gems: number }>('/learn/quests', { method: 'POST', body: { questKey }, idempotentRetry: true });
}

export async function fetchShop(): Promise<ShopResponse> {
  return api<ShopResponse>('/learn/shop');
}

export async function buyShopItem(item: string): Promise<ShopResponse> {
  // The wallet re-validates on every apply (stash full / already
  // running / not enough gems), so a cold-start retry cannot
  // double-spend gems.
  return api<ShopResponse>('/learn/shop', { method: 'POST', body: { item }, idempotentRetry: true });
}

export async function fetchLeague(): Promise<LeagueBoard> {
  return api<LeagueBoard>('/learn/leaderboard');
}

export async function openChest(chestKey: string): Promise<{ chestKey: string; gems: number; gemsTotal: number }> {
  // chest_opens is keyed per (user, chestKey): the retry either lands
  // fresh or answers "already opened", never double-pays.
  return api(`/learn/chests`, { method: 'POST', body: { chestKey }, idempotentRetry: true });
}

export async function fetchPractice(): Promise<{ questions: PracticeQuestion[] }> {
  return api('/learn/practice');
}

export async function gradePractice(body: {
  correct: number; total: number; resolvedIds: string[];
}): Promise<CompleteResult> {
  return api('/learn/practice', { method: 'POST', body });
}

export async function fetchReview(courseId: string, unit: number): Promise<{ questions: PracticeQuestion[] }> {
  return api(`/learn/review?courseId=${encodeURIComponent(courseId)}&unit=${unit}`);
}

// ─── Local helpers ────────────────────────────────────────────────────────

/** Focus desk for the course tab: jamb | waec | neco | tertiary.
 * Founder directive 2026-10-14: the JAMB/WAEC/NECO subjects appear ONLY
 * on their own desks, and Post-UTME prep belongs to the tertiary
 * institution desk (its courses are the institutions' own), so the
 * desk never resolves to 'post-utme'. */
export function learnBodyFromExams(exams: string[] | undefined): string {
  const first = (exams && exams[0] ? exams[0] : '').toLowerCase();
  if (first.includes('university')) return 'tertiary';
  if (first.includes('post-utme') || first.includes('post utme')) return 'tertiary';
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
    case 'tertiary': return 'Tertiary Institution';
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
