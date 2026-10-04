package store

import (
        "context"
        "crypto/sha256"
        "encoding/hex"
        "errors"
        "time"

        "github.com/jackc/pgx/v5"
)

// Password reset (founder directive 2026-10-02): a single-use, 30-minute
// token per account. Only the SHA-256 hex of the token is stored, so a
// database leak cannot be replayed against /auth/reset-password.

// ErrResetInvalid covers an unknown, already-used or expired token; the
// handler answers the same message for all three so the response cannot
// be mined for live tokens.
var ErrResetInvalid = errors.New("store: reset token is invalid or expired")

// CreatePasswordReset retires any live token for the account and stores
// a fresh one (hash + expiry). One live token per account keeps the
// flow honest: a second request always supersedes the first.
func (s *Store) CreatePasswordReset(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return err
        }
        defer tx.Rollback(ctx)
        if _, err := tx.Exec(ctx,
                `UPDATE study.password_resets SET used_at = now()
                 WHERE user_id = $1 AND used_at IS NULL`, userID); err != nil {
                return err
        }
        if _, err := tx.Exec(ctx,
                `INSERT INTO study.password_resets (user_id, token_hash, expires_at)
                 VALUES ($1, $2, $3)`, userID, tokenHash, expiresAt); err != nil {
                return err
        }
        return tx.Commit(ctx)
}

// LatestPasswordResetAt reports when the account's newest reset row was
// created (zero time when the account never requested one). The duplicate-
// mail guard reads it: inside the cooldown window the forgot-password
// handler answers the uniform sent:true WITHOUT mailing a second copy of
// the same link (founder directive 2026-10-04 - the inbox was filling
// with identical reset mails, one per retried submit or extra tab).
func (s *Store) LatestPasswordResetAt(ctx context.Context, userID string) (time.Time, error) {
        var at time.Time
        err := s.Pool.QueryRow(ctx,
                `SELECT created_at FROM study.password_resets
                 WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
                userID).Scan(&at)
        if errors.Is(err, pgx.ErrNoRows) {
                return time.Time{}, nil
        }
        if err != nil {
                return time.Time{}, err
        }
        return at, nil
}

// CountPasswordResetsSince counts the account's reset rows created after
// the given instant. The forgot-password daily cap reads it (quota armor,
// founder directive 2026-10-04): at most maxResetMailsPerDay fresh links
// are mailed to one inbox per rolling 24 hours, no matter how often a
// bot re-fires the endpoint past the cooldown.
func (s *Store) CountPasswordResetsSince(ctx context.Context, userID string, since time.Time) (int, error) {
        var n int
        err := s.Pool.QueryRow(ctx,
                `SELECT count(*) FROM study.password_resets
                 WHERE user_id = $1 AND created_at > $2`,
                userID, since).Scan(&n)
        if err != nil {
                return 0, err
        }
        return n, nil
}

// ConsumePasswordReset validates the token (not used, not expired) and
// burns it in the same breath, returning the account it belongs to.
func (s *Store) ConsumePasswordReset(ctx context.Context, tokenHash string) (string, error) {
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return "", err
        }
        defer tx.Rollback(ctx)
        var userID string
        err = tx.QueryRow(ctx,
                `SELECT user_id FROM study.password_resets
                 WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()`,
                tokenHash).Scan(&userID)
        if errors.Is(err, pgx.ErrNoRows) {
                return "", ErrResetInvalid
        }
        if err != nil {
                return "", err
        }
        if _, err := tx.Exec(ctx,
                `UPDATE study.password_resets SET used_at = now() WHERE token_hash = $1`,
                tokenHash); err != nil {
                return "", err
        }
        if err := tx.Commit(ctx); err != nil {
                return "", err
        }
        return userID, nil
}

// UpdatePasswordHash overwrites the credential after a successful reset.
func (s *Store) UpdatePasswordHash(ctx context.Context, userID, passwordHash string) error {
        _, err := s.Pool.Exec(ctx,
                `UPDATE study.users SET password_hash = $2 WHERE id = $1`, userID, passwordHash)
        if err != nil {
                return err
        }
        return nil
}

// HashResetToken is the storage form of a reset token.
func HashResetToken(token string) string {
        sum := sha256.Sum256([]byte(token))
        return hex.EncodeToString(sum[:])
}
