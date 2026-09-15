'use client';

/**
 * GPA / CGPA calculator — the tool the founder asked for behind every
 * "calculate" icon. Pure client-side: no account, no API, works offline.
 * Nigerian 5.0 scale (A=5 … F=0), current-semester GPA plus a previous
 * CGPA fold-in, persisted to localStorage so a student can pick up where
 * they left off. Class-of-degree bands follow the standard Nigerian bands.
 */

import { useEffect, useMemo, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';

const GRADES = [
  { letter: 'A', points: 5 },
  { letter: 'B', points: 4 },
  { letter: 'C', points: 3 },
  { letter: 'D', points: 2 },
  { letter: 'E', points: 1 },
  { letter: 'F', points: 0 },
] as const;

const UNIT_OPTIONS = [0, 1, 2, 3, 4, 5, 6] as const;

interface CourseRow {
  id: number;
  code: string;
  units: number;
  grade: string;
}

interface SavedState {
  rows: CourseRow[];
  prevCgpa: string;
  prevUnits: string;
}

const STORE_KEY = 'renance.gpa.v1';

function freshRows(): CourseRow[] {
  return [
    { id: 1, code: '', units: 3, grade: 'A' },
    { id: 2, code: '', units: 3, grade: 'A' },
    { id: 3, code: '', units: 2, grade: 'B' },
    { id: 4, code: '', units: 2, grade: 'B' },
    { id: 5, code: '', units: 2, grade: 'C' },
  ];
}

function pointsOf(letter: string): number {
  return GRADES.find((g) => g.letter === letter)?.points ?? 0;
}

function classify(cgpa: number): { label: string; tone: string } {
  if (cgpa >= 4.5) return { label: 'First Class', tone: 'text-primary' };
  if (cgpa >= 3.5) return { label: 'Second Class Upper (2:1)', tone: 'text-primary' };
  if (cgpa >= 2.4) return { label: 'Second Class Lower (2:2)', tone: 'text-accent-ink' };
  if (cgpa >= 1.5) return { label: 'Third Class', tone: 'text-accent-amber' };
  if (cgpa >= 1.0) return { label: 'Pass', tone: 'text-accent-amber' };
  return { label: 'Below pass mark', tone: 'text-error' };
}

export default function GpaPage() {
  const [rows, setRows] = useState<CourseRow[]>(freshRows);
  const [prevCgpa, setPrevCgpa] = useState('');
  const [prevUnits, setPrevUnits] = useState('');
  const [loaded, setLoaded] = useState(false);

  // Load the saved sheet once (guard JSON parse — private mode, old shapes).
  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORE_KEY);
      if (raw) {
        const saved = JSON.parse(raw) as SavedState;
        if (Array.isArray(saved.rows) && saved.rows.length > 0) setRows(saved.rows);
        setPrevCgpa(saved.prevCgpa ?? '');
        setPrevUnits(saved.prevUnits ?? '');
      }
    } catch {
      /* corrupt or unavailable storage: keep the fresh sheet */
    }
    setLoaded(true);
  }, []);

  // Persist on every change after the first load.
  useEffect(() => {
    if (!loaded) return;
    try {
      const sheet: SavedState = { rows, prevCgpa, prevUnits };
      window.localStorage.setItem(STORE_KEY, JSON.stringify(sheet));
    } catch {
      /* private mode: calculator still works, just not persisted */
    }
  }, [rows, prevCgpa, prevUnits, loaded]);

  function patch(id: number, part: Partial<CourseRow>) {
    setRows((rs) => rs.map((r) => (r.id === id ? { ...r, ...part } : r)));
  }
  function addRow() {
    setRows((rs) => [
      ...rs,
      { id: Math.max(0, ...rs.map((r) => r.id)) + 1, code: '', units: 2, grade: 'A' },
    ]);
  }
  function dropRow(id: number) {
    setRows((rs) => (rs.length > 1 ? rs.filter((r) => r.id !== id) : rs));
  }
  function resetAll() {
    setRows(freshRows());
    setPrevCgpa('');
    setPrevUnits('');
  }

  const { gpa, semesterUnits, cgpa, totalUnits, classOf } = useMemo(() => {
    let points = 0;
    let units = 0;
    for (const r of rows) {
      const u = Number(r.units) || 0;
      points += u * pointsOf(r.grade);
      units += u;
    }
    const semGpa = units > 0 ? points / units : 0;

    const prevU = Number(prevUnits) || 0;
    const prevC = Number(prevCgpa) || 0;
    const allPoints = points + prevC * prevU;
    const allUnits = units + prevU;
    const allCgpa = allUnits > 0 ? allPoints / allUnits : 0;

    return {
      gpa: semGpa,
      semesterUnits: units,
      cgpa: allCgpa,
      totalUnits: allUnits,
      classOf: classify(allCgpa),
    };
  }, [rows, prevCgpa, prevUnits]);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="GPA Calculator" />
      <div className="mx-auto w-full max-w-5xl px-4 pt-4 sm:px-6">
        {/* Result card ------------------------------------------------ */}
        <section className="grid grid-cols-2 gap-3">
          <div className="rounded-xl bg-hero p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <p className="font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-hero-muted">
              Semester GPA
            </p>
            <p className="mt-1 text-3xl font-bold text-on-hero">{gpa.toFixed(2)}</p>
            <p className="mt-1 text-[13px] text-hero-muted">{semesterUnits} units this semester</p>
          </div>
          <div className="rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <p className="font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-on-surface-variant">
              CGPA
            </p>
            <p className="mt-1 text-3xl font-bold text-on-surface">{cgpa.toFixed(2)}</p>
            <p className={`mt-1 text-[13px] font-semibold ${classOf.tone}`}>{classOf.label}</p>
          </div>
        </section>

        {/* Semester courses ------------------------------------------- */}
        <section className="mt-6">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-on-surface">This semester&apos;s courses</h2>
            <button
              type="button"
              onClick={resetAll}
              className="rounded-full px-3 py-1.5 text-[13px] font-semibold text-error transition hover:bg-error-container/40"
            >
              Reset
            </button>
          </div>

          <div className="mt-3 flex flex-col gap-2">
            {rows.map((r) => (
              <div
                key={r.id}
                className="flex items-center gap-2 rounded-xl bg-card p-2 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]"
              >
                <input
                  value={r.code}
                  onChange={(e) => patch(r.id, { code: e.target.value })}
                  placeholder="Course (e.g. CSC 201)"
                  aria-label="Course code"
                  className="min-w-0 flex-1 rounded-lg bg-transparent px-2 py-2 text-[14px] text-on-surface outline-none placeholder:text-on-surface-variant/70"
                />
                <select
                  value={r.units}
                  onChange={(e) => patch(r.id, { units: Number(e.target.value) })}
                  aria-label="Credit units"
                  className="shrink-0 rounded-lg bg-surface-container-low px-2 py-2 text-[14px] font-semibold text-on-surface outline-none"
                >
                  {UNIT_OPTIONS.map((u) => (
                    <option key={u} value={u}>
                      {u} U
                    </option>
                  ))}
                </select>
                <select
                  value={r.grade}
                  onChange={(e) => patch(r.id, { grade: e.target.value })}
                  aria-label="Grade"
                  className={`shrink-0 rounded-lg px-2 py-2 text-[14px] font-bold outline-none ${
                    r.grade === 'F' ? 'bg-error-container text-error' : 'bg-selection-blue text-on-surface'
                  }`}
                >
                  {GRADES.map((g) => (
                    <option key={g.letter} value={g.letter}>
                      {g.letter}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  onClick={() => dropRow(r.id)}
                  aria-label={`Remove ${r.code || 'course'}`}
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container"
                >
                  <span className="material-symbols-outlined text-[18px]">close</span>
                </button>
              </div>
            ))}
          </div>

          <button
            type="button"
            onClick={addRow}
            className="mt-3 flex h-11 w-full items-center justify-center gap-2 rounded-[10px] border border-dashed border-outline-variant text-[14px] font-semibold text-on-surface-variant transition hover:bg-surface-container-low"
          >
            <span className="material-symbols-outlined text-[18px]">add</span>
            Add course
          </button>
        </section>

        {/* Previous CGPA fold-in -------------------------------------- */}
        <section className="mt-6 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          <h2 className="text-sm font-semibold text-on-surface">Fold in previous sessions</h2>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Enter your cumulative record so far — the CGPA above combines this semester with it.
          </p>
          <div className="mt-3 grid grid-cols-2 gap-3">
            <label className="flex flex-col gap-1">
              <span className="text-[12px] font-semibold uppercase tracking-wide text-on-surface-variant">
                Previous CGPA
              </span>
              <input
                value={prevCgpa}
                onChange={(e) => setPrevCgpa(e.target.value.replace(/[^0-9.]/g, ''))}
                inputMode="decimal"
                placeholder="e.g. 4.12"
                className="rounded-lg bg-surface-container-low px-3 py-2.5 text-[14px] text-on-surface outline-none placeholder:text-on-surface-variant/60"
              />
            </label>
            <label className="flex flex-col gap-1">
              <span className="text-[12px] font-semibold uppercase tracking-wide text-on-surface-variant">
                Total units so far
              </span>
              <input
                value={prevUnits}
                onChange={(e) => setPrevUnits(e.target.value.replace(/[^0-9]/g, ''))}
                inputMode="numeric"
                placeholder="e.g. 86"
                className="rounded-lg bg-surface-container-low px-3 py-2.5 text-[14px] text-on-surface outline-none placeholder:text-on-surface-variant/60"
              />
            </label>
          </div>
          <p className="mt-3 text-[13px] text-on-surface-variant">
            Scale: A=5 · B=4 · C=3 · D=2 · E=1 · F=0 — the standard Nigerian university 5.0 scale.
            {totalUnits > 0 && (
              <>
                {' '}
                Cumulative total: <span className="font-semibold text-on-surface">{totalUnits} units</span> at{' '}
                <span className="font-semibold text-on-surface">{cgpa.toFixed(2)}</span>.
              </>
            )}
          </p>
        </section>
      </div>
      <SideNav />
      <BottomNav />
    </main>
  );
}
