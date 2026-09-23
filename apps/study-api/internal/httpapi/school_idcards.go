// ID card HTTP surface: issue, list, revoke. Management only. The
// printable card sheet lives in the web app; this is the ledger.

package httpapi

import (
	"net/http"
	"strings"
)

// GET /school/id-cards?schoolId=&classId=&session= - the issued cards
// joined to their students, ready for the card sheet.
func (s *Server) handleSchoolIDCards(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	q := r.URL.Query()
	classID := strings.TrimSpace(q.Get("classId"))
	session := strings.TrimSpace(q.Get("session"))
	cards, err := s.store.ListIDCards(r.Context(), m.SchoolID, classID, session)
	if err != nil {
		s.log.Error("list id cards", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the cards")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"cards": cards})
}

// POST /school/id-card?schoolId - issue (or re-issue) one card. The
// store is idempotent per student per session, so tapping the button
// twice never mints a second serial.
func (s *Server) handleSchoolIssueCard(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		StudentID string `json:"studentId"`
		Session   string `json:"session"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	req.StudentID = strings.TrimSpace(req.StudentID)
	req.Session = strings.TrimSpace(req.Session)
	if req.StudentID == "" || req.Session == "" {
		fail(w, http.StatusBadRequest, "missing_params", "studentId and session are required")
		return
	}
	card, err := s.store.IssueIDCard(r.Context(), m.SchoolID, req.StudentID, req.Session, m.UserID)
	if err != nil {
		s.log.Error("issue id card", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not issue the card")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"card": card})
}

// POST /school/id-cards?schoolId= - batch issue: every active student
// in scope who lacks a card for the session gets one. Existing cards
// stay; the count says how many gaps were filled.
func (s *Server) handleSchoolIssueCardsBatch(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		ClassID string `json:"classId"`
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
	issued, err := s.store.IssueIDCardsBatch(r.Context(), m.SchoolID, strings.TrimSpace(req.ClassID), req.Session, m.UserID)
	if err != nil {
		s.log.Error("batch issue cards", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not issue every card")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"issued": issued})
}

// PUT /school/id-card?schoolId - management flips a card's status
// (issued / revoked) when a card is lost or found again.
func (s *Server) handleSchoolCardStatus(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		CardID string `json:"cardId"`
		Status string `json:"status"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	status := strings.ToLower(strings.TrimSpace(req.Status))
	if status != "issued" && status != "revoked" {
		fail(w, http.StatusBadRequest, "invalid_status", "status must be issued or revoked")
		return
	}
	if err := s.store.SetCardStatus(r.Context(), m.SchoolID, strings.TrimSpace(req.CardID), status); err != nil {
		s.log.Error("set card status", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not update the card")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}
