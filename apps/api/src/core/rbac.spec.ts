import { describe, expect, it } from 'vitest';
import { canManageMembers } from './rbac';

describe('RBAC decisions (pure)', () => {
  it('owner and admin manage members; member does not', () => {
    expect(canManageMembers('owner')).toBe(true);
    expect(canManageMembers('admin')).toBe(true);
    expect(canManageMembers('member')).toBe(false);
  });
});
