-- ============================================================================
--  Renance - 00_bootstrap_schemas.sql   (v2, slim)
--
--  Owns: extensions + cross-cutting audit bookkeeping ONLY.
--  Module schemas are created by DRIZZLE MIGRATIONS from now on:
--    every module's first `pnpm db:generate` cycle automatically emits
--    `CREATE SCHEMA <module>;` alongside its tables (see packages/db/drizzle).
--  This avoids double-creation conflicts between two DDL owners.
--
--  HOW TO APPLY
--    Option A:  bash scripts/db-bootstrap.sh        (uses DATABASE_URL + psql)
--    Option B:  paste into the Neon Console SQL Editor
--  Idempotent: safe to run multiple times.
-- ============================================================================

BEGIN;

-- Extensions -----------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid() used by users.id
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive unique emails
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- fast name search later

-- Audit schema arrives in Phase 4 hardening; pre-create now so the
-- migration-journal table below has a home even before that phase opens.
CREATE SCHEMA IF NOT EXISTS audit;

COMMENT ON SCHEMA audit IS 'Cross-cutting audit trail and migration bookkeeping';

COMMIT;
