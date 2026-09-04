// Tutor endpoints (ROADMAP #9).
//
// GET  /tutor/status          — {aiEnabled} so clients badge the mode
// POST /attempts/{id}/tutor   — Socratic chat anchored to one graded
//
//	attempt + question (AI mode when a
//	provider key is configured, deterministic
//	hint mode otherwise)
//
// Anchoring doctrine: the attempt must exist, belong to the caller and be
// GRADED before any tutor traffic — the coach is post-review by design,
// exactly like the answer-review endpoint.
package httpapi

import (
	"net/http"
	"strings"

	"renance.dev/study-api/internal/tutor"
)

type tutorMsg struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type tutorRequest struct {
	QuestionID string     `json:"questionId"`
	Messages   []tutorMsg `json:"messages"`
}

func (s *Server) handleTutorStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"aiEnabled": s.tutor != nil && s.tutor.Provider != nil})
}

func (s *Server) handleAttemptTutor(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	if !s.limiter.allow("tutor:user:" + uid) {
		w.Header().Set("Retry-After", "15")
		fail(w, http.StatusTooManyRequests, "rate_limited", "tutor cooling down — retry in a few seconds")
		return
	}

	var req tutorRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.QuestionID = strings.TrimSpace(req.QuestionID)
	if req.QuestionID == "" {
		fail(w, http.StatusBadRequest, "invalid_question", "questionId is required")
		return
	}
	if len(req.Messages) == 0 || len(req.Messages) > 20 {
		fail(w, http.StatusBadRequest, "invalid_messages", "messages must hold 1..20 turns")
		return
	}
	msgs := make([]tutor.Message, 0, len(req.Messages))
	hasUser := false
	for _, m := range req.Messages {
		switch m.Role {
		case "user":
			hasUser = true
		case "assistant":
		default:
			fail(w, http.StatusBadRequest, "invalid_messages", "message role must be user or assistant")
			return
		}
		content := strings.TrimSpace(m.Content)
		if content == "" || len(content) > 1000 {
			fail(w, http.StatusBadRequest, "invalid_messages", "message content must be 1..1000 chars")
			return
		}
		msgs = append(msgs, tutor.Message{Role: m.Role, Content: content})
	}
	if !hasUser {
		fail(w, http.StatusBadRequest, "invalid_messages", "conversation needs at least one student turn")
		return
	}

	attemptID := r.PathValue("id")
	attempt, err := s.store.AttemptByID(r.Context(), attemptID, uid)
	if err != nil {
		s.log.Error("tutor attempt lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load attempt")
		return
	}
	if attempt == nil || attempt.UserID != uid {
		fail(w, http.StatusNotFound, "unknown_attempt", "no such attempt")
		return
	}
	if attempt.Status != "graded" {
		fail(w, http.StatusConflict, "not_graded",
			"the tutor unlocks after the attempt is graded (current: "+attempt.Status+")")
		return
	}
	bundle, ok := s.lib.Bundle(attempt.Code)
	if !ok {
		fail(w, http.StatusInternalServerError, "internal", "pack no longer available")
		return
	}
	q, ok := bundle.Question(req.QuestionID)
	if !ok {
		fail(w, http.StatusNotFound, "unknown_question", "no such question in this pack")
		return
	}
	keys, err := s.store.KeysForBank(r.Context(), attempt.Code)
	if err != nil {
		s.log.Error("tutor key lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load answer key")
		return
	}
	key, keyed := keys[q.ID]
	if !keyed {
		fail(w, http.StatusNotFound, "unkeyed_question", "this question has no answer key to discuss")
		return
	}
	picks, err := s.store.AnswersForAttempt(r.Context(), attempt.ID)
	if err != nil {
		s.log.Error("tutor answers lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load answers")
		return
	}
	picked := ""
	for _, p := range picks {
		if p.QuestionID == q.ID {
			picked = p.Selected
			break
		}
	}

	ac := tutor.AttemptContext{
		ExamTitle:   bundle.Title,
		Code:        bundle.Code,
		QuestionID:  q.ID,
		Stem:        q.Stem,
		Topic:       q.Topic,
		Options:     q.Options,
		Picked:      picked,
		Correct:     key.Letter,
		Explanation: key.Explanation,
	}
	reply := s.tutor.Reply(r.Context(), ac, msgs)
	writeJSON(w, http.StatusOK, map[string]any{"reply": reply.Text, "mode": reply.Mode})
}
