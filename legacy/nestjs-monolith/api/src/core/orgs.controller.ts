import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Inject,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  addMemberSchema,
  createOrgSchema,
  setMemberRoleSchema,
  transferOwnershipSchema,
  type AddMemberRequest,
  type CreateOrgRequest,
  type JwtPayload,
  type MyOrg,
  type OrgMember,
  type OrgRole,
  type PublicOrg,
  type SetMemberRoleRequest,
  type TransferOwnershipRequest,
} from '@renance/shared';
import { ZodValidationPipe } from '../common/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { OrgRolesGuard } from './org-roles.guard';
import { RequireOrgRole } from './require-org-role.decorator';
import { OrgsService } from './orgs.service';

@Controller('orgs')
@UseGuards(JwtAuthGuard)
export class OrgsController {
  constructor(@Inject(OrgsService) private readonly orgs: OrgsService) {}

  /** 201 + org. Errors: 400 validation · 409 slug taken */
  @Post()
  create(
    @CurrentUser() me: JwtPayload,
    @Body(new ZodValidationPipe(createOrgSchema)) dto: CreateOrgRequest,
  ): Promise<PublicOrg> {
    return this.orgs.create(me.sub, dto);
  }

  /** Every org I belong to, with my role in each. */
  @Get()
  listMine(@CurrentUser() me: JwtPayload): Promise<MyOrg[]> {
    return this.orgs.listMine(me.sub);
  }

  /** 200 org+my role · 404 unknown · 403 non-member */
  @Get(':orgId')
  detail(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
  ): Promise<{ org: PublicOrg; yourRole: OrgRole }> {
    return this.orgs.getOrgForUser(orgId, me.sub);
  }

  @Get(':orgId/members')
  members(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
  ): Promise<OrgMember[]> {
    return this.orgs.listMembers(orgId, me.sub);
  }

  /** Owner/admin adds an existing user. Guard: active + ≥admin.
   *  201 member · 403 non-manager · 404 no user · 409 already member */
  @Post(':orgId/members')
  @HttpCode(HttpStatus.CREATED)
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('admin')
  add(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Body(new ZodValidationPipe(addMemberSchema)) dto: AddMemberRequest,
  ): Promise<OrgMember> {
    return this.orgs.addMember(orgId, me.sub, dto);
  }

  /** Owner/admin changes a member's role (never to/from owner — transfer is a
   *  future op). Guard: ≥admin. Fine matrix (target-aware) in OrgsService.
   *  200 updated · 400 role=owner rejected by contract · 403 member / target-owner
   *  · 404 unknown org|member */
  @Patch(':orgId/members/:userId')
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('admin')
  updateRole(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body(new ZodValidationPipe(setMemberRoleSchema)) dto: SetMemberRoleRequest,
  ): Promise<OrgMember> {
    return this.orgs.updateMemberRole(orgId, me.sub, userId, dto);
  }

  /** Org owner/admin submits for platform verification. 200 pending ·
   *  403 member · 409 already pending/verified */
  @Post(':orgId/verification/submit')
  @HttpCode(HttpStatus.OK)
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('admin')
  submitVerification(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
  ): Promise<PublicOrg> {
    return this.orgs.submitVerification(orgId, me.sub);
  }

  /** Owner hands the org to an active member. 200 new owner · 403 non-owner
   *  · 404 target not active member · 409 self-transfer */
  @Post(':orgId/ownership')
  @HttpCode(HttpStatus.OK)
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('owner')
  transferOwnership(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Body(new ZodValidationPipe(transferOwnershipSchema)) dto: TransferOwnershipRequest,
  ): Promise<OrgMember> {
    return this.orgs.transferOwnership(orgId, me.sub, dto.userId);
  }

  /** Self-service leave / invite-decline. 204 · 404 not a member ·
   *  409 owner must transfer first. Declared BEFORE :userId so 'me' is
   *  never captured as a uuid. */
  @Delete(':orgId/members/me')
  @HttpCode(HttpStatus.NO_CONTENT)
  leave(@CurrentUser() me: JwtPayload, @Param('orgId', ParseUUIDPipe) orgId: string): Promise<void> {
    return this.orgs.leaveOrg(orgId, me.sub);
  }

  /** Owner removes admins/members · admin removes members only · nobody
   *  removes an owner. Guard: ≥admin, fine matrix in OrgsService. 204 ·
   *  403 member / admin-vs-admin / owner-target · 404 unknown */
  @Delete(':orgId/members/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('admin')
  remove(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<void> {
    return this.orgs.removeMember(orgId, me.sub, userId);
  }
}
