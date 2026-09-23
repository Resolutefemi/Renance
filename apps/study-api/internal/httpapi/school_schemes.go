// Scheme-seed HTTP surface: one management action drafts the NERDC
// week-by-week scheme of work into every class+subject+term whose
// scheme is still empty for the session.

package httpapi

import (
	"net/http"
	"strings"
)

// POST /school/seed-schemes?schoolId= - management pours the drafts.
func (s *Server) handleSchoolSeedSchemes(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		Session string `json:"session"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Session = strings.TrimSpace(req.Session)
	if req.Session == "" {
		fail(w, http.StatusBadRequest, "missing_params", "session is required")
		return
	}
	filled, err := s.store.SeedSchemes(r.Context(), m.SchoolID, req.Session)
	if err != nil {
		s.log.Error("seed schemes", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not draft the schemes")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"filled": filled})
}
