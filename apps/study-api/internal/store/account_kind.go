package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

// Account kinds (founder directive 2026-10-02): school workplace
// accounts (management + teachers) and student accounts are separate.
// The kind is stamped at creation - /school/auth/register and teacher
// creation write 'school', every student signup defaults to 'student' -
// and the login endpoint reads it to enforce the audience split.

const (
	AccountKindStudent = "student"
	AccountKindSchool  = "school"
)

// AccountKindOf returns 'student' or 'school' ('' when the user is
// unknown). Kept out of the User struct on purpose: only the
// audience-checked login path needs it, one cheap point-read.
func (s *Store) AccountKindOf(ctx context.Context, userID string) (string, error) {
	var kind string
	err := s.Pool.QueryRow(ctx,
		`SELECT account_kind FROM study.users WHERE id = $1`, userID).Scan(&kind)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return kind, nil
}

// SetAccountKind stamps an account as 'student' or 'school'.
func (s *Store) SetAccountKind(ctx context.Context, userID, kind string) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE study.users SET account_kind = $2 WHERE id = $1`, userID, kind)
	if err != nil {
		return err
	}
	return nil
}
