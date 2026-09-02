package httpapi

import (
	"context"
	"net/http"
	"time"
)

// handleHealth is the boot probe used by scripts, CI E2E and the Render
// health check. It PINGS Postgres so a broken DATABASE_URL (bad Neon URI,
// wrong password) fails the deploy loudly at boot instead of shipping an
// auth-dead API that "can't create accounts".
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	if err := s.store.Pool.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"status":  "degraded",
			"service": "renance-study-api",
			"db":      "unreachable: " + truncateErr(err),
			"time":    time.Now().UTC().Format(time.RFC3339),
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "renance-study-api",
		"db":      "ok",
		"time":    time.Now().UTC().Format(time.RFC3339),
	})
}
