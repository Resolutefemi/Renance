-- 0021_entitlements.sql
--
-- Premium subscriptions, REN coins, device binding and email
-- verification, in ONE row per user so the owner can grant premium from
-- the Neon console by flipping premium_role to true and setting
-- premium_type (week | month | quarter | year | school_grant).
--
-- Student plans (Naira): week 500, month 1,500, quarter 2,500,
-- year 5,000. A JAMB premium unlocks WAEC, NECO and Post-UTME too.
-- REN coin redemption: 3 days 30 REN, 1 week 100 REN, 1 month 250 REN.
--
-- payments records every billing attempt (Paystack now, manual grants
-- by the owner); the webhook flips status to success and grants.

CREATE TABLE IF NOT EXISTS study.entitlements (
  user_id            uuid        PRIMARY KEY REFERENCES study.users(id) ON DELETE CASCADE,
  premium_role       boolean     NOT NULL DEFAULT false,
  premium_type       text        NOT NULL DEFAULT '',
  premium_expires_at timestamptz,
  ren_coins          integer     NOT NULL DEFAULT 0,
  device_id          text        NOT NULL DEFAULT '',
  email_verified     boolean     NOT NULL DEFAULT false,
  verify_token       text        NOT NULL DEFAULT '',
  verify_sent_at     timestamptz,
  first_free_cbt     boolean     NOT NULL DEFAULT false,
  referral_code      text        NOT NULL DEFAULT '',
  referred_by        uuid        REFERENCES study.users(id) ON DELETE SET NULL,
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS entitlements_referral_code_idx
  ON study.entitlements (referral_code)
  WHERE referral_code <> '';

-- One account per device (anti free-tier abuse): a device id may appear
-- on at most one entitlement row.
CREATE UNIQUE INDEX IF NOT EXISTS entitlements_device_idx
  ON study.entitlements (device_id)
  WHERE device_id <> '';

CREATE TABLE IF NOT EXISTS study.payments (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES study.users(id) ON DELETE CASCADE,
  provider    text        NOT NULL DEFAULT 'paystack',
  plan        text        NOT NULL,
  amount_kobo integer     NOT NULL DEFAULT 0,
  currency    text        NOT NULL DEFAULT 'NGN',
  reference   text        NOT NULL UNIQUE,
  status      text        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','success','failed','abandoned')),
  meta        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payments_user_idx ON study.payments (user_id, created_at DESC);

-- School plans: trial (30 days, all features but PDF export), free,
-- basic, standard, premium. Grant/renewal stamps live on the school row
-- so management can see them and the owner can flip them in Neon.
ALTER TABLE school.schools
  ADD COLUMN IF NOT EXISTS plan            text       NOT NULL DEFAULT 'trial',
  ADD COLUMN IF NOT EXISTS plan_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS trial_ends_at   timestamptz,
  ADD COLUMN IF NOT EXISTS plan_source     text       NOT NULL DEFAULT '';
