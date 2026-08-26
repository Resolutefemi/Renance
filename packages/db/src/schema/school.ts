import { pgSchema } from 'drizzle-orm/pg-core';

/** School module tables live HERE and only here (schema 'school'). */
export const school = pgSchema('school');
