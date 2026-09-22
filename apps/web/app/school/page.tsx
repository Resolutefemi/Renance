'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { SchoolHeading, SchoolShell, btnGhost, selectCls } from '@/components/school-shell';
import {
  fetchAssignments,
  fetchClasses,
  fetchClassSubjects,
  fetchStudents,
  fetchSubjects,
  getActiveSchool,
  type ActiveSchool,
  type AssignmentDetail,
  type SchoolClass,
} from '@/lib/school';

export default function SchoolOverviewPage() {
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [stats, setStats] = useState({ classes: 0, subjects: 0, students: 0, pairs: 0 });
  const [assignments, setAssignments] = useState<AssignmentDetail[]>([]);
  const [seedDone, setSeedDone] = useState<string | null>(null);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setActive(a);
    (async () => {
      try {
        const [cls, subs, studs, pairs, asg] = await Promise.all([
          fetchClasses(a.schoolId),
          fetchSubjects(a.schoolId),
          fetchStudents(a.schoolId),
          fetchClassSubjects(a.schoolId),
          fetchAssignments(a.schoolId, a.role === 'teacher' ? a.memberId : ''),
        ]);
        setStats({
          classes: cls.classes?.length ?? 0,
          subjects: subs.subjects?.length ?? 0,
          students: studs.students?.length ?? 0,
          pairs: pairs.pairs?.length ?? 0,
        });
        setAssignments(asg.assignments ?? []);
      } catch {
        /* overview is best-effort */
      }
    })();
  }, []);

  const isManagement = active?.role === 'management';

  const cards = isManagement
    ? [
        { label: 'Classes', value: stats.classes, href: '/school/teachers' },
        { label: 'Subjects', value: stats.subjects, href: '/school/teachers' },
        { label: 'Class × Subject pairs', value: stats.pairs, href: '/school/syllabus' },
        { label: 'Students enrolled', value: stats.students, href: '/school/students' },
      ]
    : [
        { label: 'My assignments', value: assignments.length, href: '/school/syllabus' },
        { label: 'Classes I cover', value: new Set(assignments.map((a) => a.classId)).size, href: '/school/syllabus' },
        { label: 'Subjects I cover', value: new Set(assignments.map((a) => a.subjectId)).size, href: '/school/syllabus' },
      ];

  return (
    <SchoolShell title="Overview">
      <SchoolHeading
        title={isManagement ? `Welcome, ${active?.fullName || 'Management'}` : `Welcome, ${active?.fullName || 'Teacher'}`}
        sub={
          isManagement
            ? 'Run the school from here: curriculum, syllabuses with notes, teacher accounts, students and results.'
            : 'Your class + subject assignments, the syllabus, scheme of work and notes — and the results you fill.'
        }
      />

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {cards.map((c) => (
          <Link
            key={c.label}
            href={c.href}
            className="rounded-xl border border-outline-variant bg-surface-container-lowest p-5 transition-shadow hover:shadow-md"
          >
            <p className="text-3xl font-semibold text-on-surface">{c.value}</p>
            <p className="mt-1 text-sm text-on-surface-variant">{c.label}</p>
          </Link>
        ))}
      </div>

      {isManagement && (
        <div className="mt-8 grid gap-4 md:grid-cols-2">
          <div className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
            <h2 className="text-base font-semibold text-on-surface">Curriculum</h2>
            <p className="mt-1 text-sm text-on-surface-variant">
              {stats.classes > 0
                ? 'The Nigerian curriculum is installed. Open Syllabus & Notes to build terms and write notes.'
                : 'Install the full Nigerian curriculum — Primary 1–6, JSS 1–3, SSS 1–3 with every NERDC subject — in one tap.'}
            </p>
            <div className="mt-4 flex gap-3">
              <Link href="/school/syllabus" className={btnGhost}>
                Syllabus & Notes
              </Link>
              {stats.classes === 0 && <SeedButton onDone={(msg) => setSeedDone(msg)} />}
            </div>
            {seedDone && <p className="mt-3 text-sm text-on-surface">{seedDone}</p>}
          </div>

          <div className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
            <h2 className="text-base font-semibold text-on-surface">Teachers & results</h2>
            <p className="mt-1 text-sm text-on-surface-variant">
              Create teacher accounts (they sign in under For Schools → For Teachers), assign them
              classes and subjects, and let them fill results exactly like the result portal.
            </p>
            <div className="mt-4 flex gap-3">
              <Link href="/school/teachers" className={btnGhost}>
                Teachers & Classes
              </Link>
              <Link href="/school/results" className={btnGhost}>
                Results
              </Link>
            </div>
          </div>
        </div>
      )}

      {!isManagement && (
        <div className="mt-8 rounded-xl border border-outline-variant bg-surface-container-lowest p-6">
          <h2 className="text-base font-semibold text-on-surface">My class + subject assignments</h2>
          {assignments.length === 0 ? (
            <p className="mt-2 text-sm text-on-surface-variant">
              No assignments yet — management will grant you classes and subjects from the portal.
            </p>
          ) : (
            <ul className="mt-3 flex flex-wrap gap-2">
              {assignments.map((a) => (
                <li key={a.id} className="rounded-full bg-surface-container px-3 py-1.5 text-sm text-on-surface">
                  {a.className} · {a.subjectName}
                </li>
              ))}
            </ul>
          )}
          <div className="mt-4 flex gap-3">
            <Link href="/school/syllabus" className={btnGhost}>
              Open Syllabus & Notes
            </Link>
            <Link href="/school/results" className={btnGhost}>
              Fill Results
            </Link>
          </div>
        </div>
      )}

      <p className="mt-8 text-xs text-on-surface-variant">
        Everything here also ships to the Renance mobile app for your staff — syllabus, scheme of
        work and notes download for offline use. Result management stays on the web.
      </p>
    </SchoolShell>
  );
}

function SeedButton({ onDone }: { onDone: (msg: string) => void }) {
  const [busy, setBusy] = useState(false);
  const a = getActiveSchool();

  return (
    <button
      className={btnGhost}
      disabled={busy || !a}
      onClick={async () => {
        if (!a) return;
        setBusy(true);
        try {
          const { seedCurriculum } = await import('@/lib/school');
          const res = await seedCurriculum(a.schoolId);
          onDone(`Installed ${res.seededClasses} classes and ${res.seededSubjects} subjects.`);
        } finally {
          setBusy(false);
        }
      }}
    >
      {busy ? 'Installing…' : 'Install curriculum'}
    </button>
  );
}
