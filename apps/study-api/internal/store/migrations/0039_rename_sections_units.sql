-- 0039_rename_sections_units.sql - founder directive 2026-10-23:
-- "change this courses/units/topics to courses/sections/units".
--
-- learn.course_units -> learn.course_sections (column unit -> section)
-- learn.topics       -> learn.units          (topic_id -> unit_id, unit -> section)
--
-- Every statement is guarded (to_regclass / information_schema), so the
-- migration is idempotent and a no-op on any pool that does not hold
-- the catalog (user primary, cache) - it can never abort a boot.
--
-- Backwards-compatible VIEWS under the old names keep the previous
-- binary serving while Render redeploys: simple views are auto-updatable
-- for plain INSERT/UPDATE/DELETE. ON CONFLICT inserts against a view are
-- rejected by Postgres - those are rare (AI unit expand / refresh) and
-- simply retry after the new binary is live. The views are dropped by
-- 0040 once the new binary is verified.

DO $$
BEGIN
    IF to_regclass('learn.course_units') IS NOT NULL AND to_regclass('learn.course_sections') IS NULL THEN
        ALTER TABLE learn.course_units RENAME TO course_sections;
    END IF;
    IF to_regclass('learn.topics') IS NOT NULL AND to_regclass('learn.units') IS NULL THEN
        ALTER TABLE learn.topics RENAME TO units;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'learn' AND table_name = 'course_sections'
                 AND column_name = 'unit') THEN
        ALTER TABLE learn.course_sections RENAME COLUMN unit TO section;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'learn' AND table_name = 'units'
                 AND column_name = 'topic_id') THEN
        ALTER TABLE learn.units RENAME COLUMN topic_id TO unit_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'learn' AND table_name = 'units'
                 AND column_name = 'unit') THEN
        ALTER TABLE learn.units RENAME COLUMN unit TO section;
    END IF;
END $$;

-- Cosmetic: the serial sequence follows its PK column.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_sequences
               WHERE schemaname = 'learn' AND sequencename = 'topics_topic_id_seq') THEN
        ALTER SEQUENCE learn.topics_topic_id_seq RENAME TO units_unit_id_seq;
    END IF;
END $$;

-- Compatibility views for the deploy window (dropped by 0040).
DO $$
BEGIN
    IF to_regclass('learn.units') IS NOT NULL THEN
        CREATE OR REPLACE VIEW learn.topics AS
            SELECT unit_id AS topic_id, course_id, section AS unit,
                   seq, title, category, keywords, figures
            FROM learn.units;
        CREATE OR REPLACE VIEW learn.course_units AS
            SELECT course_id, section AS unit, title, generated_at
            FROM learn.course_sections;
    END IF;
END $$;
