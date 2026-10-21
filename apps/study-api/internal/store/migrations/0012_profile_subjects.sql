-- Daily CBT subject combination (founder rule: the first daily tap asks
-- for the student's subject combination; every daily sprint afterwards
-- draws only those subjects). Stored on the profile so the web and the
-- app resolve the identical challenge server-side.
ALTER TABLE study.profiles ADD COLUMN IF NOT EXISTS subjects jsonb NOT NULL DEFAULT '[]'::jsonb;
