-- public.users - founder directive 2026-10-05: "make sure user details
-- is stored in public/users in neon db". The Neon console's table editor
-- opens on the public schema, where the founder could never see the
-- accounts; this surfaces the exact same rows there. It is a plain,
-- automatically-updatable view over study.users (the API's real table):
-- SELECT shows every account, and INSERT/UPDATE/DELETE issued against
-- public.users land on study.users, so the founder can even delete an
-- account right here and the ON DELETE CASCADE chain wipes its data.
--
-- NOTE for future migrations: any migration that changes study.users
-- columns must recreate this view (DROP VIEW IF EXISTS public.users;
-- CREATE VIEW public.users AS SELECT * FROM study.users;) so the public
-- mirror stays complete.

DO $$
DECLARE
    kind "char";
BEGIN
    SELECT c.relkind INTO kind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'users';

    IF kind = 'r' THEN
        -- A hand-made table occupies the name: preserve it under a dated
        -- backup name rather than dropping founder data, then create the
        -- view in its place.
        EXECUTE 'ALTER TABLE public.users RENAME TO users_manual_backup_20261005';
    END IF;

    IF kind IS DISTINCT FROM 'v' THEN
        EXECUTE 'DROP VIEW IF EXISTS public.users';
        EXECUTE 'CREATE VIEW public.users AS SELECT * FROM study.users';
    END IF;
END $$;
