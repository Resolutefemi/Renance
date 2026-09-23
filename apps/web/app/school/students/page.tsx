'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
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
  createStudent,
  fetchClasses,
  fetchClassSubjects,
  fetchStudentDetail,
  fetchStudentSubjects,
  fetchStudents,
  fetchSubjects,
  getActiveSchool,
  setStudentSubjects,
  updateStudent,
  type SchoolClass,
  type SchoolStudent,
  type SchoolSubject,
  type StudentDetail,
} from '@/lib/school';

// Students: the enrollment desk. Management fills a full detail form per
// pupil (name, admission number, sex, DOB, guardian, address) and stores
// it against the class; results are then managed under those names. For
// SSS classes the drawer also sets the student's subject offering from
// the core + department tracks wired in School Setup.

interface FormState {
  classId: string;
  fullName: string;
  admissionNo: string;
  sex: '' | 'M' | 'F';
  session: string;
  dob: string;
  guardianName: string;
  guardianPhone: string;
  address: string;
}

const EMPTY_FORM: FormState = {
  classId: '',
  fullName: '',
  admissionNo: '',
  sex: '',
  session: '2025/2026',
  dob: '',
  guardianName: '',
  guardianPhone: '',
  address: '',
};

export default function SchoolStudentsPage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [subjects, setSubjects] = useState<SchoolSubject[]>([]);
  const [pairs, setPairs] = useState<{ classId: string; subjectId: string }[]>([]);
  const [classId, setClassId] = useState('');
  const [students, setStudents] = useState<SchoolStudent[]>([]);
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');

  const [form, setForm] = useState<FormState>(EMPTY_FORM);

  // drawer state
  const [editing, setEditing] = useState<StudentDetail | null>(null);
  const [editForm, setEditForm] = useState<FormState>(EMPTY_FORM);
  const [offering, setOffering] = useState<string[] | null>(null); // null = follow class
  const [drawerBusy, setDrawerBusy] = useState(false);
  const [drawerNotice, setDrawerNotice] = useState('');

  const formRef = useRef<HTMLFormElement>(null);

  const load = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const [cls, subs, cs] = await Promise.all([
      fetchClasses(a.schoolId),
      fetchSubjects(a.schoolId),
      fetchClassSubjects(a.schoolId),
    ]);
    setClasses(cls.classes ?? []);
    setSubjects(subs.subjects ?? []);
    setPairs((cs.pairs ?? []).map((p) => ({ classId: p.classId, subjectId: p.subjectId })));
    const studs = await fetchStudents(a.schoolId, classId);
    setStudents(studs.students ?? []);
  }, [classId]);

  useEffect(() => {
    load().catch(() => setNotice('Could not load students.'));
  }, [load]);

  const activeClass = useMemo(() => classes.find((c) => c.id === (form.classId || classId)), [classes, form.classId, classId]);

  const classSubjectList = useCallback(
    (cid: string) => {
      const cls = classes.find((c) => c.id === cid);
      const ids = new Set(pairs.filter((p) => p.classId === cid).map((p) => p.subjectId));
      return subjects.filter((s) => ids.has(s.id) && cls && (s.level === cls.level || s.level === 'both'));
    },
    [classes, pairs, subjects],
  );

  async function enroll(e: React.FormEvent) {
    e.preventDefault();
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    setNotice('');
    try {
      await createStudent(a.schoolId, {
        classId: form.classId,
        fullName: form.fullName,
        admissionNo: form.admissionNo,
        sex: form.sex,
        session: form.session,
      });
      setNotice(`Enrolled ${form.fullName}. Open their record to add guardian details and subjects.`);
      setForm({ ...EMPTY_FORM, classId: form.classId, session: form.session });
      formRef.current?.reset();
      await load();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : 'Could not enroll the student.');
    } finally {
      setBusy(false);
    }
  }

  async function openDrawer(s: SchoolStudent) {
    const a = getActiveSchool();
    if (!a) return;
    setDrawerNotice('');
    setEditing({ ...s, dob: '', guardianName: '', guardianPhone: '', address: '', photoUrl: '', status: 'active' });
    setEditForm({
      classId: s.classId,
      fullName: s.fullName,
      admissionNo: s.admissionNo,
      sex: s.sex,
      session: s.session,
      dob: '',
      guardianName: '',
      guardianPhone: '',
      address: '',
    });
    try {
      const [det, subj] = await Promise.all([
        fetchStudentDetail(a.schoolId, s.id),
        fetchStudentSubjects(a.schoolId, s.id),
      ]);
      const d = det.student;
      setEditing(d);
      setEditForm({
        classId: d.classId,
        fullName: d.fullName,
        admissionNo: d.admissionNo,
        sex: (d.sex as '' | 'M' | 'F') ?? '',
        session: d.session,
        dob: d.dob ?? '',
        guardianName: d.guardianName ?? '',
        guardianPhone: d.guardianPhone ?? '',
        address: d.address ?? '',
      });
      setOffering(subj.subjectIds?.length ? subj.subjectIds : null);
    } catch {
      /* keep the roster row values */
    }
  }

  async function saveDrawer() {
    const a = getActiveSchool();
    if (!a || !editing) return;
    setDrawerBusy(true);
    setDrawerNotice('');
    try {
      await updateStudent(a.schoolId, {
        id: editing.id,
        fullName: editForm.fullName,
        admissionNo: editForm.admissionNo,
        sex: editForm.sex,
        session: editForm.session,
        classId: editForm.classId,
        dob: editForm.dob,
        guardianName: editForm.guardianName,
        guardianPhone: editForm.guardianPhone,
        address: editForm.address,
      });
      await setStudentSubjects(a.schoolId, editing.id, offering ?? []);
      setEditing(null);
      await load();
    } catch (err) {
      setDrawerNotice(err instanceof Error ? err.message : 'Could not save the student.');
    } finally {
      setDrawerBusy(false);
    }
  }

  const filtered = students.filter((s) => {
    const q = search.trim().toLowerCase();
    if (!q) return true;
    return s.fullName.toLowerCase().includes(q) || s.admissionNo.toLowerCase().includes(q);
  });

  const drawerClass = classes.find((c) => c.id === editForm.classId);
  const drawerSubjects = drawerClass ? classSubjectList(drawerClass.id) : [];
  const offeringBuckets = useMemo(() => {
    const buckets: Record<string, SchoolSubject[]> = { core: [], art: [], science: [], commercial: [], general: [] };
    for (const s of drawerSubjects) {
      if (s.isCore) buckets.core.push(s);
      else if (s.department) buckets[s.department].push(s);
      else buckets.general.push(s);
    }
    return buckets;
  }, [drawerSubjects]);

  return (
    <SchoolShell title="Students">
      <SchoolHeading
        title="Students"
        sub="Enroll each pupil with full details under their class, then manage their results, attendance and subject tracks under that record."
      />

      <div className="grid gap-4 xl:grid-cols-[420px_1fr]">
        {/* ------------------------------------------------- enroll form */}
        <Card className="h-fit">
          <CardTitle hint="Every field is stored on the student record for this class.">
            Enroll a student
          </CardTitle>
          <form ref={formRef} className="grid gap-3" onSubmit={enroll}>
            <select
              className={selectCls}
              value={form.classId}
              onChange={(e) => setForm({ ...form, classId: e.target.value })}
              required
            >
              <option value="">Select class…</option>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <input className={inputCls} placeholder="Full name" value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} required />
            <div className="grid grid-cols-2 gap-3">
              <input className={inputCls} placeholder="Admission number" value={form.admissionNo} onChange={(e) => setForm({ ...form, admissionNo: e.target.value })} />
              <select className={selectCls} value={form.sex} onChange={(e) => setForm({ ...form, sex: e.target.value as '' | 'M' | 'F' })}>
                <option value="">Sex…</option>
                <option value="M">Male</option>
                <option value="F">Female</option>
              </select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <label className="grid gap-1">
                <span className="text-xs text-on-surface-variant">Date of birth</span>
                <input type="date" className={inputCls} value={form.dob} onChange={(e) => setForm({ ...form, dob: e.target.value })} />
              </label>
              <label className="grid gap-1">
                <span className="text-xs text-on-surface-variant">Session</span>
                <input className={inputCls} placeholder="2025/2026" value={form.session} onChange={(e) => setForm({ ...form, session: e.target.value })} />
              </label>
            </div>
            <input className={inputCls} placeholder="Parent / guardian name" value={form.guardianName} onChange={(e) => setForm({ ...form, guardianName: e.target.value })} />
            <input className={inputCls} placeholder="Guardian phone" value={form.guardianPhone} onChange={(e) => setForm({ ...form, guardianPhone: e.target.value })} />
            <input className={inputCls} placeholder="Home address" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            <button className={btnPrimary} disabled={busy || !form.classId || !form.fullName.trim()}>
              {busy ? 'Enrolling…' : 'Enroll student'}
            </button>
            {notice && <p className="text-sm text-on-surface">{notice}</p>}
          </form>
        </Card>

        {/* ------------------------------------------------------ roster */}
        <Card>
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <CardTitle hint={activeClass ? `${activeClass.name} · ${students.length} student(s)` : `${students.length} student(s)`}>
              Roster
            </CardTitle>
            <div className="flex flex-wrap items-center gap-2">
              <input
                className={inputCls + ' h-10 w-44'}
                placeholder="Search name or number…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              <select className={selectCls + ' h-10 w-auto'} value={classId} onChange={(e) => setClassId(e.target.value)}>
                <option value="">All classes</option>
                {classes.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {filtered.length === 0 ? (
            <p className="text-sm text-on-surface-variant">
              No students{classId ? ' in this class' : ''} yet. Enroll the first one with the form.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[640px] text-sm">
                <thead>
                  <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                    <th className="py-2.5 pr-3">Student</th>
                    <th className="py-2.5 pr-3">Admission no.</th>
                    <th className="py-2.5 pr-3">Sex</th>
                    <th className="py-2.5 pr-3">Guardian</th>
                    <th className="py-2.5" />
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((s) => (
                    <tr key={s.id} className="border-b border-outline-variant/50 last:border-0">
                      <td className="py-2.5 pr-3">
                        <p className="font-medium text-on-surface">{s.fullName}</p>
                        <p className="text-xs text-on-surface-variant">{classes.find((c) => c.id === s.classId)?.name ?? ''}</p>
                      </td>
                      <td className="py-2.5 pr-3 font-mono text-xs text-on-surface-variant">{s.admissionNo || '-'}</td>
                      <td className="py-2.5 pr-3 text-on-surface-variant">{s.sex || '-'}</td>
                      <td className="py-2.5 pr-3 text-on-surface-variant">{s.guardianName || '-'}</td>
                      <td className="py-2.5 text-right">
                        <button className={btnSmall} onClick={() => openDrawer(s)}>
                          Open record
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>

      {/* ------------------------------------------------------- drawer */}
      {editing && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/40" onClick={() => setEditing(null)}>
          <aside
            className="school-bw h-full w-full max-w-xl overflow-y-auto bg-surface-container-lowest p-6 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-lg font-bold text-on-surface">{editing.fullName}</h2>
                <p className="text-sm text-on-surface-variant">
                  {drawerClass?.name ?? 'No class'} · {editing.admissionNo || 'no admission number'}
                </p>
              </div>
              <button className={btnSmall} onClick={() => setEditing(null)}>
                Close
              </button>
            </div>

            <div className="grid gap-3">
              <label className="grid gap-1.5">
                <span className="text-sm font-medium text-on-surface">Full name</span>
                <input className={inputCls} value={editForm.fullName} onChange={(e) => setEditForm({ ...editForm, fullName: e.target.value })} />
              </label>
              <div className="grid grid-cols-2 gap-3">
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Class</span>
                  <select className={selectCls} value={editForm.classId} onChange={(e) => setEditForm({ ...editForm, classId: e.target.value })}>
                    {classes.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Admission number</span>
                  <input className={inputCls} value={editForm.admissionNo} onChange={(e) => setEditForm({ ...editForm, admissionNo: e.target.value })} />
                </label>
              </div>
              <div className="grid grid-cols-3 gap-3">
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Sex</span>
                  <select className={selectCls} value={editForm.sex} onChange={(e) => setEditForm({ ...editForm, sex: e.target.value as '' | 'M' | 'F' })}>
                    <option value="">…</option>
                    <option value="M">Male</option>
                    <option value="F">Female</option>
                  </select>
                </label>
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Date of birth</span>
                  <input type="date" className={inputCls} value={editForm.dob} onChange={(e) => setEditForm({ ...editForm, dob: e.target.value })} />
                </label>
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Session</span>
                  <input className={inputCls} value={editForm.session} onChange={(e) => setEditForm({ ...editForm, session: e.target.value })} />
                </label>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Guardian name</span>
                  <input className={inputCls} value={editForm.guardianName} onChange={(e) => setEditForm({ ...editForm, guardianName: e.target.value })} />
                </label>
                <label className="grid gap-1.5">
                  <span className="text-sm font-medium text-on-surface">Guardian phone</span>
                  <input className={inputCls} value={editForm.guardianPhone} onChange={(e) => setEditForm({ ...editForm, guardianPhone: e.target.value })} />
                </label>
              </div>
              <label className="grid gap-1.5">
                <span className="text-sm font-medium text-on-surface">Home address</span>
                <input className={inputCls} value={editForm.address} onChange={(e) => setEditForm({ ...editForm, address: e.target.value })} />
              </label>
            </div>

            {/* subject offering */}
            {drawerSubjects.length > 0 && (
              <div className="mt-6 border-t border-outline-variant pt-5">
                <div className="mb-1 flex items-center justify-between gap-3">
                  <h3 className="text-base font-semibold text-on-surface">Subjects this student offers</h3>
                  <button
                    className="text-xs text-on-surface-variant underline"
                    onClick={() => setOffering(offering === null ? drawerSubjects.map((s) => s.id) : null)}
                  >
                    {offering === null ? 'Customize' : 'Follow the class list'}
                  </button>
                </div>
                <p className="mb-3 text-[13px] leading-relaxed text-on-surface-variant">
                  {offering === null
                    ? drawerClass?.level === 'senior'
                      ? 'This student currently follows the whole class list. Customize to pick their core + department subjects.'
                      : 'Following the whole class list. Customize only if this pupil offers a shorter list.'
                    : 'A custom offering: only these subjects appear on their report card and in the results grid.'}
                </p>
                {offering !== null && (
                  <div className="grid gap-4">
                    {(['core', 'art', 'science', 'commercial', 'general'] as const)
                      .filter((k) => offeringBuckets[k].length > 0)
                      .map((k) => (
                        <div key={k}>
                          <p className="mb-1.5 text-xs font-semibold uppercase tracking-[0.12em] text-on-surface-variant">
                            {k === 'general' ? 'General' : k}
                          </p>
                          <div className="flex flex-wrap gap-2">
                            {offeringBuckets[k].map((s) => {
                              const on = offering.includes(s.id);
                              return (
                                <button
                                  key={s.id}
                                  type="button"
                                  onClick={() =>
                                    setOffering(on ? offering.filter((x) => x !== s.id) : [...offering, s.id])
                                  }
                                  className={`rounded-full border px-3 py-1.5 text-sm transition-colors ${
                                    on ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant text-on-surface hover:bg-surface-container'
                                  }`}
                                >
                                  {s.name}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      ))}
                  </div>
                )}
              </div>
            )}

            <div className="mt-6 flex items-center gap-3">
              <button className={btnPrimary} disabled={drawerBusy || !editForm.fullName.trim()} onClick={saveDrawer}>
                {drawerBusy ? 'Saving…' : 'Save record'}
              </button>
              <button className={btnGhost} onClick={() => setEditing(null)}>
                Cancel
              </button>
            </div>
            {drawerNotice && <p className="mt-3 text-sm text-on-surface">{drawerNotice}</p>}
          </aside>
        </div>
      )}
    </SchoolShell>
  );
}
