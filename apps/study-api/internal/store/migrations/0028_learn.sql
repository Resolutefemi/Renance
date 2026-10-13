-- 0028_learn.sql — the Supreme learn module merged into Renance
-- (founder directive 2026-10-14: "the architecture and the backend in
-- supreme will now be under Renance", all state live on the Renance
-- account, nothing mock).
--
-- Schema learn holds the curriculum tree (seeded once from the in-repo
-- curriculum CSVs + the secondary subject roadmaps) and the full
-- gamification ledger (hearts / gems / quests / league / chests) keyed
-- by the EXISTING study.users id - one identity across the platform.

CREATE SCHEMA IF NOT EXISTS learn;

-- ─── Curriculum tree (static, seeded once; no AI involved) ────────────────

CREATE TABLE IF NOT EXISTS learn.departments (
  dept_id  TEXT PRIMARY KEY,          -- U-AGR-001 / P-APS-001 / C-EDU-001 / GST-ALL / SEC-JAMB
  itype    TEXT NOT NULL,             -- University | Polytechnic | College of Education | General Studies | Secondary
  faculty  TEXT NOT NULL DEFAULT '',
  name     TEXT NOT NULL,
  focus    TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS learn_departments_itype_idx ON learn.departments(itype);

CREATE TABLE IF NOT EXISTS learn.courses (
  course_id  TEXT PRIMARY KEY,        -- CRS-00001 / GST 101 / SEC-JAMB-BIOLOGY
  dept_id    TEXT NOT NULL REFERENCES learn.departments(dept_id) ON DELETE CASCADE,
  code       TEXT NOT NULL DEFAULT '',
  title      TEXT NOT NULL,
  level      TEXT NOT NULL DEFAULT '', -- data lineage only; never shown (founder: remove the level tag)
  category   TEXT NOT NULL DEFAULT 'Core',
  body       TEXT NOT NULL DEFAULT 'tertiary', -- tertiary | jamb | waec | neco | post-utme
  subject    TEXT NOT NULL DEFAULT ''          -- bank subject slug for secondary courses
);
CREATE INDEX IF NOT EXISTS learn_courses_dept_idx ON learn.courses(dept_id);
CREATE INDEX IF NOT EXISTS learn_courses_body_idx ON learn.courses(body);

CREATE TABLE IF NOT EXISTS learn.topics (
  topic_id   TEXT PRIMARY KEY,        -- TOP-000001 / SEC-JAMB-BIOLOGY-T01
  course_id  TEXT NOT NULL REFERENCES learn.courses(course_id) ON DELETE CASCADE,
  seq        INT  NOT NULL,           -- 1..N inside the course
  title      TEXT NOT NULL,
  category   TEXT NOT NULL DEFAULT 'Concepts & Foundations',
  unit       INT  NOT NULL DEFAULT 1, -- roadmap unit (the long ladder)
  keywords   TEXT [] NOT NULL DEFAULT '{}', -- past-question mapping keys
  figures    TEXT [] NOT NULL DEFAULT '{}'  -- curated drawing ids (organic chemistry, waves)
);
CREATE INDEX IF NOT EXISTS learn_topics_course_idx ON learn.topics(course_id);

-- ─── JIT lesson cache (read-through, single source of truth) ──────────────

CREATE TABLE IF NOT EXISTS learn.lessons (
  topic_id     TEXT PRIMARY KEY REFERENCES learn.topics(topic_id) ON DELETE CASCADE,
  title        TEXT NOT NULL DEFAULT '',
  summary      TEXT NOT NULL DEFAULT '',
  notes        JSONB NOT NULL DEFAULT '[]',     -- [{heading, body, image?, imageAlt?}]
  key_points   JSONB NOT NULL DEFAULT '[]',
  quiz         JSONB NOT NULL DEFAULT '[]',     -- Supreme exercise shapes
  drawings     JSONB NOT NULL DEFAULT '[]',     -- structured SVG figures (organic chemistry, waves)
  source       TEXT NOT NULL DEFAULT 'zai-glm', -- zai-glm | bank
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  hit_count    INT NOT NULL DEFAULT 0
);

-- ─── Learner economy (1:1 with the Renance account) ───────────────────────

CREATE TABLE IF NOT EXISTS learn.learners (
  user_id           uuid PRIMARY KEY REFERENCES study.users(id) ON DELETE CASCADE,
  hearts            INT NOT NULL DEFAULT 5,
  hearts_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  gems              INT NOT NULL DEFAULT 0,
  xp                INT NOT NULL DEFAULT 0,
  freeze_count      INT NOT NULL DEFAULT 0,
  freeze_used_on    TEXT,
  daily_goal        INT NOT NULL DEFAULT 50,   -- 20 | 50 | 100 | 200
  super_until       TIMESTAMPTZ,
  boost_until       TIMESTAMPTZ,
  streak_count      INT NOT NULL DEFAULT 0,
  last_active_on    TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS learn.user_courses (
  user_id   uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES learn.courses(course_id) ON DELETE CASCADE,
  added_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, course_id)
);
CREATE INDEX IF NOT EXISTS learn_user_courses_user_idx ON learn.user_courses(user_id);

CREATE TABLE IF NOT EXISTS learn.active_course (
  user_id   uuid PRIMARY KEY REFERENCES study.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES learn.courses(course_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS learn.progress (
  user_id     uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  topic_id    TEXT NOT NULL REFERENCES learn.topics(topic_id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'completed',
  best_score  INT NOT NULL DEFAULT 0,
  xp_earned   INT NOT NULL DEFAULT 0,
  attempts    INT NOT NULL DEFAULT 1,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, topic_id)
);
CREATE INDEX IF NOT EXISTS learn_progress_user_idx ON learn.progress(user_id);

-- ─── Gamification ledger ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS learn.xp_events (
  id         BIGSERIAL PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  amount     INT NOT NULL,
  kind       TEXT NOT NULL DEFAULT 'lesson', -- lesson|practice|review|quest|chest|league
  week_key   TEXT NOT NULL,
  day_key    TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS learn_xp_events_week_idx ON learn.xp_events(user_id, week_key);
CREATE INDEX IF NOT EXISTS learn_xp_events_day_idx ON learn.xp_events(user_id, day_key);

CREATE TABLE IF NOT EXISTS learn.daily_stats (
  user_id       uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  day_key       TEXT NOT NULL,
  xp            INT NOT NULL DEFAULT 0,
  correct       INT NOT NULL DEFAULT 0,
  lessons       INT NOT NULL DEFAULT 0,
  perfect       INT NOT NULL DEFAULT 0,
  practice      INT NOT NULL DEFAULT 0,
  max_combo     INT NOT NULL DEFAULT 0,
  chests_opened INT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day_key)
);

CREATE TABLE IF NOT EXISTS learn.mistakes (
  user_id     uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  question_id TEXT NOT NULL,
  topic_id    TEXT,
  payload     JSONB NOT NULL DEFAULT '{}',
  resolved    BOOLEAN NOT NULL DEFAULT FALSE,
  misses      INT NOT NULL DEFAULT 1,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, question_id)
);

CREATE TABLE IF NOT EXISTS learn.quest_claims (
  user_id    uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  quest_key  TEXT NOT NULL,
  period_key TEXT NOT NULL,
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, quest_key, period_key)
);

CREATE TABLE IF NOT EXISTS learn.league_members (
  user_id   uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  week_key  TEXT NOT NULL,
  league    INT NOT NULL DEFAULT 0, -- 0=Bronze .. 9=Diamond
  promoted  BOOLEAN NOT NULL DEFAULT FALSE,
  demoted   BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, week_key)
);

CREATE TABLE IF NOT EXISTS learn.chest_opens (
  user_id   uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  chest_key TEXT NOT NULL,            -- courseId#unitIndex
  gems      INT NOT NULL,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, chest_key)
);
