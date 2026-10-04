-- 0015_school_setup.sql
--
-- The people + results setup layer for the school portal:
--   - school logo on the school row (stamped on every report card, the
--     portal chrome and the public PIN checker)
--   - subject departments for the senior band (art / science / commercial)
--     with a core flag, so SSS classes compose their subject list per track
--   - full student detail forms: DOB, guardian, address, photo, status
--   - per-student subject offering (an SSS student offers their track)
--   - attendance: one row per student per day, marked by staff on the
--     roster or tapped by the pupil on a classroom kiosk screen

ALTER TABLE school.schools
  ADD COLUMN IF NOT EXISTS logo_url text NOT NULL DEFAULT '';

ALTER TABLE school.subjects
  ADD COLUMN IF NOT EXISTS department text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_core boolean NOT NULL DEFAULT false;

ALTER TABLE school.students
  ADD COLUMN IF NOT EXISTS dob text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS guardian_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS guardian_phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS address text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS photo_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

-- Per-student subject offering. An empty set means "everything the class
-- does" (the primary + JSS default); once management fills it (SSS),
-- only these subjects appear on the student's result sheet.
CREATE TABLE IF NOT EXISTS school.student_subjects (
  student_id uuid NOT NULL REFERENCES school.students(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  PRIMARY KEY (student_id, subject_id)
);
CREATE INDEX IF NOT EXISTS school_student_subjects_student_idx
  ON school.student_subjects (student_id);

-- Attendance: one row per student per day. present / absent / late /
-- excused. The UNIQUE key makes re-marking the same day an upsert, so
-- the kiosk and the staff roster can both write safely.
CREATE TABLE IF NOT EXISTS school.attendance (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  class_id   uuid        NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  student_id uuid        NOT NULL REFERENCES school.students(id) ON DELETE CASCADE,
  day        date        NOT NULL,
  status     text        NOT NULL DEFAULT 'present',
  note       text        NOT NULL DEFAULT '',
  marked_by  uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, day)
);
CREATE INDEX IF NOT EXISTS school_attendance_class_idx
  ON school.attendance (class_id, day);
CREATE INDEX IF NOT EXISTS school_attendance_school_idx
  ON school.attendance (school_id, day);

-- Departments are free-form-validated in code ('', art, science,
-- commercial) so the NERDC seed keeps working across older rows; the
-- status column likewise ('active', 'left', 'graduated').
