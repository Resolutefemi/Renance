'use client';

/**
 * Saved Questions — the reading shelf behind the explanation sheet's
 * Save button (Myschool's bookmark drawer, Renance edition).
 *
 * Every saved row is a full question snapshot, so the shelf works
 * offline forever: search, reopen the explanation sheet (Save state,
 * correct-option check, Report, Prev/Next, the AI pill), or delete.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { QText, apiImg } from '@/lib/qtext';
import { clearSaved, listSaved, removeSaved, type SavedQuestion } from '@/lib/saved-questions';
import ExplanationSheet, { type ExplanationData } from '@/components/explanation-sheet';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';

export default function SavedQuestionsPage() {
  const [rows, setRows] = useState<SavedQuestion[] | null>(null);
  const [search, setSearch] = useState('');
  const [sheetIdx, setSheetIdx] = useState<number | null>(null);

  useEffect(() => {
    setRows(listSaved());
  }, []);

  const filtered = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return rows ?? [];
    return (rows ?? []).filter(
      (q) => q.stem.toLowerCase().includes(needle) || q.title.toLowerCase().includes(needle),
    );
  }, [rows, search]);

  const sheetQuestion: ExplanationData | null =
    sheetIdx != null && filtered[sheetIdx]
      ? {
          questionId: filtered[sheetIdx].questionId,
          code: filtered[sheetIdx].code,
          title: filtered[sheetIdx].title,
          stem: filtered[sheetIdx].stem,
          passage: filtered[sheetIdx].passage,
          image: filtered[sheetIdx].image,
          options: filtered[sheetIdx].options,
          correct: filtered[sheetIdx].correct,
          explanation: filtered[sheetIdx].explanation,
          topic: filtered[sheetIdx].topic,
          year: filtered[sheetIdx].year,
        }
      : null;

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <div className="sticky top-0 z-40 border-b border-outline-variant/40 bg-surface/80 backdrop-blur-xl">
        <div className="mx-auto w-full max-w-2xl px-4 pt-3 sm:px-6">
          <div className="flex items-center gap-2">
            <Link
              href="/dashboard"
              aria-label="Back to dashboard"
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container"
            >
              <span className="material-symbols-outlined text-[22px]">arrow_back</span>
            </Link>
            <h1 className="min-w-0 flex-1 text-[15px] font-semibold text-on-surface md:text-[17px]">Saved Questions</h1>
            {(rows?.length ?? 0) > 0 && (
              <button
                onClick={() => {
                  if (window.confirm('Remove every saved question?')) {
                    clearSaved();
                    setRows([]);
                  }
                }}
                className="shrink-0 rounded-full px-3 py-1.5 text-[12.5px] font-semibold text-error transition hover:bg-error-container/30"
              >
                Clear all
              </button>
            )}
          </div>
          <div className="relative pb-3 pt-2.5">
            <span className="material-symbols-outlined pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[18px] text-outline">
              search
            </span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search saved questions…"
              className="h-10 w-full rounded-full border border-outline-variant bg-card pl-9 pr-3 text-[13.5px] text-on-surface outline-none transition placeholder:text-outline focus:border-primary"
            />
          </div>
        </div>
      </div>

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-4 sm:px-6">
        {rows === null && <p className="text-sm text-on-surface-variant">Opening the shelf…</p>}
        {rows !== null && filtered.length === 0 && (
          <div className="rounded-[14px] bg-card p-8 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <span className="material-symbols-outlined text-[40px] text-outline">bookmark</span>
            <p className="mt-2 text-[15px] font-medium text-on-surface">
              {search ? 'Nothing matches that search.' : 'No saved questions yet.'}
            </p>
            <p className="mt-1.5 text-[13px] leading-relaxed text-on-surface-variant">
              Tap <span className="font-semibold text-on-surface">Save</span> on any explanation sheet, or the
              bookmark in the Past-Questions reader, and the question lands here.
            </p>
            <Link
              href="/study-past-questions"
              className="mt-4 inline-flex h-11 items-center rounded-[10px] bg-primary px-5 text-[13.5px] font-semibold text-on-primary"
            >
              Go to Study
            </Link>
          </div>
        )}

        <div className="space-y-3">
          {filtered.map((q, i) => (
            <article
              key={q.questionId + i}
              className="rounded-[12px] border border-outline-variant/40 bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]"
            >
              <div className="flex items-center gap-2">
                <span className="flex items-center gap-1 rounded-full bg-surface-container-low px-2.5 py-1 text-[11px] text-on-surface-variant">
                  <span className="material-symbols-outlined fill-current text-[13px] text-error">bookmark</span>
                  {q.title || q.code}
                </span>
                {q.topic && (
                  <span className="rounded-full bg-surface-container-low px-2.5 py-1 text-[11px] text-on-surface-variant">
                    {q.topic}
                  </span>
                )}
                <button
                  onClick={() => {
                    removeSaved(q.questionId);
                    setRows(listSaved());
                  }}
                  aria-label="Remove saved question"
                  className="ml-auto flex h-8 w-8 items-center justify-center rounded-full text-error transition hover:bg-error-container/30"
                >
                  <span className="material-symbols-outlined text-[17px]">delete</span>
                </button>
              </div>
              <div className="mt-2.5 line-clamp-3 text-[14.5px] leading-relaxed text-on-surface">
                <QText html={q.stem} />
              </div>
              {q.image && (
                <div className="mt-2">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={apiImg(q.image)}
                    alt="question diagram"
                    loading="lazy"
                    className="max-h-36 max-w-full rounded-lg border border-outline-variant/40 object-contain"
                  />
                </div>
              )}
              <button
                onClick={() => setSheetIdx(i)}
                className="mt-3 flex h-11 w-full items-center justify-center gap-2 rounded-[10px] bg-accent-ink text-[13.5px] font-bold text-white transition hover:opacity-90 active:scale-[0.99]"
              >
                <span className="material-symbols-outlined text-[17px]">auto_stories</span>
                View Explanation
              </button>
            </article>
          ))}
        </div>
      </div>

      {sheetQuestion && (
        <ExplanationSheet
          open
          onClose={() => {
            setSheetIdx(null);
            setRows(listSaved()); // Save state may have flipped
          }}
          number={(sheetIdx ?? 0) + 1}
          question={sheetQuestion}
          onPrevious={sheetIdx! > 0 ? () => setSheetIdx(sheetIdx! - 1) : undefined}
          onNext={sheetIdx! < filtered.length - 1 ? () => setSheetIdx(sheetIdx! + 1) : undefined}
        />
      )}

      <SideNav />
      <BottomNav />
    </main>
  );
}
