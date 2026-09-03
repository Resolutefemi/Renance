package httpapi

import (
	"net/http"
	"time"

	"renance.dev/study-api/internal/store"
)

// handleListAttempts serves GET /me/attempts — the student's paper
// history (newest first). It feeds the launcher's recent-activity card,
// the review tab, and every "syllabus completion"-style metric the UI
// derives from real graded work instead of invented numbers.
func (s *Server) handleListAttempts(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	rows, err := s.store.AttemptsByUser(r.Context(), uid, 50)
	if err != nil {
		s.log.Error("attempts list failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load attempt history")
		return
	}
	if rows == nil {
		rows = []*store.AttemptRow{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"attempts": rows})
}

// reviewQuestion is one row of a post-grade answer review: the full
// question, the pick, the sealed-now-opened correct letter, and the
// explanation that was stored with the key.
type reviewQuestion struct {
	QuestionID  string            `json:"questionId"`
	Stem        string            `json:"stem"`
	Topic       string            `json:"topic,omitempty"`
	Options     map[string]string `json:"options,omitempty"`
	Selected    string            `json:"selected,omitempty"`
	Correct     string            `json:"correct"`
	Explanation string            `json:"explanation,omitempty"`
	Correctly   bool              `json:"correctly"`
}

// handleAttemptReview serves GET /attempts/{id}/review — per-question
// detail for a GRADED attempt owned by the requester. Before grading this
// is a 409: answer material never leaves while a paper is still open
// (ADR-0003 doctrine, review edition).
func (s *Server) handleAttemptReview(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	attemptID := r.PathValue("id")
	attempt, err := s.store.AttemptByID(r.Context(), attemptID, uid)
	if err != nil {
		s.log.Error("attempt lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load attempt")
		return
	}
	if attempt == nil || attempt.UserID != uid {
		fail(w, http.StatusNotFound, "unknown_attempt", "no such attempt")
		return
	}
	if attempt.Status != "graded" {
		fail(w, http.StatusConflict, "not_graded",
			"answers unlock after the attempt is graded (current: "+attempt.Status+")")
		return
	}
	bundle, ok := s.lib.Bundle(attempt.Code)
	if !ok {
		fail(w, http.StatusInternalServerError, "internal", "pack no longer available")
		return
	}
	keys, err := s.store.KeysForBank(r.Context(), attempt.Code)
	if err != nil {
		s.log.Error("key lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load answer key")
		return
	}
	picks, err := s.store.AnswersForAttempt(r.Context(), attempt.ID)
	if err != nil {
		s.log.Error("answers lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load answers")
		return
	}
	chosen := make(map[string]string, len(picks))
	for _, p := range picks {
		chosen[p.QuestionID] = p.Selected
	}

	questions := make([]reviewQuestion, 0, len(bundle.Questions))
	for _, q := range bundle.Questions {
		key, keyed := keys[q.ID]
		if !keyed {
			continue // text-typed or unkeyed question: nothing to review
		}
		rq := reviewQuestion{
			QuestionID:  q.ID,
			Stem:        q.Stem,
			Topic:       q.Topic,
			Options:     q.Options,
			Selected:    chosen[q.ID],
			Correct:     key.Letter,
			Explanation: key.Explanation,
		}
		rq.Correctly = rq.Selected == key.Letter
		questions = append(questions, rq)
	}

	result, err := s.store.ResultByAttempt(r.Context(), attempt.ID)
	if err != nil {
		s.log.Error("result lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load result")
		return
	}

	resp := map[string]any{
		"attemptId": attempt.ID,
		"code":      attempt.Code,
		"title":     bundle.Title,
		"questions": questions,
	}
	if attempt.SubmittedAt != nil {
		resp["submittedAt"] = attempt.SubmittedAt.UTC().Format(time.RFC3339Nano)
	}
	if result != nil {
		resp["score"] = result.Score
		resp["total"] = result.Total
	}
	writeJSON(w, http.StatusOK, resp)
}
