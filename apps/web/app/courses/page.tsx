'use client';

/**
 * Courses - the Course tab of the merged learn module (founder
 * directive 2026-10-14). One client shell, three faces:
 *
 *   1. MY COURSES  - the student's own list with progress; a tap opens
 *      the path. Empty list → the desk flow.
 *   2. SELECTION   - the hardcoded secondary catalog with CHECKBOXES
 *      (JAMB/WAEC/NECO subjects, client-side search).
 *   3. PATH        - the Supreme zig-zag ladder: units, chests, trophy
 *      reviews and the current topic node, opening LessonOverlay.
 *
 * THE TERTIARY DESK (founder directive 2026-10-14, third pass) asks
 * for the kind of tertiary institution FIRST, then the department
 * (the department list is driven by the institution kind and both are
 * saved to the database on the learner row), and only then shows the
 * course shelf: the national 100-level general courses (GST/GNS, the
 * general sciences and mathematics) FIRST, then the department's own
 * courses. Everything on the shelf is real data from the study-api's
 * seeded curriculum tables - no mock rows anywhere.
 *
 * SEARCH + AI (same directive): a search bar matches a course by its
 * short code (CSC, COS, MTH, MTS and friends - three letters, no
 * numbers), its title, or one of its key topics; and "Find my courses
 * with AI" reads a pasted course list, grounds every line in the real
 * catalogue and sets the course list up from the picks.
 *
 * DESK SEPARATION (founder 2026-10-15, switcher-removal pass): the
 * top desk-switcher pills are GONE. The page renders ONE desk - the
 * student's active focus body (JAMB/WAEC/NECO get the secondary
 * faces; the School/Tertiary focus gets the tertiary desk and ONLY
 * that focus ever sees it). Borrowed courses, the AI finder and the
 * manual checkboxes keep working as before.
 *
 * MARK/SELECT SPEED (same pass): the checkbox answer is OPTIMISTIC -
 * a tap flips the row on this frame from a ref-derived list and the
 * server save rides behind it; opening a course no longer waits on
 * the active-course marker write.
 *
 * NO level tag anywhere - the founder removed it from the courses list.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LessonOverlay } from '@/components/learn/lesson-overlay';
import { CourseRequestModal } from '@/components/learn/voice';
import { ProgressBar } from '@/components/learn/bits';
import { ChestOpening } from '@/components/learn/celebrations';
import { getStoredUser } from '@/lib/session';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import {
  CatalogItem, CoursePath, ChestDrop, MyCourse, TopicNode, UnitNode,
  DeskCourse, DeskDepartment, DeskShelves, AIMatchLine,
  fetchCourseDesk, fetchCoursePath, fetchDepartments, fetchDeskOthers, fetchMyCourses, learnBodyFromExams,
  learnBodyLabel, aiMatchCourses, saveDesk, searchDeskCourses,
  setActiveCourse, setMyCourses, deskSaveError,
} from '@/lib/learn';
import { JAMB_CATALOG } from '@/lib/learn-catalog-secondary';

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

/** The desk body as the student's focus spells it - jamb | waec | neco
 * | post-utme | tertiary. Founder directive 2026-10-21: the Post-UTME
 * desk now keeps its own body (it used to ride 'tertiary') so its
 * course SELECTION page lists the JAMB 300-topic subjects like the
 * other secondary desks. Only the tertiary/university desks stay on
 * the institution gate flow. */
function readCachedBody(): string {
  try {
    return window.localStorage.getItem(BODY_CACHE_KEY) || 'jamb';
  } catch {
    return 'jamb';
  }
}

/** Tertiary/institution rows (their body is stamped by the server from
 * the institution catalog) never show on a secondary desk. Every
 * secondary desk shares ONE JAMB subject catalog now, so a row saved
 * from any secondary desk shows on all of them - regardless of which
 * body the server stamped on it. */
function isTertiaryRow(c: MyCourse): boolean {
  const b = (c.body || '').toLowerCase();
  return b === 'tertiary' || b === 'university-modules' || b.includes('university');
}

export default function CoursesPage() {
  const router = useRouter();
  const [face, setFace] = useState<Face>('list');
  const [body, setBody] = useState('jamb');
  const [mine, setMine] = useState<MyCourse[] | null>(null);
  const [path, setPath] = useState<CoursePath | null>(null);
  const [topic, setTopic] = useState<TopicNode | null>(null);
  const [reviewUnit, setReviewUnit] = useState<UnitNode | null>(null);
  const [revisionUnit, setRevisionUnit] = useState<UnitNode | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState('');

  // Secondary selection state - the catalog itself is HARDCODED, only
  // the view state (query) is component state. The tertiary tree is
  // served by the API now (the desk flow below).
  const [secQuery, setSecQuery] = useState('');
  const [saving, setSaving] = useState(false);

  /** Single writer for the course list: state, the device cache and
   *  the tap-race ref move together. The optimistic toggle reads the
   *  REF (not the render snapshot), so rapid taps on several rows
   *  never stack onto a stale list. */
  const mineRef = useRef<MyCourse[] | null>(null);
  const applyMine = useCallback((rows: MyCourse[]) => {
    mineRef.current = rows;
    setMine(rows);
    cacheMine(rows);
  }, []);

  // The hardcoded secondary shelf for the selection face: the JAMB
  // 300-topic subjects on EVERY secondary desk (founder 2026-10-21).
  const secondaryItems = useMemo<CatalogItem[]>(() => {
    if (body === 'tertiary') return [];
    return JAMB_CATALOG.map((s) => ({
      id: s.id,
      title: s.title,
      faculty: 'Senior Secondary',
      institutionType: learnBodyLabel(body),
      body,
      topicCount: s.n,
      inList: false,
      learnerCount: 0,
    }));
  }, [body]);

  const filteredSecondary = useMemo(() => {
    const q = secQuery.trim().toLowerCase();
    if (!q) return secondaryItems;
    return secondaryItems.filter((c) =>
      c.title.toLowerCase().includes(q) || c.id.toLowerCase().includes(q),
    );
  }, [secondaryItems, secQuery]);

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
      applyMine(list.courses);
      setFace(list.courses.length > 0 ? 'list' : 'select');
    } catch {
      const cached = readCachedMine();
      applyMine(cached ?? []);
      setFace(cached && cached.length > 0 ? 'list' : 'select');
    } finally {
      setLoading(false);
    }
  }, [applyMine]);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/courses');
      return;
    }
    void boot();
  }, [boot, router]);

  const openPath = useCallback(async (courseId: string) => {
    setLoading(true);
    setNotice('');
    // The active-course marker rides in the BACKGROUND (founder
    // 2026-10-15: selecting a course felt slow) - it is bookkeeping,
    // not a prerequisite of the path read, and awaiting it cost a full
    // round trip before every roadmap opened.
    void setActiveCourse(courseId).catch(() => {});
    try {
      const p = await fetchCoursePath(courseId);
      setPath(p);
      setFace('path');
      window.scrollTo({ top: 0 });
    } catch {
      setNotice('Could not open that course just now - it will open once the connection is back.');
    } finally {
      setLoading(false);
    }
  }, []);

  /** Add/remove one course id on the real list - OPTIMISTIC (founder
   *  report 2026-10-15: "the reaction time when I mark or select a
   *  course is too slow"). The checkbox answers on the SAME frame as
   *  the tap: the next list is derived from the ref and applied at
   *  once, the server save rides behind it, and only a failed save
   *  rolls the row back. `hint` seeds the optimistic row so the new
   *  tertiary card shows its real title/topics before the canonical
   *  list returns. */
  const toggleCourse = useCallback(async (
    courseId: string,
    hint?: { title?: string; topicCount?: number },
  ) => {
    const cur = mineRef.current;
    if (!cur) return;
    const has = cur.some((m) => m.id === courseId);
    const next: MyCourse[] = has
      ? cur.filter((m) => m.id !== courseId)
      : [
          ...cur,
          {
            id: courseId,
            title: hint?.title || courseId,
            body,
            topicCount: hint?.topicCount ?? 0,
            completedTopics: 0,
            bestScoreSum: 0,
            active: false,
          },
        ];
    applyMine(next); // the tap answers NOW - no server round trip first
    try {
      const res = await setMyCourses(next.map((m) => m.id));
      applyMine(res.courses);
    } catch {
      applyMine(cur); // roll back to what the server last confirmed
      setNotice('That change did not stick - check your connection and try again.');
    }
  }, [applyMine, body]);

  /** Merge a batch of picks (the AI finder) into the real list.
   *  Returns whether the merge landed, so the AI panel only closes -
   *  and the shelf only re-seats - on a real save. */
  const addCourses = useCallback(async (ids: string[]): Promise<boolean> => {
    const cur = mineRef.current;
    if (!cur || ids.length === 0) return false;
    setSaving(true);
    try {
      const merged = Array.from(new Set([...cur.map((m) => m.id), ...ids]));
      const res = await setMyCourses(merged);
      applyMine(res.courses);
      return true;
    } catch {
      setNotice('Saving your courses failed - check your connection and try again.');
      return false;
    } finally {
      setSaving(false);
    }
  }, [applyMine]);

  const afterLesson = useCallback(async () => {
    setTopic(null);
    if (path) {
      const p = await fetchCoursePath(path.id);
      setPath(p);
    }
  }, [path]);

  /** The back key unwinds the page's OWN faces first (founder report
   *  2026-10-16: the top-left back button dumped students on the home
   *  page). Path → the course list; selection → the list; and only
   *  from the list face does it leave the page - real history back
   *  where one exists (the desk, the dashboard, wherever the student
   *  came from), /dashboard as the fresh-entry fallback. */
  const handleBack = useCallback(() => {
    if (face === 'path') {
      setTopic(null);
      setReviewUnit(null);
      setRevisionUnit(null);
      setPath(null);
      setFace('list');
      return;
    }
    if (face === 'select') {
      setFace('list');
      setSecQuery('');
      return;
    }
    const state = typeof window !== 'undefined' ? (window.history.state as { idx?: number } | null) : null;
    if (typeof window !== 'undefined' && window.history.length > 1 && (state?.idx ?? 0) > 0) {
      router.back();
      return;
    }
    router.push('/dashboard');
  }, [face, router]);

  // ─── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      {/* Founder directive 2026-10-15: the courses area carries NO
          top button / header anymore - the PageBar is a plain back +
          title bar (the Add-remove / Done pills that used to ride it
          are gone; the affordances live inline with the list they
          act on). */}
      <PageBar
        title={face === 'path' && path ? path.title : 'Course'}
        onBack={handleBack}
      />

      {/* pb clears the fixed BottomNav AND the device safe area: the
          path ladder's last rows (the lock node and its description,
          the unit revision card) must never sit behind the bar or the
          home indicator (founder report 2026-10-17). */}
      <main className="mx-auto w-full max-w-3xl px-4 pb-[calc(7rem+env(safe-area-inset-bottom))] pt-4">
        {notice && (
          <p className="mb-3 rounded-xl bg-surface-container px-4 py-2.5 text-[12.5px] font-bold text-on-surface-variant">
            {notice}
          </p>
        )}
        {loading && <SkeletonList />}

        {/* Founder directive 2026-10-15 (switcher-removal pass): the
            "JAMB desk / Tertiary Institution desk" toggle pills are
            GONE. The page renders exactly ONE desk - the student's
            active focus body - and the tertiary desk is reachable ONLY
            through that focus; no pill ever flips a secondary student
            onto the School desk or back. */}

        {/* ── The tertiary institution desk: the ONLY thing a School
            focus student sees (gates → shelf), at any face but path ── */}
        {!loading && body === 'tertiary' && mine && face !== 'path' && (
          <TertiaryDesk
            mine={mine}
            onOpen={(id) => void openPath(id)}
            onToggle={(id, hint) => void toggleCourse(id, hint)}
            onAdd={(ids) => addCourses(ids)}
            onNotice={setNotice}
          />
        )}

        {/* ── Face 1: my courses (secondary desks) ── */}
        {!loading && face === 'list' && body !== 'tertiary' && mine && (
          mine.length === 0 ? (
            <EmptyList onChoose={() => setFace('select')} />
          ) : (
            <div className="flex flex-col gap-3">
              <p className="px-1 text-[12.5px] font-bold text-on-surface-variant">
                Your {learnBodyLabel(body)} desk courses - tap one to open its roadmap.
              </p>
              {mine
                .filter((c) => !isTertiaryRow(c))
                .map((c) => (
                  <CourseCard key={c.id} c={c} onOpen={() => void openPath(c.id)} />
                ))}
              {mine.filter((c) => !isTertiaryRow(c)).length === 0 && (
                <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-8 text-center text-[13px] font-bold text-on-surface-variant">
                  No courses on this desk yet - tap Add / remove courses below.
                </p>
              )}
              {/* The inline add-remove affordance (founder 2026-10-15):
                  no top button - a quiet text link under the desk rows. */}
              <button
                type="button"
                onClick={() => { setFace('select'); setSecQuery(''); }}
                className="mx-auto rounded-xl px-4 py-2.5 text-[12.5px] font-extrabold text-primary-ink transition hover:bg-primary/10 active:translate-y-[1px]"
              >
                Add / remove courses
              </button>
            </div>
          )
        )}

        {/* ── Face 2: secondary selection catalog (hardcoded + search) ── */}
        {!loading && face === 'select' && body !== 'tertiary' && (
          <div className="flex flex-col gap-3">
            {/* Founder directive 2026-10-15: the big intro header card is
                gone - the catalog starts straight in with the search box. */}
            <input
              value={secQuery}
              onChange={(e) => setSecQuery(e.target.value)}
              placeholder={`Search ${learnBodyLabel(body)} subjects…`}
              aria-label="Search subjects"
              className="w-full rounded-xl border-2 border-outline-variant bg-card px-3.5 py-2.5 text-[14px] font-bold text-on-surface outline-none focus:border-primary"
            />

            <ul className="flex flex-col gap-2">
              {filteredSecondary.map((c) => {
                const inList = mine?.some((m) => m.id === c.id) ?? false;
                return (
                  <li key={c.id}>
                    <button
                      type="button"
                      onClick={() => void toggleCourse(c.id, { title: c.title, topicCount: c.topicCount })}
                      aria-pressed={inList}
                      className={`learn-tile flex w-full items-center gap-3 rounded-2xl border-2 p-3.5 text-left transition active:translate-y-[2px] ${
                        inList ? 'border-primary bg-primary/10' : 'border-outline-variant bg-card'
                      }`}
                    >
                      <span className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 transition ${
                        inList ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant bg-surface'
                      }`} aria-hidden>
                        {inList && <span className="material-symbols-outlined text-[16px]">check</span>}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[14.5px] font-extrabold text-on-surface">{c.title}</span>
                        <span className="block truncate text-[11.5px] font-bold text-on-surface-variant">
                          {c.topicCount} topics{inList ? ' · in your list' : ''}
                        </span>
                      </span>
                      {/* Founder 2026-10-21: the red cancel ❌ is GONE from
                          the selection rows - the checkbox already adds/
                          removes, so the red key was a duplicate that
                          cluttered every taken row. Removal lives in the
                          dashboard's YOUR COURSES section. */}
                    </button>
                  </li>
                );
              })}
            </ul>

            {filteredSecondary.length === 0 && (
              <p className="py-10 text-center text-[13px] font-bold text-on-surface-variant">
                Nothing matches &ldquo;{secQuery}&rdquo;.
              </p>
            )}

            {/* Done (founder 2026-10-15): the top-bar pill is gone; the
                exit rides quietly at the end of the catalog. */}
            <button
              type="button"
              onClick={() => setFace('list')}
              className="key-btn mx-auto mt-2 bg-primary text-on-primary"
            >
              Done
            </button>
          </div>
        )}

        {/* ── Face 3: the path ── */}
        {!loading && face === 'path' && path && (
          <CoursePathView path={path} onOpenTopic={setTopic} onOpenReview={setReviewUnit} onOpenRevision={setRevisionUnit} />
        )}
      </main>

      {topic && (
        <LessonOverlay topicId={topic.id} mode="lesson" onClose={() => setTopic(null)} onCompleted={afterLesson} />
      )}
      {reviewUnit && path && (
        <LessonOverlay mode="review" courseId={path.id} unit={reviewUnit.index} onClose={() => setReviewUnit(null)} onCompleted={afterLesson} />
      )}
      {revisionUnit && path && (
        <LessonOverlay mode="revision" courseId={path.id} unit={revisionUnit.index} onClose={() => setRevisionUnit(null)} onCompleted={afterLesson} />
      )}

      <BottomNav />
    </div>
  );
}

// ─── The tertiary institution desk ────────────────────────────────────────
// Founder flow: click Courses → the kind of tertiary institution FIRST
// (the department list depends on it), then the department - both saved
// to the database - and only then the course shelf: the national
// 100-level general courses first, then the department's own courses.

const INSTITUTION_META: Record<string, { icon: string; blurb: string }> = {
  University: { icon: 'account_balance', blurb: 'Degree programmes - BSc, BEng, BA and friends' },
  Polytechnic: { icon: 'precision_manufacturing', blurb: 'ND and HND technical programmes' },
  'College of Education': { icon: 'history_edu', blurb: 'NCE and degree education programmes' },
};

function TertiaryDesk({
  mine, onOpen, onToggle, onAdd, onNotice,
}: {
  mine: MyCourse[];
  onOpen: (courseId: string) => void;
  onToggle: (courseId: string, hint?: { title?: string; topicCount?: number }) => void;
  onAdd: (courseIds: string[]) => Promise<boolean>;
  onNotice: (msg: string) => void;
}) {
  // 'desk' = MY SEMESTER DASHBOARD (the clean study view the founder
  // asked for: chosen courses as cards, no config noise, no delete
  // buttons). 'manage' = Add / Remove Courses (selection, the AI
  // finder, department switching, and the only place a course can be
  // removed). The gates (itype/dept) sit in front of both; 'shelf' is
  // the transient "gates passed" state the landing effect resolves to
  // desk or manage.
  const [phase, setPhase] = useState<'load' | 'itype' | 'dept' | 'shelf' | 'desk' | 'manage'>('load');
  const [itype, setItype] = useState('');
  const [shelf, setShelf] = useState<DeskShelves | null>(null);
  const [deps, setDeps] = useState<DeskDepartment[] | null>(null);
  const [depQuery, setDepQuery] = useState('');
  const [gateBusy, setGateBusy] = useState(false);

  // The shelf's search + AI finder state.
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<DeskCourse[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [aiOpen, setAiOpen] = useState(false);
  // "I cannot find my course" (founder 2026-10-17): the learner submits
  // the course + topics; it lands on the admin desk with their name.
  const [courseReqOpen, setCourseReqOpen] = useState(false);
  const [aiText, setAiText] = useState('');
  const [aiBusy, setAiBusy] = useState(false);
  const [aiLines, setAiLines] = useState<AIMatchLine[] | null>(null);
  const [aiPicked, setAiPicked] = useState<Set<string>>(new Set());

  // The borrowed-course pages (founder directive 2026-10-15: schools
  // borrow courses across departments - the desk offers the WHOLE
  // catalogue, paged 100 at a time so a phone never swallows all of it).
  const [others, setOthers] = useState<DeskCourse[] | null>(null);
  const [othersTotal, setOthersTotal] = useState(0);
  const [othersBusy, setOthersBusy] = useState(false);
  // The borrowed catalogue is a REAL fetch (founder round 8): a swallowed
  // failure used to render as an honest-looking "empty" section. The
  // error is kept apart so the section can say what actually happened.
  const [othersError, setOthersError] = useState(false);

  // Live in-list flags: the checkboxes ride the parent's mine list -
  // the server's canonical answer after every toggle - instead of the
  // shelf snapshot, which only refreshes on a full reload and made the
  // manual checkboxes look dead (founder report 2026-10-15: "I can't
  // mark the course manually"). A tap now shows its check immediately.
  const inListIds = useMemo(() => new Set((mine ?? []).map((m) => m.id)), [mine]);
  const withLive = useCallback(
    (c: DeskCourse): DeskCourse => ({ ...c, inList: inListIds.has(c.id) }),
    [inListIds],
  );

  const loadShelf = useCallback(async () => {
    try {
      const s = await fetchCourseDesk();
      setShelf(s);
      setItype(s.institutionType);
      if (s.institutionType && !s.department) {
        setPhase('dept');
        void loadDeps(s.institutionType);
      } else if (!s.institutionType) {
        setPhase('itype');
      } else {
        setPhase('shelf'); // the post-gate effect lands desk or manage
      }
    } catch {
      setPhase('itype'); // the gate works even when the shelf hiccups
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const loadDeps = useCallback(async (t: string) => {
    setDeps(null);
    try {
      const res = await fetchDepartments(t);
      setDeps(res.departments);
    } catch {
      setDeps([]);
    }
  }, []);

  // The borrowed pages: the first page lands with the shelf, and
  // "Show more" appends the next hundred. reset=true refetches from
  // zero (also the right move when the department itself changes).
  const loadOthers = useCallback(async (reset: boolean) => {
    setOthersBusy(true);
    try {
      const offset = reset ? 0 : others?.length ?? 0;
      const res = await fetchDeskOthers(offset, 100);
      setOthersTotal(res.total);
      setOthersError(false); // only a success clears the failure state
      setOthers((prev) => (reset ? res.items : [...(prev ?? []), ...res.items]));
    } catch {
      setOthersError(true);
      if (reset) setOthers([]);
    } finally {
      setOthersBusy(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [others]);

  useEffect(() => {
    if (phase === 'shelf') void loadOthers(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  useEffect(() => { void loadShelf(); }, [loadShelf]);

  // Post-gate landing + the dead-end fix (founder directive 2026-10-16):
  // "Once a tertiary user selects their department and courses,
  // automatically transition them out of the configuration screen into
  // a dedicated My Semester Dashboard." A configured desk with courses
  // lands on the dashboard; a fresh desk lands in manage to pick
  // courses; and the FIRST course that lands while in manage (AI finder
  // or manual checkbox) flips the view to the dashboard by itself.
  const mineCount = mine.length;
  const mineSeenRef = useRef(0);
  useEffect(() => {
    if (phase === 'shelf') {
      setPhase(mineCount > 0 ? 'desk' : 'manage');
    } else if (phase === 'manage' && mineCount > 0 && mineSeenRef.current === 0) {
      setPhase('desk');
      window.scrollTo({ top: 0 });
    }
    mineSeenRef.current = mineCount;
  }, [phase, mineCount]);

  // Course search: debounced, real rows only (code / title / key topic).
  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) {
      setResults(null);
      setSearching(false);
      return;
    }
    setSearching(true);
    const t = setTimeout(async () => {
      try {
        const res = await searchDeskCourses(q);
        setResults(res.items);
      } catch {
        setResults([]);
      } finally {
        setSearching(false);
      }
    }, 350);
    return () => clearTimeout(t);
  }, [query]);

  const chooseInstitution = async (t: string) => {
    // Optimistic gate (founder report 2026-10-14/15: "the school type
    // selection is not working" - the old flow BLOCKED on the desk save,
    // so a cold Render start froze the screen for up to 45s and the tap
    // looked dead). The gate advances the moment the student picks; the
    // save rides in the background (nothing waits on it - the department
    // pick saves BOTH values in one idempotent call, so a failed
    // institution-only save is repaired by the very next tap without
    // the student ever knowing).
    setItype(t);
    setPhase('dept');
    void loadDeps(t);
    try {
      await saveDesk(t, '');
    } catch (err) {
      // Dev forensics (founder 2026-10-15: log the full error object -
      // status, code, message, payload - so a failing save is
      // diagnosable from the browser console).
      if (process.env.NODE_ENV !== 'production') {
        console.error('[desk-save] institution-only save failed', err);
      }
      // The department save re-issues the full pair - nothing to alert
      // the student about yet.
    }
  };

  const chooseDepartment = async (d: DeskDepartment) => {
    // Payload guard (founder 2026-10-15: "ensure no field is unexpectedly
    // null or undefined"): the save pair must never ride with an empty
    // institution kind - if state somehow lost it, recover it from the
    // shelf before sending.
    const kind = (itype || shelf?.institutionType || '').trim();
    if (!kind || !d?.id) {
      setPhase('itype');
      setDepQuery('');
      onNotice('Pick your kind of institution first, then your department.');
      return;
    }
    setGateBusy(true);
    try {
      // Saves institution kind + department together (idempotent upsert):
      // this also lands a first institution-only save that failed above.
      await saveDesk(kind, d.id);
      await loadShelf();
    } catch (err) {
      // Error categorisation (founder directive 2026-10-15: "even with an
      // active internet connection" the app blamed the connection):
      // an HTTP answer (400/409/500) surfaces the server's own actionable
      // message - e.g. "department does not belong to that institution
      // kind" - via deskSaveError(); ONLY a real network failure / timeout
      // keeps the "check your connection" wording. 401 already bounced
      // the session to /login inside api(). In dev the full error object
      // (status, code, message, data) logs to the console.
      if (process.env.NODE_ENV !== 'production') {
        console.error('[desk-save] department save failed', err);
      }
      onNotice(deskSaveError(err, 'Could not save that - check your connection and try again.'));
    } finally {
      setGateBusy(false);
    }
  };

  const runAI = async () => {
    if (!aiText.trim()) return;
    setAiBusy(true);
    setAiLines(null);
    try {
      const res = await aiMatchCourses(aiText);
      setAiLines(res.lines);
      const picks = new Set<string>();
      for (const l of res.lines) if (l.picked) picks.add(l.picked);
      setAiPicked(picks);
    } catch {
      onNotice('The AI finder is not reachable right now - search still works.');
    } finally {
      setAiBusy(false);
    }
  };

  const saveAI = async () => {
    const ids = Array.from(aiPicked);
    if (ids.length === 0) return;
    setGateBusy(true);
    try {
      // Wait for the merge to actually land before touching the view:
      // the old fire-and-forget raced the shelf refresh, the refreshed
      // rows came back with stale inList flags, and the student read
      // "added nothing, nothing is clickable" (founder report
      // 2026-10-15: the AI picks never moved to the course list).
      const ok = await onAdd(ids);
      if (!ok) return; // the notice explains; the picks stay on screen
      await loadShelf();
      setAiOpen(false);
      setAiText('');
      setAiLines(null);
      setAiPicked(new Set());
      // Straight to the My Semester dashboard (founder 2026-10-16:
      // "add to my courses" must land on the page where the saved
      // courses are shown and clickable).
      setPhase('desk');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } finally {
      setGateBusy(false);
    }
  };

  const togglePick = (id: string) => {
    setAiPicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  // ── Gate 1: the kind of tertiary institution ──
  if (phase === 'load') return <SkeletonList />;
  if (phase === 'itype') {
    return (
      <div className="flex flex-col gap-3">
        <GateHeader
          step="Step 1 of 2"
          title="What kind of tertiary institution?"
          sub="Your department list depends on this - we ask once and remember it."
        />
        {Object.entries(INSTITUTION_META).map(([name, meta]) => (
          <button
            key={name}
            type="button"
            disabled={gateBusy}
            onClick={() => void chooseInstitution(name)}
            className="learn-tile flex w-full items-center gap-3.5 rounded-2xl border-2 border-outline-variant bg-card p-4 text-left transition hover:border-primary/50 active:translate-y-[2px] disabled:opacity-60"
          >
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-primary/15">
              <span className="material-symbols-outlined text-[24px] text-primary-ink">{meta.icon}</span>
            </span>
            <span className="min-w-0 flex-1">
              <span className="block text-[15.5px] font-black text-on-surface">{name}</span>
              <span className="mt-0.5 block text-[12.5px] font-bold leading-snug text-on-surface-variant">{meta.blurb}</span>
            </span>
            <span className="material-symbols-outlined shrink-0 text-[20px] text-on-surface-variant">chevron_right</span>
          </button>
        ))}
      </div>
    );
  }

  // ── Gate 2: the department (list driven by the institution kind) ──
  if (phase === 'dept') {
    const q = depQuery.trim().toLowerCase();
    const shown = (deps ?? []).filter(
      (d) => !q || d.name.toLowerCase().includes(q) || d.faculty.toLowerCase().includes(q),
    );
    return (
      <div className="flex flex-col gap-3">
        <GateHeader
          step="Step 2 of 2"
          title="Which department are you in?"
          sub={`Real departments for ${itype} students - pick yours and your course list appears.`}
        />
        <input
          value={depQuery}
          onChange={(e) => setDepQuery(e.target.value)}
          placeholder="Search departments…"
          aria-label="Search departments"
          className="w-full rounded-xl border-2 border-outline-variant bg-card px-3.5 py-2.5 text-[14px] font-bold text-on-surface outline-none focus:border-primary"
        />
        <div className="flex flex-col gap-2">
          {deps === null && <SkeletonList />}
          {deps !== null && shown.map((d) => (
            <button
              key={d.id}
              type="button"
              disabled={gateBusy}
              onClick={() => void chooseDepartment(d)}
              className="learn-tile w-full rounded-2xl border-2 border-outline-variant bg-card p-3.5 text-left transition hover:border-primary/50 active:translate-y-[2px] disabled:opacity-60"
            >
              <div className="flex items-center gap-3">
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[14.5px] font-black text-on-surface">{d.name}</span>
                  <span className="mt-0.5 block truncate text-[11.5px] font-bold text-on-surface-variant">
                    {d.faculty}{d.courseCount > 0 ? ` · ${d.courseCount} courses` : ''}
                  </span>
                </span>
                <span className="material-symbols-outlined shrink-0 text-[20px] text-on-surface-variant">chevron_right</span>
              </div>
            </button>
          ))}
          {deps !== null && shown.length === 0 && (
            <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-8 text-center text-[13px] font-bold text-on-surface-variant">
              {q ? 'No department matches that search.' : 'The department list is on its way - check your connection.'}
            </p>
          )}
        </div>
        <button
          type="button"
          onClick={() => { setPhase('itype'); setDepQuery(''); }}
          className="mx-auto mt-1 rounded-xl border-2 border-outline-variant bg-card px-4 py-2 text-[12.5px] font-extrabold text-on-surface-variant transition active:translate-y-[2px]"
        >
          Change institution kind
        </button>
      </div>
    );
  }

  // ── MY SEMESTER DASHBOARD (founder directive 2026-10-16): the clean
  // study view a configured tertiary student lands on - chosen courses
  // as independent JAMB-style cards with progress bars and roadmap
  // links, NO configuration noise and NO delete buttons (removal lives
  // behind the Add / remove courses mode). ──
  if (phase === 'desk') {
    const totalTopics = mine.reduce((n, c) => n + (c.topicCount ?? 0), 0);
    const doneTopics = mine.reduce((n, c) => n + (c.completedTopics ?? 0), 0);
    return (
      <div className="flex flex-col gap-4">
        {/* Semester header */}
        <div className="learn-tile rounded-2xl border-2 border-primary/40 bg-gradient-to-br from-primary to-[color-mix(in_srgb,var(--color-primary)_78%,#000)] p-4 text-on-primary">
          <div className="flex items-center gap-2.5">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/20">
              <span className="material-symbols-outlined text-[22px]">school</span>
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[16px] font-black leading-tight">My Semester</p>
              <p className="truncate text-[11.5px] font-bold opacity-85">
                {shelf?.institutionType || itype} · {shelf?.departmentName || 'Your department'}
              </p>
            </div>
          </div>
          <div className="mt-3 flex items-center gap-3 rounded-xl bg-white/15 px-3 py-2 text-[12px] font-extrabold">
            <span>{mine.length} course{mine.length === 1 ? '' : 's'}</span>
            <span className="opacity-60">·</span>
            <span>{doneTopics.toLocaleString()} / {totalTopics.toLocaleString()} topics done</span>
          </div>
        </div>

        {/* The semester's courses - tap one to open its roadmap. */}
        {mine.length > 0 ? (
          <section className="flex flex-col gap-2">
            <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
              Your courses
              <span className="ml-1.5 font-bold normal-case text-on-surface-variant/70">- tap one to open its roadmap</span>
            </h3>
            {mine.map((c) => (
              <CourseCard key={c.id} c={c} onOpen={() => onOpen(c.id)} />
            ))}
          </section>
        ) : (
          <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-8 text-center text-[13px] font-bold text-on-surface-variant">
            No courses on your semester yet - add your first ones below.
          </p>
        )}

        {/* The single management doorway - keeps the study page clean. */}
        <button
          type="button"
          onClick={() => { setPhase('manage'); setQuery(''); }}
          className="key-btn mx-auto bg-card text-on-surface"
        >
          Add / remove courses
        </button>
        <p className="text-center text-[11.5px] font-bold text-on-surface-variant/70">
          Your courses and department can be changed anytime.
        </p>
      </div>
    );
  }

  // ── Manage: Add / Remove Courses (selection, AI finder, removal,
  // department switching - the decoupled configuration mode) ──
  const general = shelf?.general ?? [];
  const departmental = shelf?.departmental ?? [];
  const showSearch = query.trim().length >= 2;
  // Founder 2026-10-21 - the search must never look dead again: the
  // server hit (/learn/search, ranked across the whole catalogue) is
  // merged with INSTANT client-side matches over every already-loaded
  // row (general + departmental + borrowed pages). When the API is
  // cold, slow or erroring, the local half still answers on the very
  // first keystroke - and the shelves/AI/request panels step aside
  // while a query is live so the results ARE the page.
  const searchQuery = query.trim().toLowerCase();
  const localMatches: DeskCourse[] = [];
  if (showSearch) {
    const seenLocal = new Set<string>();
    for (const c of [...general, ...departmental, ...(others ?? [])]) {
      if (seenLocal.has(c.id)) continue;
      seenLocal.add(c.id);
      const hay = `${c.code ?? ''} ${c.title} ${c.department ?? ''}`.toLowerCase();
      if (hay.includes(searchQuery)) localMatches.push(c);
    }
  }
  const mergedResults: DeskCourse[] = showSearch
    ? [...(results ?? []), ...localMatches.filter((c) => !(results ?? []).some((r) => r.id === c.id))]
    : [];
  // YOUR COURSES renders straight from the `mine` prop - founder report
  // 2026-10-16: the rows used to come from a useMemo parked BELOW the
  // phase early-returns above, so reaching the shelf added one hook to
  // the render and React tore the whole tree down ("Rendered more hooks
  // than during the previous render" - the client-side exception the
  // founder saw on /courses and, after any navigation, on every other
  // page until a full reload). Plain render data has no hook to
  // misplace, and the desk lists ALL of the student's picked courses:
  // it is a School-focus student's only desk, so no row is hidden by
  // the body it was added under (founder: "make sure ALL the selected
  // courses ... are now arranged and listed just like the JAMB focus
  // own and can be changed later").
  return (
    <div className="flex flex-col gap-4">
      {/* Manage header: the Done key back to the semester dashboard */}
      <div className="flex items-center gap-2 rounded-2xl border-2 border-outline-variant bg-card px-4 py-3">
        <span className="material-symbols-outlined text-[20px] text-primary-ink">tune</span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[14px] font-black text-on-surface">Add / remove courses</p>
          <p className="text-[11.5px] font-bold text-on-surface-variant">{shelf?.institutionType || itype} · {shelf?.departmentName || 'your department'} · general + your department + every other department's courses</p>
        </div>
        <button
          type="button"
          onClick={() => { setPhase('desk'); window.scrollTo({ top: 0 }); }}
          className="shrink-0 rounded-xl bg-primary px-3.5 py-1.5 text-[11.5px] font-extrabold text-on-primary transition active:translate-y-[2px]"
        >
          Done
        </button>
      </div>

      {/* YOUR COURSES - every picked course as a JAMB-style card
          (progress "0/12 topics done", bar, action arrow). This is the
          MANAGE mode, so each card carries its remove control - the
          only place a course can be deleted from (the dashboard's
          cards have no X, so accidental taps can never drop a course). */}
      {mine.length > 0 && (
        <section className="flex flex-col gap-2">
          <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
            Your courses
            <span className="ml-1.5 font-bold normal-case text-on-surface-variant/70">- tap the × to remove one</span>
          </h3>
          {mine.map((c) => (
            <CourseCard key={c.id} c={c} onOpen={() => onOpen(c.id)} onRemove={() => onToggle(c.id)} />
          ))}
        </section>
      )}

      {/* Search: short code (CSC, MTH…), title, or a key topic */}
      <div className="flex flex-col gap-2">
        <div className="relative">
          <span className="material-symbols-outlined pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[20px] text-on-surface-variant">search</span>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search by code (CSC, MTH…), title or topic"
            aria-label="Search courses"
            className="w-full rounded-xl border-2 border-outline-variant bg-card py-2.5 pl-11 pr-10 text-[13.5px] font-bold text-on-surface outline-none focus:border-primary"
          />
          {query && (
            <button
              type="button"
              onClick={() => setQuery('')}
              aria-label="Clear search"
              className="absolute right-2.5 top-1/2 -translate-y-1/2 rounded-full p-1 text-on-surface-variant"
            >
              <span className="material-symbols-outlined text-[18px]">close</span>
            </button>
          )}
        </div>

        {showSearch && (
          <div className="flex flex-col gap-2">
            {searching && <p className="px-1 text-[12px] font-bold text-on-surface-variant">Searching the whole catalogue…</p>}
            {!searching && mergedResults.length === 0 && (
              <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
                Nothing matches &ldquo;{query}&rdquo;. Try a course code (three letters) or a topic.
              </p>
            )}
            {mergedResults.map((c) => {
              const row = withLive(c);
              return <DeskRow key={c.id} c={row} onOpen={() => row.inList && onOpen(c.id)} onToggle={() => onToggle(c.id, { title: c.title, topicCount: c.topicCount })} />;
            })}
          </div>
        )}
      </div>

      {/* AI course finder - paused while a search query is live */}
      {!showSearch && (
      <div className="rounded-2xl border-2 border-primary/40 bg-primary/5 p-4">
        <button
          type="button"
          onClick={() => setAiOpen((v) => !v)}
          className="flex w-full items-center gap-3 text-left"
          aria-expanded={aiOpen}
        >
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/15">
            <span className="material-symbols-outlined text-[22px] text-primary-ink">auto_awesome</span>
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[14px] font-black text-on-surface">Find my courses with AI</span>
            <span className="block text-[11.5px] font-bold leading-snug text-on-surface-variant">
              Type all your course titles - the AI finds them in the catalogue and sets up your list.
            </span>
          </span>
          <span className="material-symbols-outlined shrink-0 text-[20px] text-on-surface-variant">{aiOpen ? 'expand_less' : 'expand_more'}</span>
        </button>

        {aiOpen && (
          <div className="mt-3 flex flex-col gap-2.5">
            <textarea
              value={aiText}
              onChange={(e) => setAiText(e.target.value)}
              rows={5}
              placeholder={'One course per line, e.g.\nCSC 101 Introduction to Computing\nGeneral Mathematics\nUse of English'}
              className="w-full resize-y rounded-xl border-2 border-outline-variant bg-card px-3.5 py-2.5 text-[13px] font-bold leading-relaxed text-on-surface outline-none focus:border-primary"
            />
            <button
              type="button"
              disabled={aiBusy || !aiText.trim()}
              onClick={() => void runAI()}
              className="key-btn mx-auto bg-primary text-on-primary disabled:opacity-60"
            >
              {aiBusy ? 'Finding your courses…' : 'Find my courses'}
            </button>

            {aiLines !== null && (
              <div className="flex flex-col gap-2">
                {aiLines.map((l, i) => {
                  const best = l.matches.find((m) => m.id === l.picked);
                  return (
                    <div key={`${l.input}-${i}`} className="rounded-xl border-2 border-outline-variant bg-card p-3">
                      <p className="truncate text-[12px] font-black text-on-surface">{l.input}</p>
                      {best ? (
                        <label className="mt-1.5 flex cursor-pointer items-center gap-2.5">
                          <input
                            type="checkbox"
                            checked={aiPicked.has(best.id)}
                            onChange={() => togglePick(best.id)}
                            className="h-4 w-4 accent-[var(--color-primary)]"
                          />
                          <span className="min-w-0 flex-1 text-[12.5px] font-bold text-on-surface">
                            {best.code && <span className="mr-1.5 rounded-md bg-primary/15 px-1.5 py-0.5 text-[10.5px] font-black text-primary-ink">{best.code}</span>}
                            {best.title}
                          </span>
                        </label>
                      ) : l.matches.length > 0 ? (
                        <div className="mt-1 flex flex-col gap-1">
                          {l.matches.slice(0, 4).map((m) => (
                            <label key={m.id} className="flex cursor-pointer items-center gap-2.5">
                              <input
                                type="checkbox"
                                checked={aiPicked.has(m.id)}
                                onChange={() => togglePick(m.id)}
                                className="h-4 w-4 accent-[var(--color-primary)]"
                              />
                              <span className="min-w-0 flex-1 truncate text-[12px] font-bold text-on-surface-variant">
                                {m.code && <span className="mr-1 font-black text-primary-ink">{m.code}</span>}
                                {m.title}
                              </span>
                            </label>
                          ))}
                        </div>
                      ) : (
                        <p className="mt-1 text-[11.5px] font-bold text-on-surface-variant">No match in the catalogue yet.</p>
                      )}
                    </div>
                  );
                })}
                {aiPicked.size > 0 && (
                  <button
                    type="button"
                    disabled={gateBusy}
                    onClick={() => void saveAI()}
                    className="key-btn mx-auto bg-primary text-on-primary disabled:opacity-60"
                  >
                    {gateBusy ? 'Saving…' : `Add ${aiPicked.size} course${aiPicked.size === 1 ? '' : 's'} to my list`}
                  </button>
                )}
              </div>
            )}
          </div>
        )}
      </div>
      )}

      {/* Still lost? Submit the missing course straight to the desk. */}
      {!showSearch && (
      <button
        type="button"
        onClick={() => setCourseReqOpen(true)}
        className="flex items-center gap-2.5 rounded-2xl border-2 border-dashed border-outline-variant bg-card p-4 text-left transition hover:border-outline"
      >
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-surface-container-high">
          <span className="material-symbols-outlined text-[20px] text-on-surface-variant">add_circle</span>
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-[13.5px] font-black text-on-surface">Can&apos;t find your course?</span>
          <span className="block text-[11.5px] font-bold text-on-surface-variant">
            Submit the course and its topics - the desk builds the bank for it.
          </span>
        </span>
        <span className="material-symbols-outlined shrink-0 text-on-surface-variant">chevron_right</span>
      </button>
      )}

      {/* General shelf: the national first-year courses, GST suite first */}
      {!showSearch && (
      <section className="flex flex-col gap-2">
        <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
          {shelf?.institutionType === 'Polytechnic' ? 'ND I general courses' : shelf?.institutionType === 'College of Education' ? 'NCE I general courses' : '100 Level general courses'}
          <span className="ml-1.5 font-bold normal-case text-on-surface-variant/70">- everyone takes these</span>
        </h3>
        {general.map((c) => {
          const row = withLive(c);
          return <DeskRow key={c.id} c={row} onOpen={() => row.inList && onOpen(c.id)} onToggle={() => onToggle(c.id, { title: c.title, topicCount: c.topicCount })} />;
        })}
        {general.length === 0 && (
          <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
            The general shelf is on its way - check your connection.
          </p>
        )}
      </section>
      )}

      {/* Department shelf */}
      {!showSearch && shelf?.departmentName && (
        <section className="flex flex-col gap-2">
          <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
            {shelf.departmentName} courses
          </h3>
          {departmental.map((c) => {
            const row = withLive(c);
            return <DeskRow key={c.id} c={row} onOpen={() => row.inList && onOpen(c.id)} onToggle={() => onToggle(c.id, { title: c.title, topicCount: c.topicCount })} />;
          })}
          {departmental.length === 0 && (
            <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
              No courses listed for this department yet.
            </p>
          )}
        </section>
      )}

      {/* Other departments' courses - schools borrow courses across
          departments, so the desk offers the WHOLE catalogue (founder
          directive 2026-10-15: "add the remaining 10,000 to the list").
          Paged at 100, so a phone never swallows all of it at once. */}
      {!showSearch && (
      <section className="flex flex-col gap-2">
        <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
          Other departments&rsquo; courses
          <span className="ml-1.5 font-bold normal-case text-on-surface-variant/70">
            {othersTotal > 0 ? `- ${othersTotal.toLocaleString()} borrowable` : '- borrowed across schools'}
          </span>
        </h3>
        {others === null && (
          <p className="px-1 text-[12px] font-bold text-on-surface-variant">Loading the rest of the catalogue…</p>
        )}
        {(others ?? []).map((c) => {
          const row = withLive(c);
          return <DeskRow key={c.id} c={row} onOpen={() => row.inList && onOpen(c.id)} onToggle={() => onToggle(c.id, { title: c.title, topicCount: c.topicCount })} />;
        })}
        {othersError && (
          <div className="flex items-center justify-between gap-3 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-4">
            <p className="min-w-0 text-[12.5px] font-bold text-on-surface-variant">
              Couldn&rsquo;t load the borrowed catalogue.
            </p>
            <button
              type="button"
              disabled={othersBusy}
              onClick={() => void loadOthers((others ?? []).length === 0)}
              className="shrink-0 rounded-lg border-2 border-outline-variant bg-card px-3 py-1.5 text-[12px] font-extrabold text-on-surface transition active:translate-y-[1px] disabled:opacity-60"
            >
              {othersBusy ? 'Loading…' : 'Tap to retry'}
            </button>
          </div>
        )}
        {!othersError && others !== null && others.length === 0 && othersTotal === 0 && (
          <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
            Nothing beyond the shelves above - your department covers the catalogue.
          </p>
        )}
        {others !== null && others.length < othersTotal && (
          <button
            type="button"
            disabled={othersBusy}
            onClick={() => void loadOthers(false)}
            className="mx-auto rounded-xl border-2 border-outline-variant bg-card px-4 py-2 text-[12.5px] font-extrabold text-on-surface transition active:translate-y-[2px] disabled:opacity-60"
          >
            {othersBusy ? 'Loading…' : `Show more (${(othersTotal - others.length).toLocaleString()} more)`}
          </button>
        )}
      </section>
      )}

      {/* Department switching lives here, in manage mode - the study
          dashboard never offers it (founder directive 2026-10-16). */}
      {!showSearch && (
      <button
        type="button"
        onClick={() => { setPhase('dept'); setDepQuery(''); }}
        className="mx-auto rounded-xl border-2 border-outline-variant bg-card px-4 py-2 text-[12.5px] font-extrabold text-on-surface-variant transition active:translate-y-[2px]"
      >
        Change department or institution kind
      </button>
      )}
      {courseReqOpen && (
        <CourseRequestModal
          defaultSchool=''
          onClose={() => setCourseReqOpen(false)}
        />
      )}
    </div>
  );
}

function GateHeader({ step, title, sub }: { step: string; title: string; sub: string }) {
  return (
    <div className="learn-tile rounded-2xl border-2 border-primary/40 bg-primary/10 p-4 text-center">
      <p className="text-[10.5px] font-black uppercase tracking-widest text-primary-ink">{step}</p>
      <h2 className="mt-1 text-[17px] font-black leading-tight text-on-surface">{title}</h2>
      <p className="mx-auto mt-1 max-w-sm text-[12.5px] font-bold leading-snug text-on-surface-variant">{sub}</p>
    </div>
  );
}

/** One course row: code badge + title + department, checkbox to add,
 * tap the title to open (when it is already on the list). */
function DeskRow({ c, onOpen, onToggle }: { c: DeskCourse; onOpen: () => void; onToggle: () => void }) {
  return (
    <div
      className={`learn-tile flex w-full items-center gap-3 rounded-2xl border-2 p-3 transition ${
        c.inList ? 'border-primary/50 bg-primary/5' : 'border-outline-variant bg-card'
      }`}
    >
      <button
        type="button"
        onClick={onToggle}
        aria-pressed={c.inList}
        aria-label={c.inList ? `Remove ${c.title}` : `Add ${c.title}`}
        className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 transition active:scale-95 ${
          c.inList ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant bg-surface'
        }`}
      >
        {c.inList && <span className="material-symbols-outlined text-[16px]">check</span>}
      </button>
      <button type="button" onClick={onOpen} className="min-w-0 flex-1 text-left" disabled={!c.inList}>
        <span className="flex items-center gap-1.5">
          {c.code && (
            <span className="shrink-0 rounded-md bg-primary/15 px-1.5 py-0.5 text-[10.5px] font-black tracking-wide text-primary-ink">
              {c.code}
            </span>
          )}
          <span className="truncate text-[14px] font-extrabold text-on-surface">{c.title}</span>
        </span>
        <span className="mt-0.5 block truncate text-[11px] font-bold text-on-surface-variant">
          {c.department} · {c.topicCount} topic{c.topicCount === 1 ? '' : 's'}
          {c.inList ? ' · in your list' : ''}
        </span>
      </button>
      {c.inList && (
        <button type="button" onClick={onOpen} aria-label={`Open ${c.title}`} className="shrink-0 p-1 text-on-surface-variant">
          <span className="material-symbols-outlined text-[20px]">chevron_right</span>
        </button>
      )}
      {/* Founder 2026-10-21: the red cancel ❌ at the right-hand tip is
          GONE - the checkbox already toggles, and removal lives in the
          YOUR COURSES section at the top of the manage page. */}
    </div>
  );
}

// ─── The course card (shared, the JAMB-desk style) ─────────────────────

/** The card the founder asked to share across desks (2026-10-15):
 *  book icon, title, "0/12 topics done" progress line and the bar.
 *  A tap opens the course roadmap. The secondary desks and the
 *  tertiary desk's YOUR COURSES section render the same tile.
 *  Optional `onRemove` (founder 2026-10-16) rides as an INLINE flex
 *  sibling - vertically centred on the right-hand side, its own button
 *  so tap targets stay honest. Founder 2026-10-21: the '>' chevron is
 *  GONE from every card and the floating top-right × overlay is out -
 *  ONLY the × sits on the RHS, properly aligned. */
function CourseCard({ c, onOpen, onRemove }: { c: MyCourse; onOpen: () => void; onRemove?: () => void }) {
  return (
    <div className="learn-tile flex w-full items-center gap-3 rounded-2xl border-2 border-outline-variant bg-card p-4 text-left transition hover:border-primary/40">
      <button
        type="button"
        onClick={onOpen}
        className="flex min-w-0 flex-1 items-center gap-3 text-left"
      >
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/15">
          <span className="material-symbols-outlined text-[22px] text-primary-ink">menu_book</span>
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-[15px] font-black text-on-surface">{c.title}</span>
          <span className="mt-0.5 block text-[12px] font-bold text-on-surface-variant">
            {c.completedTopics}/{c.topicCount} topics done
          </span>
          <span className="mt-1.5 block">
            <ProgressBar value={c.topicCount ? (c.completedTopics / c.topicCount) * 100 : 0} />
          </span>
        </span>
      </button>
      {onRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remove ${c.title} from your list`}
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-error/35 bg-error/10 text-error transition hover:bg-error/20 active:scale-90"
        >
          <span className="material-symbols-outlined text-[16px]">close</span>
        </button>
      )}
    </div>
  );
}

// ─── Path view ────────────────────────────────────────────────────────────

const ZIGZAG = ['ml-0', 'ml-14', 'ml-28', 'ml-14'];

/** Unit colours (founder directive 2026-10-16: "make the course page
 * lively - unit 1 hero card green, unit 2 blue, unit 3 purple, unit 4
 * orange, and the other units some good random colours"). The later
 * units rotate one fixed vivid palette instead of literal randomness:
 * a repaint on every refresh would feel broken, a stable rotation
 * stays lively AND predictable. White ink works on every entry. */
interface UnitTheme {
  solid: string; // banner / node / icon fill
  deep: string;  // gradient partner, darker
  wash: string;  // same hue at ~12% alpha, card backgrounds
  ink: string;   // readable accent on light surfaces
}
const UNIT_COLORS: UnitTheme[] = [
  { solid: '#16a34a', deep: '#15803d', wash: '#16a34a1f', ink: '#15803d' }, // 1 green
  { solid: '#2563eb', deep: '#1d4ed8', wash: '#2563eb1f', ink: '#1d4ed8' }, // 2 blue
  { solid: '#9333ea', deep: '#7e22ce', wash: '#9333ea1f', ink: '#7e22ce' }, // 3 purple
  { solid: '#ea580c', deep: '#c2410c', wash: '#ea580c1f', ink: '#c2410c' }, // 4 orange
  { solid: '#0d9488', deep: '#0f766e', wash: '#0d94881f', ink: '#0f766e' }, // 5 teal
  { solid: '#e11d48', deep: '#be123c', wash: '#e11d481f', ink: '#be123c' }, // 6 rose
  { solid: '#4f46e5', deep: '#4338ca', wash: '#4f46e51f', ink: '#4338ca' }, // 7 indigo
  { solid: '#0891b2', deep: '#0e7490', wash: '#0891b21f', ink: '#0e7490' }, // 8 cyan
  { solid: '#c026d3', deep: '#a21caf', wash: '#c026d31f', ink: '#a21caf' }, // 9 fuchsia
  { solid: '#65a30d', deep: '#4d7c0f', wash: '#65a30d1f', ink: '#4d7c0f' }, // 10 lime
  { solid: '#0284c7', deep: '#0369a1', wash: '#0284c71f', ink: '#0369a1' }, // 11 sky
  { solid: '#d97706', deep: '#b45309', wash: '#d977061f', ink: '#b45309' }, // 12 amber
  { solid: '#059669', deep: '#047857', wash: '#0596691f', ink: '#047857' }, // 13 emerald
  { solid: '#7c3aed', deep: '#6d28d9', wash: '#7c3aed1f', ink: '#6d28d9' }, // 14 violet
  { solid: '#dc2626', deep: '#b91c1c', wash: '#dc26261f', ink: '#b91c1c' }, // 15 red
];

function unitTheme(unit: number): UnitTheme {
  const t = UNIT_COLORS[(unit - 1) % UNIT_COLORS.length];
  return t ?? UNIT_COLORS[0];
}

function CoursePathView({
  path, onOpenTopic, onOpenReview, onOpenRevision,
}: {
  path: CoursePath;
  onOpenTopic: (t: TopicNode) => void;
  onOpenReview: (u: UnitNode) => void;
  onOpenRevision: (u: UnitNode) => void;
}) {
  const [chestToast, setChestToast] = useState('');
  // The founder's gamification pass: opening the unit-1 treasure chest
  // plays the SAME full-screen chest-opening moment a topic chest gets
  // (shake → lid bursts → spin → gems pop out) instead of a quiet toast.
  const [chestDrop, setChestDrop] = useState<ChestDrop | null>(null);
  const [localOpened, setLocalOpened] = useState<Set<number>>(new Set());
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
    if (localOpened.has(u.index)) return;
    try {
      const { openChest: post } = await import('@/lib/learn');
      const res = await post(`${path.id}#${u.index}`);
      setLocalOpened((s) => new Set(s).add(u.index));
      setChestDrop({ kind: 'gems', amount: res.gems, icon: 'diamond', label: `${res.gems} gems` });
    } catch {
      setChestToast('Chest already opened');
      setTimeout(() => setChestToast(''), 1600);
    }
  };

  // Founder 2026-10-22: the unit banner rides right under the hero
  // card (the old 20px float read as a dead gap and pushed the path
  // off the fold).
  return (
    <div className="flex flex-col gap-2.5">
      {/* The full-screen chest moment - same celebration a topic quiz pays. */}
      {chestDrop && <ChestOpening drop={chestDrop} onDone={() => setChestDrop(null)} />}

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
      </header>

      {path.units.map((u) => {
        const topics = byUnit.get(u.index) ?? [];
        const isChest = u.index === 1;
        const theme = unitTheme(u.index);
        const revisionUnlocked = topics.some((t) => t.status === 'completed');
        return (
          <section key={u.index} className="flex flex-col">
            {/* Unit banner - every unit wears its own colour (founder
                2026-10-16: green, blue, purple, orange, then a vivid
                rotation) */}
            <div
              className="sticky top-12 z-10 -mx-1 rounded-xl border-2 px-3.5 py-2.5 text-white learn-tile"
              style={{
                borderColor: theme.deep,
                background: `linear-gradient(135deg, ${theme.solid}, ${theme.deep})`,
              }}
            >
              <div className="flex items-center justify-between gap-2">
                <p className="text-[13px] font-black">{u.name}</p>
                {isChest ? (
                  <button
                    type="button"
                    onClick={() => void openChest(u)}
                    disabled={u.chestOpened || localOpened.has(u.index)}
                    className="flex items-center gap-1 rounded-lg border-2 border-white/50 bg-white/20 px-2 py-1 text-[11px] font-extrabold text-white disabled:opacity-60"
                  >
                    <span className="material-symbols-outlined text-[15px]">{u.chestOpened || localOpened.has(u.index) ? 'inventory_2' : 'redeem'}</span>
                    {u.chestOpened || localOpened.has(u.index) ? 'Opened' : 'Open chest'}
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => u.reviewReady && onOpenReview(u)}
                    disabled={!u.reviewReady}
                    className="flex items-center gap-1 rounded-lg border-2 border-white/50 bg-white/20 px-2 py-1 text-[11px] font-extrabold text-white disabled:opacity-60"
                  >
                    <span className="material-symbols-outlined text-[15px]">trophy</span>
                    {u.reviewReady ? 'Review' : 'Locked'}
                  </button>
                )}
              </div>
            </div>

            {/* Zig-zag ladder */}
            <div className="mt-3 flex flex-col items-center gap-1">
              {topics.map((t, i) => (
                <PathNode key={t.id} topic={t} offset={ZIGZAG[i % ZIGZAG.length]} color={theme.solid} onOpen={() => onOpenTopic(t)} />
              ))}
            </div>

            {/* The unit revision - the special section at the LAST place
                of every unit (founder 2026-10-16): one tap serves a
                50 question paper drawn from every topic of the unit. */}
            <button
              type="button"
              onClick={() => revisionUnlocked && onOpenRevision(u)}
              disabled={!revisionUnlocked}
              aria-label={`Unit ${u.index} revision: 50 questions`}
              className={`learn-tile mt-4 w-full rounded-2xl border-2 p-3.5 text-left transition ${revisionUnlocked ? 'active:translate-y-[2px] hover:brightness-[1.03]' : 'opacity-70'}`}
              style={{
                borderColor: theme.solid,
                background: `linear-gradient(135deg, ${theme.wash}, transparent 72%)`,
              }}
            >
              <div className="flex items-center gap-3">
                <span
                  className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-white"
                  style={{ backgroundColor: theme.solid }}
                >
                  <span className="material-symbols-outlined text-[22px]">fact_check</span>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-[13.5px] font-black" style={{ color: theme.ink }}>
                    Unit {u.index} Revision
                  </span>
                  <span className="block text-[11.5px] font-bold leading-snug text-on-surface-variant">
                    {revisionUnlocked
                      ? `50 questions from all ${topics.length} topics of this unit`
                      : 'Finish a topic in this unit to unlock the revision paper'}
                  </span>
                </span>
                <span className="material-symbols-outlined shrink-0 text-[20px]" style={{ color: theme.ink }}>
                  {revisionUnlocked ? 'chevron_right' : 'lock'}
                </span>
              </div>
            </button>
          </section>
        );
      })}

      {/* The deep-tree promise (founder 2026-10-16): while the background
          loop writes the next unit of 10 topics, the ladder shows a
          quiet "being prepared" node instead of pretending the course
          ends here. It self-replaces on the next path refresh. */}
      {path.generating && (
        <div className="flex flex-col items-center gap-2 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-7 text-center">
          <span className="material-symbols-outlined animate-pulse text-[26px] text-primary-ink">progress_activity</span>
          <p className="text-[13px] font-black text-on-surface">Unit {(path.units[path.units.length - 1]?.index ?? 0) + 1} is being prepared</p>
          <p className="max-w-xs text-[11.5px] font-bold leading-snug text-on-surface-variant">
            The next 10 topics are quietly being written for this course. Reopen it in a moment and they will be waiting on the ladder.
          </p>
        </div>
      )}
    </div>
  );
}

function PathNode({ topic, offset, color, onOpen }: { topic: TopicNode; offset: string; color: string; onOpen: () => void }) {
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
            ? 'text-white learn-node-done'
            : current
              ? 'bg-accent-amber text-white learn-node-current'
              : 'border-outline-variant bg-surface-container-high text-on-surface-variant'
        } ${locked ? 'opacity-70' : 'active:translate-y-[3px] hover:brightness-105'}`}
        style={done ? { backgroundColor: color, borderColor: color } : undefined}
      >
        <span className="material-symbols-outlined text-[30px]">
          {done ? 'star' : current ? 'school' : 'lock'}
        </span>
      </button>
      <p className={`mt-1 max-w-[190px] text-center text-[11.5px] font-extrabold leading-tight ${locked ? 'text-on-surface-variant' : 'text-on-surface'}`}>
        {topic.title}
      </p>
      {done && topic.bestScore >= 100 && (
        <p className="text-[10.5px] font-black uppercase" style={{ color }}>Perfect!</p>
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
        Mark every course you want on your desk - each one becomes a long roadmap of topics, notes with real drawings, and your actual past questions.
      </p>
      <button type="button" onClick={onChoose} className="key-btn mt-1 bg-primary text-on-primary">Choose courses</button>
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
