-- 0002: Google sign-in identities.
-- password_hash stays NOT NULL (empty string for Google-only scholars) so
-- the credential flow keeps one row shape; empty hash simply never matches
-- a bcrypt comparison.
ALTER TABLE study.users
  ADD COLUMN IF NOT EXISTS google_sub text UNIQUE,
  ADD COLUMN IF NOT EXISTS email      text;
