-- 0014_school_subject_levels.sql
--
-- The NERDC catalog repeats subject names across levels (Mathematics and
-- English Studies exist in primary, junior AND senior bands with different
-- codes and syllabuses). UNIQUE (school_id, name) collapsed them into one
-- row, so JSS classes were being handed the primary-band subject. Uniqueness
-- now includes the level band.

ALTER TABLE school.subjects
  DROP CONSTRAINT IF EXISTS subjects_school_id_name_key;

ALTER TABLE school.subjects
  DROP CONSTRAINT IF EXISTS school_subjects_school_name_level_key;

ALTER TABLE school.subjects
  ADD CONSTRAINT school_subjects_school_name_level_key UNIQUE (school_id, name, level);
