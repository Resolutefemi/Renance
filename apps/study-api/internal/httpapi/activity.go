package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"

	"renance.dev/study-api/internal/learn"
)

// POST /learn/heartbeat {seconds} - presence + time-on-app (admin
// dashboard "active now" / "used today" / "most time"). Deliberately
// streak-neutral.
func (s *Server) handleLearnHeartbeat(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body struct {
		Seconds int `json:"seconds"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 512)).Decode(&body); err != nil {
		// A heartbeat with a broken body is still presence; accept it
		// as a 0-second ping rather than teaching clients to retry.
		body.Seconds = 0
	}
	if err := s.learn.Heartbeat(r.Context(), userID, body.Seconds); err != nil {
		fail(w, http.StatusInternalServerError, "learn_heartbeat", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /learn/flags - a learner reports a wrong question.
func (s *Server) handleLearnFlags(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body learn.FlagInput
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16384)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid report body")
		return
	}
	id, err := s.learn.FlagQuestion(r.Context(), userID, body)
	if err != nil {
		fail(w, http.StatusConflict, "learn_flag", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "id": id})
}

// POST /learn/course-requests - a learner submits a missing course
// with the contents/topics they expect.
func (s *Server) handleLearnCourseRequests(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body learn.CourseSubmissionInput
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 32768)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid submission body")
		return
	}
	id, err := s.learn.SubmitCourse(r.Context(), userID, body)
	if err != nil {
		fail(w, http.StatusConflict, "learn_course_request", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "id": id})
}

var _ = strconv.Itoa // reserved for query-param helpers
