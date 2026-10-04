-- 0013_school_platform.sql
--
-- The school platform: a management + teacher workspace layered on top of
-- the scholar world. Schools sign up (name + type), management seeds the
-- Nigerian curriculum (classes + subjects), builds term syllabuses with
-- topics and notes, enrolls students, manages results (ggportal-style:
-- CA1/CA2/exam, positions on finalize, per-result PIN), and creates
-- teacher accounts with per-class-subject result-filling assignments.
-- The mobile app consumes read-only offline packs: syllabus, scheme of
-- work and notes.

CREATE SCHEMA IF NOT EXISTS school;

-- ---------------------------------------------------------------- schools
CREATE TABLE IF NOT EXISTS school.schools (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text        NOT NULL,
  school_type   text        NOT NULL DEFAULT 'secondary'
                            CHECK (school_type IN ('primary', 'secondary', 'both')),
  address       text        NOT NULL DEFAULT '',
  owner_user_id uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Members: management (the school's own staff account) and teachers.
-- Every member IS a study.users row, so one JWT flow serves both worlds.
CREATE TABLE IF NOT EXISTS school.members (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  role       text        NOT NULL CHECK (role IN ('management', 'teacher')),
  full_name  text        NOT NULL DEFAULT '',
  staff_code text        NOT NULL DEFAULT '',
  status     text        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (school_id, user_id)
);
CREATE INDEX IF NOT EXISTS school_members_user_idx ON school.members (user_id);

-- Classes: Primary 1-6, JSS 1-3, SSS 1-3 (seeded from the NERDC catalog).
CREATE TABLE IF NOT EXISTS school.classes (
  id        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  name      text        NOT NULL,
  level     text        NOT NULL DEFAULT 'junior'
                        CHECK (level IN ('primary', 'junior', 'senior')),
  seq       integer     NOT NULL DEFAULT 0,
  UNIQUE (school_id, name)
);

-- Subjects: the Nigerian curriculum offer (seeded per school on demand).
CREATE TABLE IF NOT EXISTS school.subjects (
  id        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  name      text        NOT NULL,
  code      text        NOT NULL DEFAULT '',
  level     text        NOT NULL DEFAULT 'both'
                        CHECK (level IN ('primary', 'junior', 'senior', 'both')),
  seq       integer     NOT NULL DEFAULT 0,
  UNIQUE (school_id, name)
);

-- Which subject is taught in which class.
CREATE TABLE IF NOT EXISTS school.class_subjects (
  class_id   uuid NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  PRIMARY KEY (class_id, subject_id)
);

-- Term syllabuses: one per class+subject+term(+session). scheme_of_work
-- is the weekly plan: [{week, topic, objectives, activities}].
CREATE TABLE IF NOT EXISTS school.syllabuses (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id      uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  class_id       uuid        NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  subject_id     uuid        NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  term           integer     NOT NULL CHECK (term BETWEEN 1 AND 3),
  session        text        NOT NULL DEFAULT '',
  scheme_of_work jsonb       NOT NULL DEFAULT '[]'::jsonb,
  updated_by     uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_id, subject_id, term, session)
);

-- Topics under a syllabus, each carrying the note body (markdown-ish
-- plain text). source records where the note came from (nerdc,
-- classnotes, custom) for provenance.
CREATE TABLE IF NOT EXISTS school.topics (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  syllabus_id uuid        NOT NULL REFERENCES school.syllabuses(id) ON DELETE CASCADE,
  title       text        NOT NULL,
  seq         integer     NOT NULL DEFAULT 0,
  week        integer,
  content     text        NOT NULL DEFAULT '',
  source      text        NOT NULL DEFAULT 'custom',
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS school_topics_syllabus_idx ON school.topics (syllabus_id, seq);

-- Students: enrolled per school + class. The result-check PIN lives on
-- the finalized result, not here.
CREATE TABLE IF NOT EXISTS school.students (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id    uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  class_id     uuid        REFERENCES school.classes(id) ON DELETE SET NULL,
  full_name    text        NOT NULL,
  admission_no text        NOT NULL DEFAULT '',
  sex          text        NOT NULL DEFAULT '' CHECK (sex IN ('', 'M', 'F')),
  session      text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS school_students_class_idx ON school.students (school_id, class_id);

-- Results: one per student per term per session (ggportal pattern).
CREATE TABLE IF NOT EXISTS school.results (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id       uuid        NOT NULL REFERENCES school.students(id) ON DELETE CASCADE,
  class_id         uuid        NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  term             integer     NOT NULL CHECK (term BETWEEN 1 AND 3),
  session          text        NOT NULL DEFAULT '',
  status           text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'finalized')),
  pin              text        NOT NULL DEFAULT '',
  marks_obtainable integer     NOT NULL DEFAULT 100,
  teacher_report   text        NOT NULL DEFAULT '',
  principal_report text        NOT NULL DEFAULT '',
  finalized_at     timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, term, session)
);
CREATE INDEX IF NOT EXISTS school_results_class_idx ON school.results (class_id, term, session);

-- Result items: one row per subject. CA1/CA2 max 20 each, exam max 60.
-- total/grade/remark cached on save; position + class_average on finalize.
CREATE TABLE IF NOT EXISTS school.result_items (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  result_id     uuid        NOT NULL REFERENCES school.results(id) ON DELETE CASCADE,
  subject_id    uuid        NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  entered_by    uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  ca1           real        NOT NULL DEFAULT 0,
  ca2           real        NOT NULL DEFAULT 0,
  exam          real        NOT NULL DEFAULT 0,
  total         real        NOT NULL DEFAULT 0,
  grade         text        NOT NULL DEFAULT '',
  remark        text        NOT NULL DEFAULT '',
  position      integer,
  class_average real,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (result_id, subject_id)
);
CREATE INDEX IF NOT EXISTS school_result_items_result_idx ON school.result_items (result_id);

-- Teaching assignments: which member fills results for which class+subject.
CREATE TABLE IF NOT EXISTS school.assignments (
  id         uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  uuid    NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  member_id  uuid    NOT NULL REFERENCES school.members(id) ON DELETE CASCADE,
  class_id   uuid    NOT NULL REFERENCES school.classes(id) ON DELETE CASCADE,
  subject_id uuid    NOT NULL REFERENCES school.subjects(id) ON DELETE CASCADE,
  UNIQUE (member_id, class_id, subject_id)
);
CREATE INDEX IF NOT EXISTS school_assignments_member_idx ON school.assignments (member_id);
