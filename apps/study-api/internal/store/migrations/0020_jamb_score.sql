-- Official UTME scoring: composite JAMB mock papers carry per-subject
-- sections, so a graded result can carry a per-subject official ledger
-- (attempted, total, correct, score/100, time used). The column stores
-- store.SubjectRow JSON; NULL for static packs that have no sections.
ALTER TABLE study.results ADD COLUMN IF NOT EXISTS subjects jsonb;
