-- 0023_password_resets.sql
--
-- Forgot password (founder directive, 2026-10-02): both the web and the
-- app get a working "forgot password" flow. A requested reset mints a
-- single-use, 30-minute token; only its SHA-256 hex is stored so a
-- database leak cannot be replayed against the reset endpoint. The
-- mailed link lands on the web /reset-password page, which works in any
-- browser (including the phone's, for app users).
--
--   password_resets   one live token per account: a fresh request
--                     retires the previous live rows first

CREATE TABLE IF NOT EXISTS study.password_resets (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  token_hash text        NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS password_resets_user_idx
  ON study.password_resets (user_id);
