package httpapi

import (
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5"

	"renance.dev/study-api/internal/store"
)

// handleGamification serves GET /me/gamification: the caller's streak/XP
// state plus the full badge ledger. A scholar with no graded attempts yet
// has no streaks row, they get a zero state (level 1), never a 404, so
// the mobile hub screen can render on first launch.
func (s *Server) handleGamification(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	state, awards, err := s.store.GamificationByUser(r.Context(), uid)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		s.log.Error("gamification load failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load gamification")
		return
	}
	if errors.Is(err, pgx.ErrNoRows) {
		state = &store.StreakState{Level: 1}
		awards = nil
	}
	if awards == nil {
		awards = []store.Award{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"state":  state,
		"awards": awards,
	})
}
