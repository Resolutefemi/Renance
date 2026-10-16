-- 0032_streak_forgiveness.sql - the founder's streak rules (2026-10-17):
--
--   * a streak grows ONLY on quiz/lesson activity (never app opens);
--   * a missed day does not kill a streak - it is lost on the SECOND
--     quiet day;
--   * streak freezes still bridge absences automatically;
--   * NEW: a lost streak of 7+ days can be FORGIVEN (restored without
--     a freeze) when the learner returns within 3 quiet days - at most
--     three times, ever; after that only freezes can save a streak.
--
-- The count column tracks lifetime forgiveness uses per learner.
-- GUARDED: learn.learners exists on the user pools only (Neon primary
-- + the InsForge mirror); the content pool has no such table and must
-- not abort its boot here.
DO $$
BEGIN
    IF to_regclass('learn.learners') IS NOT NULL THEN
        ALTER TABLE learn.learners ADD COLUMN IF NOT EXISTS streak_forgiven_count int NOT NULL DEFAULT 0;
    END IF;
END
$$;
