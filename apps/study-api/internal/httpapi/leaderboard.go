package httpapi

import (
	"net/http"

	"renance.dev/study-api/internal/store"
)

// Leaderboards (ROADMAP #14 slice): public standings over data the
// product already records — arena outcomes and study XP. Both routes are
// auth-gated like the rest of the student surface; the caller's own row
// rides along as "me" even when it sits outside the top 25, so a student
// always learns exactly where they stand.

// boardPeriod validates the ?period= query for the arena board. Empty
// means the default (week); anything unknown is a 400, never a silent
// fallback, so client bugs surface instead of showing the wrong board.
func boardPeriod(raw string) (string, bool) {
	switch raw {
	case "", "week":
		return "week", true
	case "all":
		return "all", true
	default:
		return "", false
	}
}

// handleArenaLeaderboard serves GET /leaderboard/arena?period=week|all.
func (s *Server) handleArenaLeaderboard(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	period, ok := boardPeriod(r.URL.Query().Get("period"))
	if !ok {
		fail(w, http.StatusBadRequest, "bad_period", "period must be week or all")
		return
	}
	entries, err := s.store.ArenaLeaderboard(r.Context(), period, 25)
	if err != nil {
		s.log.Error("arena leaderboard", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load arena leaderboard")
		return
	}
	// The caller may never have queued for the arena yet — that keeps
	// "me" null instead of inventing a rank they have not earned.
	var me *store.ArenaBoardEntry
	if row, found, err := s.store.ArenaRank(r.Context(), uid, period); err != nil {
		s.log.Error("arena rank", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load arena leaderboard")
		return
	} else if found {
		me = &row
	}
	for i := range entries {
		entries[i].Rank = i + 1
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"board":   "arena",
		"period":  period,
		"me":      me,
		"entries": entries,
	})
}

// handleStudyLeaderboard serves GET /leaderboard/xp (all-time XP board).
func (s *Server) handleStudyLeaderboard(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	entries, err := s.store.StudyLeaderboard(r.Context(), 25)
	if err != nil {
		s.log.Error("study leaderboard", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
		return
	}
	var me *store.StudyBoardEntry
	if row, found, err := s.store.StudyRank(r.Context(), uid); err != nil {
		s.log.Error("study rank", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
		return
	} else if found {
		me = &row
	}
	for i := range entries {
		entries[i].Rank = i + 1
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"board":   "xp",
		"period":  "all",
		"me":      me,
		"entries": entries,
	})
}
