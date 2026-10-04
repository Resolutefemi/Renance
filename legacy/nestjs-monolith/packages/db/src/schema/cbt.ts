import { integer, jsonb, pgSchema, text, timestamp, uniqueIndex, uuid, index } from 'drizzle-orm/pg-core';
import { organizations, users } from './core';

/**
 * CBT module (Phase 2). ADR-0003 doctrine:
 *   - `payload`  = student-safe question bundle (NEVER contains answers)
 *   - `answerKey`= grading material (NEVER returned by any endpoint)
 * Questions are authored in repo JSON banks (packages/cbt-content); Neon
 * stores the published registry + attempts, not the authoring source.
 */
export const cbt = pgSchema('cbt');

export const cbtBundleStatusEnum = cbt.enum('bundle_status', ['draft', 'published', 'archived']);
export const cbtAttemptStatusEnum = cbt.enum('attempt_status', ['in_progress', 'graded']);

export const bundles = cbt.table(
  'bundles',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    organizationId: uuid('organization_id')
      .notNull()
      .references(() => organizations.id, { onDelete: 'cascade' }),
    /** bank code, e.g. 'bio101' — unique per org WITH version */
    code: text('code').notNull(),
    version: integer('version').notNull().default(1),
    title: text('title').notNull(),
    /** sha256 of the canonical payload — attempts pin this fingerprint */
    sha256: text('sha256').notNull(),
    questionCount: integer('question_count').notNull(),
    totalMarks: integer('total_marks').notNull(),
    durationMinutes: integer('duration_minutes'),
    /** CbtBundle.questions — student-safe by construction */
    payload: jsonb('payload').notNull(),
    /** CbtKey.answers — SERVER ONLY. No endpoint ever returns this. */
    answerKey: jsonb('answer_key').notNull(),
    status: cbtBundleStatusEnum('status').notNull().default('published'),
    createdById: uuid('created_by_id')
      .notNull()
      .references(() => users.id),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('bundles_org_code_version_unique').on(t.organizationId, t.code, t.version),
    index('bundles_org_status_idx').on(t.organizationId, t.status),
  ],
);

export const attempts = cbt.table(
  'attempts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    bundleId: uuid('bundle_id')
      .notNull()
      .references(() => bundles.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    organizationId: uuid('organization_id')
      .notNull()
      .references(() => organizations.id, { onDelete: 'cascade' }),
    status: cbtAttemptStatusEnum('status').notNull().default('graded'),
    /** the student's responses exactly as submitted: {qid: letter|text} */
    answers: jsonb('answers').notNull(),
    score: integer('score').notNull(),
    totalMarks: integer('total_marks').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // MVP: ONE attempt per (bundle, user) — retakes are a later product decision
    uniqueIndex('attempts_bundle_user_unique').on(t.bundleId, t.userId),
    index('attempts_user_idx').on(t.userId),
  ],
);

export type BundleRow = typeof bundles.$inferSelect;
export type NewBundleRow = typeof bundles.$inferInsert;
export type AttemptRow = typeof attempts.$inferSelect;
