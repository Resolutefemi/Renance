import { z } from 'zod';
import { emailSchema, uuidSchema } from './primitives';

/**
 * Organization + membership contracts (Gate 1.2).
 * Imports ONLY from primitives — see the anti-cycle rule in primitives.ts.
 */

export const ORG_ROLES = ['owner', 'admin', 'member'] as const;
export const orgRoleSchema = z.enum(ORG_ROLES);
export type OrgRole = (typeof ORG_ROLES)[number];

export const ORG_TYPES = ['school', 'business', 'other'] as const;
export const orgTypeSchema = z.enum(ORG_TYPES);
export type OrgType = (typeof ORG_TYPES)[number];

export const MEMBERSHIP_STATUSES = ['active', 'invited', 'revoked'] as const;
export const membershipStatusSchema = z.enum(MEMBERSHIP_STATUSES);
export type MembershipStatus = (typeof MEMBERSHIP_STATUSES)[number];

/** URL-safe, lowercase, dash-separated. Uniqueness enforced by the DB. */
export const slugSchema = z
  .string()
  .min(2)
  .max(64)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'slug must be lowercase letters/digits separated by dashes');

export const createOrgSchema = z.object({
  name: z.string().trim().min(2, 'name too short').max(80),
  slug: slugSchema,
  type: orgTypeSchema.default('other'),
});
export type CreateOrgRequest = z.infer<typeof createOrgSchema>;

/**
 * Direct add of an EXISTING platform user to an org.
 * 'owner' is deliberately NOT assignable here — owners only arise at org
 * creation; owner transfer is a future, heavily-guarded operation.
 */
export const addMemberSchema = z.object({
  email: emailSchema,
  role: z.enum(['admin', 'member']),
});
export type AddMemberRequest = z.infer<typeof addMemberSchema>;

/**
 * PATCH member role contract (Gate 1.3). Same doctrine as addMember:
 * 'owner' is NOT a settable target — transfer is its own future operation,
 * guarded with confirmation flows, never a casual one-field PATCH.
 */
export const SETTABLE_MEMBER_ROLES = ['admin', 'member'] as const;
export const settableRoleSchema = z.enum(SETTABLE_MEMBER_ROLES);
export type SettableRole = (typeof SETTABLE_MEMBER_ROLES)[number];

export const setMemberRoleSchema = z.object({
  role: settableRoleSchema,
});
export type SetMemberRoleRequest = z.infer<typeof setMemberRoleSchema>;

export const publicOrgSchema = z.object({
  id: uuidSchema,
  name: z.string(),
  slug: z.string(),
  type: orgTypeSchema,
  status: z.enum(['active', 'suspended']),
  createdAt: z.string().datetime(),
});
export type PublicOrg = z.infer<typeof publicOrgSchema>;

/** GET /orgs row: the org plus YOUR standing in it. */
export const myOrgSchema = z.object({
  org: publicOrgSchema,
  yourRole: orgRoleSchema,
  membershipStatus: membershipStatusSchema,
});
export type MyOrg = z.infer<typeof myOrgSchema>;

export const orgMemberSchema = z.object({
  id: uuidSchema, // membership id
  role: orgRoleSchema,
  status: membershipStatusSchema,
  joinedAt: z.string().datetime(),
  user: z.object({
    id: uuidSchema,
    email: z.string().email(),
    displayName: z.string(),
  }),
});
export type OrgMember = z.infer<typeof orgMemberSchema>;
