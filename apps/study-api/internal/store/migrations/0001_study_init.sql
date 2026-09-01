-- 0001: study schema — the entire ERA-2 data model (ADR-0004).
-- The Go service owns ONLY this schema; legacy core.*/cbt.* stay untouched.

CREATE SCHEMA IF NOT EXISTS study;

CREATE TABLE IF NOT EXISTS study.users (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  username      text        NOT NULL,
  password_hash text        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_idx
  ON study.users (lower(username));

CREATE TABLE IF NOT EXISTS study.profiles (
  user_id     uuid        PRIMARY KEY REFERENCES study.users(id) ON DELETE CASCADE,
  full_name   text        NOT NULL DEFAULT '',
  institution text        NOT NULL DEFAULT '',
  grade_level text        NOT NULL DEFAULT '',
  exams       jsonb       NOT NULL DEFAULT '[]'::jsonb,
  completed   boolean     NOT NULL DEFAULT false,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Answer keys are SERVER-ONLY (ADR-0003): never leave via any student route.
CREATE TABLE IF NOT EXISTS study.answer_keys (
  code        text NOT NULL,
  question_id text NOT NULL,
  letter      text NOT NULL,
  explanation text NOT NULL DEFAULT '',
  PRIMARY KEY (code, question_id)
);

CREATE TABLE IF NOT EXISTS study.attempts (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  code         text        NOT NULL,
  status       text        NOT NULL DEFAULT 'in_progress'
                           CHECK (status IN ('in_progress','grading','graded','error')),
  started_at   timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  duration_ms  integer
);

CREATE INDEX IF NOT EXISTS attempts_user_idx ON study.attempts (user_id, started_at DESC);

CREATE TABLE IF NOT EXISTS study.attempt_answers (
  attempt_id  uuid NOT NULL REFERENCES study.attempts(id) ON DELETE CASCADE,
  question_id text NOT NULL,
  selected    text NOT NULL,
  PRIMARY KEY (attempt_id, question_id)
);

CREATE TABLE IF NOT EXISTS study.results (
  attempt_id uuid        PRIMARY KEY REFERENCES study.attempts(id) ON DELETE CASCADE,
  score      integer     NOT NULL,
  total      integer     NOT NULL,
  breakdown  jsonb       NOT NULL DEFAULT '[]'::jsonb,
  graded_at  timestamptz NOT NULL DEFAULT now()
);

-- Drives the post-onboarding silent asset-sync strip in the web UI.
CREATE TABLE IF NOT EXISTS study.sync_jobs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  status     text        NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','running','done')),
  progress   integer     NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  detail     jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sync_jobs_user_idx ON study.sync_jobs (user_id, created_at DESC);
