-- 0009: daily challenge (ROADMAP #20) — one deterministic 10-question
-- sprint per exam body per UTC day.
--
-- study.attempts.daily_day marks an attempt as THE day's challenge
-- (NULL = an ordinary paper). The mark has teeth: the submit handler
-- rejects answers outside that day's seeded selection, so every daily
-- attempt is scored over exactly the same 10 questions.
--
-- study.daily_results is the leaderboard ledger: PRIMARY KEY
-- (day, body, user_id) means one ranked seat per student per body per
-- day. The grading engine inserts best-effort with ON CONFLICT DO
-- NOTHING, so the FIRST graded submission of the day owns the seat and
-- every replay stays practice-only — the board can never be ground
-- farmed, and a DB hiccup costs a board row, never a graded paper.
-- submitted_at is back-filled from the attempt itself so tie-breaks
-- honour the actual submission moment, not grading-queue timing.

ALTER TABLE study.attempts ADD COLUMN IF NOT EXISTS daily_day date;

CREATE TABLE IF NOT EXISTS study.daily_results (
  day          date        NOT NULL,
  body         text        NOT NULL,
  user_id      uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  attempt_id   uuid        NOT NULL REFERENCES study.attempts(id) ON DELETE CASCADE,
  code         text        NOT NULL,
  score        integer     NOT NULL DEFAULT 0,
  total        integer     NOT NULL DEFAULT 0,
  duration_ms  integer,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (day, body, user_id)
);

CREATE INDEX IF NOT EXISTS daily_results_board_idx
  ON study.daily_results (body, day, score DESC, submitted_at ASC);
