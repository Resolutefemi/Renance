import type { BundleQuestion, KeyEntry } from '@renance/shared';

/**
 * Pure server-side grading (Gate 2.0, ADR-0003). The key NEVER leaves this
 * boundary — only verdicts, canonical answers, and explanations after grading.
 *
 * MCQ: trimmed, case-insensitive letter compare.
 * Text: trimmed, case-insensitive match against ANY accepted variant
 *      (CVE105-style banks carry case variants like ['Science','science']).
 * Missing responses are 'unanswered' (worth 0, reported distinctly).
 */
export interface BreakdownEntry {
  questionId: string;
  result: 'correct' | 'wrong' | 'unanswered';
  yours: string | null;
  answer: string | null;
  explanation: string | null;
}

export interface GradeOutcome {
  score: number;
  totalMarks: number;
  breakdown: BreakdownEntry[];
}

export function gradeAttempt(
  questions: BundleQuestion[],
  key: Record<string, KeyEntry>,
  submitted: Record<string, string>,
): GradeOutcome {
  let score = 0;
  let totalMarks = 0;
  const breakdown: BreakdownEntry[] = [];

  for (const q of questions) {
    totalMarks += q.marks;
    const raw = submitted[q.id];
    const yours = typeof raw === 'string' ? raw.trim() : '';
    const entry = key[q.id];

    if (!entry || !yours) {
      breakdown.push({ questionId: q.id, result: 'unanswered', yours: null, answer: canonicalAnswer(entry), explanation: entry?.explanation ?? null });
      continue;
    }

    let correct = false;
    if (entry.type === 'mcq') {
      correct = yours.toUpperCase() === entry.letter;
    } else {
      const mine = yours.toLowerCase();
      correct = entry.accepted.some((a) => a.trim().toLowerCase() === mine);
    }

    if (correct) score += q.marks;
    breakdown.push({
      questionId: q.id,
      result: correct ? 'correct' : 'wrong',
      yours: yours || null,
      answer: canonicalAnswer(entry),
      explanation: entry.explanation ?? null,
    });
  }

  return { score, totalMarks, breakdown };
}

function canonicalAnswer(entry?: KeyEntry): string | null {
  if (!entry) return null;
  return entry.type === 'mcq' ? entry.letter : entry.accepted[0] ?? null;
}
