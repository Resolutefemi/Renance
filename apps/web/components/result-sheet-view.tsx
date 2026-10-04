'use client';

// The report-card body shared by the management results grid and the
// public PIN checker page - rebuilt as the GGSA "Stitch" result sheet
// (founder directive 2026-10-04: use the exact God Generals Standard
// Academy result template and colours). Ported from
// ggsa-result-portal/src/components/result-sheet.tsx; same props/
// export as the old B&W table so callers keep working. GGSA-only data
// (traits, attendance, term history, school contact lines) renders when
// the API ships it and falls back to neutral dashes otherwise.

import Link from 'next/link';
import {
  BEHAVIOUR_TRAITS,
  GRADE_SCALE,
  SKILL_TRAITS,
  termLabel,
  type ResultItem,
  type ResultSheet,
} from '@/lib/school';

function ordinal(n: number | null | undefined): string {
  if (n == null) return '-';
  const s = ['th', 'st', 'nd', 'rd'];
  const v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]);
}

function fmt(n: number | null | undefined): string {
  if (n == null) return '';
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}

function dash(n: number | null | undefined): string {
  if (n == null) return '-';
  return fmt(n);
}

/* Grade chip colouring (matches the Stitch design) */
const GRADE_CELL: Record<string, string> = {
  A: 'font-bold text-emerald-800 bg-emerald-50',
  B: 'font-bold text-brand-800 bg-purple-100/50',
  C: 'font-bold text-slate-800 bg-slate-100',
  D: 'font-bold text-sky-800 bg-sky-50',
  E: 'font-bold text-amber-800 bg-amber-50',
  F: 'font-bold text-red-800 bg-red-50',
};

const GRADE_REMARK: Record<string, string> = {
  A: 'text-xs text-emerald-700 font-medium',
  B: 'text-xs text-slate-700',
  C: 'text-xs text-slate-700',
  D: 'text-xs text-sky-700',
  E: 'text-xs text-amber-700',
  F: 'text-xs text-red-700',
};

const BIO_LABEL = 'rs-bio-label text-slate-500 font-medium block text-[11px] leading-tight';

export function ResultSheetView({ sheet }: { sheet: ResultSheet }) {
  // items may arrive null from older API payloads (unscored students) -
  // normalize once so every reader below is safe.
  const items = sheet.items ?? [];

  // Overall average (mean of subject totals)
  const totals = items.map((i) => i.total).filter((t): t is number => t != null);
  const overallAvg = totals.length > 0 ? totals.reduce((a, b) => a + b, 0) / totals.length : 0;

  const cls = (sheet.className || '').toUpperCase();
  const isSenior = cls.startsWith('SS');
  const isJunior = cls.startsWith('JSS') || cls.startsWith('JS');
  const pillText = isSenior
    ? 'REPORT CARD FOR SENIOR SECONDARY SCHOOL'
    : isJunior
      ? 'REPORT CARD FOR JUNIOR SECONDARY SCHOOL'
      : 'REPORT CARD';
  const termNum = sheet.term === 1 ? 1 : sheet.term === 2 ? 2 : sheet.term === 3 ? 3 : 0;

  const dateIssued = new Date().toLocaleDateString('en-US', {
    month: 'numeric',
    day: 'numeric',
    year: 'numeric',
  });

  // Cumulative total across terms when history ships, else the term total.
  const cumulative = (it: ResultItem): number | null => {
    const first = it.firstTermScore ?? null;
    const second = it.secondTermScore ?? null;
    const third = it.thirdTermScore ?? null;
    if (first != null || second != null || third != null) {
      return (first ?? 0) + (second ?? 0) + (third ?? 0);
    }
    return it.total;
  };

  // Traits: props when present, else the GGSA paper-card lists, unrated.
  const propTraits = sheet.traits ?? [];
  const propSkills = propTraits.filter((t) => t.section === 'SKILL');
  const propBehaviours = propTraits.filter((t) => t.section === 'BEHAVIOUR');
  const skillTraits =
    propSkills.length > 0 ? propSkills : SKILL_TRAITS.map((name) => ({ name, rating: null as string | null }));
  const behaviourTraits =
    propBehaviours.length > 0
      ? propBehaviours
      : BEHAVIOUR_TRAITS.map((name) => ({ name, rating: null as string | null }));

  return (
    <div>
      <p className="school-no-print mb-3 text-sm text-slate-600">
        {sheet.className} · {termLabel(sheet.term)} · {sheet.session || ''} ·{' '}
        {sheet.status === 'finalized' ? 'Finalized' : 'Draft'}
      </p>

      <article className="result-sheet page-sheet w-full max-w-4xl mx-auto bg-white rounded-xl shadow-lg border border-slate-200 overflow-hidden flex flex-col p-4 sm:p-6 md:p-7 space-y-3 text-slate-800">
        {/* ==================== HEADER ==================== */}
        <header className="rs-header border-b-2 border-brand-900 pb-3">
          <div className="flex flex-col md:flex-row items-center justify-between gap-3 text-center md:text-left">
            {/* School Crest */}
            <div className="flex items-center gap-3 shrink-0">
              <div className="rs-logo w-20 h-20 sm:w-24 sm:h-24 flex items-center justify-center shrink-0">
                {sheet.schoolLogoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={sheet.schoolLogoUrl}
                    alt={`${sheet.schoolName || 'School'} logo`}
                    className="w-full h-full object-cover rounded-full border border-brand-200"
                  />
                ) : (
                  <span className="school-title flex h-full w-full items-center justify-center rounded-full border border-brand-200 bg-brand-50 text-2xl font-bold text-brand-900">
                    {(sheet.schoolName || 'R').trim().charAt(0).toUpperCase()}
                  </span>
                )}
              </div>
            </div>
            {/* School Names & Details */}
            <div className="flex-1 px-1 sm:px-3 text-center">
              <h1 className="school-title text-xl sm:text-2xl md:text-3xl font-bold tracking-tight text-brand-900 leading-tight">
                {sheet.schoolName || 'Report Card'}
              </h1>
              {(sheet.schoolAddress || sheet.schoolPhone || sheet.schoolEmail) && (
                <>
                  {sheet.schoolAddress && (
                    <p className="rs-addr text-[11px] sm:text-xs text-slate-600 mt-1 font-medium leading-snug max-w-xl mx-auto">
                      {sheet.schoolAddress}
                    </p>
                  )}
                  <p className="rs-contact text-[10px] sm:text-[11px] text-slate-500 mt-0.5">
                    {sheet.schoolPhone && (
                      <span>
                        <strong>Tel:</strong> {sheet.schoolPhone}
                      </span>
                    )}
                    {sheet.schoolPhone && sheet.schoolEmail && (
                      <span className="inline-block text-slate-300 mx-1 sm:mx-2">|</span>
                    )}
                    {sheet.schoolEmail && (
                      <span>
                        <strong>E-mail:</strong> {sheet.schoolEmail}
                      </span>
                    )}
                  </p>
                </>
              )}
            </div>
            {/* Academic Motto Badge */}
            {sheet.schoolMotto && (
              <div className="shrink-0 flex items-center">
                <div className="rs-motto bg-brand-900 text-amber-300 px-3 py-2 rounded-lg text-center shadow-sm border border-brand-700 max-w-[130px]">
                  <span className="block text-[10px] italic leading-tight font-medium">{sheet.schoolMotto}</span>
                </div>
              </div>
            )}
          </div>
          {/* Report Card Subheading */}
          <div className="mt-2 pt-1.5 border-t border-purple-100 flex items-center justify-center">
            <div className="rs-pill inline-block bg-brand-100 border border-brand-200 text-brand-900 text-xs sm:text-sm font-bold tracking-wider uppercase px-4 py-1 rounded-full">
              {pillText}
            </div>
          </div>
        </header>

        {/* ==================== STUDENT PROFILE GRID ==================== */}
        <section className="rs-bio bg-slate-50 border border-slate-200 rounded-lg p-2.5 text-xs leading-relaxed">
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-y-2 gap-x-4">
            <div>
              <span className={BIO_LABEL}>Pupil Name</span>
              <span className="font-bold text-slate-900 uppercase">{sheet.studentName || '-'}</span>
            </div>
            <div>
              <span className={BIO_LABEL}>Class &amp; Year</span>
              <span className="font-bold text-slate-900">
                {sheet.className || '-'} • {sheet.session || '-'}
              </span>
            </div>
            <div>
              <span className={BIO_LABEL}>Admission No</span>
              <span className="font-bold text-slate-900 font-mono tracking-tight">
                {sheet.admissionNo || '-'}
              </span>
            </div>
            <div>
              <span className={BIO_LABEL}>Term</span>
              <span className="font-bold text-brand-900">{termLabel(sheet.term) || '-'}</span>
            </div>
            <div>
              <span className={BIO_LABEL}>Sex</span>
              <span className="font-semibold text-slate-800">
                {sheet.sex === 'F' ? 'Female' : sheet.sex === 'M' ? 'Male' : sheet.sex || '-'}
              </span>
            </div>
            <div>
              <span className={BIO_LABEL}>No. in Class</span>
              <span className="font-semibold text-slate-800">{sheet.noInClass ?? '-'}</span>
            </div>
            <div>
              <span className={BIO_LABEL}>Attendance / Opened</span>
              <span className="font-semibold text-slate-800">
                {sheet.attendancePresent ?? '-'} / {sheet.attendanceOpened ?? '-'} Times
              </span>
            </div>
            <div>
              <span className={BIO_LABEL}>Marks Obtainable</span>
              <span className="font-semibold text-slate-800">{sheet.marksObtainable ?? 100}</span>
            </div>
            <div className="col-span-2 sm:col-span-3 lg:col-span-4 pt-1.5 border-t border-slate-200/75 flex items-center justify-between gap-2">
              <div className="text-slate-600 font-medium text-xs">
                Academic Status:{' '}
                <span className="text-emerald-700 font-semibold">
                  {sheet.status === 'finalized' ? 'Active Enrollment' : 'Pending Review'}
                </span>
              </div>
              <div className="text-xs font-bold text-brand-900 bg-brand-50 px-3 py-0.5 rounded border border-brand-200 whitespace-nowrap">
                Overall Average:{' '}
                <span className="text-sm font-extrabold text-brand-700">
                  {overallAvg ? overallAvg.toFixed(1) + '%' : '-'}
                </span>
              </div>
            </div>
          </div>
        </section>

        {/* ==================== ACADEMIC PERFORMANCE TABLE ==================== */}
        <section className="rs-table-wrap overflow-x-auto rounded-lg border border-slate-300">
          <table className="table-report w-full border-collapse text-left text-xs bg-white min-w-[700px]">
            <colgroup>
              <col style={{ width: '20%' }} />
              <col style={{ width: '5%' }} />
              <col style={{ width: '5%' }} />
              <col style={{ width: '6.5%' }} />
              <col style={{ width: '6%' }} />
              <col style={{ width: '5.5%' }} />
              <col style={{ width: '5.5%' }} />
              <col style={{ width: '5.5%' }} />
              <col style={{ width: '5.5%' }} />
              <col style={{ width: '6.5%' }} />
              <col style={{ width: '5.5%' }} />
              <col style={{ width: '5.5%' }} />
              <col style={{ width: '5%' }} />
              <col style={{ width: '8.5%' }} />
            </colgroup>
            <thead>
              <tr className="bg-white text-slate-900 font-bold text-[11px] uppercase tracking-wider text-center border-b border-slate-300">
                <th className="p-2 text-left border-b border-slate-300 text-slate-900">Subject</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Test 1</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Test 2</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Term Exam</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900 bg-slate-50 font-extrabold">
                  Total
                </th>
                <th className="p-1.5 border-b border-slate-300 text-slate-700">1st Term</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-700">2nd Term</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-700">3rd Term</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900 font-extrabold bg-slate-50">
                  Total Score
                </th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Graded</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Class Avg</th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Position</th>
                <th className="p-1.5 border-b border-slate-300 text-amber-800 bg-amber-50 font-black">
                  Grade
                </th>
                <th className="p-1.5 border-b border-slate-300 text-slate-900">Remark</th>
              </tr>
              <tr className="bg-white text-slate-700 font-semibold text-[10px] text-center border-b-2 border-slate-300">
                <td className="p-1 text-left font-normal italic pl-2 text-slate-600">Marks Obtainable</td>
                <td className="p-1 text-slate-700">20</td>
                <td className="p-1 text-slate-700">20</td>
                <td className="p-1 text-slate-700">60</td>
                <td className="p-1 font-bold text-slate-900 bg-slate-50">100</td>
                <td className="p-1 text-slate-700">100</td>
                <td className="p-1 text-slate-700">100</td>
                <td className="p-1 text-slate-700">100</td>
                <td className="p-1 font-bold text-slate-900 bg-slate-50">100</td>
                <td className="p-1 text-slate-700">100</td>
                <td className="p-1 text-slate-700">100</td>
                <td className="p-1 text-slate-500">-</td>
                <td className="p-1 text-slate-500">-</td>
                <td className="p-1 text-slate-500">-</td>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 text-center font-medium text-slate-700">
              {items.length === 0 && (
                <tr>
                  <td colSpan={14} className="p-4 text-center text-slate-500">
                    No subjects recorded.
                  </td>
                </tr>
              )}
              {items.map((item, idx) => {
                const g = item.grade || '';
                const totalScore = cumulative(item);
                const termCell = (col: number, score: number | null | undefined) => (
                  <td
                    className={`p-1.5 ${
                      score == null
                        ? 'text-slate-400'
                        : col === termNum
                          ? 'font-semibold text-slate-800'
                          : 'text-slate-700'
                    }`}
                  >
                    {dash(score)}
                  </td>
                );
                return (
                  <tr key={item.subjectId || idx}>
                    <td className="p-1.5 text-left font-semibold text-slate-900 pl-2">{item.subjectName}</td>
                    <td className="p-1.5">{dash(item.ca1)}</td>
                    <td className="p-1.5">{dash(item.ca2)}</td>
                    <td className="p-1.5">{dash(item.exam)}</td>
                    <td className="p-1.5 font-bold text-slate-900 bg-purple-50/50">{dash(item.total)}</td>
                    {termCell(1, item.firstTermScore)}
                    {termCell(2, item.secondTermScore)}
                    {termCell(3, item.thirdTermScore)}
                    <td className="p-1.5 font-bold text-brand-900 bg-purple-50">{dash(totalScore)}</td>
                    <td className="p-1.5">{dash(item.total)}</td>
                    <td className="p-1.5">{dash(item.classAverage)}</td>
                    <td className="p-1.5 text-slate-500">
                      {item.position != null ? ordinal(item.position) : '-'}
                    </td>
                    <td className={`p-1.5 ${GRADE_CELL[g] || 'font-bold text-slate-800'}`}>{g || '-'}</td>
                    <td className={`p-1.5 ${GRADE_REMARK[g] || 'text-xs text-slate-700'}`}>
                      {item.remark || ''}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </section>

        {/* ==================== SKILLS & BEHAVIOUR ==================== */}
        <section className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {/* Development (Skills) Card */}
          <div className="rs-card border border-slate-200 rounded-lg overflow-hidden bg-white shadow-xs">
            <div className="rs-card-head bg-brand-900 text-white px-3 py-1.5 text-xs font-semibold uppercase tracking-wider flex items-center justify-between">
              <span>DEVELOPMENT (Skills)</span>
              <span className="text-[10px] text-amber-300 font-normal">Grade</span>
            </div>
            <div className="p-2.5 grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
              {skillTraits.length === 0 && (
                <div className="col-span-2 text-slate-400">No ratings recorded.</div>
              )}
              {skillTraits.map((t, i) => (
                <div
                  key={t.name}
                  className={`flex justify-between py-0.5 ${
                    i < skillTraits.length - 1 ? 'border-b border-slate-100' : 'col-span-2 sm:col-span-1'
                  }`}
                >
                  <span className="text-slate-600">{t.name}</span>
                  <span className="font-bold text-brand-900">{t.rating || '-'}</span>
                </div>
              ))}
            </div>
          </div>
          {/* Behaviour Card */}
          <div className="rs-card border border-slate-200 rounded-lg overflow-hidden bg-white shadow-xs">
            <div className="rs-card-head bg-brand-900 text-white px-3 py-1.5 text-xs font-semibold uppercase tracking-wider flex items-center justify-between">
              <span>BEHAVIOUR (Character)</span>
              <span className="text-[10px] text-amber-300 font-normal">Grade</span>
            </div>
            <div className="p-2.5 grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
              {behaviourTraits.length === 0 && (
                <div className="col-span-2 text-slate-400">No ratings recorded.</div>
              )}
              {behaviourTraits.map((t, i) => (
                <div
                  key={t.name}
                  className={`flex justify-between py-0.5 ${
                    i < behaviourTraits.length - 1 ? 'border-b border-slate-100' : 'col-span-2 sm:col-span-1'
                  }`}
                >
                  <span className="text-slate-600">{t.name}</span>
                  <span className="font-bold text-brand-900">{t.rating || '-'}</span>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ==================== REMARKS & REPORTS ==================== */}
        <section className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {/* Teacher Remark Box */}
          <div className="rs-report border border-purple-200 bg-purple-50/40 rounded-lg p-3 flex flex-col justify-between">
            <div>
              <span className="text-[11px] font-bold uppercase tracking-wider text-brand-900 block">
                Class Teacher&apos;s Report:
              </span>
              <p className="text-xs text-slate-800 italic mt-1.5 font-medium leading-relaxed">
                {sheet.teacherReport || '(No teacher report yet.)'}
              </p>
            </div>
            <div className="mt-3 pt-2 border-t border-dashed border-slate-300">
              <div className="flex items-end justify-between text-xs gap-2">
                <span className="text-slate-500 font-medium">Class Teacher&apos;s Signature:</span>
                {/* Left blank on purpose - the teacher signs by hand on the printed sheet */}
                <span className="inline-block w-28 border-b border-slate-400">&nbsp;</span>
              </div>
            </div>
          </div>
          {/* Principal Remark Box */}
          <div className="rs-report border border-purple-200 bg-purple-50/40 rounded-lg p-3 flex flex-col justify-between">
            <div>
              <span className="text-[11px] font-bold uppercase tracking-wider text-brand-900 block">
                Principal&apos;s Report:
              </span>
              <p className="text-xs text-slate-800 italic mt-1.5 font-medium leading-relaxed">
                {sheet.principalReport || '(No principal report yet.)'}
              </p>
            </div>
            <div className="mt-3 pt-2 border-t border-dashed border-slate-300">
              <div className="flex items-end justify-between text-xs gap-2">
                <span className="text-slate-500 font-medium">Principal&apos;s Signature:</span>
                {/* Left blank on purpose - the principal signs by hand on the printed sheet */}
                <span className="inline-block w-28 border-b border-slate-400">&nbsp;</span>
              </div>
            </div>
          </div>
        </section>

        {/* ==================== RATING KEYS & NEXT TERM ==================== */}
        <section className="grid grid-cols-1 md:grid-cols-3 gap-3 pt-1">
          {/* Grading Scale Legend */}
          <div className="rs-keys md:col-span-2 border border-slate-200 bg-slate-50/80 rounded-lg p-3">
            <h4 className="text-[11px] font-bold uppercase tracking-wider text-brand-900 mb-2">
              Keys to Rating / Score Rating
            </h4>
            <div className="grid grid-cols-3 gap-y-1.5 gap-x-2 text-[11px] text-slate-700">
              {GRADE_SCALE.map((g) => (
                <div key={g.grade}>
                  <strong className="text-brand-900 font-bold">{g.grade}</strong> = {g.remark} ({g.min}
                  {g.max < 100 ? `-${g.max}` : '+'})
                </div>
              ))}
            </div>
          </div>
          {/* Resumption Date Callout */}
          <div className="rs-next border-2 border-purple-300 bg-brand-50 rounded-lg p-3 flex flex-col justify-center items-center text-center">
            <span className="text-[11px] font-bold uppercase text-brand-900 tracking-wider">
              Next Term Begins
            </span>
            <div className="text-sm font-extrabold text-brand-950 mt-1">
              {sheet.nextTermBegins || 'To be announced'}
            </div>
            <span className="text-[10px] text-slate-500 mt-0.5">Please ensure prompt resumption</span>
          </div>
        </section>

        {/* ==================== VERIFICATION FOOTER ==================== */}
        <footer className="rs-footer pt-1.5 border-t border-slate-200 flex flex-col sm:flex-row items-center justify-between text-[11px] text-slate-500 gap-1">
          <div>
            Generated by <span className="font-medium text-slate-700">{sheet.schoolName || 'Renance for Schools'} - Renance Result Portal</span>
          </div>
          <div className="font-mono text-[10px] text-slate-400">
            Date Issued: {dateIssued} • Official Digital Copy
          </div>
        </footer>
      </article>

      {sheet.pin && (
        <p className="school-no-print mt-3 text-sm text-slate-600">
          Result-check PIN: <span className="font-mono font-semibold text-brand-900">{sheet.pin}</span> - students
          check it on the{' '}
          <Link className="text-ggsa-purple underline" href="/school/check">
            result checker
          </Link>
          .
        </p>
      )}
    </div>
  );
}
