import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Inject,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  changePasswordSchema,
  loginRequestSchema,
  registerRequestSchema,
  updateProfileSchema,
  type AuthResponse,
  type ChangePasswordRequest,
  type JwtPayload,
  type LoginRequest,
  type PublicUser,
  type RegisterRequest,
  type UpdateProfileRequest,
} from '@renance/shared';
import { ZodValidationPipe } from '../common/zod-validation.pipe';
import { AuthService } from './auth.service';
import { CurrentUser } from './current-user.decorator';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  // explicit token: survives esbuild/tsx (no emitDecoratorMetadata)
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}

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

  /** Gate 1.6 — update own display name. 200 user · 401 no/invalid token · 400 validation */
  @Patch('me')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  updateMe(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(updateProfileSchema)) dto: UpdateProfileRequest,
  ): Promise<PublicUser> {
    return this.auth.updateProfile(user.sub, dto);
  }

  /** Gate 1.6 — change own password. 200 user · 401 wrong current · 400 weak new */
  @Post('me/change-password')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  changePassword(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(changePasswordSchema)) dto: ChangePasswordRequest,
  ): Promise<PublicUser> {
    return this.auth.changePassword(user.sub, dto);
  }
}
