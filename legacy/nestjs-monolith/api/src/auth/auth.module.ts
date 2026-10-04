import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  imports: [
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret:
          config.get<string>('JWT_SECRET') ??
          (() => {
            if (config.get<string>('APP_ENV') === 'production') {
              throw new Error('JWT_SECRET must be set in production');
            }
            // dev-only fallback so the very first boot works out of the box
            return 'dev-insecure-secret-change-me';
          })(),
        signOptions: { expiresIn: '12h' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService, JwtModule], // facade start: future core services reuse tokens here
})
export class AuthModule {}
