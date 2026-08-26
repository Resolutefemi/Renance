import { createParamDecorator, type ExecutionContext } from '@nestjs/common';
import type { JwtPayload } from '@renance/shared';
import type { AuthenticatedRequest } from './jwt-auth.guard';

/** Route parameter decorator: @CurrentUser() user: JwtPayload */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayload => {
    const request = ctx.switchToHttp().getRequest<AuthenticatedRequest>();
    return request.user as JwtPayload;
  },
);
