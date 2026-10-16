-- 0035: learn.seed_meta — versioned seed markers. The secondary
-- curriculum refresh (JAMB 30 units x 10 topics, founder directive
-- 2026-10-17) runs once per seed version at boot; the marker row
-- keeps later boots instant.
CREATE TABLE IF NOT EXISTS learn.seed_meta (
  key        text PRIMARY KEY,
  value      text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);
