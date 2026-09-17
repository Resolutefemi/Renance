-- 0011: email-first auth.
-- Registration and login move to email + password on the web; the username
-- is picked later in the account-setup modal (exams / class questions).
-- Legacy clients (mobile) keep posting {username, password} — the auth
-- handlers accept either identifier.
-- Emails are unique case-insensitively; partial index because Google-only
-- rows, legacy rows and pre-email registrations may carry NULL/''.
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx
  ON study.users (lower(email))
  WHERE email IS NOT NULL AND email <> '';
