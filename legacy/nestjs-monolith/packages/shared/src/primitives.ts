import { z } from 'zod';

/**
 * Primitive field contracts with ZERO internal imports.
 * Keeping these leaf-level prevents the shared barrel's import cycles
 * (auth.ts -> index.ts -> auth.ts) that crashed at runtime on 2026-08-27.
 * Rule of thumb for this package: schemas may only import DOWN
 * (primitives <- domain contracts <- barrel), never sideways/up.
 */
export const emailSchema = z.string().trim().toLowerCase().email();
export type Email = z.infer<typeof emailSchema>;

export const uuidSchema = z.string().uuid();
