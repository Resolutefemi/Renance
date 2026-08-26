import { pgSchema } from 'drizzle-orm/pg-core';

/** Cbt module tables live HERE and only here (schema 'cbt'). */
export const cbt = pgSchema('cbt');
