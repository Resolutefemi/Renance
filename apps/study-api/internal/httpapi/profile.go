package httpapi

import (
	"net/http"
	"strings"

	"renance.dev/study-api/internal/store"
)

type profileRequest struct {
	FullName    string   `json:"fullName"`
	Institution string   `json:"institution"`
	GradeLevel  string   `json:"gradeLevel"`
	Exams       []string `json:"exams"`
}

// handleUpdateProfile is the contextual profile modal target: full name,
// target institution, grade level, active examinations. Completion kicks
// the silent background asset sync.
func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req profileRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.FullName = strings.TrimSpace(req.FullName)
	req.Institution = strings.TrimSpace(req.Institution)
	req.GradeLevel = strings.TrimSpace(req.GradeLevel)

	if len(req.FullName) < 2 || len(req.FullName) > 120 {
		fail(w, http.StatusBadRequest, "invalid_fullName", "full name must be 2-120 characters")
		return
	}
	if len(req.Institution) < 2 || len(req.Institution) > 160 {
		fail(w, http.StatusBadRequest, "invalid_institution", "institution must be 2-160 characters")
		return
	}
	if len(req.GradeLevel) > 60 {
		fail(w, http.StatusBadRequest, "invalid_gradeLevel", "grade level must be at most 60 characters")
		return
	}
	if len(req.Exams) == 0 || len(req.Exams) > 4 {
		fail(w, http.StatusBadRequest, "invalid_exams", "select between 1 and 4 active examinations")
		return
	}
	seen := map[string]struct{}{}
	for _, e := range req.Exams {
		if _, dup := seen[e]; dup {
			fail(w, http.StatusBadRequest, "invalid_exams", "duplicate examination: "+e)
			return
		}
		seen[e] = struct{}{}
		if _, ok := s.allowed[e]; !ok {
			fail(w, http.StatusBadRequest, "invalid_exams",
				"examinations must be chosen from: JAMB, WAEC, NECO, University Modules")
			return
		}
	}

	profile, err := s.store.UpsertProfile(r.Context(), uid, &store.Profile{
		FullName:    req.FullName,
		Institution: req.Institution,
		GradeLevel:  req.GradeLevel,
		Exams:       req.Exams,
		Completed:   true,
	})
	if err != nil {
		s.log.Error("profile upsert failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save profile")
		return
	}

	// Silent background asset sync starts the moment preferences land.
	s.syncer.Kick(uid)

	writeJSON(w, http.StatusOK, map[string]any{
		"profile": profile,
		"sync":    "kicked",
	})
}
