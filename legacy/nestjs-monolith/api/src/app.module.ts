import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './health/health.module';
import { DbModule } from './db/db.module';
import { AuthModule } from './auth/auth.module';
import { CoreModule } from './core/core.module';
import { CbtModule } from './modules/cbt/cbt.module';

/**
 * Modular single-deploy monolith (PRD option 2).
 * Every business module is a Nest module registered here. Cross-module
 * access goes ONLY through exported facades — never by reaching into
 * another module's internals. See docs/architecture.md.
 */
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DbModule,
    HealthModule,
    AuthModule, // Phase 1 gate 1.1: register/login/me (first slice of identity)
    CoreModule,
    CbtModule,
    // Phase 3 modules are generated with `pnpm module:new <name>` and wired
    // here one gate at a time — never before their phase opens.
  ],
})
export class AppModule {}
