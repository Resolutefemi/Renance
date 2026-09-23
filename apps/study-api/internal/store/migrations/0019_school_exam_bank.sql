-- 0019_school_exam_bank.sql
--
-- The exam-question bank: original, curriculum-aligned questions held
-- per subject per term per session, tagged with their class band so a
-- school can assemble a paper for any class. Questions are multiple
-- choice (options jsonb array + answer_index) with an optional
-- explanation, marks and source tag. The `exams` table assembles bank
-- questions into a published paper for a class + subject + term; the
-- PIN check page and the print pipeline read from there.

CREATE TABLE IF NOT EXISTS school.exam_questions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id    uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  subject_id   uuid        NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  band         text        NOT NULL DEFAULT 'junior', -- primary | junior | senior
  term         int         NOT NULL DEFAULT 1,
  session      text        NOT NULL DEFAULT '',
  question     text        NOT NULL,
  options      jsonb       NOT NULL DEFAULT '[]', -- ["A text","B text",...]
  answer_index int         NOT NULL DEFAULT 0,
  explanation  text        NOT NULL DEFAULT '',
  marks        int         NOT NULL DEFAULT 1,
  source       text        NOT NULL DEFAULT 'renance-original',
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS school_exam_questions_pool_idx
  ON school.exam_questions (school_id, subject_id, term);
CREATE INDEX IF NOT EXISTS school_exam_questions_band_idx
  ON school.exam_questions (band);

-- A published exam pins the paper composition: which bank filter made
-- it, how many questions, and how long the sitting runs.
CREATE TABLE IF NOT EXISTS school.exams (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id       uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  class_id        uuid        NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  subject_id      uuid        NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  term            int         NOT NULL DEFAULT 1,
  session         text        NOT NULL DEFAULT '',
  title           text        NOT NULL DEFAULT '',
  duration_minutes int        NOT NULL DEFAULT 60,
  question_count  int         NOT NULL DEFAULT 40,
  status          text        NOT NULL DEFAULT 'published', -- draft | published
  created_by      uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_id, subject_id, term, session)
);
CREATE INDEX IF NOT EXISTS school_exams_school_idx
  ON school.exams (school_id, session, term);
