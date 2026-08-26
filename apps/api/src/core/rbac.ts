import type { OrgRole } from '@renance/shared';

/**
 * Pure RBAC decisions for Gate 1.2 — kept as functions so Gate 1.3 can
 * matrix-test them AND wrap them in guards without touching services.
 */
export function canManageMembers(role: OrgRole): boolean {
  return role === 'owner' || role === 'admin';
}
