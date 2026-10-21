-- 0036: profile avatar (founder directive 2026-10-17: "introduce 50
-- different avatar image that users can use as profile picture").
-- The avatar column stores the chosen avatar key, e.g. 'avatar-17'.
-- Empty string = the classic initial-letter avatar.
ALTER TABLE study.profiles ADD COLUMN IF NOT EXISTS avatar text NOT NULL DEFAULT '';
