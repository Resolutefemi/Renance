'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { SchoolHeading, SchoolShell, btnGhost, btnPrimary, btnSmall, inputCls, selectCls } from '@/components/school-shell';
import { ResultSheetView } from '@/components/result-sheet-view';
import { downloadReportCardPDF } from '@/lib/report-pdf';
import {
  fetchAssignments,
  fetchClasses,
  fetchResults,
  fetchStudentSubjects,
  fetchSubjects,
  finalizeResults,
  getActiveSchool,
  saveResultItem,
  setStudentSubjects,
  termLabel,
  type ActiveSchool,
  type AssignmentDetail,
  type ResultSheet,
  type SchoolClass,
  type SchoolSubject,
} from '@/lib/school';

// The results workspace (ggportal doctrine): pick class + term + session,
// fill CA1 (20) / CA2 (20) / Exam (60) per subject per student, finalize
// to compute positions + averages + PINs, then print the report card
// (logo stamped, black & white) or export the class broadsheet CSV.
// Teachers can only edit their assigned class+subject cells. Management
// can tune what each student offers right here.

export default function SchoolResultsPage() {
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [subjects, setSubjects] = useState<SchoolSubject[]>([]);
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
      const [cls, subs, asg] = await Promise.all([
        fetchClasses(a.schoolId),
        fetchSubjects(a.schoolId).catch(() => ({ subjects: [] })),
        fetchAssignments(a.schoolId, a.role === 'teacher' ? a.memberId : ''),
      ]);
      setClasses(cls.classes ?? []);
      setSubjects((subs as { subjects: SchoolSubject[] }).subjects ?? []);
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

  // Columns: the union of subjects across the class for this term, so
  // mixed-track SSS classes still read as one broadsheet.
  const subjectCols = useMemo(() => {
    const set = new Map<string, string>();
    for (const r of grid) for (const it of r.items) set.set(it.subjectId, it.subjectName);
    if (set.size === 0) {
      const cls = classes.find((c) => c.id === classId);
      for (const s of subjects) if (cls && (s.level === cls.level || s.level === 'both')) set.set(s.id, s.name);
    }
    return [...set.entries()];
  }, [grid, subjects, classes, classId]);

  // Per-student offering editor inside the sheet modal (management only).
  const student = grid.find((r) => r.studentId === openStudent);

  function exportCSV() {
    const header = ['Student', 'Admission no', ...subjectCols.flatMap(([sid, name]) => [`${name} CA1`, `${name} CA2`, `${name} Exam`, `${name} Total`, `${name} Grade`, `${name} Pos`]), 'Status', 'PIN'];
    const lines: (string | number)[][] = [header];
    for (const r of grid) {
      const row: (string | number)[] = [r.studentName, r.admissionNo ?? ''];
      for (const [sid] of subjectCols) {
        const it = r.items.find((x) => x.subjectId === sid);
        row.push(it?.ca1 ?? '', it?.ca2 ?? '', it?.exam ?? '', it?.total ?? '', it?.grade ?? '', it?.position ?? '');
      }
      row.push(r.status, r.pin ?? '');
      lines.push(row);
    }
    const csv = lines
      .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      .join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    const clsName = classes.find((c) => c.id === classId)?.name ?? 'class';
    a.href = url;
    a.download = `${clsName.replace(/\s+/g, '-')}-results-${termLabel(term).toLowerCase().replace(' ', '-')}-${session}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <SchoolShell title="Results">
      <SchoolHeading
        title="Results"
        sub="CA1 + CA2 max 20 each, exam max 60. Finalize to compute positions and class averages and to issue each student's result-check PIN. Report cards carry the school logo."
        actions={
          <button className={btnGhost} onClick={exportCSV} disabled={grid.length === 0}>
            <span className="material-symbols-outlined text-[18px]">table_view</span>
            Export CSV
          </button>
        }
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
        <p className="text-sm text-on-surface-variant">No students in this class yet. Enroll them from the Students page.</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-outline-variant bg-surface-container-lowest">
          <table className="w-full min-w-[760px] text-sm">
            <thead>
              <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                <th className="px-4 py-3">Student</th>
                {subjectCols.map(([sid, name]) => (
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
                  {subjectCols.map(([sid]) => {
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
                            {item ? `${item.ca1}/${item.ca2}/${item.exam} = ${item.total} (${item.grade})` : '-'}
                          </span>
                        )}
                      </td>
                    );
                  })}
                  <td className="px-4 py-3 text-xs text-on-surface-variant">{r.status}</td>
                  <td className="px-4 py-3 font-mono text-xs text-on-surface">{r.pin || '-'}</td>
                  <td className="px-4 py-3">
                    <button className={btnSmall} onClick={() => setOpenStudent(r.studentId)}>
                      Sheet
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {student && <SheetModal sheet={student} isManagement={active?.role === 'management'} onClose={() => setOpenStudent(null)} onChanged={load} />}
    </SchoolShell>
  );
}

// SheetModal: the report card view + PDF download + (management) the
// per-student subject offering editor, so scores can be tuned per track
// without leaving the results desk.
function SheetModal({
  sheet,
  isManagement,
  onClose,
  onChanged,
}: {
  sheet: ResultSheet;
  isManagement: boolean;
  onClose: () => void;
  onChanged: () => Promise<void>;
}) {
  const [offering, setOffering] = useState<string[] | null>(null);
  const [allSubjects, setAllSubjects] = useState<SchoolSubject[]>([]);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    (async () => {
      const { fetchSubjects } = await import('@/lib/school');
      const subs = await fetchSubjects(a.schoolId);
      setAllSubjects(subs.subjects ?? []);
      if (isManagement) {
        const res = await fetchStudentSubjects(a.schoolId, sheet.studentId);
        setOffering(res.subjectIds?.length ? res.subjectIds : null);
      }
    })().catch(() => undefined);
  }, [sheet.studentId, isManagement]);

  const relevant = useMemo(() => {
    const ids = new Set(sheet.items.map((it) => it.subjectId));
    return allSubjects.filter((s) => ids.has(s.id) || (offering ?? []).includes(s.id));
  }, [allSubjects, sheet.items, offering]);

  const buckets = useMemo(() => {
    const b: Record<string, SchoolSubject[]> = { core: [], art: [], science: [], commercial: [], general: [] };
    for (const s of relevant) {
      if (s.isCore) b.core.push(s);
      else if (s.department) b[s.department].push(s);
      else b.general.push(s);
    }
    return b;
  }, [relevant]);

  async function saveOffering() {
    const a = getActiveSchool();
    if (!a || !offering) return;
    setSaving(true);
    setNotice('');
    try {
      await setStudentSubjects(a.schoolId, sheet.studentId, offering);
      await onChanged();
      setNotice('Subject offering updated.');
    } catch (err) {
      setNotice(err instanceof Error ? err.message : 'Could not update the offering.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/50 p-4 md:p-10">
      <div className="school-bw w-full max-w-3xl rounded-xl bg-surface-container-lowest p-6 shadow-xl">
        <div className="mb-4 flex items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            {sheet.schoolLogoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={sheet.schoolLogoUrl} alt="" className="h-12 w-12 rounded-lg border border-outline-variant object-cover" />
            )}
            <div>
              <h2 className="text-lg font-semibold text-on-surface">Report sheet - {sheet.studentName}</h2>
              {sheet.schoolName && <p className="text-xs text-on-surface-variant">{sheet.schoolName}</p>}
            </div>
          </div>
          <div className="flex gap-2">
            <button className={btnSmall} onClick={() => downloadReportCardPDF(sheet).catch(() => undefined)}>
              <span className="material-symbols-outlined text-[15px]">picture_as_pdf</span>
              PDF
            </button>
            <button className={btnSmall} onClick={onClose}>
              Close
            </button>
          </div>
        </div>

        <ResultSheetView sheet={sheet} />

        {isManagement && (
          <div className="mt-6 border-t border-outline-variant pt-5">
            <div className="mb-2 flex items-center justify-between gap-3">
              <h3 className="text-base font-semibold text-on-surface">Subjects this student offers</h3>
              <button
                className="text-xs text-on-surface-variant underline"
                onClick={() => setOffering(offering === null ? sheet.items.map((it) => it.subjectId) : null)}
              >
                {offering === null ? 'Customize' : 'Follow the class list'}
              </button>
            </div>
            <p className="mb-3 text-[13px] text-on-surface-variant">
              Edit while you fill: only the ticked subjects land on this student's report card.
            </p>
            {offering !== null && (
              <>
                <div className="grid gap-3 sm:grid-cols-2">
                  {(['core', 'art', 'science', 'commercial', 'general'] as const)
                    .filter((k) => buckets[k].length > 0)
                    .map((k) => (
                      <div key={k}>
                        <p className="mb-1.5 text-xs font-semibold uppercase tracking-[0.12em] text-on-surface-variant">{k}</p>
                        <div className="flex flex-wrap gap-2">
                          {buckets[k].map((s) => {
                            const on = offering.includes(s.id);
                            return (
                              <button
                                key={s.id}
                                className={`rounded-full border px-3 py-1.5 text-xs transition-colors ${
                                  on ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant text-on-surface hover:bg-surface-container'
                                }`}
                                onClick={() => setOffering(on ? offering.filter((x) => x !== s.id) : [...offering, s.id])}
                              >
                                {s.name}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    ))}
                </div>
                <button className={btnPrimary + ' mt-4'} disabled={saving} onClick={saveOffering}>
                  {saving ? 'Saving…' : 'Save offering'}
                </button>
              </>
            )}
          </div>
        )}
        {notice && <p className="mt-3 text-sm text-on-surface">{notice}</p>}
        {busy && <p className="mt-2 text-xs text-on-surface-variant">Refreshing…</p>}
      </div>
    </div>
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
