import type { VerificationState } from '@renance/shared';

/**
 * Pure verification state machine (Gate 1.4) — mirrors VERIFICATION_STATES.
 *
 *   draft ──submit(org admin)──► pending ──verify(admin)────► verified
 *                                   ▲    └───reject(admin)────► rejected
 *                                   └────────resubmit──────────┘
 *
 * - verified is terminal in MVP (revocation arrives with Phase 4 hardening)
 * - only rejected orgs may resubmit (draft is pre-submission; verified needs
 *   no re-review)
 */
const TRANSITIONS: Record<VerificationState, VerificationState[]> = {
  draft: ['pending'],
  pending: ['verified', 'rejected'],
  verified: [],
  rejected: ['pending'],
};

export function canTransition(from: VerificationState, to: VerificationState): boolean {
  return TRANSITIONS[from].includes(to);
}

/** Org-side actors (owner/admin) may drive exactly one kind of transition. */
export function canSubmit(from: VerificationState): boolean {
  return canTransition(from, 'pending');
}

/** Platform-admin decisions on a pending org. */
export function canReview(from: VerificationState): from is 'pending' {
  return from === 'pending';
}
