import { z } from 'zod';
import { emailSchema } from './primitives';

/**
 * Auth contracts shared between api and future web/mobile clients.
 * These schemas are the single validation truth: the same file validates
 * API input today and (Phase 2) Flutter/web form payloads via generated types.
 */

export const passwordSchema = z
  .string()
  .min(8, 'password must be at least 8 characters')
  .max(128, 'password too long')
  // pragmatic strength floor — no regex police beyond this for MVP
  .refine((v) => /[a-zA-Z]/.test(v) && /\d/.test(v), {
    message: 'password must contain at least one letter and one number',
  });

export const registerRequestSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  displayName: z.string().trim().min(2, 'name too short').max(80),
});
export type RegisterRequest = z.infer<typeof registerRequestSchema>;

export const loginRequestSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, 'password required'),
});
export type LoginRequest = z.infer<typeof loginRequestSchema>;

/** PATCH /auth/me (Gate 1.6) — profile fields a user may change themselves. */
export const updateProfileSchema = z.object({
  displayName: z.string().trim().min(2, 'name too short').max(80),
});
export type UpdateProfileRequest = z.infer<typeof updateProfileSchema>;

/** POST /auth/change-password (Gate 1.6) — current proves ownership, new uses
 *  the SAME strength floor as registration. */
export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'current password required'),
  newPassword: passwordSchema,
});
export type ChangePasswordRequest = z.infer<typeof changePasswordSchema>;

export const USER_STATUSES_PUBLIC = ['active', 'suspended'] as const;
export const publicUserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  displayName: z.string(),
  status: z.enum(USER_STATUSES_PUBLIC),
  createdAt: z.string().datetime(), // ISO-8601 over the wire
});
export type PublicUser = z.infer<typeof publicUserSchema>;

export const authResponseSchema = z.object({
  user: publicUserSchema,
  accessToken: z.string(),
});
export type AuthResponse = z.infer<typeof authResponseSchema>;

export const jwtPayloadSchema = z.object({
  sub: z.string().uuid(),
  email: z.string().email(),
});
export type JwtPayload = z.infer<typeof jwtPayloadSchema>;
