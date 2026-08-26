import {
  pgSchema,
  text,
  timestamp,
  uuid,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { citext } from '../types/citext';

/** core: identity, orgs, memberships, RBAC, verification (Phase 1 owner). */
export const core = pgSchema('core');

/** Account lifecycle. Suspension blocks login; deletion comes with Phase 4 GDPR pass. */
export const userStatusEnum = core.enum('user_status', ['active', 'suspended']);

/**
 * users — the platform-wide identity record.
 * One user = one human login credential set today. Organizations/memberships
 * reference users.id; modules never copy credentials.
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

// ---------------------------------------------------------------------------
// Gate 1.2 — Organizations + Memberships
// ---------------------------------------------------------------------------

/** Coarse org classification. Module-specific profiles arrive with each module phase. */
export const orgTypeEnum = core.enum('org_type', ['school', 'business', 'other']);
export const orgStatusEnum = core.enum('org_status', ['active', 'suspended']);
/** RBAC ladder for Gate 1.3 enforcement. owner > admin > member. */
export const memberRoleEnum = core.enum('member_role', ['owner', 'admin', 'member']);
/** 'invited' backs the invite-by-email stub; email delivery lands in a later gate. */
export const membershipStatusEnum = core.enum('membership_status', [
  'active',
  'invited',
  'revoked',
]);

/**
 * organizations — a school, business or group using one or more modules.
 * Modules (cbt.exams, school.classes, ...) will reference organizations.id
 * when their phases open; they NEVER duplicate org data.
 */
export const organizations = core.table(
  'organizations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: text('name').notNull(),
    /** URL-safe identifier (zod enforces lowercase-dash format; uniqueness here). */
    slug: text('slug').notNull().unique(),
    type: orgTypeEnum('type').notNull().default('other'),
    status: orgStatusEnum('status').notNull().default('active'),
    createdById: uuid('created_by_id')
      .notNull()
      .references(() => users.id),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('organizations_created_at_idx').on(t.createdAt)],
);

/**
 * memberships — the ONLY join between humans and organizations.
 * One membership per (org, user): role changes are UPDATEs, not new rows.
 * addedById is null for the creator's self-owned owner membership.
 */
export const memberships = core.table(
  'memberships',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    organizationId: uuid('organization_id')
      .notNull()
      .references(() => organizations.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: memberRoleEnum('role').notNull().default('member'),
    status: membershipStatusEnum('status').notNull().default('active'),
    addedById: uuid('added_by_id').references(() => users.id, { onDelete: 'set null' }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // a user has at most ONE membership (and therefore one role) per org
    uniqueIndex('memberships_org_user_unique').on(t.organizationId, t.userId),
    index('memberships_user_id_idx').on(t.userId),
  ],
);

export type UserRow = typeof users.$inferSelect;
export type NewUserRow = typeof users.$inferInsert;
export type OrganizationRow = typeof organizations.$inferSelect;
export type NewOrganizationRow = typeof organizations.$inferInsert;
export type MembershipRow = typeof memberships.$inferSelect;
export type NewMembershipRow = typeof memberships.$inferInsert;
