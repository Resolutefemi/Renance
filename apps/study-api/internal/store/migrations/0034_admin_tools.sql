-- 0034 admin tools (founder directive 2026-10-17): presence/time tracking
-- for the admin dashboard + question flags + user course submissions.
--
-- heartbeat: POST /learn/heartbeat stamps last_seen_at and accumulates
-- time_spent_seconds. It NEVER touches the streak - the founder doctrine
-- stands (streaks move on quiz/lesson activity only, opening the app
-- counts for presence, not for the flame).

ALTER TABLE learn.learners
    ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;
ALTER TABLE learn.learners
    ADD COLUMN IF NOT EXISTS time_spent_seconds bigint NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_learners_last_seen
    ON learn.learners (last_seen_at DESC);

-- A learner flags a question that is wrong / badly formed / has a broken
-- answer key. The admin dashboard reads and resolves these.
CREATE TABLE IF NOT EXISTS learn.question_flags (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
    source      TEXT NOT NULL DEFAULT 'lesson',
    question_id TEXT NOT NULL DEFAULT '',
    course_code TEXT NOT NULL DEFAULT '',
    reason      TEXT NOT NULL DEFAULT '',
    details     TEXT NOT NULL DEFAULT '',
    status      TEXT NOT NULL DEFAULT 'open',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_question_flags_status
    ON learn.question_flags (status, created_at DESC);

-- A learner cannot find their course (or the content is wrong) and
-- submits the course + some topics they expect. The admin dashboard
-- reads these with the submitter's details.
CREATE TABLE IF NOT EXISTS learn.course_submissions (
    id               BIGSERIAL PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
    institution_type TEXT NOT NULL DEFAULT '',
    school_name      TEXT NOT NULL DEFAULT '',
    department       TEXT NOT NULL DEFAULT '',
    course_code      TEXT NOT NULL DEFAULT '',
    course_title     TEXT NOT NULL DEFAULT '',
    topics           TEXT NOT NULL DEFAULT '',
    details          TEXT NOT NULL DEFAULT '',
    status           TEXT NOT NULL DEFAULT 'open',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_course_submissions_status
    ON learn.course_submissions (status, created_at DESC);

-- The 20-tier ladder (founder 2026-10-17): Diamond moves from index 9
-- to index 19. Every member seated at the old Diamond tier rides up
-- with the name.
UPDATE learn.league_members SET league = 19 WHERE league = 9;

