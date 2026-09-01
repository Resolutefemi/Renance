import { pgSchema } from 'drizzle-orm/pg-core';

/** Payroll module tables live HERE and only here (schema 'payroll'). */
export const payroll = pgSchema('payroll');
