-- Founder directive 2026-10-05: deleting an account must delete ALL of
-- its details and information, INCLUDING activities - and accounts
-- already deleted by hand (in study.users or public.users in the Neon
-- editor) must have their leftovers swept out of every other table.

-- study.purge_user: THE one-account delete. The explicit child deletes
-- run first (belt and braces: every FK already cascades, but the purge
-- stays correct even if a future table ships without its FK), then the
-- users row itself goes last - a half-deleted account can never exist.
CREATE OR REPLACE FUNCTION study.purge_user(p_user uuid) RETURNS void AS $$
BEGIN
    DELETE FROM study.password_resets WHERE user_id = p_user;
    DELETE FROM study.ai_artifacts      WHERE user_id = p_user;
    DELETE FROM study.ai_memories       WHERE user_id = p_user;
    DELETE FROM study.ai_messages       WHERE chat_id IN (SELECT id FROM study.ai_chats WHERE user_id = p_user);
    DELETE FROM study.ai_chats          WHERE user_id = p_user;
    DELETE FROM study.payments          WHERE user_id = p_user;
    DELETE FROM study.entitlements      WHERE user_id = p_user;
    DELETE FROM school.members          WHERE user_id = p_user;
    DELETE FROM arena.participants      WHERE user_id = p_user;
    DELETE FROM study.daily_results     WHERE user_id = p_user;
    DELETE FROM study.card_progress     WHERE user_id = p_user;
    DELETE FROM study.sessions          WHERE user_id = p_user;
    DELETE FROM study.review_queue      WHERE user_id = p_user;
    DELETE FROM study.awards            WHERE user_id = p_user;
    DELETE FROM study.streaks           WHERE user_id = p_user;
    DELETE FROM study.sync_jobs         WHERE user_id = p_user;
    -- attempt_answers and results ride their attempt (ON DELETE CASCADE).
    DELETE FROM study.attempts          WHERE user_id = p_user;
    DELETE FROM study.profiles          WHERE user_id = p_user;
    DELETE FROM study.users             WHERE id = p_user;
END $$ LANGUAGE plpgsql;

-- study.purge_deleted_users: the orphan sweep. Any row in a user-keyed
-- table whose owner is gone from study.users is deleted - this is what
-- cleans up after accounts that were already deleted by hand before the
-- purge function existed.
CREATE OR REPLACE FUNCTION study.purge_deleted_users() RETURNS void AS $$
BEGIN
    DELETE FROM study.password_resets r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.ai_artifacts    r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.ai_memories     r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.ai_messages     r WHERE NOT EXISTS (SELECT 1 FROM study.ai_chats c WHERE c.id = r.chat_id);
    DELETE FROM study.ai_chats        r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.payments        r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.entitlements    r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM school.members        r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM arena.participants    r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.daily_results   r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.card_progress   r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.sessions        r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.review_queue    r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.awards          r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.streaks         r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.sync_jobs       r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    -- attempt_answers / results cascade with their attempts.
    DELETE FROM study.attempts        r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
    DELETE FROM study.profiles        r WHERE NOT EXISTS (SELECT 1 FROM study.users u WHERE u.id = r.user_id);
END $$ LANGUAGE plpgsql;

-- Run the sweep once at boot so the founder's report ("users that their
-- info or account has been deleted ... delete all their remaining info
-- in other tables") is settled the moment this migration lands.
SELECT study.purge_deleted_users();
