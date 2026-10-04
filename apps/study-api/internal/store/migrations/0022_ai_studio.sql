-- 0022_ai_studio.sql
--
-- Renance AI Studio (founder directive, 2026-09-30): the AI becomes a
-- first-class product surface with persistence, mirroring what the big
-- AI chat products ship:
--
--   ai_chats      conversation threads, each parked in a named folder
--                 (folders are a plain text column + index, Claude-style
--                 projects without a second table to keep every query
--                 simple and fast on Neon's pooler)
--   ai_messages   every turn of every chat, with the thinking trace the
--                 UI replays and the past-question bridge count
--   ai_memories   durable facts about the student ("I am in SSS 2,
--                 my target is UNILAG for Medicine") injected into every
--                 system prompt
--   ai_artifacts  generated documents: quizzes, study notes, lesson
--                 notes and notebooks (NotebookLM-style). share_slug is
--                 the public quiz link tag: /quiz/<slug> where the slug
--                 carries the quiz's own name.
--
-- Artifacts are INSERT-only JSON documents; regenerating writes a new
-- row. Nothing here touches graded attempts or the exam banks.

CREATE TABLE IF NOT EXISTS study.ai_chats (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  folder     text        NOT NULL DEFAULT 'General',
  title      text        NOT NULL DEFAULT 'New chat',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_chats_user_idx
  ON study.ai_chats (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS ai_chats_folder_idx
  ON study.ai_chats (user_id, folder);

CREATE TABLE IF NOT EXISTS study.ai_messages (
  id         bigserial   PRIMARY KEY,
  chat_id    uuid        NOT NULL REFERENCES study.ai_chats(id) ON DELETE CASCADE,
  role       text        NOT NULL CHECK (role IN ('user','assistant')),
  content    text        NOT NULL,
  thinking   text        NOT NULL DEFAULT '',
  bridged    integer     NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_messages_chat_idx ON study.ai_messages (chat_id, id);

CREATE TABLE IF NOT EXISTS study.ai_memories (
  id         bigserial   PRIMARY KEY,
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  content    text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_memories_user_idx ON study.ai_memories (user_id, id DESC);

CREATE TABLE IF NOT EXISTS study.ai_artifacts (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  kind        text        NOT NULL CHECK (kind IN ('quiz','note','notebook','lesson_note')),
  title       text        NOT NULL DEFAULT '',
  subject     text        NOT NULL DEFAULT '',
  class_level text        NOT NULL DEFAULT '',
  data        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  share_slug  text        NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_artifacts_user_idx
  ON study.ai_artifacts (user_id, created_at DESC);
-- The public quiz link: one live artifact per slug; regenerating a quiz
-- never collides because slugs carry a short random suffix.
CREATE UNIQUE INDEX IF NOT EXISTS ai_artifacts_share_idx
  ON study.ai_artifacts (share_slug)
  WHERE share_slug <> '';
