// Package store: entitlements - the premium subscription ledger. One row
// per user, readable from the Neon console: the owner grants premium by
// flipping premium_role to true and setting premium_type + premium_type's
// expiry. Everything the paywall, the blue tick, the REN wallet and the
// device lock read flows through here.
package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
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
// first touch) and returns the current state.
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
	return e, nil
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
// is rejected with ErrDeviceTaken; rebinding the same user is a no-op.
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

// SetEmailVerification stamps the token + send time (empty token clears).
func (s *Store) SetEmailVerification(ctx context.Context, userID, token string) error {
	_, err := s.Pool.Exec(ctx, `
		UPDATE study.entitlements
		SET verify_token = $2,
		    verify_sent_at = CASE WHEN $2 <> '' THEN now() ELSE verify_sent_at END,
		    updated_at = now()
		WHERE user_id = $1`, userID, token)
	if err != nil {
		return fmt.Errorf("store: set email verification: %w", err)
	}
	return nil
}

// VerifyEmail consumes a verification token, marks the address verified
// and returns the owning user id; ok=false for unknown/stale tokens.
func (s *Store) VerifyEmail(ctx context.Context, token string) (string, bool, error) {
	if token == "" {
		return "", false, nil
	}
	var userID string
	err := s.Pool.QueryRow(ctx, `
		UPDATE study.entitlements
		SET email_verified = true, verify_token = '', updated_at = now()
		WHERE verify_token = $1
		RETURNING user_id`, token).Scan(&userID)
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

// CreditReferral pays the referrer's 3 REN once per referred signup.
func (s *Store) CreditReferral(ctx context.Context, referrerUserID string) error {
	return s.AddCoins(ctx, referrerUserID, 3)
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
