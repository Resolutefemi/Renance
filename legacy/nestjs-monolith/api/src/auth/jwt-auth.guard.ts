import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import type { JwtPayload } from '@renance/shared';

export interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}

/**
 * Minimal Bearer guard — no passport dependency for now. When resource
 * servers multiply (mobile vs web), swap internals; route surfaces stay same.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(@Inject(JwtService) private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;

    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('missing bearer token');
    }

    try {
      request.user = await this.jwt.verifyAsync<JwtPayload>(header.slice('Bearer '.length));
    } catch {
      throw new UnauthorizedException('invalid or expired token');
    }
    return true;
  }
}
