// Timetable HTTP surface: read one class's week, save the whole grid.
// Management owns the edit; teachers read their class's week.

package httpapi

import (
	"net/http"
	"strings"

	"renance.dev/study-api/internal/store"
)

// GET /school/timetable?schoolId=&classId= - the week's slots plus the
// subject list the slot picker offers.
func (s *Server) handleSchoolTimetable(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	classID := strings.TrimSpace(r.URL.Query().Get("classId"))
	if classID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "classId is required")
		return
	}
	week, err := s.store.Timetable(r.Context(), m.SchoolID, classID)
	if err != nil {
		s.log.Error("load timetable", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the timetable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"timetable": week})
}

// POST /school/timetable?schoolId= - replace one class's week with the
// posted grid. The store does the delete + insert in one transaction.
func (s *Server) handleSchoolSaveTimetable(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		ClassID string                `json:"classId"`
		Slots   []store.TimetableSlot `json:"slots"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	req.ClassID = strings.TrimSpace(req.ClassID)
	if req.ClassID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "classId is required")
		return
	}
	// Normalise the grid: trim times, drop empty labels on subject
	// slots, cap the noise.
	cleaned := make([]store.TimetableSlot, 0, len(req.Slots))
	for _, t := range req.Slots {
		t.StartTime = strings.TrimSpace(t.StartTime)
		t.EndTime = strings.TrimSpace(t.EndTime)
		t.Label = strings.TrimSpace(t.Label)
		t.SubjectID = strings.TrimSpace(t.SubjectID)
		cleaned = append(cleaned, t)
	}
	saved, err := s.store.SaveTimetable(r.Context(), m.SchoolID, req.ClassID, cleaned)
	if err != nil {
		s.log.Error("save timetable", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save the timetable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"saved": saved})
}
