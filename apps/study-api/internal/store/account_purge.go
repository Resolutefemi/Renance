package store

import (
        "context"
)

// PurgeUser deletes the account row and every remaining row that
// references it (founder directive 2026-10-05): one SQL function call,
// one transaction, nothing left behind - profiles, attempts, results,
// sessions, streaks, awards, daily results, arena seats, school
// memberships, entitlements, payments, AI chats/memories/artifacts and
// password resets all go with the account.
func (s *Store) PurgeUser(ctx context.Context, userID string) error {
        _, err := s.Pool.Exec(ctx, `SELECT study.purge_user($1)`, userID)
        return err
}

// PurgeDeletedUsers sweeps rows whose owner no longer exists in
// study.users - leftovers from accounts deleted by hand in the Neon
// editor (study.users or public.users) before the purge function
// existed. Wired to also run once per boot via migration 0027.
func (s *Store) PurgeDeletedUsers(ctx context.Context) error {
        _, err := s.Pool.Exec(ctx, `SELECT study.purge_deleted_users()`)
        return err
}
