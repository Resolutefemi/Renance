package httpapi

import (
	"net/http"
)

// handleSyncStatus powers the dashboard's silent-asset-sync strip.
func (s *Server) handleSyncStatus(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	job, err := s.store.LatestSyncJob(r.Context(), uid)
	if err != nil {
		s.log.Error("sync status failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load sync status")
		return
	}
	if job == nil {
		writeJSON(w, http.StatusOK, map[string]any{"job": nil})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"job": job})
}
