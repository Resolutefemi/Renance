package httpapi

import (
	"context"
	"net/http"
	"time"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/grading"
	"renance.dev/study-api/internal/store"
)

type createAttemptRequest struct {
	Code     string `json:"code"`
	Adaptive bool   `json:"adaptive,omitempty"`
}

func (s *Server) handleCreateAttempt(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req createAttemptRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	bundle, ok := s.lib.Bundle(req.Code)
	if !ok {
		fail(w, http.StatusNotFound, "unknown_pack", "no study pack with code "+req.Code)
		return
	}
	// Adaptive ordering (ROADMAP #5): rank the pack's topics by the
	// student's own SM-2 weakness (review_queue) and persist the walk.
	var order []string
	if req.Adaptive {
		order = s.adaptiveOrder(r.Context(), uid, bundle)
	}
	attempt, err := s.store.CreateAttempt(r.Context(), uid, req.Code, order, req.Adaptive)
	if err != nil {
		s.log.Error("create attempt failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not start attempt")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"attemptId":       attempt.ID,
		"code":            attempt.Code,
		"status":          attempt.Status,
		"startedAt":       attempt.StartedAt.UTC().Format(time.RFC3339Nano),
		"durationMinutes": bundle.DurationMinutes,
		"questionCount":   bundle.QuestionCount,
		"adaptive":        req.Adaptive,
		"order":           order,
	})
}

// adaptiveOrder computes the weak-topic-first question sequence for a
// bundle from the user's review state. A state-load failure degrades
// gracefully to unseen-first ordering: adaptive is an enhancement,
// never a hard gate on starting a paper.
func (s *Server) adaptiveOrder(ctx context.Context, uid string, bundle *cbtdata.Bundle) []string {
	topics := make([]string, 0, len(bundle.Questions))
	seen := map[string]struct{}{}
	for _, q := range bundle.Questions {
		t := q.Topic
		if t == "" {
			t = "General"
		}
		if _, dup := seen[t]; dup {
			continue
		}
		seen[t] = struct{}{}
		topics = append(topics, t)
	}
	state, err := s.store.ReviewStates(ctx, uid, topics)
	if err != nil {
		s.log.Error("adaptive: review state", "err", err)
		state = map[string]store.TopicState{}
	}
	items := make([]store.OrderItem, len(bundle.Questions))
	for i, q := range bundle.Questions {
		items[i] = store.OrderItem{QuestionID: q.ID, Topic: q.Topic, Difficulty: q.Difficulty}
	}
	return store.AdaptiveOrder(items, state, time.Now().UTC().Truncate(24*time.Hour))
}

type submitRequest struct {
	Answers []struct {
		QuestionID string `json:"questionId"`
		Selected   string `json:"selected"`
	} `json:"answers"`
	DurationMs *int64 `json:"durationMs,omitempty"`
}

// handleSubmitAttempt flips the attempt to grading, persists picks and
// hands the job to the goroutine engine (202 Accepted → client polls).
func (s *Server) handleSubmitAttempt(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	attemptID := r.PathValue("id")
	attempt, err := s.store.AttemptByID(r.Context(), attemptID, uid)
	if err != nil {
		s.log.Error("attempt lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not submit")
		return
	}
	if attempt == nil || attempt.UserID != uid {
		fail(w, http.StatusNotFound, "unknown_attempt", "no such attempt")
		return
	}
	if attempt.Status != "in_progress" {
		fail(w, http.StatusConflict, "already_submitted",
			"attempt is "+attempt.Status+" and cannot be resubmitted")
		return
	}
	bundle, ok := s.lib.Bundle(attempt.Code)
	if !ok {
		fail(w, http.StatusInternalServerError, "internal", "pack vanished mid-attempt")
		return
	}

	var req submitRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.Answers) > bundle.QuestionCount {
		fail(w, http.StatusBadRequest, "too_many_answers",
			"submitted more answers than questions in the pack")
		return
	}
	picks := make([]store.Picked, 0, len(req.Answers))
	seen := map[string]struct{}{}
	for _, a := range req.Answers {
		if _, dup := seen[a.QuestionID]; dup {
			fail(w, http.StatusBadRequest, "duplicate_answer", "duplicate answer for "+a.QuestionID)
			return
		}
		seen[a.QuestionID] = struct{}{}
		q, ok := bundle.Question(a.QuestionID)
		if !ok {
			fail(w, http.StatusBadRequest, "unknown_question",
				"question "+a.QuestionID+" is not part of this pack")
			return
		}
		if _, valid := q.Options[a.Selected]; !valid {
			fail(w, http.StatusBadRequest, "invalid_choice",
				"selection for "+a.QuestionID+" is not one of the options")
			return
		}
		picks = append(picks, store.Picked{QuestionID: a.QuestionID, Selected: a.Selected})
	}
	var durationMs *int
	if req.DurationMs != nil && *req.DurationMs >= 0 && *req.DurationMs <= 24*60*60*1000 {
		d := int(*req.DurationMs)
		durationMs = &d
	}

	ok2, err := s.store.SubmitAttempt(r.Context(), attemptID, uid, picks, durationMs)
	if err != nil {
		s.log.Error("submit failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not submit")
		return
	}
	if !ok2 {
		fail(w, http.StatusConflict, "already_submitted", "attempt is no longer open")
		return
	}

	if !s.engine.Enqueue(grading.Job{AttemptID: attemptID, UserID: uid, Code: attempt.Code}) {
		// Queue saturated, fail loud rather than strand the attempt.
		_ = s.store.SetAttemptStatus(r.Context(), attemptID, "error")
		fail(w, http.StatusServiceUnavailable, "grading_busy",
			"grading queue is saturated, try again shortly")
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]any{
		"attemptId": attemptID,
		"status":    "grading",
	})
}

func (s *Server) handleGetAttempt(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	attempt, err := s.store.AttemptByID(r.Context(), r.PathValue("id"), uid)
	if err != nil {
		s.log.Error("attempt lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load attempt")
		return
	}
	if attempt == nil || attempt.UserID != uid {
		fail(w, http.StatusNotFound, "unknown_attempt", "no such attempt")
		return
	}
	resp := map[string]any{
		"attemptId":   attempt.ID,
		"code":        attempt.Code,
		"status":      attempt.Status,
		"startedAt":   attempt.StartedAt.UTC().Format(time.RFC3339Nano),
		"submittedAt": nil,
	}
	if attempt.SubmittedAt != nil {
		resp["submittedAt"] = attempt.SubmittedAt.UTC().Format(time.RFC3339Nano)
	}
	if attempt.Status == "graded" {
		result, err := s.store.ResultByAttempt(r.Context(), attempt.ID)
		if err != nil {
			s.log.Error("result lookup failed", "err", err)
			fail(w, http.StatusInternalServerError, "internal", "could not load result")
			return
		}
		if result != nil {
			resp["result"] = result
		}
	}
	writeJSON(w, http.StatusOK, resp)
}
