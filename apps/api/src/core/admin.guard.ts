import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { JwtPayload } from '@renance/shared';
import type { AuthenticatedRequest } from '../auth/jwt-auth.guard';

/**
 * Platform-admin gate (Gate 1.4). MVP doctrine: admins are the emails in
 * ADMIN_EMAILS (comma-separated). Deliberately env-based — a roles table for
 * platform staff arrives with Phase 4 hardening; org RBAC (the interesting
 * part) is already table-driven since Gate 1.3.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const me = request.user as JwtPayload | undefined;
    if (!me?.email) throw new UnauthorizedException('missing authenticated user');

    const admins = (process.env.ADMIN_EMAILS ?? '')
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .filter(Boolean);
    if (admins.length === 0) {
      // misconfigured deploy: refuse closed rather than open
      throw new ForbiddenException('platform admin review is not configured');
    }
    if (!admins.includes(me.email.toLowerCase())) {
      throw new ForbiddenException('platform admin only');
    }
    return true;
  }
}
