-- 0025_school_report_card.sql
-- GGSA report-card parity (founder directive 2026-10-04): the traits
-- (skills + behaviour A-E), attendance counts, next-term-begins line on
-- each result, and the school's phone / email / motto for the header.

ALTER TABLE school.results
  ADD COLUMN IF NOT EXISTS traits jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS attendance_present integer,
  ADD COLUMN IF NOT EXISTS attendance_opened integer,
  ADD COLUMN IF NOT EXISTS next_term_begins text NOT NULL DEFAULT '';

ALTER TABLE school.schools
  ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS email text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS motto text NOT NULL DEFAULT '';
