-- 0029_social.sql — the Renance feed + follows (founder directive
-- 2026-10-14: "the major update feeds just like Duolingo feeds that
-- people interact with").
--
-- social holds the public social graph (follows) and the feed (posts,
-- likes, comments). Milestone posts are auto-written by the platform
-- ("Joy hits 400 streak", "scored 360 in JAMB", "reached Platinum
-- league", "won an arena duel") and deduped per (user, milestone);
-- user posts are freeform. Every user_id rides the REAL study.users
-- id (uuid) — the 0028 lesson learned the first time.

CREATE SCHEMA IF NOT EXISTS social;

-- ─── Follow graph ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS social.follows (
  follower_id uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  followee_id uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX IF NOT EXISTS social_follows_followee_idx ON social.follows(followee_id);
CREATE INDEX IF NOT EXISTS social_follows_follower_idx ON social.follows(follower_id);

-- ─── Feed posts ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS social.posts (
  post_id    BIGSERIAL PRIMARY KEY,
  user_id    uuid REFERENCES study.users(id) ON DELETE CASCADE, -- NULL = platform voice
  kind       TEXT NOT NULL DEFAULT 'user',  -- user | milestone
  milestone  TEXT NOT NULL DEFAULT '',      -- dedup key: streak_400 / jamb_360 / league_3 / arena_win_7
  body       TEXT NOT NULL DEFAULT '',
  meta       JSONB NOT NULL DEFAULT '{}',   -- {score, exam, league, streak, topic, course…}
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- One milestone post per (user, milestone) — the 400-streak post is
-- written once, ever. Freeform posts (milestone='') are unbounded.
CREATE UNIQUE INDEX IF NOT EXISTS social_posts_milestone_uniq
  ON social.posts(user_id, milestone) WHERE milestone <> '';
CREATE INDEX IF NOT EXISTS social_posts_created_idx ON social.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS social_posts_user_idx ON social.posts(user_id, created_at DESC);

-- ─── Interactions ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS social.post_likes (
  post_id    BIGINT NOT NULL REFERENCES social.posts(post_id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS social.post_comments (
  id         BIGSERIAL PRIMARY KEY,
  post_id    BIGINT NOT NULL REFERENCES social.posts(post_id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS social_post_comments_post_idx ON social.post_comments(post_id, created_at);
