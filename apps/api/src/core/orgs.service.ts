import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, desc, eq } from 'drizzle-orm';
import {
  memberships,
  organizations,
  users,
  type Db as DbClient,
  type MembershipRow,
  type OrganizationRow,
} from '@renance/db';
import type {
  AddMemberRequest,
  CreateOrgRequest,
  MyOrg,
  OrgMember,
  OrgRole,
  PublicOrg,
  ReviewVerificationRequest,
  SetMemberRoleRequest,
  SettableRole,
  VerificationState,
} from '@renance/shared';
import { DB } from '../db/db.module';
import { canManageMembers, canRemoveMember, canSetRole } from './rbac';
import { canReview, canSubmit } from './verification';

function toPublicOrg(row: OrganizationRow): PublicOrg {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    type: row.type,
    status: row.status,
    verificationStatus: row.verificationStatus,
    createdAt: row.createdAt.toISOString(),
  };
}

function toMemberDto(
  membership: MembershipRow,
  user: { id: string; email: string; displayName: string },
): OrgMember {
  return {
    id: membership.id,
    role: membership.role,
    status: membership.status,
    joinedAt: membership.createdAt.toISOString(),
    user,
  };
}

@Injectable()
export class OrgsService {
  constructor(@Inject(DB) private readonly database: DbClient) {}

  /** Creates the org and its owner membership atomically. */
  async create(meId: string, dto: CreateOrgRequest): Promise<PublicOrg> {
    try {
      return await this.database.db.transaction(async (tx) => {
        const rows = await tx
          .insert(organizations)
          .values({
            name: dto.name,
            slug: dto.slug,
            type: dto.type,
            createdById: meId,
          })
          .returning();
        const org = rows.at(0);
        if (!org) throw new ConflictException('could not create organization');

        await tx.insert(memberships).values({
          organizationId: org.id,
          userId: meId,
          role: 'owner',
          status: 'active',
          addedById: meId,
        });
        return toPublicOrg(org);
      });
    } catch (err) {
      if ((err as { code?: string }).code === '23505') {
        throw new ConflictException('slug already taken');
      }
      throw err;
    }
  }

  async listMine(meId: string): Promise<MyOrg[]> {
    const rows = await this.database.db
      .select({
        org: organizations,
        role: memberships.role,
        membershipStatus: memberships.status,
      })
      .from(memberships)
      .innerJoin(organizations, eq(memberships.organizationId, organizations.id))
      .where(eq(memberships.userId, meId))
      .orderBy(desc(memberships.createdAt));

    return rows.map((r) => ({
      org: toPublicOrg(r.org),
      yourRole: r.role as OrgRole,
      membershipStatus: r.membershipStatus,
    }));
  }

  /** Org + requester's standing. 404 unknown org, 403 non-member. */
  async getOrgForUser(orgId: string, meId: string): Promise<{ org: PublicOrg; yourRole: OrgRole }> {
    const org = await this.findById(orgId);
    if (!org) throw new NotFoundException('organization not found');

    const membership = await this.getMembership(orgId, meId);
    if (!membership || membership.status === 'revoked') {
      throw new ForbiddenException('you are not a member of this organization');
    }
    return { org: toPublicOrg(org), yourRole: membership.role as OrgRole };
  }

  async listMembers(orgId: string, meId: string): Promise<OrgMember[]> {
    await this.getOrgForUser(orgId, meId); // member-visibility gate
    const rows = await this.database.db
      .select({
        membership: memberships,
        userId: users.id,
        email: users.email,
        displayName: users.displayName,
      })
      .from(memberships)
      .innerJoin(users, eq(memberships.userId, users.id))
      .where(eq(memberships.organizationId, orgId))
      .orderBy(desc(memberships.createdAt));

    return rows.map((r) => toMemberDto(r.membership, { id: r.userId, email: r.email, displayName: r.displayName }));
  }

  /** Owner/admin adds an EXISTING platform user directly (invite stub).
   *  Coarse gate ALSO enforced by OrgRolesGuard at the route; the service
   *  re-checks so direct service reuse (future facades) stays safe. */
  async addMember(orgId: string, meId: string, dto: AddMemberRequest): Promise<OrgMember> {
    const actor = await this.requireActiveMembership(orgId, meId);
    if (!canManageMembers(actor.role as OrgRole)) {
      throw new ForbiddenException('owner or admin role required');
    }

    const targetRows = await this.database.db
      .select({ id: users.id, email: users.email, displayName: users.displayName })
      .from(users)
      .where(eq(users.email, dto.email))
      .limit(1);
    const target = targetRows.at(0);
    if (!target) throw new NotFoundException('no Renance user with that email yet');

    const dupRows = await this.database.db
      .select({ id: memberships.id })
      .from(memberships)
      .where(and(eq(memberships.organizationId, orgId), eq(memberships.userId, target.id)))
      .limit(1);
    if (dupRows.length > 0) throw new ConflictException('user is already a member');

    const createdRows = await this.database.db
      .insert(memberships)
      .values({
        organizationId: orgId,
        userId: target.id,
        role: dto.role,
        status: 'active',
        addedById: meId,
      })
      .returning();
    const created = createdRows.at(0);
    if (!created) throw new ConflictException('could not add member');
    return toMemberDto(created, target);
  }

  // ---------------------------------------------------------------------------
  // Gate 1.3 — RBAC enforcement: role changes + member removal
  // ---------------------------------------------------------------------------

  /**
   * Change a member's role. Matrix in rbac.ts: owner/admin may set
   * admin|member on any NON-owner target; member may not. Idempotent —
   * setting the role a member already has returns 200 without writing.
   */
  async updateMemberRole(
    orgId: string,
    meId: string,
    targetUserId: string,
    dto: SetMemberRoleRequest,
  ): Promise<OrgMember> {
    const actor = await this.requireActiveMembership(orgId, meId);
    const target = await this.getMembership(orgId, targetUserId);
    if (!target) {
      throw new NotFoundException('that user is not a member of this organization');
    }

    const actorRole = actor.role as OrgRole;
    const targetRole = target.role as OrgRole;
    if (!canSetRole(actorRole, targetRole, dto.role as SettableRole)) {
      throw new ForbiddenException(
        targetRole === 'owner'
          ? 'the owner role can only change via ownership transfer (not built yet)'
          : 'owner or admin role required to change member roles',
      );
    }

    if (target.role === dto.role) return this.memberDtoFor(target); // idempotent no-op

    const updatedRows = await this.database.db
      .update(memberships)
      .set({ role: dto.role, updatedAt: new Date() })
      .where(eq(memberships.id, target.id))
      .returning();
    const updated = updatedRows.at(0);
    if (!updated) throw new ConflictException('could not update member role');
    return this.memberDtoFor(updated);
  }

  /**
   * Remove a member. Matrix in rbac.ts: owner removes admins+members;
   * admin removes members only; owners themselves are unremovable —
   * ownership transfers first (future operation).
   */
  async removeMember(orgId: string, meId: string, targetUserId: string): Promise<void> {
    const actor = await this.requireActiveMembership(orgId, meId);
    const target = await this.getMembership(orgId, targetUserId);
    if (!target) {
      throw new NotFoundException('that user is not a member of this organization');
    }

    const actorRole = actor.role as OrgRole;
    const targetRole = target.role as OrgRole;
    if (!canRemoveMember(actorRole, targetRole)) {
      throw new ForbiddenException(
        targetRole === 'owner'
          ? 'the owner cannot be removed — transfer ownership first (not built yet)'
          : targetRole === 'admin'
            ? 'only the owner can remove an admin'
            : 'owner or admin role required to remove members',
      );
    }

    await this.database.db.delete(memberships).where(eq(memberships.id, target.id));
  }

  /** Guard-clause helper: active membership or 403. */
  private async requireActiveMembership(orgId: string, userId: string) {
    const membership = await this.getMembership(orgId, userId);
    if (!membership || membership.status !== 'active') {
      throw new ForbiddenException('you are not an active member of this organization');
    }
    return membership;
  }

  /** Membership row + fresh user fields -> client DTO. */
  private async memberDtoFor(membership: MembershipRow): Promise<OrgMember> {
    const userRows = await this.database.db
      .select({ id: users.id, email: users.email, displayName: users.displayName })
      .from(users)
      .where(eq(users.id, membership.userId))
      .limit(1);
    const user = userRows.at(0);
    if (!user) throw new NotFoundException('member user record missing');
    return toMemberDto(membership, user);
  }

  // ---------------------------------------------------------------------------
  // Gate 1.4 — verification lifecycle
  // ---------------------------------------------------------------------------

  /** Org owner/admin submits for review: draft|rejected -> pending (409 otherwise). */
  async submitVerification(orgId: string, meId: string): Promise<PublicOrg> {
    const actor = await this.requireActiveMembership(orgId, meId);
    if (!canManageMembers(actor.role as OrgRole)) {
      throw new ForbiddenException('owner or admin role required to submit for verification');
    }
    const org = await this.findById(orgId);
    if (!org) throw new NotFoundException('organization not found');
    const current = org.verificationStatus as VerificationState;
    if (!canSubmit(current)) {
      throw new ConflictException(`cannot submit from state '${current}'`);
    }
    const updated = await this.database.db
      .update(organizations)
      .set({
        verificationStatus: 'pending',
        verificationNote: null, // fresh review, old note cleared
        reviewedAt: null,
        reviewedById: null,
        updatedAt: new Date(),
      })
      .where(eq(organizations.id, orgId))
      .returning();
    const row = updated.at(0);
    if (!row) throw new ConflictException('could not submit verification');
    return toPublicOrg(row);
  }

  /** Platform admin decides: pending -> verified|rejected (409 otherwise). */
  async reviewVerification(
    orgId: string,
    reviewerId: string,
    dto: ReviewVerificationRequest,
  ): Promise<PublicOrg> {
    const org = await this.findById(orgId);
    if (!org) throw new NotFoundException('organization not found');
    const current = org.verificationStatus as VerificationState;
    if (!canReview(current)) {
      throw new ConflictException(`cannot review from state '${current}' — org must be pending`);
    }
    const updated = await this.database.db
      .update(organizations)
      .set({
        verificationStatus: dto.decision,
        verificationNote: dto.note ?? null,
        reviewedAt: new Date(),
        reviewedById: reviewerId,
        updatedAt: new Date(),
      })
      .where(eq(organizations.id, orgId))
      .returning();
    const row = updated.at(0);
    if (!row) throw new ConflictException('could not record review');
    return toPublicOrg(row);
  }

  /** Platform admin queue: every org awaiting review, oldest first. */
  async listPendingOrgs(): Promise<PublicOrg[]> {
    const rows = await this.database.db
      .select()
      .from(organizations)
      .where(eq(organizations.verificationStatus, 'pending'))
      .orderBy(organizations.createdAt);
    return rows.map(toPublicOrg);
  }

  private async findById(orgId: string): Promise<OrganizationRow | undefined> {
    const rows = await this.database.db
      .select()
      .from(organizations)
      .where(eq(organizations.id, orgId))
      .limit(1);
    return rows.at(0);
  }

  private async getMembership(orgId: string, userId: string): Promise<MembershipRow | undefined> {
    const rows = await this.database.db
      .select()
      .from(memberships)
      .where(and(eq(memberships.organizationId, orgId), eq(memberships.userId, userId)))
      .limit(1);
    return rows.at(0);
  }
}
