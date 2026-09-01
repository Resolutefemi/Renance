// Barrel: import order here is irrelevant BECAUSE nothing in domain files
// imports from this barrel anymore — primitives are leaf modules.
import { z } from 'zod';

export * from './primitives';
export * from './auth';
export * from './orgs';
export * from './cbt';

/** Registry of business modules — mirrors db/sql schemas and api modules. */
export const MODULE_REGISTRY = [
  { id: 'cbt', title: 'CBT / Study', phase: 2 },
  { id: 'school', title: 'School Suite', phase: 3 },
  { id: 'sme', title: 'SME Tools', phase: 3 },
  { id: 'skills', title: 'Skills', phase: 3 },
  { id: 'utilities', title: 'Utilities', phase: 3 },
  { id: 'payroll', title: 'Payroll', phase: 3 },
] as const;

export type ModuleId = (typeof MODULE_REGISTRY)[number]['id'];

/** Verification states used across identity/documents (Phase 1). */
export const VERIFICATION_STATES = [
  'draft',
  'pending',
  'verified',
  'rejected',
] as const;
export type VerificationState = (typeof VERIFICATION_STATES)[number];
