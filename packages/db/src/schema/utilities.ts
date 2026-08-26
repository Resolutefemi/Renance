import { pgSchema } from 'drizzle-orm/pg-core';

/** Utilities module tables live HERE and only here (schema 'utilities'). */
export const utilities = pgSchema('utilities');
