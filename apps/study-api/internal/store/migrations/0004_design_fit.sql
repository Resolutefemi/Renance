-- 0004: design-fit — the Stitch UI needs a target year on the profile.
-- The launcher hero card shows "NEXT TARGET — UTME 2027 — 142 days" and the
-- profile screen shows the "JAMB 2027" chip. target_year is picked during
-- onboarding, stored on the profile row, and nullable until then (older
-- clients never send it).

ALTER TABLE study.profiles ADD COLUMN IF NOT EXISTS target_year integer;

ALTER TABLE study.profiles DROP CONSTRAINT IF EXISTS profiles_target_year_range;
ALTER TABLE study.profiles ADD CONSTRAINT profiles_target_year_range
  CHECK (target_year IS NULL OR target_year BETWEEN 2000 AND 2100);
