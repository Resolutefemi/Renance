// Package store: entitlements - the premium subscription ledger. One row
// per user, readable from the Neon console: the owner grants premium by
// flipping premium_role to true and setting premium_type + premium_type's
// expiry. Everything the paywall, the blue tick, the REN wallet and the
// device lock read flows through here. While student billing is paused
// the API stamps every row premium (GrantEveryonePremium at boot,
// GrantPremiumYear for any row that slips through) so the database
// itself says premium, not just the gate.
package store

import (
        "context"
        "errors"
        "fmt"
        "strings"
        "time"

        "github.com/jackc/pgx/v5"
        "github.com/jackc/pgx/v5/pgconn"

        "renance.dev/study-api/internal/plans"
)

// Entitlement is one user's subscription + wallet + device lock state.
type Entitlement struct {
        UserID           string     `json:"userId"`
        PremiumRole      bool       `json:"premiumRole"`
        PremiumType      string     `json:"premiumType"`
        PremiumExpiresAt *time.Time `json:"premiumExpiresAt,omitempty"`
        RenCoins         int        `json:"renCoins"`
        DeviceID         string     `json:"-"`
        EmailVerified    bool       `json:"emailVerified"`
        VerifyToken      string     `json:"-"`
        VerifySentAt     *time.Time `json:"-"`
        FirstFreeCbt     bool       `json:"firstFreeCbt"`
        ReferralCode     string     `json:"referralCode,omitempty"`
        ReferredBy       *string    `json:"-"`
        UpdatedAt        time.Time  `json:"-"`
}

// PremiumActive reports whether the subscription is live right now: the
// role flag is on and, when an expiry is stamped, it is still ahead of
// the clock. The owner's console flip (premium_role = true with no
// expiry) is a lifetime grant.
func (e *Entitlement) PremiumActive(now time.Time) bool {
        if !e.PremiumRole {
                return false
        }
        return e.PremiumExpiresAt == nil || e.PremiumExpiresAt.After(now)
}

// ErrDeviceTaken is returned when a second account tries to claim a
// device that already owns an account (one device, one account).
var ErrDeviceTaken = errors.New("store: device already bound to an account")

// ErrDeviceMismatch is returned when a login arrives from a device that
// is bound to a DIFFERENT account (the app locks onto its first account).
var ErrDeviceMismatch = errors.New("store: device bound to another account")

const entitlementCols = `user_id, premium_role, premium_type, premium_expires_at,
        ren_coins, device_id, email_verified, verify_token, verify_sent_at,
        first_free_cbt, referral_code, referred_by, updated_at`

func scanEntitlement(row pgx.Row) (*Entitlement, error) {
        e := &Entitlement{}
        var referredBy *string
        err := row.Scan(&e.UserID, &e.PremiumRole, &e.PremiumType, &e.PremiumExpiresAt,
                &e.RenCoins, &e.DeviceID, &e.EmailVerified, &e.VerifyToken, &e.VerifySentAt,
                &e.FirstFreeCbt, &e.ReferralCode, &referredBy, &e.UpdatedAt)
        if err != nil {
                return nil, err
        }
        e.ReferredBy = referredBy
        return e, nil
}

// EnsureEntitlement lazily creates the row (every new user gets one on
// first touch) and returns the current state. While student billing is
// paused (plans.StudentBillingEnabled=false) a freshly created or
// still-free row is stamped premium on the spot, so any account the
// backfill missed (signed up mid-deploy, restored backup) still rides
// premium in the database itself.
func (s *Store) EnsureEntitlement(ctx context.Context, userID string) (*Entitlement, error) {
        _, err := s.Pool.Exec(ctx, `
                INSERT INTO study.entitlements (user_id) VALUES ($1)
                ON CONFLICT (user_id) DO NOTHING`, userID)
        if err != nil {
                return nil, fmt.Errorf("store: ensure entitlement: %w", err)
        }
        e, err := scanEntitlement(s.Pool.QueryRow(ctx, `
                SELECT `+entitlementCols+` FROM study.entitlements WHERE user_id = $1`, userID))
        if err != nil {
                return nil, fmt.Errorf("store: entitlement: %w", err)
        }
        if !plans.StudentBillingEnabled && !e.PremiumActive(time.Now().UTC()) {
                if gerr := s.GrantPremiumYear(ctx, userID); gerr != nil {
                        return nil, fmt.Errorf("store: entitlement open-door grant: %w", gerr)
                }
                e, err = scanEntitlement(s.Pool.QueryRow(ctx, `
                        SELECT `+entitlementCols+` FROM study.entitlements WHERE user_id = $1`, userID))
                if err != nil {
                        return nil, fmt.Errorf("store: entitlement reload: %w", err)
                }
        }
        return e, nil
}

// GrantPremiumYear stamps one user's row premium for a year, keeping
// any expiry that is already further out (a paying subscriber's date
// is never pulled back).
func (s *Store) GrantPremiumYear(ctx context.Context, userID string) error {
        _, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements
                SET premium_role = true,
                    premium_type = 'premium',
                    premium_expires_at = GREATEST(COALESCE(premium_expires_at, 'epoch'::timestamptz), now() + interval '365 days'),
                    updated_at = now()
                WHERE user_id = $1`, userID)
        if err != nil {
                return fmt.Errorf("store: grant premium year: %w", err)
        }
        return nil
}

// GrantEveryonePremium is the billing-paused backfill: every row that
// is not premium-active right now (free, or expired) is stamped
// premium for a year. Lifetime grants (premium_role with no expiry)
// are left untouched - they already outrank a dated grant. Returns the
// number of rows upgraded so the boot log can say what it did.
func (s *Store) GrantEveryonePremium(ctx context.Context) (int64, error) {
        tag, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements
                SET premium_role = true,
                    premium_type = 'premium',
                    premium_expires_at = now() + interval '365 days',
                    updated_at = now()
                WHERE premium_role = false
                   OR (premium_expires_at IS NOT NULL AND premium_expires_at < now())`)
        if err != nil {
                return 0, fmt.Errorf("store: grant everyone premium: %w", err)
        }
        return tag.RowsAffected(), nil
}

// SetPremium stamps the subscription. duration 0 (or negative) keeps the
// current expiry (or none = lifetime), the console-grant shape.
func (s *Store) SetPremium(ctx context.Context, userID, planType string, duration time.Duration) error {
        now := time.Now().UTC()
        tag, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements
                SET premium_role = true,
                    premium_type = $2,
                    premium_expires_at = CASE
                      WHEN $3::interval <= interval '0 seconds' THEN premium_expires_at
                      WHEN premium_role AND premium_expires_at IS NOT NULL AND premium_expires_at > $4
                        THEN premium_expires_at + $3::interval
                      ELSE $4 + $3::interval
                    END,
                    updated_at = $4
                WHERE user_id = $1`, userID, planType, fmt.Sprintf("%d seconds", int(duration.Seconds())), now)
        if err != nil {
                return fmt.Errorf("store: set premium: %w", err)
        }
        if tag.RowsAffected() == 0 {
                return fmt.Errorf("store: set premium: no user %s", userID)
        }
        return nil
}

// AddCoins credits REN coins (arena wins, referrals).
func (s *Store) AddCoins(ctx context.Context, userID string, amount int) error {
        if amount == 0 {
                return nil
        }
        _, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements SET ren_coins = GREATEST(0, ren_coins + $2), updated_at = now()
                WHERE user_id = $1`, userID, amount)
        if err != nil {
                return fmt.Errorf("store: add coins: %w", err)
        }
        return nil
}

// SpendCoins atomically debits the wallet; false when the balance is short.
func (s *Store) SpendCoins(ctx context.Context, userID string, amount int) (bool, error) {
        tag, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements SET ren_coins = ren_coins - $2, updated_at = now()
                WHERE user_id = $1 AND ren_coins >= $2`, userID, amount)
        if err != nil {
                return false, fmt.Errorf("store: spend coins: %w", err)
        }
        return tag.RowsAffected() > 0, nil
}

// ClaimDevice binds a device id. A device already bound to another user
// is rejected with ErrDeviceTaken; an account already bound to a
// DIFFERENT device is rejected with ErrDeviceMismatch (one account per
// device, both directions - founder directive 2026-10-02: a login from a
// second phone must be refused until management moves the account).
// Rebinding the same user+device pair is a no-op.
func (s *Store) ClaimDevice(ctx context.Context, userID, deviceID string) error {
        if deviceID == "" {
                return nil
        }
        var owner string
        err := s.Pool.QueryRow(ctx, `
                SELECT user_id FROM study.entitlements WHERE device_id = $1`, deviceID).Scan(&owner)
        if err != nil && !errors.Is(err, pgx.ErrNoRows) {
                return fmt.Errorf("store: claim device lookup: %w", err)
        }
        if err == nil && owner != userID {
                return ErrDeviceTaken
        }
        // The account side of the lock: refuse to silently re-bind an
        // account that is already seated on another device. The row
        // exists (bindDevice runs after EnsureEntitlement); a device
        // already pointing at this login's device (or never set) sails
        // through.
        var bound string
        err = s.Pool.QueryRow(ctx, `
                SELECT device_id FROM study.entitlements
                WHERE user_id = $1 AND device_id IS NOT NULL AND device_id <> ''`, userID).Scan(&bound)
        if err != nil && !errors.Is(err, pgx.ErrNoRows) {
                return fmt.Errorf("store: account device lookup: %w", err)
        }
        if err == nil && bound != deviceID {
                return ErrDeviceMismatch
        }
        _, err = s.Pool.Exec(ctx, `
                UPDATE study.entitlements SET device_id = $2, updated_at = now() WHERE user_id = $1`,
                userID, deviceID)
        if err != nil {
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
                        return ErrDeviceTaken
                }
                return fmt.Errorf("store: claim device: %w", err)
        }
        return nil
}

// DeviceTaken reports whether a device id is already bound to some
// account. The school sign-up runs this check BEFORE creating any rows
// so a refused device never orphans a half-registered account.
func (s *Store) DeviceTaken(ctx context.Context, deviceID string) (bool, error) {
        if deviceID == "" {
                return false, nil
        }
        var one int
        err := s.Pool.QueryRow(ctx, `
                SELECT 1 FROM study.entitlements WHERE device_id = $1`, deviceID).Scan(&one)
        if errors.Is(err, pgx.ErrNoRows) {
                return false, nil
        }
        if err != nil {
                return false, fmt.Errorf("store: device taken lookup: %w", err)
        }
        return true, nil
}

// UnbindDevice frees a user's device lock (management rescue for a lost
// or replaced phone: the student DMs management, management verifies and
// clears the binding so the next login on the new device seats cleanly).
// Returns true when a binding was actually cleared, false when the
// account carried none.
func (s *Store) UnbindDevice(ctx context.Context, userID string) (bool, error) {
        tag, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements SET device_id = NULL, updated_at = now()
                WHERE user_id = $1 AND device_id IS NOT NULL AND device_id <> ''`, userID)
        if err != nil {
                return false, fmt.Errorf("store: unbind device: %w", err)
        }
        return tag.RowsAffected() > 0, nil
}

// CheckDeviceLock rejects a login when the device is bound to another
// account. Unbound devices and web requests (empty deviceId) pass.
func (s *Store) CheckDeviceLock(ctx context.Context, userID, deviceID string) error {
        if deviceID == "" {
                return nil
        }
        var bound string
        err := s.Pool.QueryRow(ctx, `
                SELECT user_id FROM study.entitlements WHERE device_id = $1`, deviceID).Scan(&bound)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil
        }
        if err != nil {
                return fmt.Errorf("store: device lock: %w", err)
        }
        if bound != userID {
                return ErrDeviceMismatch
        }
        return nil
}

// MarkFirstFreeCbt consumes the one free full CBT; returns true when the
// caller was the one spending it (their first regular paper runs full).
func (s *Store) MarkFirstFreeCbt(ctx context.Context, userID string) (bool, error) {
        tag, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements SET first_free_cbt = true, updated_at = now()
                WHERE user_id = $1 AND first_free_cbt = false`, userID)
        if err != nil {
                return false, fmt.Errorf("store: mark first free cbt: %w", err)
        }
        return tag.RowsAffected() > 0, nil
}

// SetEmailVerification APPENDS the code to the active list (founder
// directive 2026-10-03, kept for the code era): a re-send (the resend
// button, a blocked login, a fresh signup) must never kill a code
// already sitting in a student's inbox - the column keeps a comma-
// joined list of the most recent codes (capped at 5), each stamped
// `code:expiry-epoch` with a 24-hour life, and consuming ANY unexpired
// one verifies the address. ChangeUserEmail is the one legitimate
// reset: a code mailed to the OLD address must never verify the NEW
// one. (Founder directive 2026-10-05: the confirmation token is now a
// 6-digit code, not a mailed link.)
//
// UPSERT (founder bug 2026-10-05, "the first code doesn't work, the
// second one does"): the stamp used to be a bare UPDATE, and a brand-
// new account's entitlements row did not exist yet at signup time
// (with DEVICE_LOCK off, bindDevice never ran EnsureEntitlement) - the
// UPDATE hit zero rows and the signup's OWN code was silently dropped,
// so the first mail's code verified nothing and only a resent one
// worked. The INSERT arm now creates the missing row; the conflict arm
// keeps the append behaviour for every later stamp.
func (s *Store) SetEmailVerification(ctx context.Context, userID, code string) error {
        stamped := code + ":" + fmt.Sprintf("%d", time.Now().Add(24*time.Hour).Unix())
        _, err := s.Pool.Exec(ctx, `
                INSERT INTO study.entitlements AS e (user_id, verify_token, verify_sent_at)
                VALUES ($1, $2, now())
                ON CONFLICT (user_id) DO UPDATE SET
                        verify_token = COALESCE((
                                SELECT string_agg(t, ',' ORDER BY ord)
                                FROM (
                                        SELECT t, ord
                                        FROM unnest(string_to_array(
                                                CASE WHEN e.verify_token = '' OR $2 = '' THEN $2
                                                     ELSE e.verify_token || ',' || $2 END,
                                                ',')) WITH ORDINALITY AS u(t, ord)
                                        ORDER BY ord DESC
                                        LIMIT 5
                                ) kept
                        ), EXCLUDED.verify_token),
                        verify_sent_at = CASE WHEN $2 <> '' THEN now() ELSE e.verify_sent_at END,
                        updated_at = now()`,
                userID,
                stamped)
        if err != nil {
                return fmt.Errorf("store: set email verification: %w", err)
        }
        return nil
}

// MarkEmailVerified stamps the row confirmed and clears any pending
// token in one upsert: Google signins arrive pre-verified by Google
// (the address was proven on Google's side), so the account never sees
// a confirmation mail or the unverified gate.
func (s *Store) MarkEmailVerified(ctx context.Context, userID string) error {
        _, err := s.Pool.Exec(ctx, `
                INSERT INTO study.entitlements (user_id, email_verified)
                VALUES ($1, true)
                ON CONFLICT (user_id) DO UPDATE
                SET email_verified = true, verify_token = '', updated_at = now()`, userID)
        if err != nil {
                return fmt.Errorf("store: mark email verified: %w", err)
        }
        return nil
}

// ChangeUserEmail is the wrong-email rescue: the signup address is
// OVERWRITTEN, so the mistaken address leaves the database entirely and
// the same account continues with the corrected one. Verification resets
// atomically - email_verified flips back to false and the fresh code
// REPLACES the active list (not appends: every code mailed to the old
// address must die, it must never verify the new one) so the next
// confirmation mail targets the new inbox only. The replacement code is
// stamped with the same 24-hour expiry format VerifyEmail matches
// (code:expiry-epoch) - a bare code would never verify.
// ErrUniqueEmail propagates when the new address already belongs to an
// account (the partial unique index users_email_lower_idx fires).
func (s *Store) ChangeUserEmail(ctx context.Context, userID, newEmail, code string) error {
        normalized := strings.ToLower(strings.TrimSpace(newEmail))
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return fmt.Errorf("store: change email begin: %w", err)
        }
        defer tx.Rollback(ctx)
        if _, err := tx.Exec(ctx, `
                UPDATE study.users
                SET email = $2
                WHERE id = $1`, userID, normalized); err != nil {
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation && pgErr.ConstraintName == "users_email_lower_idx" {
                        return ErrUniqueEmail
                }
                return fmt.Errorf("store: change email user: %w", err)
        }
        if _, err := tx.Exec(ctx, `
                UPDATE study.entitlements
                SET email_verified = false,
                    verify_token = $2 || ':' || extract(epoch from now() + interval '24 hours')::bigint,
                    verify_sent_at = NULL,
                    updated_at = now()
                WHERE user_id = $1`, userID, code); err != nil {
                return fmt.Errorf("store: change email entitlement: %w", err)
        }
        if err := tx.Commit(ctx); err != nil {
                return fmt.Errorf("store: change email commit: %w", err)
        }
        return nil
}

// VerifyEmail consumes a 6-digit confirmation code, marks the address
// verified and returns the owning user id; ok=false for unknown,
// expired or stale codes. The column holds a comma-joined list of
// `code:expiry-epoch` entries (see SetEmailVerification) - entering
// the code from an older mail in the same inbox verifies just the same
// as the newest, as long as it has not passed its 24-hour stamp. One
// success clears the whole list: the code works once. Legacy entries
// without the expiry stamp (the old link tokens) never match again.
func (s *Store) VerifyEmail(ctx context.Context, code string) (string, bool, error) {
        if code == "" {
                return "", false, nil
        }
        var userID string
        err := s.Pool.QueryRow(ctx, `
                UPDATE study.entitlements
                SET email_verified = true, verify_token = '', updated_at = now()
                WHERE user_id = (
                        SELECT user_id FROM study.entitlements
                        WHERE verify_token <> ''
                          AND EXISTS (
                                SELECT 1
                                FROM unnest(string_to_array(verify_token, ',')) AS entry
                                WHERE split_part(entry, ':', 1) = $1
                                  AND split_part(entry, ':', 2) <> ''
                                  AND split_part(entry, ':', 2)::double precision > extract(epoch from now())
                          )
                        LIMIT 1
                )
                RETURNING user_id`, code).Scan(&userID)
        if errors.Is(err, pgx.ErrNoRows) {
                return "", false, nil
        }
        if err != nil {
                return "", false, fmt.Errorf("store: verify email: %w", err)
        }
        return userID, true, nil
}

// EnsureReferralCode mints the user's referral code once (RNC + 8 hex).
func (s *Store) EnsureReferralCode(ctx context.Context, userID, code string) (string, error) {
        var existing string
        err := s.Pool.QueryRow(ctx, `
                SELECT referral_code FROM study.entitlements WHERE user_id = $1`, userID).Scan(&existing)
        if err != nil {
                return "", fmt.Errorf("store: referral code lookup: %w", err)
        }
        if existing != "" {
                return existing, nil
        }
        for attempt := 0; attempt < 5; attempt++ {
                candidate := code
                if attempt > 0 {
                        candidate = fmt.Sprintf("%s%d", code, attempt+1)
                }
                tag, err := s.Pool.Exec(ctx, `
                        UPDATE study.entitlements SET referral_code = $2, updated_at = now()
                        WHERE user_id = $1 AND referral_code = ''`, userID, candidate)
                if err != nil {
                        return "", fmt.Errorf("store: referral code mint: %w", err)
                }
                if tag.RowsAffected() > 0 {
                        return candidate, nil
                }
                // Collision or a concurrent mint re-reads.
                err = s.Pool.QueryRow(ctx, `
                        SELECT referral_code FROM study.entitlements WHERE user_id = $1`, userID).Scan(&existing)
                if err != nil {
                        return "", fmt.Errorf("store: referral code re-read: %w", err)
                }
                if existing != "" {
                        return existing, nil
                }
        }
        return "", fmt.Errorf("store: referral code mint: could not derive a code for %s", userID)
}

// ------------------------------------------------------------- payments

// Payment is one billing attempt (Paystack or a manual owner grant).
type Payment struct {
        ID         string    `json:"id"`
        UserID     string    `json:"userId"`
        Provider   string    `json:"provider"`
        Plan       string    `json:"plan"`
        AmountKobo int       `json:"amountKobo"`
        Currency   string    `json:"currency"`
        Reference  string    `json:"reference"`
        Status     string    `json:"status"`
        Meta       string    `json:"-"`
        CreatedAt  time.Time `json:"createdAt"`
}

// CreatePayment records a pending charge before the redirect.
func (s *Store) CreatePayment(ctx context.Context, userID, provider, plan string, amountKobo int, reference, meta string) (*Payment, error) {
        if meta == "" {
                meta = "{}"
        }
        p := &Payment{}
        err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.payments (user_id, provider, plan, amount_kobo, reference, meta)
                VALUES ($1, $2, $3, $4, $5, $6::jsonb)
                RETURNING id, user_id, provider, plan, amount_kobo, currency, reference, status, meta, created_at`,
                userID, provider, plan, amountKobo, reference, meta,
        ).Scan(&p.ID, &p.UserID, &p.Provider, &p.Plan, &p.AmountKobo, &p.Currency,
                &p.Reference, &p.Status, &p.Meta, &p.CreatedAt)
        if err != nil {
                return nil, fmt.Errorf("store: create payment: %w", err)
        }
        return p, nil
}

// SetPaymentStatus moves a payment's status; returns the payment's user
// and plan when the row flipped to success THIS call (idempotent webhook
// guard: a replayed charge.success does not re-grant).
func (s *Store) SetPaymentStatus(ctx context.Context, reference, status string) (string, string, bool, error) {
        var userID, plan string
        var meta string
        err := s.Pool.QueryRow(ctx, `
                UPDATE study.payments SET status = $2, updated_at = now()
                WHERE reference = $1 AND status <> $2
                RETURNING user_id, plan, meta`, reference, status).Scan(&userID, &plan, &meta)
        if errors.Is(err, pgx.ErrNoRows) {
                return "", "", false, nil
        }
        if err != nil {
                return "", "", false, fmt.Errorf("store: set payment status: %w", err)
        }
        return userID, plan, true, nil
}

// UserByReferralCode resolves a referral code to its owner (nil when the
// code is empty or unknown).
func (s *Store) UserByReferralCode(ctx context.Context, code string) (*User, error) {
        code = strings.TrimSpace(code)
        if code == "" {
                return nil, nil
        }
        var userID string
        err := s.Pool.QueryRow(ctx, `
                SELECT user_id FROM study.entitlements WHERE referral_code = $1`, code).Scan(&userID)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: user by referral code: %w", err)
        }
        return s.UserByID(ctx, userID)
}

// SetReferredBy stamps who brought this account in (once, immutable).
func (s *Store) SetReferredBy(ctx context.Context, userID, referrerID string) error {
        _, err := s.Pool.Exec(ctx, `
                UPDATE study.entitlements SET referred_by = $2, updated_at = now()
                WHERE user_id = $1 AND referred_by IS NULL`, userID, referrerID)
        if err != nil {
                return fmt.Errorf("store: set referred by: %w", err)
        }
        return nil
}

// SaveAnswers persists a capped sitting's picks WITHOUT flipping the
// attempt out of in_progress: the free-tier cap saves the answers so
// the student continues exactly where they stopped after subscribing.
// The full submit later re-upserts the same rows (idempotent keys).
func (s *Store) SaveAnswers(ctx context.Context, attemptID, userID string, answers []Picked) error {
        var status string
        err := s.Pool.QueryRow(ctx, `
                SELECT status FROM study.attempts WHERE id = $1 AND user_id = $2`,
                attemptID, userID).Scan(&status)
        if errors.Is(err, pgx.ErrNoRows) {
                return fmt.Errorf("store: save answers: no attempt %s", attemptID)
        }
        if err != nil {
                return fmt.Errorf("store: save answers lookup: %w", err)
        }
        if status != "in_progress" {
                return nil
        }
        b := &pgx.Batch{}
        for _, a := range answers {
                b.Queue(`
                        INSERT INTO study.attempt_answers (attempt_id, question_id, selected)
                        VALUES ($1, $2, $3)
                        ON CONFLICT (attempt_id, question_id) DO UPDATE SET selected = EXCLUDED.selected`,
                        attemptID, a.QuestionID, a.Selected)
        }
        br := s.Pool.SendBatch(ctx, b)
        defer br.Close()
        for range answers {
                if _, err := br.Exec(); err != nil {
                        return fmt.Errorf("store: save answer: %w", err)
                }
        }
        return nil
}
