-- 0008: multiplayer arena (ROADMAP #14, in-process hub slice).
--
-- arena.matches is the durable record of one head-to-head quiz: the pack
-- both students played, the lifecycle status and the winner (NULL = draw
-- or aborted). arena.participants holds one row per student per match
-- with the final score. The LIVE match itself (question cadence, answers,
-- countdowns) lives entirely in the hub's memory: the database only ever
-- sees the outcome, written best-effort after the last question, so a DB
-- hiccup can never break a live match.

CREATE TABLE IF NOT EXISTS arena.matches (
  id             text        PRIMARY KEY,
  code           text        NOT NULL,
  body           text        NOT NULL DEFAULT '',
  status         text        NOT NULL DEFAULT 'live',
  winner_user_id uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  player_count   integer     NOT NULL DEFAULT 2,
  started_at     timestamptz NOT NULL DEFAULT now(),
  finished_at    timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT arena_status_check CHECK (status IN ('live', 'finished', 'aborted'))
);

CREATE INDEX IF NOT EXISTS arena_matches_finished_idx
  ON arena.matches (finished_at DESC);

CREATE TABLE IF NOT EXISTS arena.participants (
  match_id    uuid        NOT NULL REFERENCES arena.matches(id) ON DELETE CASCADE,
  user_id     uuid        REFERENCES study.users(id) ON DELETE CASCADE,
  username    text        NOT NULL DEFAULT '',
  score       integer     NOT NULL DEFAULT 0,
  correct     integer     NOT NULL DEFAULT 0,
  answered    integer     NOT NULL DEFAULT 0,
  is_bot      boolean     NOT NULL DEFAULT false,
  finished_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT arena_participants_unique UNIQUE (match_id, user_id)
);

CREATE INDEX IF NOT EXISTS arena_participants_user_idx
  ON arena.participants (user_id, finished_at DESC);
