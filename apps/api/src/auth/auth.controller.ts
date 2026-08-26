import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  loginRequestSchema,
  registerRequestSchema,
  type AuthResponse,
  type JwtPayload,
  type LoginRequest,
  type PublicUser,
  type RegisterRequest,
} from '@renance/shared';
import { ZodValidationPipe } from '../common/zod-validation.pipe';
import { AuthService } from './auth.service';
import { CurrentUser } from './current-user.decorator';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** 201 + { user, accessToken }. Errors: 400 validation · 409 duplicate email */
  @Post('register')
  register(
    @Body(new ZodValidationPipe(registerRequestSchema)) dto: RegisterRequest,
  ): Promise<AuthResponse> {
    return this.auth.register(dto);
  }

  /** 200 + { user, accessToken }. Uniform 401 — never reveals which half failed. */
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body(new ZodValidationPipe(loginRequestSchema)) dto: LoginRequest): Promise<AuthResponse> {
    return this.auth.login(dto);
  }

  /** Profile of the token bearer. The template for every guarded route that follows. */
  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: JwtPayload): Promise<PublicUser> {
    return this.auth.me(user.sub);
  }
}
