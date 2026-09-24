/**
 * CBT Pacing & Panic Forensics Engine for Renance Study OS.
 *
 * Trains students to manage the CBT clock, avoid deadly time-traps,
 * and eliminate end-of-exam panic in high-stakes tests (e.g. JAMB UTME, WAEC).
 *
 * Pure, zero-dependency logic, runs 100% offline-first.
 */

export type PacingState = 'on_track' | 'lingering' | 'trap_risk';

export interface LivePacingInfo {
  elapsedSec: number;
  targetSec: number;
  ratio: number;
  state: PacingState;
  label: string;
  advice: string;
}

export interface QuestionTimeRecord {
  questionId: string;
  index: number;
  stem?: string;
  topic?: string;
  durationMs: number;
  selected?: string;
  correct?: boolean;
}

export interface TimeTrap {
  questionId: string;
  index: number;
  topic: string;
  durationSec: number;
  targetSec: number;
  excessSec: number;
  correct: boolean;
}

export interface PacingForensicsReport {
  targetSecPerQuestion: number;
  averageSecPerQuestion: number;
  pacingEfficiencyPct: number;
  timeTraps: TimeTrap[];
  totalTimeTrapsDurationSec: number;
  hasPanicZone: boolean;
  panicQuestionsCount: number;
  panicZoneStartIndex: number;
  estimatedRecoverableMarks: number;
  summaryFeedback: string;
}

/**
 * Evaluates live pacing for the active question on screen.
 *
 * @param currentQuestionMs - Milliseconds spent so far on this active question
 * @param totalDurationMinutes - Total allowed exam time in minutes (default 30)
 * @param questionCount - Total number of questions on the paper
 */
export function assessLivePacing(
  currentQuestionMs: number,
  totalDurationMinutes: number = 30,
  questionCount: number = 40,
): LivePacingInfo {
  const safeCount = Math.max(1, questionCount);
  const totalSec = Math.max(1, totalDurationMinutes * 60);
  const targetSec = Math.max(10, Math.round(totalSec / safeCount));
  const elapsedSec = Math.max(0, Math.floor(currentQuestionMs / 1000));
  const ratio = elapsedSec / targetSec;

  if (ratio >= 2.0) {
    return {
      elapsedSec,
      targetSec,
      ratio,
      state: 'trap_risk',
      label: 'Time Trap Risk',
      advice: 'You have spent double the target time. Flag this question and move on!',
    };
  }

  if (ratio >= 1.25) {
    return {
      elapsedSec,
      targetSec,
      ratio,
      state: 'lingering',
      label: 'Lingering',
      advice: 'Pace is slowing down. Narrow your options and pick your best guess.',
    };
  }

  return {
    elapsedSec,
    targetSec,
    ratio,
    state: 'on_track',
    label: 'On Track',
    advice: 'Good steady speed. Keep moving through the paper.',
  };
}

/**
 * Computes post-exam panic and time-mismanagement forensics.
 */
export function computePacingForensics(
  records: QuestionTimeRecord[],
  totalDurationMinutes: number = 30,
  questionCount: number = 40,
): PacingForensicsReport {
  const safeCount = Math.max(1, questionCount);
  const totalAllowedSec = Math.max(1, totalDurationMinutes * 60);
  const targetSec = Math.max(10, Math.round(totalAllowedSec / safeCount));

  if (records.length === 0) {
    return {
      targetSecPerQuestion: targetSec,
      averageSecPerQuestion: 0,
      pacingEfficiencyPct: 100,
      timeTraps: [],
      totalTimeTrapsDurationSec: 0,
      hasPanicZone: false,
      panicQuestionsCount: 0,
      panicZoneStartIndex: 0,
      estimatedRecoverableMarks: 0,
      summaryFeedback: 'No pacing records recorded for this sitting.',
    };
  }

  const totalUsedMs = records.reduce((acc, r) => acc + r.durationMs, 0);
  const avgSec = Math.round(totalUsedMs / records.length / 1000);

  // 1. Identify Time Traps (> 2.0x target time, especially those missed)
  const timeTraps: TimeTrap[] = [];
  let totalTrapSec = 0;

  records.forEach((r) => {
    const sec = Math.round(r.durationMs / 1000);
    if (sec >= Math.round(targetSec * 1.8)) {
      const excess = sec - targetSec;
      totalTrapSec += excess;
      timeTraps.push({
        questionId: r.questionId,
        index: r.index,
        topic: r.topic || 'General Question',
        durationSec: sec,
        targetSec,
        excessSec: excess,
        correct: Boolean(r.correct),
      });
    }
  });

  // Sort time traps by longest time wasted first
  timeTraps.sort((a, b) => b.durationSec - a.durationSec);

  // 2. Identify End-of-Paper Panic Zone (< 12 seconds per question on the final 20% of the paper)
  const finalQuarterCount = Math.max(3, Math.floor(records.length * 0.2));
  const finalQuarterStartIndex = records.length - finalQuarterCount;
  const finalQuestions = records.slice(finalQuarterStartIndex);

  const rushedInEnd = finalQuestions.filter((q) => q.durationMs / 1000 < 14);
  const hasPanicZone =
    finalQuestions.length >= 3 &&
    rushedInEnd.length >= Math.ceil(finalQuestions.length * 0.6) &&
    totalTrapSec > targetSec * 2;

  const panicCount = hasPanicZone ? rushedInEnd.length : 0;

  // 3. Pacing Efficiency Percentage
  // Questions completed within 1.5x target time
  const onTimeCount = records.filter((r) => r.durationMs / 1000 <= targetSec * 1.5).length;
  const pacingEfficiencyPct = Math.round((onTimeCount / records.length) * 100);

  // 4. Estimated Recoverable Marks
  // Marks lost on questions where student either burned time and still got wrong,
  // OR had to panic-rush at the end and got wrong.
  const trapLosses = timeTraps.filter((t) => !t.correct).length;
  const panicLosses = hasPanicZone
    ? finalQuestions.filter((q) => q.durationMs / 1000 < 14 && !q.correct).length
    : 0;

  const estimatedRecoverableMarks = Math.min(
    records.length,
    Math.round(trapLosses * 1.0 + panicLosses * 0.8),
  );

  // 5. Summary Feedback
  let feedback = 'Your pacing was well-balanced across the entire paper.';
  if (timeTraps.length > 0 && hasPanicZone) {
    feedback = `You spent ${Math.round(totalTrapSec / 60)} extra minutes battling ${timeTraps.length} tough questions, which forced you to rush the last ${rushedInEnd.length} questions in under 14 seconds each.`;
  } else if (timeTraps.length > 0) {
    feedback = `You spent extended time on ${timeTraps.length} questions. In real CBT, flagging these early protects your points on easier questions down the road.`;
  } else if (hasPanicZone) {
    feedback = 'You had to rush through the final questions. Try budgeting slightly less time for the early questions.';
  }

  return {
    targetSecPerQuestion: targetSec,
    averageSecPerQuestion: avgSec,
    pacingEfficiencyPct,
    timeTraps,
    totalTimeTrapsDurationSec: totalTrapSec,
    hasPanicZone,
    panicQuestionsCount: panicCount,
    panicZoneStartIndex: finalQuarterStartIndex,
    estimatedRecoverableMarks,
    summaryFeedback: feedback,
  };
}
