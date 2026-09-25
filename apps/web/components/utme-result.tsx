'use client';

/**
 * UtmeResultSlip - the official JAMB UTME score slip for composite mock
 * papers (jamb-mock-*). Prints like the real thing: one row per subject
 * with questions attempted, total questions, marks (correct over total),
 * the subject score out of 100 and the time spent on that subject, then
 * the four subject marks summed into the final score out of 400.
 *
 * Scoring rules (official UTME):
 *   Use of English: 60 questions, score = correct / 60 * 100.
 *   Other subjects: 40 questions each at 2.5 marks per question,
 *                   score = correct / 40 * 100.
 *   Total: the four subject scores (each out of 100) added together,
 *          out of 400.
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
  questions: ReactNode;
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

export default function UtmeResultSlip({ subjects, questions }: Props) {
  if (!subjects || subjects.length === 0) return null;
  const totalScore = subjects.reduce((sum, s) => sum + s.score, 0);
  const totalQ = subjects.reduce((sum, s) => sum + s.total, 0);
  const totalCorrect = subjects.reduce((sum, s) => sum + s.correct, 0);
  const totalTime = subjects.reduce((sum, s) => sum + s.timeMs, 0);
  const totalAttempted = subjects.reduce((sum, s) => sum + s.attempted, 0);

  return (
    <section
      className="renance-rise mt-4 overflow-hidden rounded-xl border-2 border-[#101418] bg-white"
      aria-label="JAMB UTME official score slip"
    >
      {/* slip head */}
      <div className="border-b-2 border-[#101418] bg-[#101418] px-4 py-3 text-white sm:px-6">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-white/70">
              Unified Tertiary Matriculation Examination
            </p>
            <p className="mt-0.5 text-lg font-bold tracking-tight sm:text-xl">
              JAMB UTME Mock · Official Score
            </p>
          </div>
          <div className="text-right">
            <p className="text-4xl font-bold leading-none tracking-tight sm:text-5xl">
              {Math.round(totalScore)}
              <span className="text-xl text-white/60">/400</span>
            </p>
            <p className="mt-1 font-mono text-[11px] uppercase tracking-widest text-white/70">
              aggregate
            </p>
          </div>
        </div>
      </div>

      {/* scoring rules strip */}
      <div className="border-b border-[#101418]/20 bg-[#F5F5F4] px-4 py-2.5 sm:px-6">
        <p className="font-mono text-[10.5px] leading-relaxed text-[#3F3F46] sm:text-[11.5px]">
          Use of English: 60 questions, score divided by 60 and multiplied
          by 100. Other subjects: 40 questions each, 2.5 marks per question
          (100 marks per subject), correct answers divided by 40 and
          multiplied by 100. Total: the four subject scores added together,
          out of 400.
        </p>
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
                {Math.round(totalScore)}
                <span className="text-white/60">/400</span>
              </td>
              <td className="px-4 py-3 text-right font-mono text-[13.5px] sm:px-6">
                {fmtTime(totalTime)}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      {/* per-subject mark bar */}
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
        <p className="pt-1 font-mono text-[10.5px] leading-relaxed text-[#71717A]">
          {questions}
        </p>
      </div>
    </section>
  );
}
