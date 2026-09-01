import { describe, expect, it } from 'vitest';
import {
  addMemberSchema,
  createOrgSchema,
  slugSchema,
} from './orgs';

describe('org contracts', () => {
  it('createOrgSchema: accepts a valid org and defaults type to other', () => {
    const parsed = createOrgSchema.parse({
      name: '  Renance HQ ',
      slug: 'renance-hq',
    });
    expect(parsed.name).toBe('Renance HQ'); // trimmed
    expect(parsed.type).toBe('other');
  });

  it('slug rules: lowercase-dashes only', () => {
    expect(slugSchema.safeParse('renance-hq').success).toBe(true);
    expect(slugSchema.safeParse('Renance HQ').success).toBe(false); // no caps/spaces
    expect(slugSchema.safeParse('-leading').success).toBe(false);
    expect(slugSchema.safeParse('double--dash').success).toBe(false);
    expect(slugSchema.safeParse('ok1-2o-k').success).toBe(true);
  });

  it('addMemberSchema: owner role is NOT assignable (creation-only)', () => {
    expect(
      addMemberSchema.safeParse({ email: 'a@b.co', role: 'admin' }).success,
    ).toBe(true);
    expect(
      addMemberSchema.safeParse({ email: 'a@b.co', role: 'owner' }).success,
    ).toBe(false);
  });

  it('addMemberSchema: email is normalised like everywhere else', () => {
    const parsed = addMemberSchema.parse({ email: '  ADA@Example.COM ', role: 'member' });
    expect(parsed.email).toBe('ada@example.com');
  });
});
