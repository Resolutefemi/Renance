-- 0016_school_fees.sql
--
-- The money desk for the school portal. Management prices each term's
-- charges per class (or school-wide), then records payments against
-- students. Amounts live in kobo (bigint) so no float ever touches the
-- ledger. A fee row with class_id NULL applies to every class in the
-- school (PTA levy, sports levy); one with a class applies to that
-- class only.

CREATE TABLE IF NOT EXISTS school.fees (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id   uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  class_id    uuid        REFERENCES school.classes(id) ON DELETE CASCADE,
  title       text        NOT NULL,
  description text        NOT NULL DEFAULT '',
  amount_kobo bigint      NOT NULL DEFAULT 0,
  term        int         NOT NULL DEFAULT 1,
  session     text        NOT NULL DEFAULT '',
  seq         int         NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (school_id, class_id, title, term, session)
);
CREATE INDEX IF NOT EXISTS school_fees_school_idx
  ON school.fees (school_id, session, term);
CREATE INDEX IF NOT EXISTS school_fees_class_idx
  ON school.fees (class_id);

-- One payment row per receipt. `recorded_by` keeps the staff member who
-- took the money; `method` is cash / transfer / pos.
CREATE TABLE IF NOT EXISTS school.fee_payments (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id   uuid        NOT NULL REFERENCES school.schools(id) ON DELETE CASCADE,
  fee_id      uuid        NOT NULL REFERENCES school.fees(id) ON DELETE CASCADE,
  student_id  uuid        NOT NULL REFERENCES school.students(id) ON DELETE CASCADE,
  amount_kobo bigint      NOT NULL DEFAULT 0,
  method      text        NOT NULL DEFAULT 'cash',
  reference   text        NOT NULL DEFAULT '',
  paid_on     date        NOT NULL DEFAULT current_date,
  recorded_by uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS school_fee_payments_student_idx
  ON school.fee_payments (student_id, fee_id);
CREATE INDEX IF NOT EXISTS school_fee_payments_school_idx
  ON school.fee_payments (school_id, paid_on);
