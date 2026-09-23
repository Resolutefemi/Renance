'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnGhost,
  btnPrimary,
  selectCls,
} from '@/components/school-shell';
import { fetchAssignments, fetchClasses, getActiveSchool, type SchoolClass } from '@/lib/school';
import {
  DAY_NAMES,
  fetchTimetable,
  saveTimetable,
  type TimetableSlot,
  type TimetableWeek,
} from '@/lib/school-timetable';

// The weekly timetable: rows are periods, columns are weekdays. Each
// cell holds a subject (from the class's offering) or a labelled block
// like Assembly or Break. Management edits the grid; teachers read it.
// Saving replaces the whole week in one transaction.

const DAYS = [1, 2, 3, 4, 5];
const PERIODS = [1, 2, 3, 4, 5, 6, 7, 8];
const DEFAULT_TIMES: Record<number, [string, string]> = {
  1: ['8:00', '8:40'], 2: ['8:40', '9:20'], 3: ['9:20', '10:00'], 4: ['10:00', '10:40'],
  5: ['10:40', '11:20'], 6: ['11:20', '12:00'], 7: ['12:40', '1:20'], 8: ['1:20', '2:00'],
};

export default function SchoolTimetablePage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [classId, setClassId] = useState('');
  const [week, setWeek] = useState<TimetableWeek | null>(null);
  const [slots, setSlots] = useState<TimetableSlot[]>([]);
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [management, setManagement] = useState(false);
  const [dirty, setDirty] = useState(false);

  const load = useCallback(async (cid: string) => {
    const a = getActiveSchool();
    if (!a || !cid) return;
    const res = await fetchTimetable(a.schoolId, cid);
    setWeek(res.timetable);
    setSlots(res.timetable?.slots ?? []);
    setDirty(false);
  }, []);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setManagement(a.role === 'management');
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
    load(classId).catch(() => setNotice('Could not load the timetable.'));
  }, [classId, load]);

  const subjectName = useMemo(() => {
    const m = new Map<string, string>();
    for (const s of week?.subjects ?? []) m.set(s.subjectId, s.subjectName);
    return m;
  }, [week]);

  function cellAt(day: number, period: number): TimetableSlot | undefined {
    return slots.find((s) => s.day === day && s.period === period);
  }

  function setCell(day: number, period: number, patch: Partial<TimetableSlot>) {
    setDirty(true);
    setSlots((cur) => {
      const found = cur.find((s) => s.day === day && s.period === period);
      if (found) {
        return cur.map((s) => (s.day === day && s.period === period ? { ...s, ...patch } : s));
      }
      return [
        ...cur,
        {
          id: '', classId, day, period,
          startTime: DEFAULT_TIMES[period]?.[0] ?? '',
          endTime: DEFAULT_TIMES[period]?.[1] ?? '',
          subjectId: '', label: '', ...patch,
        },
      ];
    });
  }

  async function save() {
    const a = getActiveSchool();
    if (!a || !classId) return;
    setBusy(true);
    setNotice('');
    try {
      // Drop empty cells: no subject and no label means the period is
      // not timetabled.
      const keep = slots.filter((s) => s.subjectId || s.label);
      const res = await saveTimetable(a.schoolId, classId, keep);
      setNotice(`Saved ${res.saved} period${res.saved === 1 ? '' : 's'}.`);
      await load(classId);
    } catch {
      setNotice('Could not save the timetable.');
    } finally {
      setBusy(false);
    }
  }

  function clearWeek() {
    setSlots([]);
    setDirty(true);
  }

  return (
    <SchoolShell title="Timetable">
      <SchoolHeading
        title="Weekly Timetable"
        sub="One grid per class. Pick a subject or type a block name like Break for each period; save rewrites the week cleanly."
        actions={
          <select
            value={classId}
            onChange={(e) => setClassId(e.target.value)}
            className={`${selectCls} h-11 w-auto`}
            aria-label="Class"
          >
            {classes.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        }
      />

      {notice && (
        <p className="mb-4 rounded-lg border border-outline-variant bg-surface-container-lowest px-4 py-3 text-sm text-on-surface-variant">
          {notice}
        </p>
      )}

      <Card className="overflow-hidden">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <CardTitle hint={management ? 'You are editing as management.' : 'Read-only view.'}>
            {classes.find((c) => c.id === classId)?.name ?? 'Class'} week
            {dirty && <span className="ml-2 text-xs font-normal text-on-surface-variant">unsaved edits</span>}
          </CardTitle>
          <div className="flex gap-2">
            <button onClick={() => window.print()} className={btnGhost} title="Print the week">
              Print
            </button>
            {management && (
              <>
                <button onClick={clearWeek} className={btnGhost}>
                  Clear
                </button>
                <button onClick={save} disabled={busy || !classId} className={btnPrimary}>
                  Save week
                </button>
              </>
            )}
          </div>
        </div>

        <div className="-mx-5 overflow-x-auto px-5 pb-1 sm:mx-0 sm:px-0">
          <table className="w-full min-w-[720px] border-collapse text-sm" aria-label="Weekly timetable grid">
            <thead>
              <tr>
                <th className="w-24 border border-outline-variant bg-surface-container px-2 py-2 text-xs uppercase tracking-wide text-on-surface-variant">
                  Period
                </th>
                {DAYS.map((d) => (
                  <th
                    key={d}
                    className="border border-outline-variant bg-surface-container px-2 py-2 text-xs uppercase tracking-wide text-on-surface-variant"
                  >
                    {DAY_NAMES[d]}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {PERIODS.map((p) => (
                <tr key={p}>
                  <td className="border border-outline-variant bg-surface-container px-2 py-2 text-center text-xs text-on-surface-variant">
                    <span className="block font-semibold text-on-surface">P{p}</span>
                    <span>{DEFAULT_TIMES[p]?.[0] ?? ''}</span>
                  </td>
                  {DAYS.map((d) => {
                    const cell = cellAt(d, p);
                    const subj = cell?.subjectId ? subjectName.get(cell.subjectId) : '';
                    return (
                      <td key={d} className="border border-outline-variant p-1 align-top">
                        {management ? (
                          <div className="space-y-1">
                            <select
                              value={cell?.subjectId ?? ''}
                              onChange={(e) => setCell(d, p, { subjectId: e.target.value, label: e.target.value ? '' : cell?.label ?? '' })}
                              className="h-8 w-full rounded border border-outline-variant bg-surface-container-lowest px-1.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
                            >
                              <option value="">Subject?</option>
                              {(week?.subjects ?? []).map((s) => (
                                <option key={s.subjectId} value={s.subjectId}>
                                  {s.subjectName}
                                </option>
                              ))}
                            </select>
                            <input
                              value={cell?.label ?? ''}
                              onChange={(e) => setCell(d, p, { label: e.target.value })}
                              placeholder="or a block, e.g. Break"
                              className="h-8 w-full rounded border border-outline-variant bg-surface-container-lowest px-1.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
                            />
                          </div>
                        ) : (
                          <div className="min-h-9 px-1.5 py-1.5 text-xs">
                            {subj || cell?.label || <span className="text-on-surface-variant">-</span>}
                          </div>
                        )}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </SchoolShell>
  );
}
