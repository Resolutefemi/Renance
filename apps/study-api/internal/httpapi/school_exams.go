// Exam-bank HTTP surface: the question pool (add, list, delete) and
// the published papers (list, publish, draw the printable sheet).
// Management owns publishing; teachers with the subject assigned can
// top up the pool for their classes.

package httpapi

import (
	"net/http"
	"strings"

	"renance.dev/study-api/internal/store"
)

// validBand checks the class-band tag on a bank question.
func validBand(b string) bool {
	return b == "" || b == "primary" || b == "junior" || b == "senior"
}

// GET /school/exam-questions?schoolId=&subjectId=&term=&session=&band=
// pours one pool, oldest first.
func (s *Server) handleSchoolExamQuestions(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	q := r.URL.Query()
	subjectID := strings.TrimSpace(q.Get("subjectId"))
	if subjectID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "subjectId is required")
		return
	}
	term, _ := queryInt(r, "term")
	if term == 0 {
		term = 1
	}
	session := strings.TrimSpace(q.Get("session"))
	band := strings.TrimSpace(q.Get("band"))
	if !validBand(band) {
		fail(w, http.StatusBadRequest, "invalid_band", "band must be primary, junior or senior")
		return
	}
	qs, err := s.store.ListExamQuestions(r.Context(), m.SchoolID, subjectID, term, session, band)
	if err != nil {
		s.log.Error("list exam questions", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the question pool")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"questions": qs})
}

// POST /school/exam-question?schoolId= adds one question to the pool.
func (s *Server) handleSchoolAddExamQuestion(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SubjectID   string   `json:"subjectId"`
		Band        string   `json:"band"`
		Term        int      `json:"term"`
		Session     string   `json:"session"`
		Question    string   `json:"question"`
		Options     []string `json:"options"`
		AnswerIndex int      `json:"answerIndex"`
		Explanation string   `json:"explanation"`
		Marks       int      `json:"marks"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	req.SubjectID = strings.TrimSpace(req.SubjectID)
	req.Question = strings.TrimSpace(req.Question)
	req.Session = strings.TrimSpace(req.Session)
	req.Band = strings.TrimSpace(req.Band)
	if req.SubjectID == "" || req.Question == "" || req.Session == "" {
		fail(w, http.StatusBadRequest, "missing_params", "subjectId, question and session are required")
		return
	}
	if !validBand(req.Band) {
		fail(w, http.StatusBadRequest, "invalid_band", "band must be primary, junior or senior")
		return
	}
	if req.Term < 1 || req.Term > 3 {
		fail(w, http.StatusBadRequest, "invalid_term", "term must be 1, 2 or 3")
		return
	}
	if len(req.Options) < 2 || len(req.Options) > 6 {
		fail(w, http.StatusBadRequest, "invalid_options", "a question needs two to six options")
		return
	}
	cleaned := make([]string, 0, len(req.Options))
	for _, o := range req.Options {
		o = strings.TrimSpace(o)
		if o == "" {
			fail(w, http.StatusBadRequest, "invalid_options", "options cannot be empty")
			return
		}
		if len(o) > 400 {
			fail(w, http.StatusBadRequest, "invalid_options", "an option is too long")
			return
		}
		cleaned = append(cleaned, o)
	}
	if req.AnswerIndex < 0 || req.AnswerIndex >= len(cleaned) {
		fail(w, http.StatusBadRequest, "invalid_answer", "the answer must point at one of the options")
		return
	}
	if req.Marks < 1 || req.Marks > 100 {
		req.Marks = 1
	}
	// The never-a-dash rule: bank text is stored clean.
	req.Question = stripDoubleDashes(req.Question)
	req.Explanation = stripDoubleDashes(req.Explanation)

	q := &store.SchoolExamQuestion{
		SchoolID:    m.SchoolID,
		SubjectID:   req.SubjectID,
		Band:        req.Band,
		Term:        req.Term,
		Session:     req.Session,
		Question:    req.Question,
		Options:     cleaned,
		AnswerIndex: req.AnswerIndex,
		Explanation: strings.TrimSpace(req.Explanation),
		Marks:       req.Marks,
		Source:      "school-original",
	}
	saved, err := s.store.AddExamQuestion(r.Context(), q)
	if err != nil {
		s.log.Error("add exam question", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save the question")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"question": saved})
}

// DELETE /school/exam-question?schoolId=&id= drops one bank question.
func (s *Server) handleSchoolDeleteExamQuestion(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		fail(w, http.StatusBadRequest, "missing_params", "id is required")
		return
	}
	deleted, err := s.store.DeleteExamQuestion(r.Context(), m.SchoolID, id)
	if err != nil {
		s.log.Error("delete exam question", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not delete the question")
		return
	}
	if !deleted {
		fail(w, http.StatusNotFound, "not_found", "that question is gone already")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// POST /school/seed-exam-bank?schoolId= - management pours the
// original starter questions into the pool. Idempotent: questions
// already present are skipped, so the button can be tapped safely.
func (s *Server) handleSchoolSeedExamBank(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	poured, err := s.store.SeedExamBank(r.Context(), m.SchoolID)
	if err != nil {
		s.log.Error("seed exam bank", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not pour the starter questions")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"added": poured})
}

// GET /school/exams?schoolId=&term=&session= lists published papers.
func (s *Server) handleSchoolExams(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	term, _ := queryInt(r, "term")
	if term == 0 {
		term = 1
	}
	session := strings.TrimSpace(r.URL.Query().Get("session"))
	exams, err := s.store.ListExams(r.Context(), m.SchoolID, term, session)
	if err != nil {
		s.log.Error("list exams", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the exams")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"exams": exams})
}

// POST /school/exam?schoolId= publishes a paper for a class.
func (s *Server) handleSchoolPublishExam(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClassID         string `json:"classId"`
		SubjectID       string `json:"subjectId"`
		Term            int    `json:"term"`
		Session         string `json:"session"`
		Title           string `json:"title"`
		DurationMinutes int    `json:"durationMinutes"`
		QuestionCount   int    `json:"questionCount"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.ClassID = strings.TrimSpace(req.ClassID)
	req.SubjectID = strings.TrimSpace(req.SubjectID)
	req.Session = strings.TrimSpace(req.Session)
	if req.ClassID == "" || req.SubjectID == "" || req.Session == "" {
		fail(w, http.StatusBadRequest, "missing_params", "classId, subjectId and session are required")
		return
	}
	if req.Term < 1 || req.Term > 3 {
		fail(w, http.StatusBadRequest, "invalid_term", "term must be 1, 2 or 3")
		return
	}
	if req.QuestionCount < 1 || req.QuestionCount > 100 {
		req.QuestionCount = 40
	}
	if req.DurationMinutes < 5 || req.DurationMinutes > 300 {
		req.DurationMinutes = 60
	}
	e := &store.SchoolExam{
		SchoolID:        m.SchoolID,
		ClassID:         req.ClassID,
		SubjectID:       req.SubjectID,
		Term:            req.Term,
		Session:         req.Session,
		Title:           stripDoubleDashes(strings.TrimSpace(req.Title)),
		DurationMinutes: req.DurationMinutes,
		QuestionCount:   req.QuestionCount,
	}
	published, err := s.store.PublishExam(r.Context(), e, m.UserID)
	if err != nil {
		s.log.Error("publish exam", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not publish the exam")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"exam": published})
}

// GET /school/exam-paper?schoolId=&id= draws the paper's questions for
// printing and for the online sitting.
func (s *Server) handleSchoolExamPaper(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		fail(w, http.StatusBadRequest, "missing_params", "id is required")
		return
	}
	exam, qs, err := s.store.ExamPaper(r.Context(), m.SchoolID, id)
	if err != nil {
		s.log.Error("exam paper", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not assemble the paper")
		return
	}
	if exam == nil {
		fail(w, http.StatusNotFound, "not_found", "no such exam")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"exam": exam, "questions": qs})
}
