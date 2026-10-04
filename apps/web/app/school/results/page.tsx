'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { SchoolHeading, SchoolShell, btnGhost, btnGold, btnPrimary, btnSmall, inputCls, selectCls } from '@/components/school-shell';
import { ResultSheetView } from '@/components/result-sheet-view';
import { downloadReportCardPDF } from '@/lib/report-pdf';
import {
  BEHAVIOUR_TRAITS,
  SKILL_TRAITS,
  fetchAssignments,
  fetchClasses,
  fetchResultSheet,
  fetchResults,
  fetchStudentSubjects,
  fetchSubjects,
  finalizeResults,
  getActiveSchool,
  saveResultDetail,
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
// (GGSA Stitch sheet, purple & gold) or export the class broadsheet CSV.
// The entry table wears the GGSA teacher-form look (black header,
// gray-100 max-marks row, purple-50/30 zebra, amber current-term totals).
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
      // Guard (founder bug report 2026-10-02): unscored students came back
      // with items:null and crashed the broadsheet (for...of null). The API
      // now ships items:[] but normalize anyway so old payloads never
      // take the results desk down again.
      setGrid((res.results ?? []).map((r) => ({ ...r, items: r.items ?? [] })));
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
    const item = (student?.items ?? []).find((it) => it.subjectId === subjectId);
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
    for (const r of grid) for (const it of r.items ?? []) set.set(it.subjectId, it.subjectName);
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
        const it = (r.items ?? []).find((x) => x.subjectId === sid);
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
        <button className={btnGold} disabled={busy || !classId} onClick={onFinalize}>
          Finalize & issue PINs
        </button>
      </div>

      {notice && <p className="mb-4 rounded-lg bg-brand-50 px-4 py-3 text-sm text-brand-900">{notice}</p>}

      {!classId ? (
        <p className="text-sm text-on-surface-variant">Pick a class to open its result sheet.</p>
      ) : grid.length === 0 ? (
        <p className="text-sm text-on-surface-variant">No students in this class yet. Enroll them from the Students page.</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-slate-300 bg-white">
          <table className="w-full min-w-[760px] border-collapse text-sm">
            <thead>
              {/* GGSA black header row */}
              <tr className="bg-black text-white text-left text-[11px] uppercase tracking-wider">
                <th className="border border-black px-4 py-2.5 text-left">Student</th>
                {subjectCols.map(([sid, name]) => (
                  <th key={sid} className="border border-black px-3 py-2.5 text-center">
                    {name}
                  </th>
                ))}
                <th className="border border-black px-4 py-2.5">Status</th>
                <th className="border border-black px-4 py-2.5">PIN</th>
                <th className="border border-black px-4 py-2.5" />
              </tr>
              {/* GGSA gray-100 max-marks row: CA1 / CA2 / Exam per subject */}
              <tr className="bg-gray-100 text-gray-600 text-[10px]">
                <th className="border border-slate-300 px-4 py-1 text-left font-medium">Max marks</th>
                {subjectCols.map(([sid]) => (
                  <th key={sid} className="border border-slate-300 px-3 py-1 text-center font-medium">
                    20 · 20 · 60
                  </th>
                ))}
                <th className="border border-slate-300 px-4 py-1">-</th>
                <th className="border border-slate-300 px-4 py-1">-</th>
                <th className="border border-slate-300 px-4 py-1">-</th>
              </tr>
            </thead>
            <tbody>
              {grid.map((r, idx) => (
                <tr key={r.studentId} className={`border-b border-slate-200 last:border-0 ${idx % 2 ? 'bg-purple-50/30' : ''}`}>
                  <td className="px-4 py-3">
                    <p className="font-medium text-slate-900">{r.studentName}</p>
                    {r.admissionNo && <p className="text-xs text-slate-500">{r.admissionNo}</p>}
                  </td>
                  {subjectCols.map(([sid]) => {
                    const item = (r.items ?? []).find((it) => it.subjectId === sid);
                    const editable = canEditCell(sid) && r.status !== 'finalized';
                    return (
                      <td key={sid} className="px-2 py-2">
                        {editable ? (
                          <div className="flex flex-wrap items-center justify-center gap-1">
                            <CellInput value={item?.ca1 ?? 0} onCommit={(v) => onCell(r.studentId, sid, 'ca1', v)} title="CA1 /20" />
                            <CellInput value={item?.ca2 ?? 0} onCommit={(v) => onCell(r.studentId, sid, 'ca2', v)} title="CA2 /20" />
                            <CellInput value={item?.exam ?? 0} onCommit={(v) => onCell(r.studentId, sid, 'exam', v)} title="Exam /60" />
                            {item && item.total != null && (
                              <span className="ml-0.5 rounded bg-amber-50 px-1.5 py-0.5 text-center text-xs font-bold text-amber-700" title="Current-term total">
                                {item.total}
                              </span>
                            )}
                            {item?.grade && (
                              <span className="rounded bg-amber-100/40 px-1.5 py-0.5 text-center text-xs font-bold text-slate-900">
                                {item.grade}
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="flex flex-wrap items-center justify-center gap-1.5 text-slate-600">
                            {item ? (
                              <>
                                <span className="text-xs">
                                  {item.ca1}/{item.ca2}/{item.exam}
                                </span>
                                <span className="rounded bg-amber-50 px-1.5 py-0.5 text-xs font-bold text-amber-700">{item.total}</span>
                                {item.grade && (
                                  <span className="rounded bg-amber-100/40 px-1.5 py-0.5 text-xs font-bold text-slate-900">
                                    {item.grade}
                                  </span>
                                )}
                              </>
                            ) : (
                              '-'
                            )}
                          </span>
                        )}
                      </td>
                    );
                  })}
                  <td className="px-4 py-3">
                    {r.status === 'finalized' ? (
                      <span className="rounded-full bg-green-100 px-2.5 py-1 text-xs font-semibold text-green-700">Final</span>
                    ) : (
                      <span className="rounded-full border border-amber-300 px-2.5 py-1 text-xs font-semibold text-amber-700">Draft</span>
                    )}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-700">{r.pin || '-'}</td>
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

// SheetModal: the report card view + PDF download + the GGSA report-card
// details editor (traits, attendance, reports, next term) + (management)
// the per-student subject offering editor, so scores can be tuned per
// track without leaving the results desk.
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
  // The full report card (bio + GGSA extras + items): fetched fresh when
  // the modal opens so the trait cards / attendance / reports render what
  // is actually saved, not just the broadsheet row.
  const [full, setFull] = useState<ResultSheet | null>(null);

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
      const fresh = await fetchResultSheet(a.schoolId, sheet.studentId, sheet.term, sheet.session).catch(() => null);
      if (fresh) setFull(fresh);
    })().catch(() => undefined);
  }, [sheet.studentId, sheet.term, sheet.session, isManagement]);

  const view = full ?? sheet;

  const relevant = useMemo(() => {
    const ids = new Set((sheet.items ?? []).map((it) => it.subjectId));
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
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-brand-950/50 p-4 md:p-10">
      <div className="school-ggsa w-full max-w-4xl rounded-xl bg-surface-container-lowest p-6 shadow-xl">
        <div className="mb-4 flex items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            {sheet.schoolLogoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={sheet.schoolLogoUrl} alt="" className="h-12 w-12 rounded-lg border border-brand-200 object-cover" />
            )}
            <div>
              <h2 className="text-lg font-semibold text-ggsa-purple">Report sheet - {sheet.studentName}</h2>
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

        <ResultSheetView sheet={view} />

        {/* GGSA report-card details editor (founder directive 2026-10-04):
            traits A-E, attendance, teacher/principal reports, next term. */}
        <ReportCardDetails sheet={view} onSaved={onChanged} />

        {isManagement && (
          <div className="mt-6 border-t border-outline-variant pt-5">
            <div className="mb-2 flex items-center justify-between gap-3">
              <h3 className="text-base font-semibold text-on-surface">Subjects this student offers</h3>
              <button
                className="text-xs text-on-surface-variant underline"
                onClick={() => setOffering(offering === null ? (sheet.items ?? []).map((it) => it.subjectId) : null)}
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
      className="h-8 w-10 rounded border border-slate-300 bg-white px-0.5 text-center text-xs text-slate-800 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
    />
  );
}

/* ------------------------------------------------------------------ */
/* ReportCardDetails: the GGSA teacher-form section (founder directive */
/* 2026-10-04) - DEVELOPMENT (Skills) + BEHAVIOUR (Character) A-E      */
/* selects, attendance counts, teacher/principal reports and the       */
/* next-term-begins line, saved through PUT /school/result-detail.     */
/* Available to management and any teacher assigned to the class.      */
/* ------------------------------------------------------------------ */
function ReportCardDetails({ sheet, onSaved }: { sheet: ResultSheet; onSaved: () => Promise<void> }) {
  const [open, setOpen] = useState(false);
  const [traits, setTraits] = useState<Record<string, string>>({});
  const [attPresent, setAttPresent] = useState('');
  const [attOpened, setAttOpened] = useState('');
  const [teacherReport, setTeacherReport] = useState('');
  const [principalReport, setPrincipalReport] = useState('');
  const [nextTerm, setNextTerm] = useState('');
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState('');
  const [loadedFor, setLoadedFor] = useState('');

  // Seed the form from the sheet whenever a different student opens.
  useEffect(() => {
    const key = `${sheet.studentId}:${sheet.term}:${sheet.session}`;
    if (loadedFor === key) return;
    setLoadedFor(key);
    const record: Record<string, string> = {};
    for (const t of sheet.traits ?? []) if (t.rating) record[t.name] = t.rating;
    setTraits(record);
    setAttPresent(sheet.attendancePresent != null ? String(sheet.attendancePresent) : '');
    setAttOpened(sheet.attendanceOpened != null ? String(sheet.attendanceOpened) : '');
    setTeacherReport(sheet.teacherReport ?? '');
    setPrincipalReport(sheet.principalReport ?? '');
    setNextTerm(sheet.nextTermBegins ?? '');
  }, [sheet, loadedFor]);

  async function save() {
    const a = getActiveSchool();
    if (!a) return;
    setSaving(true);
    setNotice('');
    try {
      const clean: Record<string, string> = {};
      for (const [k, v] of Object.entries(traits)) if (/^[A-E]$/.test(v)) clean[k] = v;
      await saveResultDetail(a.schoolId, {
        studentId: sheet.studentId,
        classId: sheet.classId,
        term: sheet.term,
        session: sheet.session,
        traits: clean,
        attendancePresent: attPresent === '' ? null : Math.max(0, parseInt(attPresent, 10) || 0),
        attendanceOpened: attOpened === '' ? null : Math.max(0, parseInt(attOpened, 10) || 0),
        teacherReport,
        principalReport,
        nextTermBegins: nextTerm,
      });
      setNotice('Report-card details saved.');
      await onSaved();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : 'Could not save the details.');
    } finally {
      setSaving(false);
    }
  }

  const traitSelect = (name: string) => (
    <label key={name} className="flex items-center justify-between gap-2 rounded-lg bg-purple-50/30 px-2.5 py-1.5">
      <span className="text-[13px] text-slate-700">{name}</span>
      <select
        value={traits[name] ?? ''}
        onChange={(e) => setTraits({ ...traits, [name]: e.target.value })}
        className="h-8 rounded border border-slate-300 bg-white px-1.5 text-center text-[13px] font-semibold text-ggsa-purple focus:border-brand-500 focus:outline-none"
      >
        <option value="">-</option>
        {['A', 'B', 'C', 'D', 'E'].map((g) => (
          <option key={g} value={g}>
            {g}
          </option>
        ))}
      </select>
    </label>
  );

  return (
    <div className="mt-6 rounded-xl border border-purple-200 bg-white/70">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="flex w-full items-center gap-2 px-4 py-3 text-left"
      >
        <span className="material-symbols-outlined text-[20px] text-ggsa-purple">edit_note</span>
        <span className="flex-1">
          <span className="block text-sm font-semibold text-ggsa-purple">Report-card details</span>
          <span className="block text-xs text-on-surface-variant">
            Skills &amp; behaviour ratings (A-E), attendance, reports, next term
          </span>
        </span>
        <span className="material-symbols-outlined text-on-surface-variant">{open ? 'expand_less' : 'expand_more'}</span>
      </button>
      {open && (
        <div className="border-t border-purple-200 px-4 py-4">
          <div className="grid gap-5 lg:grid-cols-2">
            <div>
              <p className="mb-2 rounded-t-lg bg-brand-900 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-white">
                Development (Skills)
              </p>
              <div className="grid gap-1.5">{SKILL_TRAITS.map((n) => traitSelect(n))}</div>
            </div>
            <div>
              <p className="mb-2 rounded-t-lg bg-brand-900 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-white">
                Behaviour (Character)
              </p>
              <div className="grid gap-1.5">{BEHAVIOUR_TRAITS.map((n) => traitSelect(n))}</div>
            </div>
          </div>

          <div className="mt-5 grid gap-4 sm:grid-cols-3">
            <label className="block">
              <span className="mb-1 block px-1 text-[13px] font-semibold text-on-surface-variant">Attendance (present)</span>
              <input
                value={attPresent}
                onChange={(e) => setAttPresent(e.target.value)}
                inputMode="numeric"
                placeholder="e.g. 118"
                className="h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-800 focus:border-brand-500 focus:outline-none"
              />
            </label>
            <label className="block">
              <span className="mb-1 block px-1 text-[13px] font-semibold text-on-surface-variant">Days school opened</span>
              <input
                value={attOpened}
                onChange={(e) => setAttOpened(e.target.value)}
                inputMode="numeric"
                placeholder="e.g. 122"
                className="h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-800 focus:border-brand-500 focus:outline-none"
              />
            </label>
            <label className="block">
              <span className="mb-1 block px-1 text-[13px] font-semibold text-on-surface-variant">Next term begins</span>
              <input
                value={nextTerm}
                onChange={(e) => setNextTerm(e.target.value)}
                placeholder="e.g. 5th Jan, 2027"
                className="h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-800 focus:border-brand-500 focus:outline-none"
              />
            </label>
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-2">
            <label className="block">
              <span className="mb-1 block px-1 text-[13px] font-semibold text-on-surface-variant">Teacher&apos;s report</span>
              <textarea
                value={teacherReport}
                onChange={(e) => setTeacherReport(e.target.value)}
                rows={3}
                className="w-full rounded-lg border border-purple-200 bg-purple-50/40 p-3 text-sm italic leading-relaxed text-slate-800 focus:border-brand-500 focus:outline-none"
                placeholder="A hardworking student..."
              />
            </label>
            <label className="block">
              <span className="mb-1 block px-1 text-[13px] font-semibold text-on-surface-variant">Principal&apos;s report</span>
              <textarea
                value={principalReport}
                onChange={(e) => setPrincipalReport(e.target.value)}
                rows={3}
                className="w-full rounded-lg border border-purple-200 bg-purple-50/40 p-3 text-sm italic leading-relaxed text-slate-800 focus:border-brand-500 focus:outline-none"
                placeholder="Promoted to the next class..."
              />
            </label>
          </div>

          <div className="mt-4 flex items-center gap-3">
            <button type="button" className={btnPrimary} disabled={saving} onClick={save}>
              {saving ? 'Saving…' : 'Save details'}
            </button>
            {notice && <p className="text-sm text-on-surface">{notice}</p>}
          </div>
        </div>
      )}
    </div>
  );
}
