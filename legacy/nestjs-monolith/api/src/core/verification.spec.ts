import { describe, expect, it } from 'vitest';
import { canReview, canSubmit, canTransition } from './verification';
import type { VerificationState } from '@renance/shared';

const STATES: VerificationState[] = ['draft', 'pending', 'verified', 'rejected'];

describe('verification state machine (pure)', () => {
  // expected[from][to]
  const expected: Record<VerificationState, Record<VerificationState, boolean>> = {
    draft: { draft: false, pending: true, verified: false, rejected: false },
    pending: { draft: false, pending: false, verified: true, rejected: true },
    verified: { draft: false, pending: false, verified: false, rejected: false },
    rejected: { draft: false, pending: true, verified: false, rejected: false },
  };

  for (const from of STATES) {
    for (const to of STATES) {
      it(`${from} -> ${to} = ${expected[from][to]}`, () => {
        expect(canTransition(from, to)).toBe(expected[from][to]);
      });
    }
  }

  it('submit is only legal from draft or rejected', () => {
    expect(canSubmit('draft')).toBe(true);
    expect(canSubmit('rejected')).toBe(true);
    expect(canSubmit('pending')).toBe(false);
    expect(canSubmit('verified')).toBe(false);
  });

  it('review is only legal from pending', () => {
    expect(canReview('pending')).toBe(true);
    expect(canReview('draft')).toBe(false);
    expect(canReview('verified')).toBe(false);
    expect(canReview('rejected')).toBe(false);
  });

  it('verified is terminal in MVP', () => {
    for (const to of STATES) expect(canTransition('verified', to)).toBe(false);
  });
});
