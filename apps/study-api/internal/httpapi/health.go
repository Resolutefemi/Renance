package httpapi

import (
	"net/http"
	"time"
)

// handleHealth is the boot probe used by scripts, E2E and (later) the
// Play Store infra checks.
func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "renance-study-api",
		"time":    time.Now().UTC().Format(time.RFC3339),
	})
}
