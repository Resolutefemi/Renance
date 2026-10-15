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
 * DESK SEPARATION (earlier pass, kept): every body is its own desk -
 * JAMB/WAEC/NECO subjects never appear on the tertiary institution
 * desk and vice versa.
 *
 * NO level tag anywhere - the founder removed it from the courses list.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LessonOverlay } from '@/components/learn/lesson-overlay';
import { ProgressBar } from '@/components/learn/bits';
import { getStoredUser } from '@/lib/session';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import {
  CatalogItem, CoursePath, MyCourse, TopicNode, UnitNode,
  DeskCourse, DeskDepartment, DeskShelves, AIMatchLine,
  fetchCourseDesk, fetchCoursePath, fetchDepartments, fetchMyCourses, learnBodyFromExams,
  learnBodyLabel, aiMatchCourses, saveDesk, searchDeskCourses,
  setActiveCourse, setMyCourses, deskSaveError,
} from '@/lib/learn';
import { JAMB_CATALOG, NECO_CATALOG, WAEC_CATALOG } from '@/lib/learn-catalog-secondary';

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

/** Founder directive 2026-10-14 (second pass): the JAMB subjects appear
 * ONLY on the JAMB/WAEC/NECO desks and the tertiary institution desk
 * carries the institutions' own courses - so Post-UTME prep, which is
 * tertiary work, rides the tertiary desk and never sees a JAMB subject. */
function deskOf(body: string): string {
  return body === 'post-utme' ? 'tertiary' : body;
}

function readCachedBody(): string {
  try {
    return deskOf(window.localStorage.getItem(BODY_CACHE_KEY) || 'jamb');
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

  // Secondary selection state - the catalog itself is HARDCODED, only
  // the view state (query) is component state. The tertiary tree is
  // served by the API now (the desk flow below).
  const [secQuery, setSecQuery] = useState('');
  const [saving, setSaving] = useState(false);

  // Desk separation: the desks this student actually carries, focus
  // body first. Rows saved before the body column existed (empty body)
  // ride the focus desk so they never vanish. Every row body goes
  // through deskOf, so Post-UTME rows group under the tertiary
  // institution desk and JAMB subjects never leak onto it.
  const deskBodies = useMemo(() => {
    const DESKS = ['jamb', 'waec', 'neco', 'tertiary'];
    const present = new Set<string>();
    for (const c of mine ?? []) present.add(deskOf(c.body || body));
    const focus = deskOf(body);
    const rest = DESKS.filter((b) => present.has(b) && b !== focus);
    return [focus, ...rest];
  }, [mine, body]);

  // The hardcoded secondary shelf for the selection face.
  const secondaryItems = useMemo<CatalogItem[]>(() => {
    if (body === 'tertiary') return [];
    const shelf = body === 'waec' ? WAEC_CATALOG : body === 'neco' ? NECO_CATALOG : JAMB_CATALOG;
    return shelf.map((s) => ({
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
      setNotice('Could not open that course just now - it will open once the connection is back.');
    } finally {
      setLoading(false);
    }
  }, []);

  /** Add/remove one course id on the real list (the desk rows toggle). */
  const toggleCourse = useCallback(async (courseId: string) => {
    if (!mine) return;
    const has = mine.some((m) => m.id === courseId);
    const next = has
      ? mine.filter((m) => m.id !== courseId).map((m) => m.id)
      : [...mine.map((m) => m.id), courseId];
    try {
      const res = await setMyCourses(next);
      setMine(res.courses);
      cacheMine(res.courses);
    } catch {
      setNotice('That change did not stick - check your connection and try again.');
    }
  }, [mine]);

  /** Merge a batch of picks (the AI finder) into the real list. */
  const addCourses = useCallback(async (ids: string[]) => {
    if (!mine || ids.length === 0) return;
    setSaving(true);
    try {
      const merged = Array.from(new Set([...mine.map((m) => m.id), ...ids]));
      const res = await setMyCourses(merged);
      setMine(res.courses);
      cacheMine(res.courses);
    } catch {
      setNotice('Saving your courses failed - check your connection and try again.');
    } finally {
      setSaving(false);
    }
  }, [mine]);

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
      {/* Founder directive 2026-10-15: the courses area carries NO
          top button / header anymore - the PageBar is a plain back +
          title bar (the Add-remove / Done pills that used to ride it
          are gone; the affordances live inline with the list they
          act on). */}
      <PageBar
        title={face === 'path' && path ? path.title : 'Course'}
        backHref="/dashboard"
      />

      <main className="mx-auto w-full max-w-3xl px-4 pb-28 pt-4">
        {notice && (
          <p className="mb-3 rounded-xl bg-surface-container px-4 py-2.5 text-[12.5px] font-bold text-on-surface-variant">
            {notice}
          </p>
        )}
        {loading && <SkeletonList />}

        {/* Founder directive 2026-10-15 ("remove the desk switcher
            buttons from top of the School desk focus page"): the toggle
            pills - including the "JAMB desk" button - are NOT rendered
            while the tertiary / School desk is the focus. The JAMB desk
            stays reachable only from its own focus views (profile exam
            bodies / the secondary desks); the tertiary flow is a clean
            two-gate course desk. */}
        {!loading && face !== 'path' && body !== 'tertiary' && deskBodies.length > 1 && (
          <div className="no-scrollbar -mx-4 mb-3 flex items-center gap-1.5 overflow-x-auto px-4">
            {deskBodies.map((b) => (
              <button
                key={b}
                type="button"
                onClick={() => setBody(b)}
                aria-pressed={b === body}
                className={`whitespace-nowrap rounded-full border-2 px-3.5 py-1.5 text-[12px] font-extrabold transition active:translate-y-[1px] ${
                  b === body
                    ? 'border-primary bg-primary text-white'
                    : 'border-outline-variant bg-card text-on-surface-variant'
                }`}
              >
                {learnBodyLabel(b)} desk
              </button>
            ))}
          </div>
        )}

        {/* ── Face 1: my courses ── */}
        {!loading && face === 'list' && mine && (
          mine.length === 0 ? (
            <EmptyList tertiary={body === 'tertiary'} onChoose={() => setFace('select')} />
          ) : body === 'tertiary' ? (
            <TertiaryDesk
              mine={mine}
              onOpen={(id) => void openPath(id)}
              onToggle={(id) => void toggleCourse(id)}
              onAdd={(ids) => void addCourses(ids)}
              onNotice={setNotice}
            />
          ) : (
            <div className="flex flex-col gap-3">
              <p className="px-1 text-[12.5px] font-bold text-on-surface-variant">
                Your {learnBodyLabel(body)} desk courses - tap one to open its roadmap.
              </p>
              {mine
                .filter((c) => deskOf(c.body || body) === body)
                .map((c) => (
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
                          {c.completedTopics}/{c.topicCount} topics done
                        </span>
                        <span className="mt-1.5 block">
                          <ProgressBar value={c.topicCount ? (c.completedTopics / c.topicCount) * 100 : 0} />
                        </span>
                      </span>
                      <span className="material-symbols-outlined text-[20px] text-on-surface-variant">chevron_right</span>
                    </div>
                  </button>
                ))}
              {mine.filter((c) => deskOf(c.body || body) === body).length === 0 && (
                <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-8 text-center text-[13px] font-bold text-on-surface-variant">
                  No courses on this desk yet - switch the desk above or add more courses.
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
                      onClick={() => void toggleCourse(c.id)}
                      aria-pressed={inList}
                      className={`learn-tile flex w-full items-center gap-3 rounded-2xl border-2 p-3.5 text-left transition active:translate-y-[2px] ${
                        inList ? 'border-primary bg-primary/10' : 'border-outline-variant bg-card'
                      }`}
                    >
                      <span className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 transition ${
                        inList ? 'border-primary bg-primary text-white' : 'border-outline-variant bg-surface'
                      }`} aria-hidden>
                        {inList && <span className="material-symbols-outlined text-[16px]">check</span>}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[14.5px] font-extrabold text-on-surface">{c.title}</span>
                        <span className="block truncate text-[11.5px] font-bold text-on-surface-variant">
                          {c.topicCount} topics{inList ? ' · in your list' : ''}
                        </span>
                      </span>
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
              className="key-btn mx-auto mt-2 bg-primary text-white"
            >
              Done
            </button>
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
  onToggle: (courseId: string) => void;
  onAdd: (courseIds: string[]) => void;
  onNotice: (msg: string) => void;
}) {
  const [phase, setPhase] = useState<'load' | 'itype' | 'dept' | 'shelf'>('load');
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
  const [aiText, setAiText] = useState('');
  const [aiBusy, setAiBusy] = useState(false);
  const [aiLines, setAiLines] = useState<AIMatchLine[] | null>(null);
  const [aiPicked, setAiPicked] = useState<Set<string>>(new Set());

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
        setPhase('shelf');
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

  useEffect(() => { void loadShelf(); }, [loadShelf]);

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
      onAdd(ids); // the parent merges into the real list + device cache
      await loadShelf(); // refresh the shelf's inList flags
      setAiOpen(false);
      setAiText('');
      setAiLines(null);
      setAiPicked(new Set());
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

  // ── The shelf: general first, then the department ──
  const general = shelf?.general ?? [];
  const departmental = shelf?.departmental ?? [];
  const showSearch = query.trim().length >= 2;
  return (
    <div className="flex flex-col gap-4">
      {/* Desk header + change control */}
      <div className="flex items-center gap-2 rounded-2xl border-2 border-primary/40 bg-primary/10 px-4 py-3">
        <span className="material-symbols-outlined text-[20px] text-primary-ink">school</span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[14px] font-black text-on-surface">{shelf?.departmentName || 'Your department'}</p>
          <p className="text-[11.5px] font-bold text-on-surface-variant">{shelf?.institutionType || itype} · general courses + your department</p>
        </div>
        <button
          type="button"
          onClick={() => { setPhase('dept'); setDepQuery(''); }}
          className="shrink-0 rounded-xl border-2 border-outline-variant bg-card px-3 py-1.5 text-[11.5px] font-extrabold text-on-surface transition active:translate-y-[2px]"
        >
          Change
        </button>
      </div>

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
            {!searching && results !== null && results.length === 0 && (
              <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
                Nothing matches &ldquo;{query}&rdquo;. Try a course code (three letters) or a topic.
              </p>
            )}
            {!searching && (results ?? []).map((c) => (
              <DeskRow key={c.id} c={c} onOpen={() => c.inList && onOpen(c.id)} onToggle={() => onToggle(c.id)} />
            ))}
          </div>
        )}
      </div>

      {/* AI course finder */}
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
              className="key-btn mx-auto bg-primary text-white disabled:opacity-60"
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
                    className="key-btn mx-auto bg-primary text-white disabled:opacity-60"
                  >
                    {gateBusy ? 'Saving…' : `Add ${aiPicked.size} course${aiPicked.size === 1 ? '' : 's'} to my list`}
                  </button>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      {/* General shelf: the national first-year courses, GST suite first */}
      <section className="flex flex-col gap-2">
        <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
          {shelf?.institutionType === 'Polytechnic' ? 'ND I general courses' : shelf?.institutionType === 'College of Education' ? 'NCE I general courses' : '100 Level general courses'}
          <span className="ml-1.5 font-bold normal-case text-on-surface-variant/70">- everyone takes these</span>
        </h3>
        {general.map((c) => (
          <DeskRow key={c.id} c={c} onOpen={() => c.inList && onOpen(c.id)} onToggle={() => onToggle(c.id)} />
        ))}
        {general.length === 0 && (
          <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
            The general shelf is on its way - check your connection.
          </p>
        )}
      </section>

      {/* Department shelf */}
      {shelf?.departmentName && (
        <section className="flex flex-col gap-2">
          <h3 className="px-1 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">
            {shelf.departmentName} courses
          </h3>
          {departmental.map((c) => (
            <DeskRow key={c.id} c={c} onOpen={() => c.inList && onOpen(c.id)} onToggle={() => onToggle(c.id)} />
          ))}
          {departmental.length === 0 && (
            <p className="rounded-2xl border-2 border-dashed border-outline-variant bg-card px-5 py-6 text-center text-[12.5px] font-bold text-on-surface-variant">
              No courses listed for this department yet.
            </p>
          )}
        </section>
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
          c.inList ? 'border-primary bg-primary text-white' : 'border-outline-variant bg-surface'
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
                    <span className="material-symbols-outlined text-[15px]">trophy</span>
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

function EmptyList({ tertiary, onChoose }: { tertiary: boolean; onChoose: () => void }) {
  return (
    <div className="learn-tile flex flex-col items-center gap-3 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-6 py-12 text-center">
      <span className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/15">
        <span className="material-symbols-outlined text-[32px] text-primary-ink">menu_book</span>
      </span>
      <h2 className="text-[17px] font-black text-on-surface">Build your course list</h2>
      <p className="max-w-sm text-[13.5px] font-bold leading-snug text-on-surface-variant">
        {tertiary
          ? 'Pick your institution kind and department first - your general courses and department courses appear right after.'
          : 'Mark every course you want on your desk - each one becomes a long roadmap of topics, notes with real drawings, and your actual past questions.'}
      </p>
      {!tertiary && <button type="button" onClick={onChoose} className="key-btn mt-1 bg-primary text-white">Choose courses</button>}
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
