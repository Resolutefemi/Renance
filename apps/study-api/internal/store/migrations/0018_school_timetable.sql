-- 0018_school_timetable.sql
--
-- The weekly class timetable. One row per class per day per period, so
-- re-marking a slot is a safe upsert (UNIQUE class + day + period).
-- A slot with subject_id NULL is a labelled non-subject block
-- (assembly, break, clubs). Times are plain HH:MM text so schools keep
-- whatever bell format they already use.

CREATE TABLE IF NOT EXISTS school.timetable (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  class_id   uuid        NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  day        int         NOT NULL, -- 1 Monday .. 5 Friday
  period     int         NOT NULL, -- 1 .. 10
  start_time text        NOT NULL DEFAULT '',
  end_time   text        NOT NULL DEFAULT '',
  subject_id uuid        REFERENCES school.subjects(id) ON DELETE CASCADE,
  label      text        NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_id, day, period)
);
CREATE INDEX IF NOT EXISTS school_timetable_school_idx
  ON school.timetable (school_id, class_id);
