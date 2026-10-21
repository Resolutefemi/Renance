-- 0031_deep_content.sql - the deep-content overhaul (founder directive
-- 2026-10-16). Two additions:
--
-- learn.course_units: the AI-expanded course tree. A seeded tertiary
-- course ships with its 12 CSV topics in unit 1; the expansion loop
-- grows it to up to 15 units x 10 topics, one AI-generated unit at a
-- time, and stamps every generated unit here so the ladder can tell
-- "already grown" from "still growing" without re-asking the AI.
--
-- learn.topic_chests: the reward chest every finished topic opens
-- (gems 8-30 / a streak freeze / a 15-minute 2x XP boost), rolled once
-- per user+topic - the PK makes a replayed completion idempotent.
CREATE TABLE IF NOT EXISTS learn.course_units (
    course_id    TEXT        NOT NULL REFERENCES learn.courses(course_id) ON DELETE CASCADE,
    unit         INT         NOT NULL,
    title        TEXT        NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (course_id, unit)
);

CREATE TABLE IF NOT EXISTS learn.topic_chests (
    user_id       UUID        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
    topic_id      TEXT        NOT NULL REFERENCES learn.topics(topic_id) ON DELETE CASCADE,
    reward_kind   TEXT        NOT NULL, -- gems | freeze | boost
    reward_amount INT         NOT NULL,
    opened_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, topic_id)
);

CREATE INDEX IF NOT EXISTS idx_course_units_course ON learn.course_units (course_id, unit);
CREATE INDEX IF NOT EXISTS idx_topic_chests_user ON learn.topic_chests (user_id, opened_at DESC);
