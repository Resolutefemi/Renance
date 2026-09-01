import { describe, expect, it } from 'vitest';
import { gradeAttempt } from './grading';
import type { BundleQuestion, KeyEntry } from '@renance/shared';

const questions: BundleQuestion[] = [
  { id: 'q1', type: 'mcq', stem: '2+2?', options: { A: '3', B: '4' }, marks: 1 },
  { id: 'q2', type: 'mcq', stem: 'capital of France?', options: { A: 'Paris', B: 'Lyon' }, marks: 2 },
  { id: 'q3', type: 'text', stem: 'Powerhouse of the cell?', marks: 1 },
];

const key: Record<string, KeyEntry> = {
  q1: { type: 'mcq', letter: 'B', explanation: 'basic math' },
  q2: { type: 'mcq', letter: 'A' },
  q3: { type: 'text', accepted: ['Mitochondria', 'mitochondrion'], explanation: 'ATP' },
};

describe('gradeAttempt (pure server-side)', () => {
  it('perfect score with case-insensitive mcq + text matching', () => {
    const out = gradeAttempt(questions, key, { q1: 'b', q2: 'A', q3: '  MITOCHONDRIA ' });
    expect(out.score).toBe(4);
    expect(out.totalMarks).toBe(4);
    expect(out.breakdown.map((b) => b.result)).toEqual(['correct', 'correct', 'correct']);
    // post-grading reveal carries the canonical answer + explanation
    expect(out.breakdown[2]!.answer).toBe('Mitochondria');
    expect(out.breakdown[0]!.explanation).toBe('basic math');
  });

  it('partial score + wrong entries', () => {
    const out = gradeAttempt(questions, key, { q1: 'A', q2: 'A', q3: 'Golgi' });
    expect(out.score).toBe(2);
    expect(out.breakdown.map((b) => b.result)).toEqual(['wrong', 'correct', 'wrong']);
  });

  it('missing responses are unanswered, not wrong, worth zero', () => {
    const out = gradeAttempt(questions, key, { q2: 'A' });
    expect(out.score).toBe(2);
    expect(out.breakdown.filter((b) => b.result === 'unanswered').map((b) => b.questionId)).toEqual(['q1', 'q3']);
  });

  it('text answer matches any accepted case variant', () => {
    for (const v of ['mitochondria', 'MITOCHONDRION', 'Mitochondria']) {
      const out = gradeAttempt([questions[2]!], key, { q3: v });
      expect(out.score).toBe(1);
    }
  });
});
