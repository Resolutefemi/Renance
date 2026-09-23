'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { SchoolHeading, SchoolShell, Card, CardTitle, btnGhost, btnPrimary } from '@/components/school-shell';
import {
  fetchAssignments,
  fetchClasses,
  fetchClassSubjects,
  fetchStudents,
  fetchSubjects,
  getActiveSchool,
  seedCurriculum,
  type ActiveSchool,
  type AssignmentDetail,
  type SchoolClass,
  type SchoolSubject,
} from '@/lib/school';

// The school home desk: identity band, live stats, the setup checklist
// (management) or the personal desk (teacher), then quick actions. Same
// information order as the student home, strict black & white.

export default function SchoolOverviewPage() {
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [stats, setStats] = useState({ classes: 0, subjects: 0, students: 0, pairs: 0 });
  const [assignments, setAssignments] = useState<AssignmentDetail[]>([]);
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [subjects, setSubjects] = useState<SchoolSubject[]>([]);
  const [seeding, setSeeding] = useState(false);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setActive(a);
    (async () => {
      const [cls, subs, studs, pairs, asg] = await Promise.all([
        fetchClasses(a.schoolId),
        fetchSubjects(a.schoolId),
        fetchStudents(a.schoolId),
        fetchClassSubjects(a.schoolId),
        fetchAssignments(a.schoolId, a.role === 'teacher' ? a.memberId : ''),
      ]);
      setClasses(cls.classes ?? []);
      setSubjects(subs.subjects ?? []);
      setStats({
        classes: cls.classes?.length ?? 0,
        subjects: subs.subjects?.length ?? 0,
        students: studs.students?.length ?? 0,
        pairs: pairs.pairs?.length ?? 0,
      });
      setAssignments(asg.assignments ?? []);
    })().catch(() => undefined);
  }, []);

  const isManagement = active?.role === 'management';
  const checklist = isManagement
    ? [
        { done: true, label: 'School registered', href: '/school/setup' },
        { done: stats.classes > 0, label: 'Install the Nigerian curriculum', href: '/school/setup' },
        { done: stats.pairs > 0, label: 'Choose the subjects each class offers', href: '/school/setup' },
        { done: stats.students > 0, label: 'Enroll students with full details', href: '/school/students' },
        { done: false, label: 'Create teacher accounts and assign subjects', href: '/school/teachers' },
        { done: false, label: 'Fill and finalize the first result', href: '/school/results' },
      ]
    : [];

  const actions = isManagement
    ? [
        { icon: 'auto_stories', title: 'Syllabus & Notes', body: 'Build term syllabuses, topics and the note library.', href: '/school/syllabus' },
        { icon: 'fact_check', title: 'Attendance', body: 'Mark the daily register or open the classroom kiosk.', href: '/school/attendance' },
        { icon: 'groups', title: 'Students', body: 'Enroll pupils with full details and manage their subjects.', href: '/school/students' },
        { icon: 'workspace_premium', title: 'Results', body: 'Fill CA and exam scores, finalize, issue PINs.', href: '/school/results' },
        { icon: 'co_present', title: 'Teachers & Classes', body: 'Create staff accounts and hand out class subjects.', href: '/school/teachers' },
        { icon: 'settings', title: 'School Setup', body: 'Logo, address and the subjects every class offers.', href: '/school/setup' },
      ]
    : [
        { icon: 'auto_stories', title: 'My Syllabus & Notes', body: 'The classes and subjects assigned to you.', href: '/school/syllabus' },
        { icon: 'fact_check', title: 'Attendance', body: 'Take the register for a class you cover.', href: '/school/attendance' },
        { icon: 'workspace_premium', title: 'Fill Results', body: 'Your assigned class + subject score cells.', href: '/school/results' },
      ];

  return (
    <SchoolShell title="Home">
      <SchoolHeading
        title={isManagement ? `Welcome, ${active?.fullName || 'Management'}` : `Welcome, ${active?.fullName || 'Teacher'}`}
        sub={
          isManagement
            ? 'Run the whole school from one desk: curriculum, syllabuses with notes, attendance, students, staff and results.'
            : 'Your assigned classes, the syllabus and notes you teach from, the register and the results you fill.'
        }
      />

      {/* stat band */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {(isManagement
          ? [
              { label: 'Classes', value: stats.classes, href: '/school/setup' },
              { label: 'Students enrolled', value: stats.students, href: '/school/students' },
              { label: 'Subjects', value: stats.subjects, href: '/school/setup' },
              { label: 'Staff assignments', value: assignments.length, href: '/school/teachers' },
            ]
          : [
              { label: 'My assignments', value: assignments.length, href: '/school/syllabus' },
              { label: 'Classes I cover', value: new Set(assignments.map((a) => a.classId)).size, href: '/school/syllabus' },
              { label: 'Subjects I cover', value: new Set(assignments.map((a) => a.subjectId)).size, href: '/school/syllabus' },
            ]
        ).map((c) => (
          <Link
            key={c.label}
            href={c.href}
            className="school-shell-card p-5 no-underline transition-shadow hover:shadow-md"
          >
            <p className="school-stat-value">{c.value}</p>
            <p className="school-stat-label">{c.label}</p>
          </Link>
        ))}
      </div>

      {isManagement && (
        <div className="mt-6 grid gap-4 lg:grid-cols-2">
          {/* setup checklist */}
          <Card>
            <CardTitle hint="Everything below lives on the web portal. The app mirrors syllabus, notes and scheme of work for your staff offline.">
              School setup
            </CardTitle>
            <ul className="space-y-2.5">
              {checklist.map((step) => (
                <li key={step.label}>
                  <Link
                    href={step.href}
                    className="flex items-center gap-3 rounded-lg px-2 py-1.5 no-underline transition-colors hover:bg-surface-container"
                  >
                    <span
                      className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border text-[13px] ${
                        step.done
                          ? 'border-primary bg-primary text-on-primary'
                          : 'border-outline-variant text-on-surface-variant'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[14px]">{step.done ? 'check' : 'chevron_right'}</span>
                    </span>
                    <span className={`text-sm ${step.done ? 'text-on-surface-variant line-through' : 'font-medium text-on-surface'}`}>
                      {step.label}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
            {stats.classes === 0 && (
              <button
                className={btnPrimary + ' mt-4'}
                disabled={seeding}
                onClick={async () => {
                  const a = getActiveSchool();
                  if (!a) return;
                  setSeeding(true);
                  try {
                    await seedCurriculum(a.schoolId);
                    window.location.reload();
                  } finally {
                    setSeeding(false);
                  }
                }}
              >
                {seeding ? 'Installing…' : 'Install the Nigerian curriculum'}
              </button>
            )}
          </Card>

          {/* at a glance */}
          <Card>
            <CardTitle>At a glance</CardTitle>
            <div className="space-y-3">
              <MiniRow label="Latest class" value={classes.length ? classes[classes.length - 1]?.name : 'Install the curriculum'} />
              <MiniRow
                label="Class + subject pairs wired"
                value={stats.pairs > 0 ? `${stats.pairs} pairs` : 'Not set up yet'}
              />
              <MiniRow
                label="Students needing subject tracks"
                value={
                  classes.some((c) => c.level === 'senior')
                    ? 'Set SSS subjects in Students'
                    : 'Not applicable (no SSS class yet)'
                }
              />
              <MiniRow
                label="Result-check PINs"
                value="Issued when you finalize a term"
              />
            </div>
            <div className="mt-5 flex flex-wrap gap-3">
              <Link href="/school/results" className={btnGhost}>
                Open Results
              </Link>
              <Link href="/school/attendance" className={btnGhost}>
                Take Attendance
              </Link>
            </div>
          </Card>
        </div>
      )}

      {!isManagement && (
        <div className="mt-6">
          <Card>
            <CardTitle>My class + subject assignments</CardTitle>
            {assignments.length === 0 ? (
              <p className="text-sm text-on-surface-variant">
                No assignments yet. Management will grant you classes and subjects from the portal.
              </p>
            ) : (
              <ul className="flex flex-wrap gap-2">
                {assignments.map((a) => (
                  <li
                    key={a.id}
                    className="rounded-full border border-outline-variant bg-surface-container-lowest px-3.5 py-1.5 text-sm text-on-surface"
                  >
                    {a.className} · {a.subjectName}
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      )}

      {/* quick actions */}
      <div className="mt-8">
        <h2 className="mb-4 text-sm font-semibold uppercase tracking-[0.12em] text-on-surface-variant">Quick actions</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {actions.map((a) => (
            <Link
              key={a.title}
              href={a.href}
              className="school-shell-card group flex items-start gap-4 p-5 no-underline transition-shadow hover:shadow-md"
            >
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary text-on-primary">
                <span className="material-symbols-outlined text-[22px]">{a.icon}</span>
              </span>
              <span>
                <span className="block text-[15px] font-semibold text-on-surface">{a.title}</span>
                <span className="mt-0.5 block text-[13px] leading-relaxed text-on-surface-variant">{a.body}</span>
              </span>
              <span className="material-symbols-outlined ml-auto text-on-surface-variant transition-transform group-hover:translate-x-0.5">
                arrow_forward
              </span>
            </Link>
          ))}
        </div>
      </div>

      {/* offline note */}
      <p className="mt-8 rounded-xl border border-outline-variant bg-surface-container-lowest px-5 py-4 text-[13px] leading-relaxed text-on-surface-variant">
        Everything academic here also ships to the Renance mobile app for your staff: syllabus,
        scheme of work and notes download for offline use in the For Schools workspace. Result
        management, enrollment and attendance stay on the web.
      </p>
    </SchoolShell>
  );
}

function MiniRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-outline-variant/60 pb-2.5 last:border-0 last:pb-0">
      <span className="text-sm text-on-surface-variant">{label}</span>
      <span className="text-right text-sm font-medium text-on-surface">{value}</span>
    </div>
  );
}
