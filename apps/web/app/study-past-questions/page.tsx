'use client';

/**
 * Study Past Questions - the school app's study setup, Renance cut.
 *
 * The Study tile on the desk lands here. Per focus (JAMB / WAEC / NECO
 * / Post UTME / School Desk) the page carries:
 *   · the tinted header band (back circle, title, the green book seal)
 *   (the Update Questions banner is app-only; the web reads the
 *    static shelf directly)
 *   · the full picker form - Subject, Examination Type, Year, Question
 *     type, Topic - and Start Study
 *
 * Start Study opens the browsable Past-Questions reader
 * (/study-past-questions/reader): untimed, explanations inlined, no
 * grading ceremony - reading past questions is the point here.
 */

import { Suspense, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { fetchBankBundle, fetchManifest, migrateBundleCache, subjectName, type ExamMeta } from '@/lib/exams';
import {
  SCHOOLS,
  clientCatalog,
  liveCourses,
  resolveSchoolSlug,
  storedPostUtmeSchoolSlug,
  storedSchoolSlug,
} from '@/lib/university';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';

type Body = 'jamb' | 'waec' | 'neco' | 'post-utme' | 'university';
type Qt = 'all' | 'objective' | 'theory';

const BODY_LABEL: Record<Body, string> = {
  jamb: 'JAMB',
  waec: 'WAEC',
  neco: 'NECO',
  'post-utme': 'Post UTME',
  university: 'School Desk (University)',
};

interface SubjectRow {
  id: string;
  name: string;
  /** Backing bank code (uni students: the course pack code). */
  bank: string;
  count: number;
  years: number[];
}

export default function StudySetupPage() {
  return (
    <Suspense fallback={null}>
      <StudySetupInner />
    </Suspense>
  );
}

function StudySetupInner() {
  const router = useRouter();
  const params = useSearchParams();
  // ?body= pins the focus (the desk tiles can deep-link a body); the
  // default is JAMB, the desk's opening hand.
  const focusParam = params.get('body');

  const [body, setBody] = useState<Body>(() => {
    const b = focusParam;
    if (b === 'waec' || b === 'neco' || b === 'university' || b === 'post-utme') return b;
    return 'jamb';
  });

  // The focus pins the exam type (the desk tiles deep-link ?body=);
  // the setup page never offers an exam-type switcher.
  useEffect(() => {
    const b = focusParam;
    setBody(b === 'waec' || b === 'neco' || b === 'university' || b === 'post-utme' ? b : 'jamb');
  }, [focusParam]);

  const [exams, setExams] = useState<ExamMeta[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [schoolSlug, setSchoolSlug] = useState<string | null>(null);
  const [subject, setSubject] = useState('');
  const [year, setYear] = useState<number | null>(null);
  const [qt, setQt] = useState<Qt>('all');
  const [topic, setTopic] = useState('');
  const [topics, setTopics] = useState<string[]>([]);
  const [topicsLoading, setTopicsLoading] = useState(false);
  const [starting, setStarting] = useState(false);

  // The manifest powers both the subject lists and the year pickers.
  useEffect(() => {
    migrateBundleCache();
    let alive = true;
    fetchManifest()
      .then((m) => alive && setExams(m.exams))
      .catch(() => alive && setLoadError('Could not load the question manifest. Check your connection.'));
    return () => {
      alive = false;
    };
  }, []);

  // The school pick (tertiary): stored → bundled default (FUTA). The
  // Post UTME desk keeps its own pick, separate from the School Desk's.
  useEffect(() => {
    if (body === 'university') {
      const stored = storedSchoolSlug();
      setSchoolSlug(stored ?? resolveSchoolSlug());
      return;
    }
    if (body === 'post-utme') {
      setSchoolSlug(storedPostUtmeSchoolSlug());
    }
  }, [body]);

  /** Subjects available for the chosen focus, from the real manifest. */
  const subjects: SubjectRow[] = useMemo(() => {
    if (!exams) return [];
    if (body === 'university') {
      const catalog = clientCatalog(schoolSlug ?? '');
      return liveCourses(catalog).map((c) => ({
        id: c.bank as string,
        name: c.title ? `${c.code} · ${c.title}` : c.code,
        bank: c.bank as string,
        count: c.questionCount,
        years: [],
      }));
    }
    if (body === 'post-utme') {
      // The picked school's own prep banks first, then the general
      // practice banks, every one of them a real manifest pack.
      const rows: SubjectRow[] = [];
      if (schoolSlug) {
        for (const e of exams) {
          const match = new RegExp(`^uni-${schoolSlug}-pq-(.+)-bank$`).exec(e.code);
          if (!match) continue;
          rows.push({
            id: e.code,
            name: subjectName(match[1]),
            bank: e.code,
            count: e.questionCount,
            years: e.years ?? [],
          });
        }
      }
      for (const e of exams) {
        const match = /^post_utme-(.+)-questions-bank$/.exec(e.code);
        if (!match) continue;
        rows.push({
          id: e.code,
          name: subjectName(match[1]),
          bank: e.code,
          count: e.questionCount,
          years: e.years ?? [],
        });
      }
      return rows;
    }
    const hit = new RegExp(`^${body}-(.+)-bank$`);
    const rows: SubjectRow[] = [];
    const seen = new Set<string>();
    for (const e of exams) {
      const match = hit.exec(e.code);
      if (!match) continue;
      const slug = match[1];
      if (!slug || slug.endsWith('-enrich')) continue; // enrichment forks ride the base bank
      if (seen.has(slug)) {
        const row = rows.find((r) => r.id === slug);
        if (row) row.count += e.questionCount;
        continue;
      }
      seen.add(slug);
      rows.push({ id: slug, name: subjectName(slug), bank: e.code, count: e.questionCount, years: e.years ?? [] });
    }
    return rows.sort((a, b) => a.name.localeCompare(b.name));
  }, [exams, body, schoolSlug]);

  // Keep the picks valid whenever the focus flips.
  useEffect(() => {
    setSubject('');
    setYear(null);
    setTopic('');
    setTopics([]);
  }, [body, schoolSlug]);

  // Topic options load from the chosen bank (this also warms the IDB
  // cache the reader will read from). Fails soft: "All topics" only.
  useEffect(() => {
    if (!subject || !exams) {
      setTopics([]);
      return;
    }
    let alive = true;
    setTopicsLoading(true);
    setTopic('');
    const bank = subjects.find((s) => s.id === subject)?.bank ?? subject;
    fetchBankBundle(bank)
      .then((b) => {
        if (!alive) return;
        const set = new Set<string>();
        for (const q of b.questions) {
          if (q.topic) set.add(q.topic);
        }
        setTopics([...set].sort((a, b2) => a.localeCompare(b2)).slice(0, 400));
      })
      .catch(() => alive && setTopics([]))
      .finally(() => alive && setTopicsLoading(false));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [subject]);

  const years = useMemo(() => {
    const row = subjects.find((s) => s.id === subject);
    return row ? [...row.years].sort((a, b) => b - a) : [];
  }, [subjects, subject]);

  /** Schools with banked Post-UTME prep packs, for the inline picker. */
  const pqSchools = useMemo(() => {
    if (!exams) return [];
    const slugs = new Set<string>();
    for (const e of exams) {
      const m = /^uni-([a-z0-9-]+)-pq-/.exec(e.code);
      if (m) slugs.add(m[1]);
    }
    return SCHOOLS.filter((s) => slugs.has(s.slug));
  }, [exams]);

  function startStudy() {
    if (!subject) return;
    setStarting(true);
    const query = new URLSearchParams();
    query.set('body', body);
    query.set('subject', subject);
    // The reader fetches the bank pack directly - hand it the code.
    const bank = subjects.find((s) => s.id === subject)?.bank;
    if (bank) query.set('bank', bank);
    if (year) query.set('year', String(year));
    if (qt !== 'all') query.set('qt', qt);
    if (topic) query.set('topic', topic);
    if (body === 'university' && schoolSlug) query.set('school', schoolSlug);
    if (body === 'post-utme' && schoolSlug) query.set('school', schoolSlug);
    router.push(`/study-past-questions/reader?${query.toString()}`);
  }

  const canStart = Boolean(subject) && !starting;

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      {/* ---- tinted header band ------------------------------------ */}
      <div className="w-full bg-[#FDF1EE] dark:bg-surface-container-low">
        <div className="mx-auto flex w-full max-w-2xl items-start gap-3.5 px-4 pb-[18px] pt-3 sm:px-6">
          <button
            onClick={() => router.push('/dashboard')}
            aria-label="Back to dashboard"
            className="mt-1 flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-outline-variant bg-card text-on-surface transition hover:bg-surface-container-low"
          >
            <span className="material-symbols-outlined text-[20px]">arrow_back</span>
          </button>
          <div className="min-w-0 flex-1 pt-1.5">
            <h1 className="text-[20px] font-bold tracking-tight text-on-surface">Study Past Questions</h1>
            <p className="mt-0.5 text-[14px] text-on-surface-variant">
              Get all exam questions from 1978 till date
            </p>
          </div>
          <span className="flex h-[46px] w-[46px] shrink-0 items-center justify-center rounded-full bg-accent-emerald text-white shadow-sm">
            <span className="material-symbols-outlined text-[22px]">menu_book</span>
          </span>
        </div>
      </div>

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-4 sm:px-6 lg:max-w-4xl">
            {/* ---- the picker form (focus IS the exam type: the desk
                 deep-links ?body=; no exam-type picker here) --------- */}
            <div className="mt-5 space-y-4">
              {loadError && (
                <p className="rounded-xl bg-error-container px-4 py-3 text-[13px] text-on-error-container">{loadError}</p>
              )}

              <div className="flex items-center gap-2 rounded-[12px] bg-surface-container-low px-4 py-3">
                <span className="material-symbols-outlined text-[18px] text-on-surface-variant">bookmark</span>
                <span className="text-[13px] text-on-surface-variant">Focus</span>
                <span className="ml-auto rounded-full bg-primary px-3 py-1 text-[12.5px] font-bold text-on-primary">
                  {BODY_LABEL[body]}
                </span>
              </div>

              <div className="grid gap-4 lg:grid-cols-2">
              {body === 'university' && (
                <Field label="School">
                  <select
                    value={schoolSlug ?? ''}
                    onChange={(e) => setSchoolSlug(e.target.value)}
                    className={selectCls}
                  >
                    {!schoolSlug && <option value="">Select School</option>}
                    {SCHOOLS.map((s) => (
                      <option key={s.slug} value={s.slug}>
                        {s.name}
                      </option>
                    ))}
                  </select>
                </Field>
              )}

              {body === 'post-utme' && (
                <Field label="School">
                  <select
                    value={schoolSlug ?? ''}
                    onChange={(e) => setSchoolSlug(e.target.value || null)}
                    className={selectCls}
                  >
                    <option value="">General practice (all schools)</option>
                    {pqSchools.map((s) => (
                      <option key={s.slug} value={s.slug}>
                        {s.name}
                      </option>
                    ))}
                  </select>
                </Field>
              )}

              <Field label="Subject">
                <select value={subject} onChange={(e) => setSubject(e.target.value)} className={selectCls}>
                  <option value="">{exams ? 'Select Subject' : 'Loading subjects…'}</option>
                  {subjects.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name} ({s.count.toLocaleString()} Q)
                    </option>
                  ))}
                </select>
              </Field>

              {body !== 'university' && (
                <Field label="Year">
                  <select
                    value={year ?? ''}
                    onChange={(e) => setYear(e.target.value ? Number(e.target.value) : null)}
                    className={selectCls}
                    disabled={!subject}
                  >
                    <option value="">All years (random)</option>
                    {years.map((y) => (
                      <option key={y} value={y}>
                        {y}
                      </option>
                    ))}
                  </select>
                </Field>
              )}

              <Field label="Question type">
                <select value={qt} onChange={(e) => setQt(e.target.value as Qt)} className={selectCls}>
                  <option value="all">All questions</option>
                  <option value="objective">Objectives (multiple choice)</option>
                  <option value="theory">Theory / essays</option>
                </select>
              </Field>

              <Field label="Topic">
                <select
                  value={topic}
                  onChange={(e) => setTopic(e.target.value)}
                  className={selectCls}
                  disabled={!subject || topicsLoading}
                >
                  <option value="">{topicsLoading ? 'Loading topics…' : 'All topics'}</option>
                  {topics.map((t) => (
                    <option key={t} value={t}>
                      {t}
                    </option>
                  ))}
                </select>
              </Field>
              </div>
            </div>

            <button
              onClick={startStudy}
              disabled={!canStart}
              className="mt-6 flex h-[54px] w-full items-center justify-center gap-2 rounded-[12px] bg-primary text-[15px] font-bold text-on-primary shadow-md transition hover:shadow-lg active:scale-[0.99] disabled:opacity-50"
            >
              <span className="material-symbols-outlined text-[20px]">menu_book</span>
              {starting ? 'Opening…' : 'Start Study'}
            </button>
            <p className="mt-2 text-center text-[12px] text-on-surface-variant">
              Untimed · browse every question with its explanation
            </p>

            <Link
              href="/study"
              className="mt-6 flex items-center justify-between rounded-[12px] border border-outline-variant/50 bg-card px-4 py-3.5 transition hover:bg-surface-container-low"
            >
              <span className="flex items-center gap-2.5">
                <span className="material-symbols-outlined text-[20px] text-on-surface">auto_stories</span>
                <span>
                  <span className="block text-[14px] font-semibold text-on-surface">Study Resources</span>
                  <span className="block text-[12px] text-on-surface-variant">
                    Free PDFs, textbooks and archives for your exam
                  </span>
                </span>
              </span>
              <span className="material-symbols-outlined text-[18px] text-outline">chevron_right</span>
            </Link>
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}

const selectCls =
  'h-[52px] w-full rounded-[12px] border border-outline-variant bg-card px-4 text-[15px] text-on-surface outline-none transition focus:border-primary disabled:opacity-60';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block px-1 text-[13px] font-semibold text-on-surface-variant">{label}</span>
      {children}
    </label>
  );
}
