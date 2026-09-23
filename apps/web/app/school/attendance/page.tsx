'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnGhost,
  btnPrimary,
  btnSmall,
  inputCls,
  selectCls,
} from '@/components/school-shell';
import {
  fetchAttendanceDay,
  fetchAttendanceSummary,
  fetchAssignments,
  fetchClasses,
  fetchStudents,
  getActiveSchool,
  saveAttendance,
  todayISO,
  type AttendanceEntry,
  type AttendanceStatus,
  type SchoolClass,
  type SchoolStudent,
} from '@/lib/school';

// Attendance: the daily register. Staff mark the roster (or open the
// kiosk and let pupils tap themselves in on a classroom screen); the
// summary tab rolls any date range up into per-student rates.

const STATUSES: { key: AttendanceStatus; label: string }[] = [
  { key: 'present', label: 'Present' },
  { key: 'absent', label: 'Absent' },
  { key: 'late', label: 'Late' },
  { key: 'excused', label: 'Excused' },
];

export default function SchoolAttendancePage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [classId, setClassId] = useState('');
  const [day, setDay] = useState(todayISO());
  const [students, setStudents] = useState<SchoolStudent[]>([]);
  const [marks, setMarks] = useState<Record<string, AttendanceStatus>>({});
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');

  // summary
  const [from, setFrom] = useState(todayISO(new Date(Date.now() - 30 * 864e5)));
  const [to, setTo] = useState(todayISO());
  const [summary, setSummary] = useState<{ studentId: string; present: number; absent: number; late: number; excused: number; total: number; rate: number }[]>([]);

  // kiosk
  const [kiosk, setKiosk] = useState(false);
  const [tab, setTab] = useState<'register' | 'summary'>('register');

  const load = useCallback(async () => {
    const a = getActiveSchool();
    if (!a || !classId || !day) return;
    const [studs, entries] = await Promise.all([
      fetchStudents(a.schoolId, classId),
      fetchAttendanceDay(a.schoolId, classId, day),
    ]);
    setStudents(studs.students ?? []);
    const m: Record<string, AttendanceStatus> = {};
    const n: Record<string, string> = {};
    for (const e of entries.entries ?? []) {
      m[e.studentId] = e.status;
      if (e.note) n[e.studentId] = e.note;
    }
    setMarks(m);
    setNotes(n);
  }, [classId, day]);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    fetchClasses(a.schoolId)
      .then(async (res) => {
        setClasses(res.classes ?? []);
        let first = (res.classes ?? [])[0]?.id ?? '';
        if (a.role === 'teacher') {
          try {
            const asg = await fetchAssignments(a.schoolId, a.memberId);
            const covered = new Set((asg.assignments ?? []).map((x) => x.classId));
            const mine = (res.classes ?? []).find((c) => covered.has(c.id));
            if (mine) first = mine.id;
          } catch {
            /* fall back to the first class */
          }
        }
        setClassId(first);
      })
      .catch(() => setNotice('Could not load classes.'));
  }, []);

  useEffect(() => {
    load().catch(() => setNotice('Could not load the register.'));
  }, [load]);

  const loadSummary = useCallback(async () => {
    const a = getActiveSchool();
    if (!a || !classId) return;
    const res = await fetchAttendanceSummary(a.schoolId, classId, from, to);
    setSummary(res.summary ?? []);
  }, [classId, from, to]);

  useEffect(() => {
    if (tab === 'summary') loadSummary().catch(() => undefined);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loadSummary, tab]);

  const counts = useMemo(() => {
    const c = { present: 0, absent: 0, late: 0, excused: 0, unmarked: 0 };
    for (const s of students) {
      const st = marks[s.id];
      if (!st) c.unmarked++;
      else c[st]++;
    }
    return c;
  }, [students, marks]);

  async function save() {
    const a = getActiveSchool();
    if (!a || !classId) return;
    setBusy(true);
    setNotice('');
    const entries: AttendanceEntry[] = students
      .filter((s) => marks[s.id])
      .map((s) => ({ studentId: s.id, status: marks[s.id], note: notes[s.id] ?? '' }));
    try {
      const res = await saveAttendance(a.schoolId, classId, day, entries);
      setNotice(`Saved ${res.saved} mark(s) for ${day}.`);
    } catch (err) {
      setNotice(err instanceof Error ? err.message : 'Could not save attendance.');
    } finally {
      setBusy(false);
    }
  }

  // kiosk tap: marks present and saves immediately (one call per tap)
  async function kioskTap(studentId: string) {
    const a = getActiveSchool();
    if (!a || !classId) return;
    const next = marks[studentId] === 'present' ? 'absent' : 'present';
    setMarks((m) => ({ ...m, [studentId]: next }));
    try {
      await saveAttendance(a.schoolId, classId, day, [{ studentId, status: next, note: '' }]);
    } catch {
      setMarks((m) => ({ ...m, [studentId]: marks[studentId] }));
    }
  }

  if (kiosk) {
    return (
      <SchoolShell title="Attendance Kiosk">
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-on-surface">
              {classes.find((c) => c.id === classId)?.name ?? 'Class'} · Check in
            </h1>
            <p className="text-sm text-on-surface-variant">
              Tap your name. Green means you are marked present for {day}. Management can exit from
              the header.
            </p>
          </div>
          <button className={btnGhost} onClick={() => setKiosk(false)}>
            Exit kiosk
          </button>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {students.map((s) => {
            const on = marks[s.id] === 'present';
            return (
              <button
                key={s.id}
                onClick={() => kioskTap(s.id)}
                className={`flex h-28 flex-col items-center justify-center gap-2 rounded-2xl border-2 text-center transition-all active:scale-[0.97] ${
                  on ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant bg-surface-container-lowest text-on-surface'
                }`}
              >
                <span className="material-symbols-outlined text-3xl">{on ? 'check_circle' : 'touch_app'}</span>
                <span className="px-2 text-sm font-semibold leading-tight">{s.fullName}</span>
              </button>
            );
          })}
        </div>
        {students.length === 0 && (
          <p className="text-sm text-on-surface-variant">No students in this class yet.</p>
        )}
      </SchoolShell>
    );
  }

  return (
    <SchoolShell title="Attendance">
      <SchoolHeading
        title="Attendance"
        sub="The daily register per class. Mark the roster, save, or project the kiosk on the classroom screen and let the pupils tap themselves in."
        actions={
          <button className={btnPrimary} onClick={() => setKiosk(true)} disabled={!classId}>
            <span className="material-symbols-outlined text-[18px]">touch_app</span>
            Open kiosk
          </button>
        }
      />

      <div className="mb-5 flex gap-2">
        {(['register', 'summary'] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
              tab === t ? 'bg-primary text-on-primary' : 'border border-outline-variant text-on-surface hover:bg-surface-container'
            }`}
          >
            {t === 'register' ? 'Daily register' : 'Summary'}
          </button>
        ))}
      </div>

      {tab === 'register' ? (
        <Card>
          <div className="mb-4 grid gap-3 sm:grid-cols-3">
            <select className={selectCls} value={classId} onChange={(e) => setClassId(e.target.value)}>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <input type="date" className={inputCls} value={day} onChange={(e) => setDay(e.target.value)} />
            <button
              className={btnGhost}
              onClick={() => {
                const all: Record<string, AttendanceStatus> = {};
                for (const s of students) all[s.id] = 'present';
                setMarks(all);
              }}
            >
              Mark all present
            </button>
          </div>

          <div className="mb-4 flex flex-wrap gap-2 text-xs text-on-surface-variant">
            <span className="rounded-full bg-surface-container px-3 py-1">Present: {counts.present}</span>
            <span className="rounded-full bg-surface-container px-3 py-1">Absent: {counts.absent}</span>
            <span className="rounded-full bg-surface-container px-3 py-1">Late: {counts.late}</span>
            <span className="rounded-full bg-surface-container px-3 py-1">Excused: {counts.excused}</span>
            <span className="rounded-full bg-surface-container px-3 py-1">Unmarked: {counts.unmarked}</span>
          </div>

          {students.length === 0 ? (
            <p className="text-sm text-on-surface-variant">No students in this class yet.</p>
          ) : (
            <ul className="divide-y divide-outline-variant">
              {students.map((s) => (
                <li key={s.id} className="flex flex-wrap items-center justify-between gap-3 py-2.5">
                  <div>
                    <p className="text-sm font-medium text-on-surface">{s.fullName}</p>
                    <p className="text-xs text-on-surface-variant">{s.admissionNo || s.dob || ''}</p>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {STATUSES.map((st) => {
                      const on = marks[s.id] === st.key;
                      return (
                        <button
                          key={st.key}
                          onClick={() => setMarks((m) => ({ ...m, [s.id]: st.key }))}
                          className={`rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                            on ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant text-on-surface-variant hover:bg-surface-container'
                          }`}
                        >
                          {st.label}
                        </button>
                      );
                    })}
                  </div>
                </li>
              ))}
            </ul>
          )}

          <div className="mt-5 flex items-center gap-3">
            <button className={btnPrimary} disabled={busy || !classId || students.length === 0} onClick={save}>
              {busy ? 'Saving…' : 'Save register'}
            </button>
            {notice && <p className="text-sm text-on-surface">{notice}</p>}
          </div>
        </Card>
      ) : (
        <Card>
          <div className="mb-4 grid gap-3 sm:grid-cols-3">
            <select className={selectCls} value={classId} onChange={(e) => setClassId(e.target.value)}>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <input type="date" className={inputCls} value={from} onChange={(e) => setFrom(e.target.value)} />
            <input type="date" className={inputCls} value={to} onChange={(e) => setTo(e.target.value)} />
          </div>
          {summary.length === 0 ? (
            <p className="text-sm text-on-surface-variant">No marks in this range yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[640px] text-sm">
                <thead>
                  <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                    <th className="py-2.5 pr-3">Student</th>
                    <th className="py-2.5 pr-3">Present</th>
                    <th className="py-2.5 pr-3">Absent</th>
                    <th className="py-2.5 pr-3">Late</th>
                    <th className="py-2.5 pr-3">Excused</th>
                    <th className="py-2.5 w-48">Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {summary.map((r) => {
                    const name = students.find((s) => s.id === r.studentId)?.fullName ?? r.studentId.slice(0, 8);
                    return (
                      <tr key={r.studentId} className="border-b border-outline-variant/50 last:border-0">
                        <td className="py-2.5 pr-3 font-medium text-on-surface">{name}</td>
                        <td className="py-2.5 pr-3 text-on-surface-variant">{r.present}</td>
                        <td className="py-2.5 pr-3 text-on-surface-variant">{r.absent}</td>
                        <td className="py-2.5 pr-3 text-on-surface-variant">{r.late}</td>
                        <td className="py-2.5 pr-3 text-on-surface-variant">{r.excused}</td>
                        <td className="py-2.5">
                          <div className="flex items-center gap-2">
                            <div className="h-2 flex-1 overflow-hidden rounded-full bg-surface-container-high">
                              <div className="h-full rounded-full bg-primary" style={{ width: `${r.rate}%` }} />
                            </div>
                            <span className="w-10 text-right text-xs font-semibold text-on-surface">{r.rate}%</span>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      )}
    </SchoolShell>
  );
}
