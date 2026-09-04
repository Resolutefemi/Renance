package httpapi

import (
	"crypto/subtle"
	"net/http"
	"time"
)

// handleReviewQueue serves GET /me/review: the caller's spaced-repetition
// queue split into due-today vs upcoming, plus the stats the hero cards
// and badges read. A scholar with no graded topics yet has no rows, they
// get an empty queue, never a 404, so first launch renders cleanly.
func (s *Server) handleReviewQueue(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	sum, err := s.store.ReviewByUser(r.Context(), uid)
	if err != nil {
		s.log.Error("review load failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load review queue")
		return
	}
	writeJSON(w, http.StatusOK, sum)
}

// handleReviewTick serves GET /internal/review/tick, the nightly-friendly
// maintenance probe. DISABLED (404) unless ADMIN_TOKEN is configured; with
// it set, callers must echo the token in the X-Admin-Token header. It is
// read-only and idempotent: queue-wide counters plus a server timestamp,
// safe to point a Render cron at (which doubles as a keep-warm ping).
func (s *Server) handleReviewTick(w http.ResponseWriter, r *http.Request) {
	if s.cfg.AdminToken == "" {
		fail(w, http.StatusNotFound, "not_found", "unknown route")
		return
	}
	got := r.Header.Get("X-Admin-Token")
	if subtle.ConstantTimeCompare([]byte(got), []byte(s.cfg.AdminToken)) != 1 {
		fail(w, http.StatusUnauthorized, "unauthorized", "bad admin token")
		return
	}
	h, err := s.store.ReviewHealth(r.Context())
	if err != nil {
		s.log.Error("review tick failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not tally the review queue")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":     true,
		"at":     time.Now().UTC().Format(time.RFC3339),
		"review": h,
	})
}
