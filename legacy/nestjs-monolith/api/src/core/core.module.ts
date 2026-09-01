import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminController } from './admin.controller';
import { OrgRolesGuard } from './org-roles.guard';
import { OrgsController } from './orgs.controller';
import { OrgsService } from './orgs.service';

/**
 * PHASE 1 owner: identity/auth, organizations, memberships, RBAC and the
 * verification state machine. Other modules may import ONLY services this
 * module explicitly exports (the facade rule) — e.g. CBT will resolve orgs
 * through OrgsService, never by querying core tables itself.
 */
@Module({
  imports: [AuthModule], // facade: JwtService for the guards, AuthService when needed
  controllers: [OrgsController, AdminController],
  providers: [OrgsService, OrgRolesGuard],
  exports: [OrgsService],
})
export class CoreModule {}
