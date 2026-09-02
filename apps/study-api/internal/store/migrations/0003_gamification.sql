-- 0003: gamification — streaks, XP and badge awards (ROADMAP #2).
-- One row per user in study.streaks (upserted on every graded attempt);
-- study.awards is the badge ledger, UNIQUE per (user, code) so re-grading
-- can never double-issue a badge.

CREATE TABLE IF NOT EXISTS study.streaks (
  user_id         uuid        PRIMARY KEY REFERENCES study.users(id) ON DELETE CASCADE,
  current_streak  integer     NOT NULL DEFAULT 0,
  best_streak     integer     NOT NULL DEFAULT 0,
  total_xp        integer     NOT NULL DEFAULT 0,
  total_correct   integer     NOT NULL DEFAULT 0,
  attempts_count  integer     NOT NULL DEFAULT 0,
  last_active     date,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS study.awards (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  code       text        NOT NULL,
  meta       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  earned_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, code)
);

CREATE INDEX IF NOT EXISTS awards_user_idx ON study.awards (user_id, earned_at DESC);
