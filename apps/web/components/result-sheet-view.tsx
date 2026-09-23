'use client';

// The report-card body shared by the management results grid and the
// public PIN checker page.

import Link from 'next/link';
import { termLabel, type ResultItem, type ResultSheet } from '@/lib/school';

export function ResultSheetView({ sheet }: { sheet: ResultSheet }) {
  const total = sheet.items.reduce((a, b) => a + (b.total || 0), 0);
  const count = sheet.items.length || 1;
  const average = Math.round((total / count) * 100) / 100;

  return (
    <div>
      <p className="text-sm text-on-surface-variant">
        {sheet.className} · {termLabel(sheet.term)} · {sheet.session || ''} ·{' '}
        {sheet.status === 'finalized' ? 'Finalized' : 'Draft'}
      </p>
      <table className="mt-4 w-full text-sm">
        <thead>
          <tr className="border-b border-outline-variant text-left text-xs uppercase text-on-surface-variant">
            <th className="py-2 pr-2">Subject</th>
            <th className="px-2 py-2">CA1</th>
            <th className="px-2 py-2">CA2</th>
            <th className="px-2 py-2">Exam</th>
            <th className="px-2 py-2">Total</th>
            <th className="px-2 py-2">Grade</th>
            <th className="px-2 py-2">Pos</th>
            <th className="px-2 py-2">Avg</th>
          </tr>
        </thead>
        <tbody>
          {sheet.items.length === 0 && (
            <tr>
              <td colSpan={8} className="py-4 text-on-surface-variant">
                No subject scores yet.
              </td>
            </tr>
          )}
          {sheet.items.map((it: ResultItem) => (
            <tr key={it.subjectId} className="border-b border-outline-variant/60">
              <td className="py-2 pr-2 font-medium text-on-surface">{it.subjectName}</td>
              <td className="px-2 py-2 text-on-surface">{it.ca1}</td>
              <td className="px-2 py-2 text-on-surface">{it.ca2}</td>
              <td className="px-2 py-2 text-on-surface">{it.exam}</td>
              <td className="px-2 py-2 font-semibold text-on-surface">{it.total}</td>
              <td className="px-2 py-2 text-on-surface">
                {it.grade} {it.remark && <span className="text-xs text-on-surface-variant">({it.remark})</span>}
              </td>
              <td className="px-2 py-2 text-on-surface">{it.position || '-'}</td>
              <td className="px-2 py-2 text-on-surface">{it.classAverage || '-'}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="mt-3 text-sm font-medium text-on-surface">
        Overall average: {average} ({sheet.items.length} subject{sheet.items.length === 1 ? '' : 's'})
      </p>
      {sheet.teacherReport && (
        <p className="mt-3 text-sm text-on-surface-variant">
          <span className="font-medium text-on-surface">Teacher&apos;s remark:</span> {sheet.teacherReport}
        </p>
      )}
      {sheet.principalReport && (
        <p className="mt-1 text-sm text-on-surface-variant">
          <span className="font-medium text-on-surface">Principal&apos;s remark:</span> {sheet.principalReport}
        </p>
      )}
      {sheet.pin && (
        <p className="mt-3 text-sm text-on-surface-variant">
          Result-check PIN: <span className="font-mono font-semibold text-on-surface">{sheet.pin}</span> - students check
          it on the{' '}
          <Link className="text-primary underline" href="/school/check">
            result checker
          </Link>
          .
        </p>
      )}
    </div>
  );
}
