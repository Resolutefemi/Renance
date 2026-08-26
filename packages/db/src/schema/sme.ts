import { pgSchema } from 'drizzle-orm/pg-core';

/** Sme module tables live HERE and only here (schema 'sme'). */
export const sme = pgSchema('sme');
