'use client';

import { useCallback, useEffect, useState } from 'react';
import { SchoolHeading, SchoolShell, btnGhost, btnPrimary, inputCls } from '@/components/school-shell';
import {
  createTeacher,
  fetchAssignments,
  fetchClassSubjects,
  fetchMembers,
  getActiveSchool,
  toggleAssignment,
  type AssignmentDetail,
  type MemberSummary,
} from '@/lib/school';

export default function SchoolTeachersPage() {
  const [members, setMembers] = useState<MemberSummary[]>([]);
  const [pairs, setPairs] = useState<{ classId: string; className: string; subjectId: string; subjectName: string }[]>([]);
  const [assignments, setAssignments] = useState<AssignmentDetail[]>([]);
  const [selected, setSelected] = useState<MemberSummary | null>(null);
  const [notice, setNotice] = useState('');

  // create-teacher form
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [staffCode, setStaffCode] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const [m, p, asg] = await Promise.all([
      fetchMembers(a.schoolId),
      fetchClassSubjects(a.schoolId),
      fetchAssignments(a.schoolId),
    ]);
    setMembers(m.members ?? []);
    setPairs(p.pairs ?? []);
    setAssignments(asg.assignments ?? []);
  }, []);

  useEffect(() => {
    load().catch(() => setNotice('Could not load the school roster.'));
  }, [load]);

  // Group pairs by class for the assignment grid.
  const byClass = new Map<string, { subjectId: string; subjectName: string }[]>();
  for (const p of pairs) {
    const list = byClass.get(p.classId) ?? [];
    list.push({ subjectId: p.subjectId, subjectName: p.subjectName });
    byClass.set(p.classId, list);
  }
  const classNames = new Map<string, string>();
  for (const p of pairs) classNames.set(p.classId, p.className);

  const has = (classId: string, subjectId: string) =>
    !!selected &&
    assignments.some((a) => a.memberId === selected.member.id && a.classId === classId && a.subjectId === subjectId);

  async function flip(classId: string, subjectId: string) {
    if (!selected) return;
    const a = getActiveSchool();
    if (!a) return;
    await toggleAssignment(a.schoolId, selected.member.id, classId, subjectId, has(classId, subjectId));
    await load();
  }

  const teachers = members.filter((m) => m.member.role === 'teacher');
  const management = members.filter((m) => m.member.role === 'management');

  return (
    <SchoolShell title="Teachers & Classes">
      <SchoolHeading
        title="Teachers & classes"
        sub="Create a teacher account for each of your staff — they sign in under For Schools → For Teachers. Assign classes + subjects to control who fills which results and who edits which notes."
      />

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Create teacher account */}
        <section className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
          <h2 className="text-base font-semibold text-on-surface">Create a teacher account</h2>
          <form
            className="mt-4 grid gap-3"
            onSubmit={async (e) => {
              e.preventDefault();
              const a = getActiveSchool();
              if (!a) return;
              setBusy(true);
              setNotice('');
              try {
                await createTeacher(a.schoolId, { fullName, email, password, staffCode });
                setNotice(`Account created for ${fullName}. Share the email + password — they sign in under For Schools.`);
                setFullName('');
                setEmail('');
                setPassword('');
                setStaffCode('');
                await load();
              } catch (err) {
                setNotice(err instanceof Error ? err.message : 'Could not create the account.');
              } finally {
                setBusy(false);
              }
            }}
          >
            <input className={inputCls} placeholder="Teacher full name" value={fullName} onChange={(e) => setFullName(e.target.value)} required minLength={3} />
            <input className={inputCls} type="email" placeholder="School email (their sign-in)" value={email} onChange={(e) => setEmail(e.target.value)} required />
            <input className={inputCls} type="text" placeholder="Staff code (optional)" value={staffCode} onChange={(e) => setStaffCode(e.target.value)} />
            <input className={inputCls} type="text" placeholder="Temporary password (min 8 chars)" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} />
            <button className={btnPrimary} disabled={busy}>
              {busy ? 'Creating…' : 'Create teacher account'}
            </button>
          </form>
          {notice && <p className="mt-3 text-sm text-on-surface">{notice}</p>}

          <h3 className="mt-6 text-sm font-semibold text-on-surface">Management</h3>
          <ul className="mt-2 flex flex-col gap-1 text-sm text-on-surface-variant">
            {management.map((m) => (
              <li key={m.member.id}>
                {m.member.fullName || m.username} — {m.email}
              </li>
            ))}
          </ul>
        </section>

        {/* Roster + assignments */}
        <section className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
          <h2 className="text-base font-semibold text-on-surface">Teacher roster</h2>
          {teachers.length === 0 ? (
            <p className="mt-2 text-sm text-on-surface-variant">No teachers yet — create the first account.</p>
          ) : (
            <ul className="mt-3 flex flex-col gap-2">
              {teachers.map((m) => (
                <li key={m.member.id}>
                  <button
                    onClick={() => setSelected(selected?.member.id === m.member.id ? null : m)}
                    className={`w-full rounded-lg border px-4 py-3 text-left text-sm transition-colors ${
                      selected?.member.id === m.member.id
                        ? 'border-primary bg-surface-container'
                        : 'border-outline-variant hover:bg-surface-container'
                    }`}
                  >
                    <span className="font-medium text-on-surface">{m.member.fullName || m.username}</span>
                    <span className="ml-2 text-on-surface-variant">{m.email}</span>
                    {m.member.staffCode && <span className="ml-2 text-xs text-on-surface-variant">({m.member.staffCode})</span>}
                    <span className="ml-2 text-xs text-on-surface-variant">
                      {assignments.filter((a) => a.memberId === m.member.id).length} assignment(s)
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}

          {selected && (
            <div className="mt-5">
              <h3 className="text-sm font-semibold text-on-surface">
                Assignments for {selected.member.fullName || selected.username}
              </h3>
              <p className="mt-1 text-xs text-on-surface-variant">
                Tap a subject to grant or revoke. Grants control result-filling AND note editing for that class + subject.
              </p>
              <div className="mt-3 flex flex-col gap-4">
                {[...byClass.entries()].map(([classId, subjects]) => (
                  <div key={classId}>
                    <p className="text-sm font-medium text-on-surface">{classNames.get(classId)}</p>
                    <div className="mt-2 flex flex-wrap gap-2">
                      {subjects.map((s) => {
                        const on = has(classId, s.subjectId);
                        return (
                          <button
                            key={s.subjectId}
                            onClick={() => flip(classId, s.subjectId)}
                            className={`rounded-full border px-3 py-1.5 text-xs transition-colors ${
                              on
                                ? 'border-primary bg-primary text-on-primary'
                                : 'border-outline text-on-surface-variant hover:bg-surface-container'
                            }`}
                          >
                            {s.subjectName}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </section>
      </div>
    </SchoolShell>
  );
}
