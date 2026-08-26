import { pgSchema } from 'drizzle-orm/pg-core';

/** Skills module tables live HERE and only here (schema 'skills'). */
export const skills = pgSchema('skills');
