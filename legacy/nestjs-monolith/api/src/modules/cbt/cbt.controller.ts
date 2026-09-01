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
  publishBundleSchema,
  submitAttemptSchema,
  type AttemptResult,
  type BundleFetch,
  type BundleMeta,
  type JwtPayload,
  type PublishBundleRequest,
  type SubmitAttemptRequest,
} from '@renance/shared';
import { ZodValidationPipe } from '../../common/zod-validation.pipe';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { CurrentUser } from '../../auth/current-user.decorator';
import { OrgRolesGuard } from '../../core/org-roles.guard';
import { RequireOrgRole } from '../../core/require-org-role.decorator';
import { CbtService } from './cbt.service';

/**
 * CBT surface (Gates 1.9 + 2.0). All routes org-scoped so OrgRolesGuard's
 * coarse gate applies uniformly; the answer key NEVER appears in any response
 * (ADR-0003). Route order matters: literal 'attempt' paths before conflicting
 * params where applicable.
 */
@Controller('orgs/:orgId/bundles')
@UseGuards(JwtAuthGuard)
export class CbtController {
  constructor(@Inject(CbtService) private readonly cbt: CbtService) {}

  /** Org admin publishes bundle+key. 201 meta · 400 contract · 409 dup version */
  @Post()
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('admin')
  publish(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Body(new ZodValidationPipe(publishBundleSchema)) dto: PublishBundleRequest,
  ): Promise<BundleMeta> {
    return this.cbt.publish(orgId, me.sub, dto);
  }

  /** Manifest for members: metadata only, keys and payloads excluded. */
  @Get()
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('member')
  manifest(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
  ): Promise<BundleMeta[]> {
    return this.cbt.manifest(orgId, me.sub);
  }

  /** Full questions for an active member. ZERO key material in response. */
  @Get(':bundleId')
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('member')
  fetch(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Param('bundleId', ParseUUIDPipe) bundleId: string,
  ): Promise<BundleFetch> {
    return this.cbt.fetch(orgId, me.sub, bundleId);
  }

  /** Submit responses -> server grades -> result + reveal. 201 result · 409 retaken */
  @Post(':bundleId/attempt')
  @HttpCode(HttpStatus.CREATED)
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('member')
  submit(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Param('bundleId', ParseUUIDPipe) bundleId: string,
    @Body(new ZodValidationPipe(submitAttemptSchema)) dto: SubmitAttemptRequest,
  ): Promise<AttemptResult> {
    return this.cbt.submitAttempt(orgId, me.sub, bundleId, dto);
  }

  /** My stored result for this bundle. 404 before first attempt. */
  @Get(':bundleId/attempt')
  @UseGuards(OrgRolesGuard)
  @RequireOrgRole('member')
  myAttempt(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Param('bundleId', ParseUUIDPipe) bundleId: string,
  ): Promise<AttemptResult> {
    return this.cbt.myAttempt(orgId, me.sub, bundleId);
  }
}
