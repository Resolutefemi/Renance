import 'reflect-metadata';
import { describe, expect, it } from 'vitest';
import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { getTableName } from 'drizzle-orm';

import { memberships, organizations } from '@renance/db';
import type { JwtPayload } from '@renance/shared';
import { OrgRolesGuard } from './org-roles.guard';
import { ORG_ROLE_KEY, RequireOrgRole } from './require-org-role.decorator';
import { DB } from '../db/db.module';

// ---------------------------------------------------------------------------
// Drizzle chain fake — only what the guard uses:
//   select().from(TABLE).where().limit()   keyed off the real table objects
//   via getTableName(), so org lookups and membership lookups diverge.
// ---------------------------------------------------------------------------

type Row = Record<string, unknown>;

function makeDbFake(opts: { org?: Row; membership?: Row }) {
  return {
    db: {
      select: () => ({
        from: (table: unknown) => {
          const name = getTableName(table as never);
          return {
            where: () => ({
              limit: async () => {
                if (name === 'organizations') return opts.org ? [opts.org] : [];
                if (name === 'memberships') return opts.membership ? [opts.membership] : [];
                return [];
              },
            }),
          };
        },
      }),
    },
  } as unknown as ConstructorParameters<typeof OrgRolesGuard>[0];
}

const ORG_ID = '22222222-2222-4222-8222-222222222222';
const USER_ID = '11111111-1111-4111-8111-111111111111';

const orgRow = (): Row => ({ id: ORG_ID, name: 'HQ', slug: 'hq' });

const memberRow = (over: Partial<Row> = {}): Row => ({
  id: '33333333-3333-4333-8333-333333333333',
  organizationId: ORG_ID,
  userId: USER_ID,
  role: 'member',
  status: 'active',
  addedById: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...over,
});

const me: JwtPayload = { sub: USER_ID, email: 'me@example.com' };

function makeCtx(user: JwtPayload | undefined, params: Record<string, string>): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ user, params }),
    }),
    getHandler: () => guardAnnotatedHandler,
    getClass: () => FakeClass,
  } as unknown as ExecutionContext;
}

class FakeClass {}
function guardAnnotatedHandler() {}
function memberAnnotatedHandler() {}
// tag the handlers the same way the decorators would
RequireOrgRole('admin')(guardAnnotatedHandler);
RequireOrgRole('member')(memberAnnotatedHandler);

const reflector = new Reflector();
const requiredMeta = reflector.get<never>(ORG_ROLE_KEY, guardAnnotatedHandler) as never;
void requiredMeta; // sanity: metadata is on the handler; guard reads the same key

async function run(guard: OrgRolesGuard, ctx: ExecutionContext) {
  return guard.canActivate(ctx);
}

describe('OrgRolesGuard', () => {
  it('throws (500) when applied without @RequireOrgRole metadata', async () => {
    const ctx = {
      switchToHttp: () => ({ getRequest: () => ({ user: me, params: { orgId: ORG_ID } }) }),
      getHandler: () => () => {},
      getClass: () => class {},
    } as unknown as ExecutionContext;
    const guard = new OrgRolesGuard(makeDbFake({ org: orgRow(), membership: memberRow() }), reflector);
    await expect(run(guard, ctx)).rejects.toThrow(/RequireOrgRole/);
  });

  it('401 when no authenticated user on the request', async () => {
    const guard = new OrgRolesGuard(makeDbFake({}), reflector);
    await expect(run(guard, makeCtx(undefined, { orgId: ORG_ID }))).rejects.toMatchObject({
      status: 401,
    });
  });

  it('400 when the route has no :orgId param (misapplied guard)', async () => {
    const guard = new OrgRolesGuard(makeDbFake({}), reflector);
    await expect(run(guard, makeCtx(me, {}))).rejects.toMatchObject({ status: 400 });
  });

  it('404 when the organization does not exist', async () => {
    const guard = new OrgRolesGuard(makeDbFake({ org: undefined, membership: undefined }), reflector);
    await expect(run(guard, makeCtx(me, { orgId: ORG_ID }))).rejects.toMatchObject({
      status: 404,
    });
  });

  it('403 when caller has no membership in the org', async () => {
    const guard = new OrgRolesGuard(makeDbFake({ org: orgRow(), membership: undefined }), reflector);
    await expect(run(guard, makeCtx(me, { orgId: ORG_ID }))).rejects.toMatchObject({
      status: 403,
    });
  });

  it('403 for invited membership — not active yet', async () => {
    const guard = new OrgRolesGuard(
      makeDbFake({ org: orgRow(), membership: memberRow({ status: 'invited' }) }),
      reflector,
    );
    await expect(run(guard, makeCtx(me, { orgId: ORG_ID }))).rejects.toMatchObject({
      status: 403,
    });
  });

  it('403 for revoked membership', async () => {
    const guard = new OrgRolesGuard(
      makeDbFake({ org: orgRow(), membership: memberRow({ status: 'revoked' }) }),
      reflector,
    );
    await expect(run(guard, makeCtx(me, { orgId: ORG_ID }))).rejects.toMatchObject({
      status: 403,
    });
  });

  it('403 when role ranks below requirement (member hitting admin route)', async () => {
    const guard = new OrgRolesGuard(
      makeDbFake({ org: orgRow(), membership: memberRow({ role: 'member' }) }),
      reflector,
    );
    await expect(run(guard, makeCtx(me, { orgId: ORG_ID }))).rejects.toMatchObject({
      status: 403,
    });
  });

  it('passes member ≥ member and attaches the membership to the request', async () => {
    const membership = memberRow({ role: 'member' });
    const guard = new OrgRolesGuard(makeDbFake({ org: orgRow(), membership }), reflector);
    const req: Record<string, unknown> = { user: me, params: { orgId: ORG_ID } };
    const ctx = {
      switchToHttp: () => ({ getRequest: () => req }),
      getHandler: () => memberAnnotatedHandler,
      getClass: () => FakeClass,
    } as unknown as ExecutionContext;
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    expect(req.orgMembership).toMatchObject({ role: 'member', userId: USER_ID });
  });

  it('passes admin ≥ admin and owner ≥ admin for admin-gated routes', async () => {
    for (const role of ['admin', 'owner'] as const) {
      const guard = new OrgRolesGuard(
        makeDbFake({ org: orgRow(), membership: memberRow({ role }) }),
        reflector,
      );
      await expect(run(guard, makeCtx(me, { orgId: ORG_ID }))).resolves.toBe(true);
    }
  });
});
