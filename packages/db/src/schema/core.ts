import { pgSchema, text, timestamp, uuid, pgEnum, index } from 'drizzle-orm/pg-core';
import { citext } from '../types/citext';

/** core: identity, orgs, memberships, RBAC, verification (Phase 1 owner). */
export const core = pgSchema('core');

/** Account lifecycle. Suspension blocks login; deletion comes with Phase 4 GDPR pass. */
export const userStatusEnum = core.enum('user_status', ['active', 'suspended']);

/**
 * users — the platform-wide identity record.
 * One user = one human login credential set today. Organizations/memberships
 * (next gates of Phase 1) reference users.id; modules never copy credentials.
 */
export const users = core.table(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    // enforced case-insensitive uniqueness lives here, not in app code
    email: citext('email').notNull().unique(),
    /** bcrypt hash (cost 12). NEVER leaves the api process. */
    passwordHash: text('password_hash').notNull(),
    displayName: text('display_name').notNull(),
    status: userStatusEnum('status').notNull().default('active'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('users_created_at_idx').on(t.createdAt)],
);

export type UserRow = typeof users.$inferSelect;
export type NewUserRow = typeof users.$inferInsert;
