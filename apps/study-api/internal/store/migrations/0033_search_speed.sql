-- 0033_search_speed.sql - the catalogue search was taking 30+ seconds:
-- the course sweep probed learn.topics with a correlated EXISTS per
-- course (10.7k probes into 1.6M topic rows, unnesting keywords each
-- time) and no index anywhere could serve the ILIKE '%...%' fragments.
-- The "Find my courses with AI" finder runs that sweep once per pasted
-- line, so a registration slip meant minutes before the AI pass even
-- started - the frontend's 45s guard aborted first ("not reachable").
--
-- Fix here: pg_trgm GIN indexes so title fragments are index scans.
-- Fix in code (desk.go): the topic arms run ONCE per search as a CTE,
-- and only when the course-level sweep came back thin.
--
-- GUARDED like 0032: content tables exist on the content pool only,
-- and managed Postgres without pg_trgm just keeps the seq-scan path
-- instead of failing the boot.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
EXCEPTION WHEN OTHERS THEN
    NULL; -- no pg_trgm on this pool: searches stay correct, just slower
END
$$;

-- array_to_string is only STABLE, so it cannot sit in an index
-- expression; this IMMUTABLE wrapper flattens the keyword array into
-- one trigram-indexable string (chr(31) cannot appear inside a typed
-- fragment, so element boundaries stay boundaries).
CREATE OR REPLACE FUNCTION learn.kw_flat(k text[]) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT coalesce(array_to_string(k, chr(31)), '') $$;

DO $$
BEGIN
    IF to_regclass('learn.courses') IS NOT NULL THEN
        CREATE INDEX IF NOT EXISTS learn_courses_title_trgm
            ON learn.courses USING gin (title gin_trgm_ops);
    END IF;
    IF to_regclass('learn.topics') IS NOT NULL THEN
        CREATE INDEX IF NOT EXISTS learn_topics_title_trgm
            ON learn.topics USING gin (title gin_trgm_ops);
        CREATE INDEX IF NOT EXISTS learn_topics_kw_trgm
            ON learn.topics USING gin (learn.kw_flat(keywords) gin_trgm_ops);
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL; -- a pool without the extension cannot build trgm indexes
END
$$;
