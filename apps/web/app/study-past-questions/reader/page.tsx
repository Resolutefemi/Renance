'use client';

/**
 * The Past-Questions reader — the school app's study reading surface,
 * Renance cut.
 *
 * Opens over one bank (the study setup composes the picks), filters
 * applied client-side from the same bundle: year, question type,
 * topic, and a live search. Every card carries its options and a
 * "View Explanation" button that opens the Myschool-positioned
 * ExplanationSheet (Save · correct-option check · Report · Prev/Next ·
 * Get Renance's AI Explanation).
 *
 * This page is a READER, not an exam: untimed, nothing submits, no
 * grading ceremony. The bottom "N Questions" strip jumps between
 * cards the way the school app's navigator does.
 */

import { Suspense, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { fetchBankBundle, subjectName, type Bundle, type BundleQuestion } from '@/lib/exams';
import { QText, apiImg } from '@/lib/qtext';
import ExplanationSheet, { type ExplanationData } from '@/components/explanation-sheet';

export default function StudyReaderPage() {
  return (
    <Suspense fallback={null}>
      <ReaderInner />
    </Suspense>
  );
}

function ReaderInner() {
  const router = useRouter();
  const params = useSearchParams();
  const body = params.get('body') ?? 'jamb';
  const subject = params.get('subject') ?? '';
  // The bank code the setup resolved (`jamb-biology-bank`, a uni course
  // pack, …) — the reader reads that pack directly.
  const bank = params.get('bank') ?? '';
  const year = params.get('year');
  const qt = params.get('qt') ?? 'all';
  const topicParam = params.get('topic') ?? '';
  const school = params.get('school');

  const [bundle, setBundle] = useState<Bundle | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [yearFilter, setYearFilter] = useState<number | null>(year ? Number(year) : null);
  const [qtFilter, setQtFilter] = useState<'all' | 'objective' | 'theory'>(qt === 'theory' || qt === 'objective' ? qt : 'all');
  const [topicFilter, setTopicFilter] = useState(topicParam);
  const [search, setSearch] = useState('');
  const [limit, setLimit] = useState(25);
  const [sheetIdx, setSheetIdx] = useState<number | null>(null);

  const listTopRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!subject) {
      router.replace('/study-past-questions');
      return;
    }
    const code = bank || subject;
    let alive = true;
    // The bank ships statically (scripts/web_bundles.py); a code that
    // misses the static shelf falls back to the API inside
    // fetchBankBundle. Year pins play out as a client-side filter here
    // — the reader never needs the compose machinery.
    fetchBankBundle(code)
      .then((b) => alive && setBundle(b))
      .catch(() => alive && setError('Could not load this question bank. Update your questions and try again.'));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [subject, bank]);

  /** Years present in the bank (the reader's own year chip set). */
  const bankYears = useMemo(() => {
    const set = new Set<number>();
    for (const q of bundle?.questions ?? []) if (q.year) set.add(q.year);
    return [...set].sort((a, b) => b - a);
  }, [bundle]);

  const topics = useMemo(() => {
    const set = new Set<string>();
    for (const q of bundle?.questions ?? []) if (q.topic) set.add(q.topic);
    return [...set].sort((a, b) => a.localeCompare(b));
  }, [bundle]);

  const filtered = useMemo(() => {
    const all = bundle?.questions ?? [];
    const needle = search.trim().toLowerCase();
    return all.filter((q) => {
      if (yearFilter && q.year !== yearFilter) return false;
      if (qtFilter === 'theory' && q.type !== 'theory') return false;
      if (qtFilter === 'objective' && q.type === 'theory') return false;
      if (topicFilter && q.topic !== topicFilter) return false;
      if (needle && !q.stem.toLowerCase().includes(needle)) return false;
      return true;
    });
  }, [bundle, yearFilter, qtFilter, topicFilter, search]);

  const title = useMemo(() => {
    if (body === 'university') return subject.replace(/^-|-$/g, '').toUpperCase();
    return `${subjectName(subject)} · Study`;
  }, [body, subject]);

  if (error) {
    return (
      <Centered>
        <p className="max-w-md rounded-xl bg-error-container px-5 py-4 text-center text-sm text-on-error-container">
          {error}
        </p>
        <Link href="/study-past-questions" className="mt-4 text-sm text-primary underline-offset-4 hover:underline">
          ← back to the study setup
        </Link>
      </Centered>
    );
  }

  if (!bundle) {
    return (
      <Centered>
        <span className="material-symbols-outlined animate-spin text-3xl text-on-surface-variant">progress_activity</span>
        <p className="mt-2 text-sm text-on-surface-variant">Opening the questions…</p>
      </Centered>
    );
  }

  const visible = filtered.slice(0, limit);

  function jumpTo(i: number) {
    setLimit(Math.max(limit, i + 1));
    requestAnimationFrame(() => {
      listTopRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  const sheetQuestion: ExplanationData | null =
    sheetIdx != null && filtered[sheetIdx]
      ? {
          questionId: filtered[sheetIdx].id,
          code: bundle.code,
          title: title,
          stem: filtered[sheetIdx].stem,
          passage: filtered[sheetIdx].passage,
          image: filtered[sheetIdx].image,
          options: filtered[sheetIdx].options ?? {},
          correct: filtered[sheetIdx].answer ?? '',
          explanation: filtered[sheetIdx].explanation,
          topic: filtered[sheetIdx].topic,
          year: filtered[sheetIdx].year,
        }
      : null;

  return (
    <main className="min-h-dvh bg-surface pb-40 md:pl-[var(--rail-w)]">
      {/* ---- header band ------------------------------------------- */}
      <div className="sticky top-0 z-40 border-b border-outline-variant/40 bg-surface/90 backdrop-blur-xl">
        <div className="mx-auto w-full max-w-2xl px-4 pt-3 sm:px-6">
          <div className="flex items-center gap-3">
            <button
              onClick={() => router.push('/study-past-questions')}
              aria-label="Back to study setup"
              className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-outline-variant bg-card text-on-surface transition hover:bg-surface-container-low"
            >
              <span className="material-symbols-outlined text-[20px]">arrow_back</span>
            </button>
            <div className="min-w-0 flex-1">
              <h1 className="truncate text-[17px] font-bold tracking-tight text-on-surface">{title}</h1>
              <p className="text-[12.5px] text-on-surface-variant">
                {filtered.length.toLocaleString()} of {bundle.questionCount.toLocaleString()} questions
              </p>
            </div>
          </div>
          {/* type chips — All / Objectives / Theory, the reader's grammar */}
          <div className="no-scrollbar flex items-center gap-2 overflow-x-auto pb-2.5 pt-2.5">
            {(
              [
                ['all', `All (${bundle.questionCount.toLocaleString()})`],
                ['objective', 'Objectives'],
                ['theory', 'Theory'],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                onClick={() => {
                  setQtFilter(key);
                  setLimit(25);
                }}
                className={`shrink-0 rounded-full px-4 py-1.5 font-mono text-xs transition ${
                  qtFilter === key
                    ? 'bg-selection-blue font-semibold text-on-surface'
                    : 'bg-surface-container-low text-on-surface-variant hover:text-on-surface'
                }`}
              >
                {label}
              </button>
            ))}
            {bankYears.length > 0 && (
              <select
                value={yearFilter ?? ''}
                onChange={(e) => {
                  setYearFilter(e.target.value ? Number(e.target.value) : null);
                  setLimit(25);
                }}
                className="h-[34px] shrink-0 rounded-full border border-outline-variant bg-card px-3 text-xs text-on-surface outline-none"
                aria-label="Filter by year"
              >
                <option value="">All years</option>
                {bankYears.map((y) => (
                  <option key={y} value={y}>
                    {y}
                  </option>
                ))}
              </select>
            )}
            {topics.length > 0 && (
              <select
                value={topicFilter}
                onChange={(e) => {
                  setTopicFilter(e.target.value);
                  setLimit(25);
                }}
                className="h-[34px] max-w-[180px] shrink-0 rounded-full border border-outline-variant bg-card px-3 text-xs text-on-surface outline-none"
                aria-label="Filter by topic"
              >
                <option value="">All topics</option>
                {topics.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            )}
          </div>
          {/* search */}
          <div className="relative pb-3">
            <span className="material-symbols-outlined pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[18px] text-outline">
              search
            </span>
            <input
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setLimit(25);
              }}
              placeholder="Search the questions…"
              className="h-10 w-full rounded-full border border-outline-variant bg-card pl-9 pr-3 text-[13.5px] text-on-surface outline-none transition placeholder:text-outline focus:border-primary"
            />
          </div>
        </div>
      </div>

      {/* ---- question cards ----------------------------------------- */}
      <div ref={listTopRef} className="mx-auto w-full max-w-2xl scroll-mt-44 px-4 pt-4 sm:px-6">
        {visible.length === 0 && (
          <p className="rounded-xl bg-card p-6 text-center text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            No questions match these filters yet.
          </p>
        )}
        <div className="space-y-4">
          {visible.map((q) => {
            const idx = filtered.indexOf(q);
            return <ReaderCard key={q.id} q={q} n={idx + 1} onExplain={() => setSheetIdx(idx)} />;
          })}
        </div>
        {filtered.length > visible.length && (
          <button
            onClick={() => setLimit((l) => l + 25)}
            className="mt-4 flex h-12 w-full items-center justify-center rounded-[12px] border border-outline-variant bg-card text-[14px] font-semibold text-on-surface transition hover:bg-surface-container-low"
          >
            Show 25 more · {filtered.length - visible.length} left
          </button>
        )}
      </div>

      {/* ---- bottom N-Questions strip ------------------------------- */}
      {filtered.length > 0 && (
        <div className="fixed inset-x-0 bottom-0 z-40 border-t border-outline-variant/40 bg-surface/95 pb-[max(env(safe-area-inset-bottom),8px)] backdrop-blur-xl md:left-[var(--rail-w)]">
          <div className="mx-auto flex w-full max-w-2xl items-center gap-3 px-4 py-2.5 sm:px-6">
            <span className="shrink-0 rounded-full bg-primary px-3.5 py-1.5 text-[12.5px] font-bold text-on-primary">
              {filtered.length} Questions
            </span>
            <div className="no-scrollbar flex flex-1 items-center gap-1.5 overflow-x-auto">
              {filtered.slice(0, 120).map((q, i) => (
                <button
                  key={q.id}
                  onClick={() => jumpTo(i)}
                  aria-label={`Go to question ${i + 1}`}
                  className={`flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full border text-[12.5px] font-semibold transition ${
                    i < limit ? 'border-primary/60' : 'border-outline-variant/60'
                  } bg-card text-on-surface-variant hover:border-primary`}
                >
                  {i + 1}
                </button>
              ))}
              {filtered.length > 120 && (
                <span className="shrink-0 px-1 font-mono text-[11px] text-outline">+{filtered.length - 120}</span>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ---- the explanation sheet (Myschool position) --------------- */}
      {sheetQuestion && (
        <ExplanationSheet
          open
          onClose={() => setSheetIdx(null)}
          number={(sheetIdx ?? 0) + 1}
          question={sheetQuestion}
          onPrevious={sheetIdx! > 0 ? () => setSheetIdx(sheetIdx! - 1) : undefined}
          onNext={sheetIdx! < filtered.length - 1 ? () => setSheetIdx(sheetIdx! + 1) : undefined}
        />
      )}
    </main>
  );
}

/** One reader card: N pill, stem, quiet options, View Explanation. */
function ReaderCard({ q, n, onExplain }: { q: BundleQuestion; n: number; onExplain: () => void }) {
  const [copied, setCopied] = useState(false);
  return (
    <article className="rounded-[12px] border border-outline-variant/40 bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] sm:p-5">
      <div className="flex items-center gap-2">
        <span className="rounded-full bg-surface-container-low px-3 py-1 font-mono text-[12.5px] font-semibold text-on-surface">
          Q{n}
        </span>
        {q.topic && (
          <span className="rounded-full bg-surface-container-low px-2.5 py-1 text-[11px] text-on-surface-variant">
            {q.topic}
            {q.year ? <span className="ml-1 font-mono text-[10px] text-outline">{q.year}</span> : null}
          </span>
        )}
        <button
          onClick={() => {
            const buf = [q.stem];
            for (const [k, v] of Object.entries(q.options ?? {})) buf.push(`${k}) ${v}`);
            void navigator.clipboard?.writeText(buf.join('\n')).then(() => {
              setCopied(true);
              setTimeout(() => setCopied(false), 1200);
            });
          }}
          className="ml-auto flex h-8 w-8 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container-low"
          aria-label="Copy question"
          title="Copy question"
        >
          <span className="material-symbols-outlined text-[17px]">{copied ? 'check' : 'content_copy'}</span>
        </button>
      </div>

      {q.passage && (
        <details className="mt-3 rounded-lg border border-outline-variant/40 bg-surface-container-lowest/60">
          <summary className="cursor-pointer select-none px-3 py-2 font-mono text-[10px] uppercase tracking-wider text-outline">
            comprehension passage
          </summary>
          <div className="max-h-52 overflow-y-auto px-3 pb-3 text-[14px] leading-relaxed text-on-surface">
            <QText html={q.passage} />
          </div>
        </details>
      )}

      <div className="mt-3 text-[15.5px] leading-relaxed text-on-surface">
        <QText html={q.stem} />
      </div>
      {q.image && (
        <div className="mt-3 flex justify-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={apiImg(q.image)}
            alt="question diagram"
            loading="lazy"
            className="max-h-64 max-w-full rounded-lg border border-outline-variant/40 bg-card object-contain"
          />
        </div>
      )}

      {q.options && Object.keys(q.options).length > 0 && (
        <div className="mt-3 space-y-1.5">
          {Object.entries(q.options).map(([letter, text]) => (
            <div key={letter} className="flex items-start gap-2.5 rounded-lg bg-surface-container-lowest/50 px-3 py-2">
              <span className="text-[13px] font-bold text-error/80">{letter}</span>
              <span className="min-w-0 flex-1 text-[13.5px] leading-snug text-on-surface">
                <QText html={text} />
              </span>
            </div>
          ))}
        </div>
      )}

      <button
        onClick={onExplain}
        className="mt-3.5 flex h-11 w-full items-center justify-center gap-2 rounded-[10px] bg-accent-ink text-[13.5px] font-bold text-white transition hover:opacity-90 active:scale-[0.99]"
      >
        <span className="material-symbols-outlined text-[17px]">auto_stories</span>
        View Explanation
      </button>
    </article>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-background px-6">
      {children}
    </main>
  );
}
