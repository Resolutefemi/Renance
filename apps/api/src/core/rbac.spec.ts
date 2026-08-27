import { describe, expect, it } from 'vitest';
import {
  canManageMembers,
  canRemoveMember,
  canSetRole,
  hasAtLeast,
  type SettableRole,
} from './rbac';
import type { OrgRole } from '@renance/shared';

const ROLES = ['owner', 'admin', 'member'] as const;
const SETTABLE = ['admin', 'member'] as const;

/**
 * The FULL decision matrices — every (actor × target × action) cell asserted.
 * Gate 1.3 exit criterion: owner>admin>member>anon provable at a glance.
 * ('anon' never reaches these functions: JwtAuthGuard 401s first, and
 * OrgRolesGuard 403s non/invited/revoked members before the service runs.)
 */
describe('RBAC matrix (pure decisions)', () => {
  describe('hasAtLeast — guard ladder', () => {
    // expected[actor][required]
    const expected: Record<OrgRole, Record<OrgRole, boolean>> = {
      owner: { owner: true, admin: true, member: true },
      admin: { owner: false, admin: true, member: true },
      member: { owner: false, admin: false, member: true },
    };
    for (const actor of ROLES) {
      for (const required of ROLES) {
        it(`${actor} vs required ${required} → ${expected[actor][required]}`, () => {
          expect(hasAtLeast(actor, required)).toBe(expected[actor][required]);
        });
      }
    }
  });

  describe('canManageMembers — add/invite entry', () => {
    it('owner and admin yes, member no', () => {
      expect(canManageMembers('owner')).toBe(true);
      expect(canManageMembers('admin')).toBe(true);
      expect(canManageMembers('member')).toBe(false);
    });
  });

  describe('canSetRole — PATCH member matrix', () => {
    // allowed[actor][target] with any settable next
    const allowed: Record<OrgRole, Record<OrgRole, boolean>> = {
      owner: { owner: false, admin: true, member: true },
      admin: { owner: false, admin: true, member: true },
      member: { owner: false, admin: false, member: false },
    };
    for (const actor of ROLES) {
      for (const target of ROLES) {
        for (const next of SETTABLE) {
          it(`${actor} sets ${target} → ${next} = ${allowed[actor][target]}`, () => {
            expect(canSetRole(actor, target, next)).toBe(allowed[actor][target]);
          });
        }
      }
    }
    it('nobody can ever SET owner (belt-and-braces beyond the type system)', () => {
      for (const actor of ROLES) {
        for (const target of ROLES) {
          expect(canSetRole(actor, target, 'owner' as unknown as SettableRole)).toBe(false);
        }
      }
    });
  });

  describe('canRemoveMember — DELETE member matrix', () => {
    // allowed[actor][target]
    const allowed: Record<OrgRole, Record<OrgRole, boolean>> = {
      owner: { owner: false, admin: true, member: true },
      admin: { owner: false, admin: false, member: true },
      member: { owner: false, admin: false, member: false },
    };
    for (const actor of ROLES) {
      for (const target of ROLES) {
        it(`${actor} removes ${target} = ${allowed[actor][target]}`, () => {
          expect(canRemoveMember(actor, target)).toBe(allowed[actor][target]);
        });
      }
    }
    it('owner targets are unremovable across the whole ladder', () => {
      for (const actor of ROLES) expect(canRemoveMember(actor, 'owner')).toBe(false);
    });
  });
});
