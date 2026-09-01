import { z } from 'zod';
import { uuidSchema } from './primitives';

/**
 * CBT contracts (Gates 1.9 + 2.0). Doctrine (ADR-0003): the API publishes a
 * bundle WITH its key in ONE call, but no endpoint ever returns the key.
 * Grading is server-side (Gate 2.0).
 */

export const CBTLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'] as const;

export const bundleQuestionSchema = z.object({
  id: z.string().min(1).max(64),
  type: z.enum(['mcq', 'text']),
  stem: z.string().trim().min(1).max(2000),
  options: z.record(z.string().regex(/^[A-H]$/), z.string().min(1).max(1000)).optional(),
  marks: z.number().int().positive().max(100).default(1),
});
export type BundleQuestion = z.infer<typeof bundleQuestionSchema>;

export const keyEntrySchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('mcq'),
    letter: z.enum(CBTLetters),
    explanation: z.string().max(4000).optional(),
  }),
  z.object({
    type: z.literal('text'),
    accepted: z.array(z.string().trim().min(1).max(1000)).min(1).max(20),
    explanation: z.string().max(4000).optional(),
  }),
]);
export type KeyEntry = z.infer<typeof keyEntrySchema>;

/** mcq key letters must exist in the question's options. */
function everyMcqLetterHasAnOption(v: PublishBundleShape): boolean {
  return v.questions.every((q) => {
    if (q.type !== 'mcq' || !q.options) return true;
    const key = v.answerKey[q.id];
    if (!key || key.type !== 'mcq') return false;
    return q.options[key.letter] !== undefined;
  });
}

type PublishBundleShape = {
  questions: Array<{ id: string; type: 'mcq' | 'text'; options?: Record<string, string> }>;
  answerKey: Record<string, KeyEntry>;
};

export const publishBundleSchema = z
  .object({
    code: z
      .string()
      .trim()
      .min(2)
      .max(64)
      .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'code must be lowercase-dash'),
    title: z.string().trim().min(2).max(160),
    version: z.number().int().positive().max(10000).default(1),
    durationMinutes: z.number().int().positive().max(600).nullable().default(null),
    questions: z.array(bundleQuestionSchema).min(1).max(2000),
    answerKey: z.record(z.string(), keyEntrySchema),
  })
  .refine(
    (v) => v.questions.every((q) => (q.type === 'mcq') === (q.options !== undefined)),
    { message: 'mcq questions require options; text questions must not have them' },
  )
  .refine(
    (v) => v.questions.every((q) => v.answerKey[q.id] !== undefined && v.answerKey[q.id]!.type === q.type),
    { message: 'every question needs a matching-type key entry' },
  )
  .refine(everyMcqLetterHasAnOption, {
    message: 'every mcq key letter must exist in its options',
  });
export type PublishBundleRequest = z.infer<typeof publishBundleSchema>;

/** Manifest row: metadata ONLY — no payload, no key. */
export const bundleMetaSchema = z.object({
  id: uuidSchema,
  code: z.string(),
  title: z.string(),
  version: z.number().int(),
  questionCount: z.number().int(),
  totalMarks: z.number().int(),
  durationMinutes: z.number().int().nullable(),
  sha256: z.string(),
  status: z.enum(['draft', 'published', 'archived']),
  createdAt: z.string().datetime(),
});
export type BundleMeta = z.infer<typeof bundleMetaSchema>;

/** GET /cbt/bundles/:id — full questions, ZERO key material. */
export const bundleFetchSchema = z.object({
  meta: bundleMetaSchema,
  questions: z.array(bundleQuestionSchema),
});
export type BundleFetch = z.infer<typeof bundleFetchSchema>;

/** POST /cbt/bundles/:id/attempts (Gate 2.0) — responses only. */
export const submitAttemptSchema = z.object({
  answers: z.record(z.string().min(1).max(64), z.string().trim().min(1).max(1000)),
});
export type SubmitAttemptRequest = z.infer<typeof submitAttemptSchema>;

export const attemptResultSchema = z.object({
  id: uuidSchema,
  bundleId: uuidSchema,
  status: z.enum(['in_progress', 'graded']),
  score: z.number().int(),
  totalMarks: z.number().int(),
  /** per-question: 'correct' | 'wrong' | 'unanswered' — reveal AFTER grading */
  breakdown: z.array(
    z.object({
      questionId: z.string(),
      result: z.enum(['correct', 'wrong', 'unanswered']),
      yours: z.string().nullable(),
      /** shown only post-grading: the right answer + explanation */
      answer: z.string().nullable(),
      explanation: z.string().nullable(),
    }),
  ),
  submittedAt: z.string().datetime(),
});
export type AttemptResult = z.infer<typeof attemptResultSchema>;
