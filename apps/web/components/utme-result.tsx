'use client';

/**
 * UtmeResultSlip - the official JAMB UTME score slip for composite mock
 * papers (jamb-mock-*). The hero of the result page: the aggregate out
 * of 400 is the biggest thing on the screen, the four subjects line up
 * under it with their marks, and nothing explains the scoring method -
 * the slip just prints the verdict like the real thing.
 *
 * One row per subject: questions attempted, total questions, marks
 * (correct over total), the subject score out of 100 and the time spent
 * on that subject. The four subject marks sum to the final score.
 *
 * Strictly black and white: the slip reads like printed paper.
 */

import type { ReactNode } from 'react';

export interface UtmeSubjectRow {
  subject: string;
  attempted: number;
  total: number;
  correct: number;
  score: number;
  timeMs: number;
}

interface Props {
  subjects: UtmeSubjectRow[];
  /** Optional delta vs the previous mock, shown as a small badge. */
  delta?: number | null;
  /** Optional small caption under the aggregate (e.g. the percentage). */
  caption?: ReactNode;
}

const fmtScore = (n: number) =>
  Number.isInteger(n) ? String(n) : n.toFixed(1);

const fmtTime = (ms: number) => {
  if (!ms || ms <= 0) return '-';
  const total = Math.round(ms / 1000);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
};

export default function UtmeResultSlip({ subjects, delta, caption }: Props) {
  if (!subjects || subjects.length === 0) return null;
  const totalScore = subjects.reduce((sum, s) => sum + s.score, 0);
  const aggregate = Math.round(totalScore);
  const totalQ = subjects.reduce((sum, s) => sum + s.total, 0);
  const totalCorrect = subjects.reduce((sum, s) => sum + s.correct, 0);
  const totalTime = subjects.reduce((sum, s) => sum + s.timeMs, 0);
  const totalAttempted = subjects.reduce((sum, s) => sum + s.attempted, 0);
  const best = subjects.reduce((a, s) => (s.score > a.score ? s : a), subjects[0]);

  return (
    <section
      className="renance-rise mt-4 overflow-hidden rounded-xl border-2 border-[#101418] bg-white"
      aria-label="JAMB UTME official score slip"
    >
      {/* slip head: the aggregate IS the headline */}
      <div className="border-b-2 border-[#101418] bg-[#101418] px-4 pb-7 pt-6 text-center text-white sm:px-6">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-white/60">
          Unified Tertiary Matriculation Examination · Official Score
        </p>
        <p className="mt-3 text-7xl font-bold leading-none tracking-tight sm:text-8xl">
          {aggregate}
          <span className="text-3xl text-white/50">/400</span>
        </p>
        {delta != null && (
          <div className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1">
            <span
              className={`material-symbols-outlined text-sm ${delta >= 0 ? 'text-accent-emerald' : 'text-error'}`}
            >
              {delta >= 0 ? 'trending_up' : 'trending_down'}
            </span>
            <span
              className={`font-mono text-xs ${delta >= 0 ? 'text-accent-emerald' : 'text-error'}`}
            >
              {delta >= 0 ? `+${delta}` : delta} vs last mock
            </span>
          </div>
        )}
        {caption != null && (
          <p className="mt-2 font-mono text-[11px] text-white/45">{caption}</p>
        )}
      </div>

      {/* the slip table */}
      <div className="overflow-x-auto">
        <table className="w-full min-w-[560px] border-collapse text-left">
          <thead>
            <tr className="border-b border-[#101418]/25 font-mono text-[10px] uppercase tracking-[0.14em] text-[#52525B]">
              <th className="px-4 py-2.5 font-semibold sm:px-6">Subject</th>
              <th className="px-2 py-2.5 text-center font-semibold">Attempted</th>
              <th className="px-2 py-2.5 text-center font-semibold">Questions</th>
              <th className="px-2 py-2.5 text-center font-semibold">Marks</th>
              <th className="px-2 py-2.5 text-center font-semibold">Score</th>
              <th className="px-4 py-2.5 text-right font-semibold sm:px-6">Time</th>
            </tr>
          </thead>
          <tbody>
            {subjects.map((s, i) => (
              <tr
                key={s.subject}
                className={`border-b border-[#101418]/10 text-[13.5px] sm:text-sm ${
                  i % 2 === 1 ? 'bg-[#FAFAF9]' : 'bg-white'
                }`}
              >
                <td className="px-4 py-3 font-semibold text-[#101418] sm:px-6">
                  {s.subject}
                  {s.subject === best.subject && (
                    <span className="ml-2 rounded-full border border-[#101418]/20 px-2 py-0.5 font-mono text-[9px] uppercase tracking-widest text-[#52525B]">
                      best
                    </span>
                  )}
                </td>
                <td className="px-2 py-3 text-center font-mono text-[#3F3F46]">
                  {s.attempted}
                </td>
                <td className="px-2 py-3 text-center font-mono text-[#3F3F46]">
                  {s.total}
                </td>
                <td className="px-2 py-3 text-center font-mono text-[#3F3F46]">
                  {s.correct}/{s.total}
                </td>
                <td className="px-2 py-3 text-center font-mono text-base font-bold text-[#101418]">
                  {fmtScore(s.score)}
                </td>
                <td className="px-4 py-3 text-right font-mono text-[#3F3F46] sm:px-6">
                  {fmtTime(s.timeMs)}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr className="border-t-2 border-[#101418] bg-[#101418] text-white">
              <td className="px-4 py-3 text-sm font-bold sm:px-6">Total</td>
              <td className="px-2 py-3 text-center font-mono text-[13.5px]">
                {totalAttempted}
              </td>
              <td className="px-2 py-3 text-center font-mono text-[13.5px]">
                {totalQ}
              </td>
              <td className="px-2 py-3 text-center font-mono text-[13.5px]">
                {totalCorrect}/{totalQ}
              </td>
              <td className="px-2 py-3 text-center font-mono text-base font-bold">
                {aggregate}
                <span className="text-white/60">/400</span>
              </td>
              <td className="px-4 py-3 text-right font-mono text-[13.5px] sm:px-6">
                {fmtTime(totalTime)}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      {/* per-subject mark bars: the slip's own read of where the marks sit */}
      <div className="space-y-3 px-4 py-4 sm:px-6">
        {subjects.map((s) => {
          const pct = Math.min(100, s.score);
          return (
            <div key={`bar-${s.subject}`}>
              <div className="flex items-baseline justify-between text-[12.5px]">
                <span className="font-semibold text-[#101418]">{s.subject}</span>
                <span className="font-mono text-[#3F3F46]">
                  {fmtScore(s.score)}/100
                </span>
              </div>
              <div className="mt-1.5 h-2 overflow-hidden rounded-full border border-[#101418]/15 bg-white">
                <div
                  className="h-full rounded-full bg-[#101418]"
                  style={{ width: `${pct}%` }}
                />
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
