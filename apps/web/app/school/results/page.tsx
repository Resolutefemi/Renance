'use client';

import { useCallback, useEffect, useState } from 'react';
import { SchoolHeading, SchoolShell, btnGhost, btnPrimary, inputCls, selectCls } from '@/components/school-shell';
import { ResultSheetView } from '@/components/result-sheet-view';
import {
  fetchAssignments,
  fetchClasses,
  fetchResults,
  finalizeResults,
  getActiveSchool,
  saveResultItem,
  termLabel,
  type ActiveSchool,
  type AssignmentDetail,
  type ResultItem,
  type ResultSheet,
  type SchoolClass,
} from '@/lib/school';

// The results workspace (ggportal-style): pick class + term + session,
// fill CA1 (20) / CA2 (20) / Exam (60) per subject per student, finalize
// to compute positions + averages + PINs, and open per-student report
// sheets. Teachers can only edit their assigned class+subject cells.

export default function SchoolResultsPage() {
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [classId, setClassId] = useState('');
  const [term, setTerm] = useState(1);
  const [session, setSession] = useState('2025/2026');
  const [grid, setGrid] = useState<ResultSheet[]>([]);
  const [assignments, setAssignments] = useState<AssignmentDetail[]>([]);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const [openStudent, setOpenStudent] = useState<string | null>(null);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setActive(a);
    (async () => {
      const [cls, asg] = await Promise.all([
        fetchClasses(a.schoolId),
        fetchAssignments(a.schoolId, a.role === 'teacher' ? a.memberId : ''),
      ]);
      setClasses(cls.classes ?? []);
      setAssignments(asg.assignments ?? []);
      const first = a.role === 'teacher' ? (asg.assignments ?? [])[0]?.classId : (cls.classes ?? [])[0]?.id;
      if (first) setClassId(first);
    })().catch(() => setNotice('Could not load classes.'));
  }, []);

  const load = useCallback(async () => {
    const a = active;
    if (!a || !classId) return;
    setBusy(true);
    try {
      const res = await fetchResults(a.schoolId, classId, term, session);
      setGrid(res.results ?? []);
    } finally {
      setBusy(false);
    }
  }, [active, classId, term, session]);

  useEffect(() => {
    load().catch(() => setNotice('Could not load results.'));
  }, [load]);

  const canEditCell = (subjectId: string) => {
    if (!active || active.role === 'management') return true;
    return assignments.some((a) => a.classId === classId && a.subjectId === subjectId);
  };

  const editableSubjects = useCallback(() => {
    const set = new Map<string, string>();
    for (const r of grid) for (const it of r.items) set.set(it.subjectId, it.subjectName);
    if (active?.role === 'teacher') {
      return [...set.entries()].filter(([sid]) => canEditCell(sid));
    }
    return [...set.entries()];
  }, [grid, active, classId, assignments]); // eslint-disable-line react-hooks/exhaustive-deps

  async function onCell(studentId: string, subjectId: string, field: 'ca1' | 'ca2' | 'exam', value: number) {
    const a = active;
    if (!a) return;
    const student = grid.find((r) => r.studentId === studentId);
    const item = student?.items.find((it) => it.subjectId === subjectId);
    const body = {
      studentId,
      classId,
      subjectId,
      term,
      session,
      ca1: field === 'ca1' ? value : (item?.ca1 ?? 0),
      ca2: field === 'ca2' ? value : (item?.ca2 ?? 0),
      exam: field === 'exam' ? value : (item?.exam ?? 0),
    };
    try {
      const res = await saveResultItem(a.schoolId, body);
      setGrid((g) =>
        g.map((r) =>
          r.studentId === studentId
            ? {
                ...r,
                status: 'draft',
                items: r.items.some((it) => it.subjectId === subjectId)
                  ? r.items.map((it) => (it.subjectId === subjectId ? { ...it, ...res.item } : it))
                  : [...r.items, { ...res.item, subjectName: '' }],
              }
            : r,
        ),
      );
    } catch (err) {
      setNotice(err instanceof Error ? err.message : 'Could not save scores.');
    }
  }

  async function onFinalize() {
    const a = active;
    if (!a || !classId) return;
    setBusy(true);
    setNotice('');
    try {
      const res = await finalizeResults(a.schoolId, classId, term, session);
      setNotice(`Finalized ${res.finalized} result(s). Positions, averages and PINs are live.`);
      await load();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : 'Could not finalize.');
    } finally {
      setBusy(false);
    }
  }

  const subjects = editableSubjects();
  const student = grid.find((r) => r.studentId === openStudent);

  return (
    <SchoolShell title="Results">
      <SchoolHeading
        title="Results"
        sub="CA1 + CA2 max 20 each, exam max 60. Finalize to compute positions and class averages and to issue each student's result-check PIN."
      />

      <div className="mb-5 grid gap-3 md:grid-cols-4">
        <select className={selectCls} value={classId} onChange={(e) => setClassId(e.target.value)}>
          <option value="">Select class…</option>
          {classes.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <select className={selectCls} value={term} onChange={(e) => setTerm(parseInt(e.target.value, 10))}>
          {[1, 2, 3].map((t) => (
            <option key={t} value={t}>
              {termLabel(t)}
            </option>
          ))}
        </select>
        <input className={inputCls} value={session} onChange={(e) => setSession(e.target.value)} placeholder="Session" />
        <button className={btnPrimary} disabled={busy || !classId} onClick={onFinalize}>
          Finalize & issue PINs
        </button>
      </div>

      {notice && <p className="mb-4 rounded-lg bg-surface-container px-4 py-3 text-sm text-on-surface">{notice}</p>}

      {!classId ? (
        <p className="text-sm text-on-surface-variant">Pick a class to open its result sheet.</p>
      ) : grid.length === 0 ? (
        <p className="text-sm text-on-surface-variant">No students in this class yet — enroll them from the Students page.</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-outline-variant bg-surface-container-lowest">
          <table className="w-full min-w-[720px] text-sm">
            <thead>
              <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                <th className="px-4 py-3">Student</th>
                {subjects.map(([sid, name]) => (
                  <th key={sid} className="px-3 py-3">
                    {name}
                  </th>
                ))}
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">PIN</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {grid.map((r) => (
                <tr key={r.studentId} className="border-b border-outline-variant/60 last:border-0">
                  <td className="px-4 py-3">
                    <p className="font-medium text-on-surface">{r.studentName}</p>
                    {r.admissionNo && <p className="text-xs text-on-surface-variant">{r.admissionNo}</p>}
                  </td>
                  {subjects.map(([sid]) => {
                    const item = r.items.find((it) => it.subjectId === sid);
                    const editable = canEditCell(sid) && r.status !== 'finalized';
                    return (
                      <td key={sid} className="px-2 py-2">
                        {editable ? (
                          <div className="flex items-center gap-1">
                            <CellInput value={item?.ca1 ?? 0} onCommit={(v) => onCell(r.studentId, sid, 'ca1', v)} title="CA1 /20" />
                            <CellInput value={item?.ca2 ?? 0} onCommit={(v) => onCell(r.studentId, sid, 'ca2', v)} title="CA2 /20" />
                            <CellInput value={item?.exam ?? 0} onCommit={(v) => onCell(r.studentId, sid, 'exam', v)} title="Exam /60" />
                          </div>
                        ) : (
                          <span className="px-2 text-on-surface-variant">
                            {item ? `${item.ca1}/${item.ca2}/${item.exam} = ${item.total} (${item.grade})` : '—'}
                          </span>
                        )}
                      </td>
                    );
                  })}
                  <td className="px-4 py-3 text-xs text-on-surface-variant">{r.status}</td>
                  <td className="px-4 py-3 font-mono text-xs text-on-surface">{r.pin || '—'}</td>
                  <td className="px-4 py-3">
                    <button className={btnGhost + ' !h-9 px-3 text-xs'} onClick={() => setOpenStudent(r.studentId)}>
                      Sheet
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {student && (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/50 p-4 md:p-10">
          <div className="w-full max-w-3xl rounded-xl bg-surface-container-lowest p-6 shadow-xl">
            <div className="mb-4 flex items-start justify-between">
              <h2 className="text-lg font-semibold text-on-surface">
                Report sheet — {student.studentName}
              </h2>
              <button className={btnGhost + ' !h-9 px-3 text-xs'} onClick={() => setOpenStudent(null)}>
                Close
              </button>
            </div>
            <ResultSheetView sheet={student} />
          </div>
        </div>
      )}
    </SchoolShell>
  );
}

function CellInput({ value, onCommit, title }: { value: number; onCommit: (v: number) => void; title: string }) {
  const [v, setV] = useState(String(value ?? 0));
  useEffect(() => setV(String(value ?? 0)), [value]);
  return (
    <input
      title={title}
      value={v}
      inputMode="decimal"
      onChange={(e) => setV(e.target.value)}
      onBlur={() => {
        const n = parseFloat(v);
        onCommit(Number.isFinite(n) ? Math.max(0, n) : 0);
      }}
      className="h-9 w-11 rounded border border-outline-variant bg-surface-container-lowest px-1 text-center text-xs text-on-surface focus:outline-none focus:ring-1 focus:ring-primary"
    />
  );
}
