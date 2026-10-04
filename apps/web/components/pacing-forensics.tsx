'use client';

/**
 * PacingForensicsCard - Post-Exam Time & Panic Diagnostics for Renance Study OS.
 *
 * Displays on the graded results screen to expose time leaks, identified time-traps,
 * and end-of-paper panic, helping students strategize for real exam day.
 */

import Link from 'next/link';
import { type PacingForensicsReport } from '@/lib/pacing';

interface Props {
  report: PacingForensicsReport;
  attemptId?: string;
}

export default function PacingForensicsCard({ report, attemptId }: Props) {
  const {
    targetSecPerQuestion,
    averageSecPerQuestion,
    pacingEfficiencyPct,
    timeTraps,
    hasPanicZone,
    panicQuestionsCount,
    estimatedRecoverableMarks,
    summaryFeedback,
  } = report;

  const scoreBadgeColor =
    pacingEfficiencyPct >= 80
      ? 'border-accent-emerald/40 bg-accent-emerald/10 text-accent-emerald'
      : pacingEfficiencyPct >= 60
        ? 'border-accent-amber/40 bg-accent-amber/10 text-on-surface'
        : 'border-error/40 bg-error/10 text-error';

  return (
    <section className="mt-4 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.18)]">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="material-symbols-outlined text-[20px] text-primary">avg_time</span>
          <h3 className="text-[16px] font-bold text-on-surface">Pacing & Clock Forensics</h3>
        </div>
        <span className={`rounded-full border px-2.5 py-0.5 font-mono text-[11px] font-bold ${scoreBadgeColor}`}>
          {pacingEfficiencyPct}% Pacing Score
        </span>
      </div>

      <p className="mt-2 text-[13.5px] leading-relaxed text-on-surface-variant">
        {summaryFeedback}
      </p>

      {/* Metrics Row */}
      <div className="mt-3.5 grid grid-cols-3 gap-2">
        <div className="rounded-lg bg-surface-container-low/60 p-2.5 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-outline">Target Speed</p>
          <p className="mt-0.5 text-[15px] font-bold text-on-surface">{targetSecPerQuestion}s / Q</p>
        </div>
        <div className="rounded-lg bg-surface-container-low/60 p-2.5 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-outline">Actual Speed</p>
          <p className="mt-0.5 text-[15px] font-bold text-on-surface">{averageSecPerQuestion}s / Q</p>
        </div>
        <div className="rounded-lg bg-surface-container-low/60 p-2.5 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-outline">Lost to Clock</p>
          <p className="mt-0.5 text-[15px] font-bold text-error">~{estimatedRecoverableMarks} pts</p>
        </div>
      </div>

      {/* Panic Zone Warning Banner */}
      {hasPanicZone && (
        <div className="mt-3.5 flex items-start gap-2.5 rounded-lg border border-error/30 bg-error/5 p-3 text-[13px] text-on-surface">
          <span className="material-symbols-outlined shrink-0 text-[18px] text-error">alarm_off</span>
          <div>
            <p className="font-semibold text-error">End-of-Exam Panic Zone Detected</p>
            <p className="mt-0.5 text-[12.5px] leading-relaxed text-on-surface-variant">
              You rushed through {panicQuestionsCount} questions in the final minutes with under 14 seconds each. 
              Pacing earlier questions saves high-value marks at the end.
            </p>
          </div>
        </div>
      )}

      {/* Time Traps List */}
      {timeTraps.length > 0 && (
        <div className="mt-4 border-t border-outline-variant/30 pt-3">
          <div className="flex items-center justify-between">
            <h4 className="text-[13.5px] font-bold text-on-surface">
              Identified Time Traps ({timeTraps.length})
            </h4>
            <span className="font-mono text-[10.5px] text-outline">
              Excess: {Math.round(report.totalTimeTrapsDurationSec / 60)} mins
            </span>
          </div>

          <div className="mt-2 space-y-2">
            {timeTraps.slice(0, 4).map((trap) => (
              <div
                key={trap.questionId}
                className="flex items-center justify-between rounded-lg border border-outline-variant/40 bg-surface-container-lowest p-2.5"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <span
                    className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[11px] font-bold ${
                      trap.correct
                        ? 'bg-accent-emerald/15 text-accent-emerald'
                        : 'bg-error/15 text-error'
                    }`}
                  >
                    Q{trap.index + 1}
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-[12.5px] font-semibold text-on-surface">
                      {trap.topic}
                    </p>
                    <p className="text-[11px] text-on-surface-variant">
                      {trap.durationSec}s spent (target: {trap.targetSec}s) ·{' '}
                      {trap.correct ? 'Marked Correct' : 'Missed'}
                    </p>
                  </div>
                </div>

                {attemptId && (
                  <Link
                    href={`/review?attemptId=${attemptId}`}
                    className="shrink-0 rounded-md bg-surface-container px-2 py-1 text-[11.5px] font-medium text-primary hover:bg-surface-container-high"
                  >
                    Review
                  </Link>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
