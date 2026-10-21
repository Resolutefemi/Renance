-- 0024_account_kind.sql
--
-- Separate the school workplace from the student desk (founder
-- directive, 2026-10-02): management and teacher details must never mix
-- with student details, and a student must not be able to sign in to
-- the school workspace with student credentials (nor a school account
-- into the student desk).
--
--   account_kind  'student' (default) or 'school' - stamped at
--                 /school/auth/register and teacher creation, backfilled
--                 here for every existing staff account. The login
--                 endpoint reads it to enforce the audience split.

ALTER TABLE study.users
  ADD COLUMN IF NOT EXISTS account_kind text NOT NULL DEFAULT 'student'
  CHECK (account_kind IN ('student', 'school'));

-- Backfill: anyone who already carries a school membership is staff.
UPDATE study.users u
SET    account_kind = 'school'
WHERE  u.account_kind = 'student'
  AND  EXISTS (
        SELECT 1 FROM school.members m WHERE m.user_id = u.id
      );
