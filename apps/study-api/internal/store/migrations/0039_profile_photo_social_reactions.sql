-- 0039: profile photo + feed reactions (founder directive 2026-10-22:
-- "allow users to add profile pictures which will be uploaded and
-- fetched from cloudflare's R2 - a new folder under the Renance bucket
-- called profile-picture - users can also choose to add avatars
-- instead" + the Duolingo feed's CELEBRATE / reaction pills).

-- The R2 object key of the scholar's uploaded profile photo, relative
-- to the profile-picture/ folder ('f2b6…-1769…jpg'). Empty = the
-- scholar wears an avatar key (or the classic initial letter).
-- Whichever was set LAST wins on the clients; the API clears the other
-- column on each pick so the two never fight.
ALTER TABLE study.profiles ADD COLUMN IF NOT EXISTS avatar_photo TEXT NOT NULL DEFAULT '';

-- ─── Feed reactions ──────────────────────────────────────────────────────
-- The Duolingo pill row under every milestone: 🎉 party, 👏 clap,
-- 😤 angry. The big CELEBRATE button is the party pill. Three kinds
-- per post per scholar, toggleable; the feed aggregates counts and the
-- viewer's own picks in one grouped query.

CREATE TABLE IF NOT EXISTS social.post_reactions (
  post_id    BIGINT NOT NULL REFERENCES social.posts(post_id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL CHECK (kind IN ('party', 'clap', 'angry')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id, kind)
);
CREATE INDEX IF NOT EXISTS social_post_reactions_post_idx ON social.post_reactions(post_id);
