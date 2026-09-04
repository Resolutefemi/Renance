// Fatigue endpoints (ROADMAP #6).
//
// POST /me/sessions — one sitting's telemetry in, fatigue signal out.
// The server re-computes the signal from the raw latencies with the same
// pure package the clients mirror, so nobody can disagree about a nudge.
// Logging is best-effort: a storage failure still returns the signal —
// telemetry must never break a study session.
package httpapi

import (
	"net/http"
	"time"

	"renance.dev/study-api/internal/fatigue"
	"renance.dev/study-api/internal/store"
)

type logSessionRequest struct {
	AttemptID   string  `json:"attemptId,omitempty"`
	Code        string  `json:"code,omitempty"`
	StartedAt   string  `json:"startedAt"`
	EndedAt     string  `json:"endedAt,omitempty"`
	DurationMs  *int64  `json:"durationMs,omitempty"`
	LatenciesMs []int64 `json:"latenciesMs,omitempty"`
}

func (s *Server) handleLogSession(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req logSessionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.LatenciesMs) > 500 {
		fail(w, http.StatusBadRequest, "too_many_latencies",
			"telemetry caps at 500 latency samples per sitting")
		return
	}
	started, err := time.Parse(time.RFC3339, req.StartedAt)
	if err != nil {
		fail(w, http.StatusBadRequest, "invalid_started_at",
			"startedAt must be an RFC3339 timestamp")
		return
	}
	ended := time.Now().UTC()
	if req.EndedAt != "" {
		ended, err = time.Parse(time.RFC3339, req.EndedAt)
		if err != nil {
			fail(w, http.StatusBadRequest, "invalid_ended_at",
				"endedAt must be an RFC3339 timestamp")
			return
		}
	}
	if ended.Before(started) {
		fail(w, http.StatusBadRequest, "invalid_window",
			"endedAt is before startedAt")
		return
	}
	var durationMs int64
	if req.DurationMs != nil {
		durationMs = *req.DurationMs
	} else {
		durationMs = ended.Sub(started).Milliseconds()
	}
	if durationMs < 0 {
		durationMs = 0
	}
	if durationMs > 24*60*60*1000 {
		durationMs = 24 * 60 * 60 * 1000
	}

	sig := fatigue.Assess(req.LatenciesMs, float64(durationMs)/60000.0)

	err = s.store.LogSession(r.Context(), uid, store.SessionLog{
		AttemptID:      strPtr(req.AttemptID),
		Code:           req.Code,
		StartedAt:      started,
		EndedAt:        ended,
		DurationMs:     durationMs,
		AnswerCount:    len(req.LatenciesMs),
		MedianFirst5:   sig.MedianFirst5,
		MedianLast5:    sig.MedianLast5,
		DriftRatio:     sig.DriftRatio,
		FatigueLevel:   sig.Level,
		SuggestedBreak: sig.SuggestBreak,
	})
	if err != nil {
		// Telemetry is never load-bearing — log and continue.
		s.log.Error("session log failed", "err", err)
	}
	writeJSON(w, http.StatusCreated, map[string]any{"fatigue": sig})
}

func (s *Server) handleFatigue(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	st, err := s.store.FatigueNow(r.Context(), uid)
	if err != nil {
		s.log.Error("fatigue lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not read fatigue state")
		return
	}
	writeJSON(w, http.StatusOK, st)
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
