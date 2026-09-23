-- 0017_school_idcards.sql
--
-- Student ID cards. Management issues one card per student per session;
-- the card serial is school-unique (REN-<year>-<serial>) so a lost card
-- can be revoked and reprinted without ambiguity. The portal renders
-- the printable card sheet from this table plus the student photo.

CREATE TABLE IF NOT EXISTS school.id_cards (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  student_id uuid        NOT NULL REFERENCES school.students(id) ON DELETE CASCADE,
  serial     text        NOT NULL,
  session    text        NOT NULL DEFAULT '',
  status     text        NOT NULL DEFAULT 'issued', -- issued | revoked | reprinted
  issued_by  uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  issued_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, session),
  UNIQUE (school_id, serial)
);
CREATE INDEX IF NOT EXISTS school_id_cards_school_idx
  ON school.id_cards (school_id, session);
CREATE INDEX IF NOT EXISTS school_id_cards_student_idx
  ON school.id_cards (student_id);
