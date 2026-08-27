import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { CoreModule } from '../../core/core.module';
import { OrgRolesGuard } from '../../core/org-roles.guard';
import { CbtController } from './cbt.controller';
import { CbtService } from './cbt.service';

/**
 * CBT module (Phase 2). Resolves orgs ONLY through its own membership reads
 * of core tables via Drizzle — per the facade rule this stays limited to
 * membership status/role checks identical to what OrgsService enforces;
 * when verification-gating lands, CBT must call OrgsService instead.
 */
@Module({
  imports: [AuthModule, CoreModule], // JwtService + OrgsService facade
  controllers: [CbtController],
  providers: [CbtService, OrgRolesGuard],
  exports: [CbtService],
})
export class CbtModule {}
