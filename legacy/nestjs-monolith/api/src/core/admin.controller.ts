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
  reviewVerificationSchema,
  type JwtPayload,
  type PublicOrg,
  type ReviewVerificationRequest,
} from '@renance/shared';
import { ZodValidationPipe } from '../common/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AdminGuard } from './admin.guard';
import { OrgsService } from './orgs.service';

/**
 * Platform-admin surface (Gate 1.4). Every route: JWT + AdminGuard
 * (ADMIN_EMAILS). Org RBAC does NOT apply here — this is platform staff.
 */
@Controller('admin')
@UseGuards(JwtAuthGuard, AdminGuard)
export class AdminController {
  constructor(@Inject(OrgsService) private readonly orgs: OrgsService) {}

  /** Review queue: orgs waiting on a decision, oldest first. */
  @Get('orgs/pending')
  pending(): Promise<PublicOrg[]> {
    return this.orgs.listPendingOrgs();
  }

  /** Decide a pending org: verified | rejected (+ note). 409 if not pending. */
  @Post('orgs/:orgId/verification')
  @HttpCode(HttpStatus.OK)
  review(
    @CurrentUser() me: JwtPayload,
    @Param('orgId', ParseUUIDPipe) orgId: string,
    @Body(new ZodValidationPipe(reviewVerificationSchema)) dto: ReviewVerificationRequest,
  ): Promise<PublicOrg> {
    return this.orgs.reviewVerification(orgId, me.sub, dto);
  }
}
