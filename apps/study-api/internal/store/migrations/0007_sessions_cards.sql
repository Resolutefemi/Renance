-- 0007: fatigue telemetry (ROADMAP #6) + flashcard progress (ROADMAP #7).
--
-- study.sessions is the server-side log of one sitting. The client tracks
-- per-answer latencies and session length (NO PII beyond timing), the
-- server re-computes the same pure fatigue signal from the raw numbers
-- and stores the outcome. study.card_progress is the Leitner-box state
-- of one flashcard for one student: boxes 1..5 with fixed intervals, so
-- both the app and the web page shuffle the same deck in the same order.
--
-- Telemetry writes are best-effort by design: a failed session log never
-- breaks a graded attempt.

CREATE TABLE IF NOT EXISTS study.sessions (
  id              uuid             PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid             NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  attempt_id      text,
  code            text             NOT NULL DEFAULT '',
  started_at      timestamptz      NOT NULL,
  ended_at        timestamptz      NOT NULL,
  duration_ms     bigint           NOT NULL,
  answer_count    integer          NOT NULL DEFAULT 0,
  median_first5   integer          NOT NULL DEFAULT 0,
  median_last5    integer          NOT NULL DEFAULT 0,
  drift_ratio     double precision NOT NULL DEFAULT 0,
  fatigue_level   text             NOT NULL DEFAULT 'none',
  suggested_break boolean          NOT NULL DEFAULT false,
  created_at      timestamptz      NOT NULL DEFAULT now(),
  CONSTRAINT sessions_level_check
    CHECK (fatigue_level IN ('none', 'mild', 'high')),
  CONSTRAINT sessions_time_check CHECK (ended_at >= started_at)
);

CREATE INDEX IF NOT EXISTS sessions_user_created_idx
  ON study.sessions (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS study.card_progress (
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  card_id    text        NOT NULL,
  deck_code  text        NOT NULL DEFAULT '',
  box        integer     NOT NULL DEFAULT 1,
  correct    integer     NOT NULL DEFAULT 0,
  wrong      integer     NOT NULL DEFAULT 0,
  due_on     date        NOT NULL DEFAULT current_date,
  last_grade text        NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, card_id),
  CONSTRAINT card_progress_box_range CHECK (box BETWEEN 1 AND 5),
  CONSTRAINT card_progress_grade_check
    CHECK (last_grade IN ('', 'again', 'hard', 'good'))
);

CREATE INDEX IF NOT EXISTS card_progress_due_idx
  ON study.card_progress (user_id, due_on);
