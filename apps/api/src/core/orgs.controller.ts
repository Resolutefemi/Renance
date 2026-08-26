import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Inject,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  addMemberSchema,
  createOrgSchema,
  type AddMemberRequest,
  type CreateOrgRequest,
  type JwtPayload,
  type MyOrg,
  type OrgMember,
  type OrgRole,
  type PublicOrg,
} from '@renance/shared';
import { ZodValidationPipe } from '../common/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
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

  /** Owner/admin adds an existing user. 201 member · 403 non-manager · 404 no user · 409 already member */
  @Post(':orgId/members')
  @HttpCode(HttpStatus.CREATED)
  add(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Body(new ZodValidationPipe(addMemberSchema)) dto: AddMemberRequest,
  ): Promise<OrgMember> {
    return this.orgs.addMember(orgId, me.sub, dto);
  }
}
