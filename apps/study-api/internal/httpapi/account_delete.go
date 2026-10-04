package httpapi

import (
        "net/http"
        "time"
)

// handleDeleteAccount wipes the signed-in account and EVERY piece of
// data attached to it (founder directive 2026-10-05): the profile, exam
// attempts and answers, results, sessions, streaks, awards, review
// queue, daily results, arena games, school memberships, entitlements
// and payments, AI chats/memories/artifacts and password resets. The
// purge runs inside study.purge_user() in one transaction - the users
// row goes last, so a crash can never leave half an account behind.
// The client clears the local session right after 204; any still-live
// JWT keeps failing lookups because the user row is gone.
func (s *Server) handleDeleteAccount(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if err := s.store.PurgeUser(r.Context(), uid); err != nil {
                s.log.Error("account purge failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not delete the account, try again")
                return
        }
        s.log.Info("account deleted with all its data", "at", time.Now().UTC().Format(time.RFC3339))
        w.WriteHeader(http.StatusNoContent)
}
