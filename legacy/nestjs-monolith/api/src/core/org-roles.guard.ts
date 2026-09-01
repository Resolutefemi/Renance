import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { and, eq } from 'drizzle-orm';
import {
  memberships,
  organizations,
  type Db as DbClient,
  type MembershipRow,
} from '@renance/db';
import type { JwtPayload, OrgRole } from '@renance/shared';
import { DB } from '../db/db.module';
import type { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { ORG_ROLE_KEY } from './require-org-role.decorator';
import { hasAtLeast } from './rbac';

export interface OrgScopedRequest extends AuthenticatedRequest {
  params: AuthenticatedRequest['params'] & { orgId?: string };
  orgMembership?: MembershipRow;
}

/**
 * Coarse org gate. Order of operations:
 *   1. read @RequireOrgRole() metadata (missing => programming error, 500)
 *   2. bearer identity present?        (JwtAuthGuard normally ran first)
 *   3. :orgId param exists?            (misapplied guard => 400, not silence)
 *   4. org exists?                     (404 — never leak member data of ghosts)
 *   5. caller's membership ACTIVE?     (none/invited/revoked => 403)
 *   6. ladder: rank(role) ≥ required?  (pure hasAtLeast — matrix-tested)
 *
 * Fine rules that depend on the TARGET member's role (set/remove matrices)
 * deliberately live in OrgsService via rbac.ts pure functions — a guard runs
 * before body parsing and cannot see the target. Guard = coarse door;
 * service = the actual rules.
 */
@Injectable()
export class OrgRolesGuard implements CanActivate {
  constructor(
    @Inject(DB) private readonly database: DbClient,
    @Inject(Reflector) private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<OrgRole | undefined>(
      ORG_ROLE_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required) {
      // a 500 here is CORRECT: miswired route, must be loud in dev + CI
      throw new Error('OrgRolesGuard applied without @RequireOrgRole()');
    }

    const request = context.switchToHttp().getRequest<OrgScopedRequest>();
    const me = request.user as JwtPayload | undefined;
    if (!me?.sub) throw new UnauthorizedException('missing authenticated user');

    const orgId = request.params?.orgId;
    if (!orgId) throw new BadRequestException('route must expose an :orgId parameter');

    const orgRows = await this.database.db
      .select({ id: organizations.id })
      .from(organizations)
      .where(eq(organizations.id, orgId))
      .limit(1);
    if (orgRows.length === 0) throw new NotFoundException('organization not found');

    const rows = await this.database.db
      .select()
      .from(memberships)
      .where(and(eq(memberships.organizationId, orgId), eq(memberships.userId, me.sub)))
      .limit(1);
    const membership = rows.at(0);
    if (!membership || membership.status !== 'active') {
      throw new ForbiddenException('you are not an active member of this organization');
    }
    if (!hasAtLeast(membership.role as OrgRole, required)) {
      throw new ForbiddenException(`this action requires the ${required} role`);
    }

    request.orgMembership = membership; // available for downstream reuse
    return true;
  }
}
