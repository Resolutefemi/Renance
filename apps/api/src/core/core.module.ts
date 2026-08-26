import { Module } from '@nestjs/common';

/**
 * PHASE 1 owner: identity/auth, organizations, memberships, RBAC and the
 * verification state machine. Other modules may import ONLY services this
 * module explicitly exports (the facade rule). Table DDL lands in schema
 * 'core' via Drizzle migrations.
 */
@Module({
  providers: [],
  exports: [],
})
export class CoreModule {}
