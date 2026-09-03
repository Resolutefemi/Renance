-- 0005: spaced repetition (ROADMAP #3) — SM-2 over attempt topics.
-- One row per (user, topic). The grading engine upserts a row for every
-- topic in a graded attempt's breakdown: accuracy maps to an SM-2 quality
-- (0..5) and the classic SuperMemo-2 rule advances ease / interval /
-- repetitions. due_on <= today means the topic is due for review today;
-- a lapse (quality < 3) resets repetitions and schedules it again tomorrow.

CREATE TABLE IF NOT EXISTS study.review_queue (
  user_id       uuid             NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  topic         text             NOT NULL,
  ease          double precision NOT NULL DEFAULT 2.5,
  interval_days integer          NOT NULL DEFAULT 0,
  repetitions   integer          NOT NULL DEFAULT 0,
  lapses        integer          NOT NULL DEFAULT 0,
  due_on        date             NOT NULL DEFAULT current_date,
  last_correct  integer          NOT NULL DEFAULT 0,
  last_total    integer          NOT NULL DEFAULT 0,
  updated_at    timestamptz      NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, topic),
  CONSTRAINT review_queue_ease_floor CHECK (ease >= 1.3)
);

CREATE INDEX IF NOT EXISTS review_queue_due_idx
  ON study.review_queue (user_id, due_on);
