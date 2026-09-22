'use client';

import { useCallback, useEffect, useState } from 'react';
import { SchoolHeading, SchoolShell, btnPrimary, inputCls, selectCls } from '@/components/school-shell';
import {
  createStudent,
  fetchClasses,
  fetchStudents,
  getActiveSchool,
  type SchoolClass,
  type SchoolStudent,
} from '@/lib/school';

export default function SchoolStudentsPage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [classId, setClassId] = useState('');
  const [students, setStudents] = useState<SchoolStudent[]>([]);
  const [fullName, setFullName] = useState('');
  const [admissionNo, setAdmissionNo] = useState('');
  const [sex, setSex] = useState('');
  const [session, setSession] = useState('2025/2026');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');

  const load = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const cls = await fetchClasses(a.schoolId);
    setClasses(cls.classes ?? []);
    const studs = await fetchStudents(a.schoolId, classId);
    setStudents(studs.students ?? []);
  }, [classId]);

  useEffect(() => {
    load().catch(() => setNotice('Could not load students.'));
  }, [load]);

  return (
    <SchoolShell title="Students">
      <SchoolHeading
        title="Students"
        sub="Enroll students into their classes. After results are finalized each student gets a private 6-digit PIN for checking their result."
      />

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
          <h2 className="text-base font-semibold text-on-surface">Enroll a student</h2>
          <form
            className="mt-4 grid gap-3"
            onSubmit={async (e) => {
              e.preventDefault();
              const a = getActiveSchool();
              if (!a) return;
              setBusy(true);
              setNotice('');
              try {
                await createStudent(a.schoolId, { classId, fullName, admissionNo, sex, session });
                setNotice(`Enrolled ${fullName}.`);
                setFullName('');
                setAdmissionNo('');
                await load();
              } catch (err) {
                setNotice(err instanceof Error ? err.message : 'Could not enroll the student.');
              } finally {
                setBusy(false);
              }
            }}
          >
            <select className={selectCls} value={classId} onChange={(e) => setClassId(e.target.value)} required>
              <option value="">Select class…</option>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <input className={inputCls} placeholder="Full name" value={fullName} onChange={(e) => setFullName(e.target.value)} required />
            <input className={inputCls} placeholder="Admission number (optional)" value={admissionNo} onChange={(e) => setAdmissionNo(e.target.value)} />
            <div className="grid grid-cols-2 gap-3">
              <select className={selectCls} value={sex} onChange={(e) => setSex(e.target.value)}>
                <option value="">Sex…</option>
                <option value="M">Male</option>
                <option value="F">Female</option>
              </select>
              <input className={inputCls} placeholder="Session (2025/2026)" value={session} onChange={(e) => setSession(e.target.value)} />
            </div>
            <button className={btnPrimary} disabled={busy || !classId}>
              {busy ? 'Enrolling…' : 'Enroll student'}
            </button>
          </form>
          {notice && <p className="mt-3 text-sm text-on-surface">{notice}</p>}
        </section>

        <section className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-base font-semibold text-on-surface">Roster</h2>
            <select className={`${selectCls} h-10 w-auto`} value={classId} onChange={(e) => setClassId(e.target.value)}>
              <option value="">All classes</option>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
          {students.length === 0 ? (
            <p className="mt-3 text-sm text-on-surface-variant">No students{classId ? ' in this class' : ''} yet.</p>
          ) : (
            <ul className="mt-3 divide-y divide-outline-variant">
              {students.map((s) => (
                <li key={s.id} className="flex items-center justify-between py-2.5 text-sm">
                  <span className="font-medium text-on-surface">{s.fullName}</span>
                  <span className="text-on-surface-variant">
                    {s.admissionNo || '—'} {s.sex ? `· ${s.sex}` : ''}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </SchoolShell>
  );
}
