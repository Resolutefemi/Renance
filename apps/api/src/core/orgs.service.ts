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
} from '@renance/shared';
import { DB } from '../db/db.module';
import { canManageMembers } from './rbac';

function toPublicOrg(row: OrganizationRow): PublicOrg {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    type: row.type,
    status: row.status,
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

  /** Owner/admin adds an EXISTING platform user directly (invite stub). */
  async addMember(orgId: string, meId: string, dto: AddMemberRequest): Promise<OrgMember> {
    const membership = await this.getMembership(orgId, meId);
    if (!membership || membership.status !== 'active') {
      throw new ForbiddenException('you are not an active member of this organization');
    }
    if (!canManageMembers(membership.role)) {
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
