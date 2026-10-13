'use client';

/**
 * Courses — the Course tab of the merged learn module (founder
 * directive 2026-10-14). One client shell, three faces:
 *
 *   1. MY COURSES  — the student's own list with progress; a tap opens
 *      the path. Empty list → the selection face.
 *   2. SELECTION   — the catalog with CHECKBOXES: a new user marks all
 *      the courses they want in one pass (founder: "select and mark
 *      all the ones they want to add"), then saves; more can be added
 *      or removed here at any time.
 *   3. PATH        — the Supreme zig-zag ladder: units, chests, trophy
 *      reviews and the current topic node, opening LessonOverlay.
 *
 * THE CATALOG IS HARDCODED (founder directive 2026-10-14: "make sure
 * the courses list are hard coded and make sure it's working just like
 * supreme"). The 41 JAMB/WAEC/NECO subjects ride inside the bundle and
 * the 10,604-course tertiary tree is a static JSON asset — the list is
 * on screen the instant the tab opens, exactly like the Supreme
 * reference site, and a backend hiccup can never blank it again. The
 * API is only asked for the student's OWN list, and that list falls
 * back to the last cached copy on this device.
 *
 * NO level tag anywhere — the founder removed it from the courses list.
 */

import { useCallback, useEffect, useMemo, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LessonOverlay } from '@/components/learn/lesson-overlay';
import { ProgressBar } from '@/components/learn/bits';
import { getStoredUser } from '@/lib/session';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { withBase } from '@/lib/api';
import {
  CatalogItem, CoursePath, MyCourse, TopicNode, UnitNode,
  fetchCoursePath, fetchMyCourses, learnBodyFromExams,
  learnBodyLabel, setActiveCourse, setMyCourses,
} from '@/lib/learn';
import { secondaryCatalog } from '@/lib/learn-catalog-secondary';

type Face = 'list' | 'select' | 'path';

interface ProfileLite {
  profile?: { exams?: string[] } | null;
}

/** The device cache keys: the course list and focus survive outages. */
const MINE_CACHE_KEY = 'renance.mycourses.v1';
const BODY_CACHE_KEY = 'renance.learnBody.v1';

function cacheMine(courses: MyCourse[]) {
  try {
    window.localStorage.setItem(MINE_CACHE_KEY, JSON.stringify(courses));
  } catch {
    /* private mode: the cache is a bonus, never a requirement */
  }
}

function readCachedMine(): MyCourse[] | null {
  try {
    const raw = window.localStorage.getItem(MINE_CACHE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as MyCourse[];
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function cacheBody(body: string) {
  try {
    window.localStorage.setItem(BODY_CACHE_KEY, body);
  } catch {
    /* same: best effort */
  }
}

function readCachedBody(): string {
  try {
    return window.localStorage.getItem(BODY_CACHE_KEY) || 'jamb';
  } catch {
    return 'jamb';
  }
}

export default function CoursesPage() {
  const router = useRouter();
  const [face, setFace] = useState<Face>('list');
  const [body, setBody] = useState('jamb');
  const [mine, setMine] = useState<MyCourse[] | null>(null);
  const [path, setPath] = useState<CoursePath | null>(null);
  const [topic, setTopic] = useState<TopicNode | null>(null);
  const [reviewUnit, setReviewUnit] = useState<UnitNode | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState('');

  // Selection state — the catalog itself is HARDCODED, only the view
  // state (query, filter, page) is component state.
  const [tertiaryTree, setTertiaryTree] = useState<CatalogItem[] | null>(null);
  const [catQuery, setCatQuery] = useState('');
  const [faculty, setFaculty] = useState('All');
  const [catPage, setCatPage] = useState(1);
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [saving, setSaving] = useState(false);

  const boot = useCallback(async () => {
    setLoading(true);
    setNotice('');
    // Focus first: cached instantly, refined by /me when it answers.
    let nextBody = readCachedBody();
    try {
      const me = await api<ProfileLite>('/me');
      nextBody = learnBodyFromExams(me.profile?.exams);
      cacheBody(nextBody);
    } catch {
      /* offline: the cached focus keeps the right shelf showing */
    }
    setBody(nextBody);
    // The student's own list: API first, device cache as the net.
    try {
      const list = await fetchMyCourses();
      setMine(list.courses);
      cacheMine(list.courses);
      setFace(list.courses.length > 0 ? 'list' : 'select');
    } catch {
      const cached = readCachedMine();
      setMine(cached ?? []);
      setFace(cached && cached.length > 0 ? 'list' : 'select');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/courses');
      return;
    }
    void boot();
  }, [boot, router]);

  // ── The hardcoded catalog ────────────────────────────────────────────────
  // Secondary: in the bundle, zero fetch. Tertiary: one static JSON
  // pulled once when the tertiary shelf is first shown.
  const secondaryItems = useMemo<CatalogItem[]>(
    () =>
      secondaryCatalog(body).map((s) => ({
        id: s.id,
        title: s.title,
        faculty: 'Senior Secondary',
        institutionType: learnBodyLabel(body),
        body,
        topicCount: s.n,
        inList: false,
        learnerCount: 0,
      })),
    [body],
  );

  useEffect(() => {
    if (body !== 'tertiary' || tertiaryTree) return;
    let alive = true;
    fetch(withBase('/learn/tertiary-catalog.json'))
      .then((r) => r.json())
      .then((j: { courses: Array<{ i: string; t: string; f: string; y: string; n: number }> }) => {
        if (!alive) return;
        setTertiaryTree(
          j.courses.map((c) => ({
            id: c.i,
            title: c.t,
            faculty: c.f,
            institutionType: c.y,
            body: 'tertiary',
            topicCount: c.n,
            inList: false,
            learnerCount: 0,
          })),
        );
      })
      .catch(() => {
        if (alive) setTertiaryTree([]);
      });
    return () => {
      alive = false;
    };
  }, [body, tertiaryTree]);

  const faculties = useMemo(() => {
    if (!tertiaryTree) return [];
    const seen = new Set<string>();
    for (const c of tertiaryTree) if (c.faculty) seen.add(c.faculty);
    return Array.from(seen).sort();
  }, [tertiaryTree]);

  const filteredCatalog = useMemo(() => {
    const source = body === 'tertiary' ? tertiaryTree ?? [] : secondaryItems;
    const q = catQuery.trim().toLowerCase();
    return source.filter((c) => {
      if (body === 'tertiary' && faculty !== 'All' && c.faculty !== faculty) return false;
      if (!q) return true;
      return c.title.toLowerCase().includes(q) || c.id.toLowerCase().includes(q);
    });
  }, [body, tertiaryTree, secondaryItems, catQuery, faculty]);

  const PAGE = 24;
  const catTotal = filteredCatalog.length;
  const catalog = useMemo(() => filteredCatalog.slice(0, catPage * PAGE), [filteredCatalog, catPage]);

  useEffect(() => {
    setCatPage(1);
  }, [catQuery, faculty, body]);

  const openPath = useCallback(async (courseId: string) => {
    setLoading(true);
    setNotice('');
    try {
      await setActiveCourse(courseId);
      const p = await fetchCoursePath(courseId);
      setPath(p);
      setFace('path');
      window.scrollTo({ top: 0 });
    } catch {
      setNotice('Could not open that course just now — it will open once the connection is back.');
    } finally {
      setLoading(false);
    }
  }, []);

  const saveSelection = useCallback(async () => {
    setSaving(true);
    setNotice('');
    try {
      // Preserve the student's existing picks when managing; the
      // checkbox list only carries the NEW marks and removals happen
      // straight from the list face.
      const base = mine ? mine.map((m) => m.id) : [];
      const merged = Array.from(new Set([...base, ...Array.from(picked)]));
      const res = await setMyCourses(merged);
      setMine(res.courses);
      cacheMine(res.courses);
      setPicked(new Set());
      setFace('list');
    } catch {
      setNotice('Saving your picks failed — check your connection and save again.');
    } finally {
      setSaving(false);
    }
  }, [picked, mine]);

  const removeFromList = useCallback(
    async (courseId: string) => {
      if (!mine) return;
      const next = mine.filter((m) => m.id !== courseId).map((m) => m.id);
      try {
        const res = await setMyCourses(next);
        setMine(res.courses);
        cacheMine(res.courses);
      } catch {
        // Offline removal still sticks on the device and reconciles
        // the next time the list saves from a live connection.
        const cached = mine.filter((m) => m.id !== courseId);
        setMine(cached);
        cacheMine(cached);
        setNotice('Removed on this device — it syncs away next time you are online.');
      }
    },
    [mine],
  );

  const togglePick = (id: string) => {
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const afterLesson = useCallback(async () => {
    setTopic(null);
    if (path) {
      const p = await fetchCoursePath(path.id);
      setPath(p);
    }
  }, [path]);

  // ─── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <PageBar
        title={face === 'path' && path ? path.title : 'Course'}
        backHref="/dashboard"
        right={
          face === 'list' ? (
            <button
              type="button"
              onClick={() => { setFace('select'); setPicked(new Set()); }}
              className="rounded-xl border-2 border-outline-variant bg-card px-3 py-1.5 text-[12px] font-extrabold text-on-surface transition active:translate-y-[2px]"
            >
              {mine && mine.length > 0 ? 'Add / remove' : 'Choose courses'}
            </button>
          ) : face === 'select' ? (
            <button
              type="button"
              onClick={saveSelection}
              disabled={saving}
              className="key-btn bg-primary text-white"
            >
              {saving ? 'Saving…' : picked.size > 0 ? `Add ${picked.size}` : 'Done'}
            </button>
          ) : null
        }
      />

      <main className="mx-auto w-full max-w-3xl px-4 pb-28 pt-4">
        {notice && (
          <p className="mb-3 rounded-xl bg-surface-container px-4 py-2.5 text-[12.5px] font-bold text-on-surface-variant">
            {notice}
          </p>
        )}
        {loading && <SkeletonList />}

        {/* ── Face 1: my courses ── */}
        {!loading && face === 'list' && mine && (
          <div className="flex flex-col gap-3">
            {mine.length === 0 ? (
              <EmptyList onChoose={() => setFace('select')} />
            ) : (
              <>
                <p className="px-1 text-[12.5px] font-bold text-on-surface-variant">
                  Your course list — tap one to open its roadmap.
                </p>
                {mine.map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => void openPath(c.id)}
                    className="learn-tile w-full rounded-2xl border-2 border-outline-variant bg-card p-4 text-left transition hover:border-primary/40 active:translate-y-[2px]"
                  >
                    <div className="flex items-center gap-3">
                      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/15">
                        <span className="material-symbols-outlined text-[22px] text-primary-ink">menu_book</span>
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[15px] font-black text-on-surface">{c.title}</span>
                        <span className="mt-0.5 block text-[12px] font-bold text-on-surface-variant">
                          {learnBodyLabel(c.body)} · {c.completedTopics}/{c.topicCount} topics done
                        </span>
                        <span className="mt-1.5 block">
                          <ProgressBar value={c.topicCount ? (c.completedTopics / c.topicCount) * 100 : 0} />
                        </span>
                      </span>
                      <span className="material-symbols-outlined text-[20px] text-on-surface-variant">chevron_right</span>
                    </div>
                  </button>
                ))}
              </>
            )}
          </div>
        )}

        {/* ── Face 2: selection catalog (hardcoded) ── */}
        {!loading && face === 'select' && (
          <div className="flex flex-col gap-3">
            <div className="rounded-2xl border-2 border-primary/40 bg-primary/10 p-4">
              <h2 className="text-[15px] font-black text-on-surface">
                {mine && mine.length === 0 ? 'Mark every course you want to learn' : 'Add more courses'}
              </h2>
              <p className="mt-1 text-[12.5px] font-bold leading-snug text-on-surface-variant">
                {body === 'tertiary'
                  ? 'Your institution\'s full course tree is here — mark the ones on your current semester and add more any time.'
                  : `Every ${learnBodyLabel(body)} subject with real past questions on Renance is listed. Mark all the ones you offer.`}
              </p>
            </div>

            <div className="flex gap-2">
              <input
                value={catQuery}
                onChange={(e) => setCatQuery(e.target.value)}
                placeholder={body === 'tertiary' ? 'Search 10,000+ courses…' : `Search ${learnBodyLabel(body)} subjects…`}
                aria-label="Search courses"
                className="min-w-0 flex-1 rounded-xl border-2 border-outline-variant bg-card px-3.5 py-2.5 text-[14px] font-bold text-on-surface outline-none focus:border-primary"
              />
              {body === 'tertiary' && (
                <select
                  value={faculty}
                  onChange={(e) => setFaculty(e.target.value)}
                  aria-label="Faculty filter"
                  className="rounded-xl border-2 border-outline-variant bg-card px-2 py-2.5 text-[12.5px] font-extrabold text-on-surface"
                >
                  <option value="All">All faculties</option>
                  {faculties.map((f) => <option key={f} value={f}>{f}</option>)}
                </select>
              )}
            </div>

            <ul className="flex flex-col gap-2">
              {catalog.map((c) => {
                const inList = mine?.some((m) => m.id === c.id) ?? false;
                const checked = picked.has(c.id) || inList;
                return (
                  <li key={c.id}>
                    <button
                      type="button"
                      onClick={() => (inList ? void removeFromList(c.id) : togglePick(c.id))}
                      aria-pressed={checked}
                      className={`learn-tile flex w-full items-center gap-3 rounded-2xl border-2 p-3.5 text-left transition active:translate-y-[2px] ${
                        checked ? 'border-primary bg-primary/10' : 'border-outline-variant bg-card'
                      }`}
                    >
                      <span className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 transition ${
                        checked ? 'border-primary bg-primary text-white' : 'border-outline-variant bg-surface'
                      }`} aria-hidden>
                        {checked && <span className="material-symbols-outlined text-[16px]">check</span>}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[14.5px] font-extrabold text-on-surface">{c.title}</span>
                        <span className="block truncate text-[11.5px] font-bold text-on-surface-variant">
                          {body === 'tertiary' ? `${c.faculty || c.institutionType} · ` : ''}
                          {c.topicCount} topics
                          {inList ? ' · in your list' : ''}
                        </span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>

            {catalog.length < catTotal && (
              <button type="button" onClick={() => setCatPage(catPage + 1)} className="key-btn mx-auto bg-card text-on-surface">
                Load more ({catTotal - catalog.length} left)
              </button>
            )}
            {body === 'tertiary' && !tertiaryTree && (
              <p className="py-10 text-center text-[13px] font-bold text-on-surface-variant">
                Loading the course tree…
              </p>
            )}
            {catTotal === 0 && (body !== 'tertiary' || tertiaryTree) && (
              <p className="py-10 text-center text-[13px] font-bold text-on-surface-variant">
                Nothing matches “{catQuery}”.
              </p>
            )}
          </div>
        )}

        {/* ── Face 3: the path ── */}
        {!loading && face === 'path' && path && (
          <CoursePathView path={path} onOpenTopic={setTopic} onOpenReview={setReviewUnit} onBack={() => { setFace('list'); setPath(null); }} />
        )}
      </main>

      {topic && (
        <LessonOverlay topicId={topic.id} mode="lesson" onClose={() => setTopic(null)} onCompleted={afterLesson} />
      )}
      {reviewUnit && path && (
        <LessonOverlay mode="review" courseId={path.id} unit={reviewUnit.index} onClose={() => setReviewUnit(null)} onCompleted={afterLesson} />
      )}

      <BottomNav />
    </div>
  );
}

// ─── Path view ────────────────────────────────────────────────────────────

const ZIGZAG = ['ml-0', 'ml-14', 'ml-28', 'ml-14'];

function CoursePathView({
  path, onOpenTopic, onOpenReview, onBack,
}: {
  path: CoursePath;
  onOpenTopic: (t: TopicNode) => void;
  onOpenReview: (u: UnitNode) => void;
  onBack: () => void;
}) {
  const [chestToast, setChestToast] = useState('');
  const byUnit = useMemo(() => {
    const m = new Map<number, TopicNode[]>();
    for (const t of path.topics) {
      const arr = m.get(t.unit) ?? [];
      arr.push(t);
      m.set(t.unit, arr);
    }
    return m;
  }, [path.topics]);

  const openChest = async (u: UnitNode) => {
    try {
      const { openChest: post } = await import('@/lib/learn');
      const res = await post(`${path.id}#${u.index}`);
      setChestToast(`+${res.gems} gems from the chest!`);
      setTimeout(() => setChestToast(''), 2200);
    } catch {
      setChestToast('Chest already opened');
      setTimeout(() => setChestToast(''), 1600);
    }
  };

  return (
    <div className="flex flex-col gap-5">
      {chestToast && (
        <div className="learn-toast-shadow pointer-events-none fixed inset-x-0 top-16 z-[70] mx-auto w-fit rounded-xl bg-accent-amber px-4 py-2 text-[13px] font-extrabold text-white">
          {chestToast}
        </div>
      )}

      <header className="learn-tile rounded-2xl border-2 border-outline-variant bg-gradient-to-br from-primary to-[color-mix(in_srgb,var(--color-primary)_72%,#000)] p-4 text-white">
        <p className="text-[11px] font-black uppercase tracking-wide text-white/85">
          {learnBodyLabel(path.body)} · {path.department}
        </p>
        <h2 className="mt-0.5 text-[19px] font-black leading-tight">{path.title}</h2>
        <div className="mt-2.5 flex items-center gap-2">
          <ProgressBar value={path.completedPercent} tone="gold" />
          <span className="shrink-0 text-[12px] font-black">{path.completedPercent}%</span>
        </div>
        <button type="button" onClick={onBack} className="mt-3 rounded-xl border-2 border-white/60 bg-white/15 px-3 py-1.5 text-[12px] font-extrabold text-white transition active:translate-y-[2px]">
          Add / remove courses
        </button>
      </header>

      {path.units.map((u) => {
        const topics = byUnit.get(u.index) ?? [];
        const isChest = u.index === 1;
        return (
          <section key={u.index} className="flex flex-col">
            {/* Unit banner */}
            <div className="sticky top-12 z-10 -mx-1 rounded-xl border-2 border-primary/50 bg-primary px-3.5 py-2.5 text-white learn-tile">
              <div className="flex items-center justify-between gap-2">
                <p className="text-[13px] font-black">{u.name}</p>
                {isChest ? (
                  <button
                    type="button"
                    onClick={() => void openChest(u)}
                    disabled={u.chestOpened}
                    className="flex items-center gap-1 rounded-lg border-2 border-white/50 bg-white/20 px-2 py-1 text-[11px] font-extrabold text-white disabled:opacity-60"
                  >
                    <span className="material-symbols-outlined text-[15px]">{u.chestOpened ? 'inventory_2' : 'redeem'}</span>
                    {u.chestOpened ? 'Opened' : 'Open chest'}
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => u.reviewReady && onOpenReview(u)}
                    disabled={!u.reviewReady}
                    className="flex items-center gap-1 rounded-lg border-2 border-white/50 bg-white/20 px-2 py-1 text-[11px] font-extrabold text-white disabled:opacity-60"
                  >
                    <span className="material-symbols-outlined text-[15px]">emoji_events</span>
                    {u.reviewReady ? 'Review' : 'Locked'}
                  </button>
                )}
              </div>
            </div>

            {/* Zig-zag ladder */}
            <div className="mt-3 flex flex-col items-center gap-1">
              {topics.map((t, i) => (
                <PathNode key={t.id} topic={t} offset={ZIGZAG[i % ZIGZAG.length]} onOpen={() => onOpenTopic(t)} />
              ))}
            </div>
          </section>
        );
      })}
    </div>
  );
}

function PathNode({ topic, offset, onOpen }: { topic: TopicNode; offset: string; onOpen: () => void }) {
  const locked = topic.status === 'locked';
  const done = topic.status === 'completed';
  const current = topic.status === 'current';
  return (
    <div className={`flex flex-col items-center ${offset}`}>
      <button
        type="button"
        onClick={() => !locked && onOpen()}
        disabled={locked}
        aria-label={`${topic.title}${locked ? ' (locked)' : ''}`}
        className={`flex h-[76px] w-[76px] items-center justify-center rounded-full border-2 transition ${
          done
            ? 'bg-primary text-white learn-node-done'
            : current
              ? 'bg-accent-amber text-white learn-node-current'
              : 'border-outline-variant bg-surface-container-high text-on-surface-variant'
        } ${locked ? 'opacity-70' : 'active:translate-y-[3px] hover:brightness-105'}`}
      >
        <span className="material-symbols-outlined text-[30px]">
          {done ? 'star' : current ? 'school' : 'lock'}
        </span>
      </button>
      <p className={`mt-1 max-w-[190px] text-center text-[11.5px] font-extrabold leading-tight ${locked ? 'text-on-surface-variant' : 'text-on-surface'}`}>
        {topic.title}
      </p>
      {done && topic.bestScore >= 100 && (
        <p className="text-[10.5px] font-black uppercase text-primary-ink">Perfect!</p>
      )}
      {current && <p className="learn-bubble mt-0.5">Start</p>}
    </div>
  );
}

// ─── Empty + skeleton ─────────────────────────────────────────────────────

function EmptyList({ onChoose }: { onChoose: () => void }) {
  return (
    <div className="learn-tile flex flex-col items-center gap-3 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-12 text-center">
      <span className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/15">
        <span className="material-symbols-outlined text-[32px] text-primary-ink">menu_book</span>
      </span>
      <h2 className="text-[17px] font-black text-on-surface">Build your course list</h2>
      <p className="max-w-sm text-[13.5px] font-bold leading-snug text-on-surface-variant">
        Mark every course you want on your desk — each one becomes a long roadmap of topics, notes with real drawings, and your actual past questions.
      </p>
      <button type="button" onClick={onChoose} className="key-btn mt-1 bg-primary text-white">Choose courses</button>
    </div>
  );
}

function SkeletonList() {
  return (
    <div className="flex flex-col gap-3" aria-hidden>
      {[0, 1, 2].map((i) => (
        <div key={i} className="h-[76px] animate-pulse rounded-2xl bg-surface-container" />
      ))}
    </div>
  );
}
