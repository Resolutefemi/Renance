-- 0040_ai_orchestrator.sql - the six-key GLM orchestrator (founder
-- architecture, 2026-11-07): Level 200+ units carry 5 theory questions
-- with marking guides alongside the 20-question objective quiz, so the
-- lesson cache grows a theory_questions column.
--
-- Guarded and idempotent: a no-op on any pool that does not hold
-- learn.lessons (the content database, the user primary), so the
-- split-horizon boot can run it everywhere without a role check.

DO $$
BEGIN
    IF to_regclass('learn.lessons') IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'learn' AND table_name = 'lessons'
          AND column_name = 'theory_questions') THEN
        ALTER TABLE learn.lessons ADD COLUMN theory_questions JSONB NOT NULL DEFAULT '[]';
    END IF;
END $$;
