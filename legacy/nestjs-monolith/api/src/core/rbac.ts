import type { OrgRole } from '@renance/shared';

/**
 * Pure RBAC decisions — no DB, no Nest, no I/O. Matrix-tested in rbac.spec.ts;
 * consumed by OrgRolesGuard (coarse ladder gate) and OrgsService (fine rules
 * that depend on the TARGET member's role). Keeping them as pure functions is
 * what makes the whole permission system provable in milliseconds.
 */

/** Roles a member's role may be SET to. 'owner' is reachable only through a
 *  future, heavily-guarded ownership-transfer operation — never via PATCH. */
export type SettableRole = 'admin' | 'member';

const ROLE_RANK: Record<OrgRole, number> = { member: 1, admin: 2, owner: 3 };

/** Coarse ladder check used by OrgRolesGuard. owner > admin > member. */
export function hasAtLeast(actor: OrgRole, required: OrgRole): boolean {
  return ROLE_RANK[actor] >= ROLE_RANK[required];
}

/** Gate 1.2 legacy decision — kept for addMember and the matrix tests. */
export function canManageMembers(role: OrgRole): boolean {
  return role === 'owner' || role === 'admin';
}

/**
 * PATCH-member matrix (role changes).
 *
 *   actor \ target   owner   admin   member
 *   owner             ✗       ✓       ✓      next ∈ {admin, member}
 *   admin             ✗       ✓       ✓      next ∈ {admin, member}
 *   member            ✗       ✗       ✗
 *
 * Design notes:
 * - 'owner' targets are untouchable here — ownership transfer is its own
 *   future operation with confirmation flows, not a casual PATCH.
 * - admins may promote/demote among admin|member, mirroring addMember where
 *   an admin can already invite with role 'admin': whoever can grant a role
 *   on entry can also maintain it afterwards. One consistent doctrine.
 * - `next: 'owner'` is unrepresentable via the SettableRole type; the zod
 *   contract rejects it before this function ever sees it.
 */
export function canSetRole(
  actor: OrgRole,
  target: OrgRole,
  next: SettableRole,
): boolean {
  if (target === 'owner') return false;
  return canManageMembers(actor) && (next === 'admin' || next === 'member');
}

/**
 * DELETE-member matrix (removal). Deliberately STRICTER than role-setting:
 * destroying membership is higher-stakes than changing a label.
 *
 *   actor \ target   owner   admin   member
 *   owner             ✗       ✓       ✓
 *   admin             ✗       ✗       ✓
 *   member            ✗       ✗       ✗
 *
 * - Only the owner can remove an admin (an admin team is the owner's trust
 *   boundary; peers cannot unmake each other).
 * - Owners cannot be removed, ever — they transfer first. This also makes
 *   "leave org" impossible for the last owner by construction; a dedicated
 *   leave/transfer flow arrives with org settings in a later gate.
 */
export function canRemoveMember(actor: OrgRole, target: OrgRole): boolean {
  if (target === 'owner') return false;
  if (actor === 'owner') return true;
  if (actor === 'admin') return target === 'member';
  return false;
}

/**
 * Ownership transfer (Gate 1.5) — the ONLY path that creates a new owner,
 * replacing the unremovable-owner rule's escape hatch. Owner-only, and the
 * target must be an existing active member (checked in the service).
 */
export function canTransferOwnership(actor: OrgRole): boolean {
  return actor === 'owner';
}
