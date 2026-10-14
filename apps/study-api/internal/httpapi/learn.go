// learn.go - the HTTP surface of the learn module. Every route rides
// the standard s.auth (JWT, real Renance account). Handlers are thin:
// parse → service → writeJSON, matching the house style.
package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"renance.dev/study-api/internal/learn"
)

func (s *Server) learnService() *learn.Service { return s.learn }

// GET /learn/profile - top-bar counters + settings payload.
func (s *Server) handleLearnProfile(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	p, err := s.learn.Profile(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_profile", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, p)
}

// PATCH /learn/profile {dailyGoal?, institutionType?, department?} -
// settings + course desk mutations. The desk pair validates against
// the seeded departments (learn.SetDesk) before it saves.
func (s *Server) handleLearnPatchProfile(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body struct {
		DailyGoal       *int   `json:"dailyGoal"`
		InstitutionType string `json:"institutionType"`
		Department      string `json:"department"`
		SetDesk         bool   `json:"setDesk"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
		return
	}
	if body.SetDesk {
		if err := s.learn.SetDesk(r.Context(), userID, body.InstitutionType, body.Department); err != nil {
			fail(w, http.StatusBadRequest, "learn_desk", err.Error())
			return
		}
	}
	if body.DailyGoal != nil {
		if err := s.learn.SetDailyGoal(r.Context(), userID, *body.DailyGoal); err != nil {
			fail(w, http.StatusBadRequest, "learn_goal", err.Error())
			return
		}
	}
	p, err := s.learn.Profile(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_profile", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, p)
}

// DELETE /learn/profile - reset all learn progress (settings).
func (s *Server) handleLearnReset(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	if err := s.learn.ResetProgress(r.Context(), userID); err != nil {
		fail(w, http.StatusInternalServerError, "learn_reset", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// GET /learn/catalog?body=&q=&faculty=&itype=&page=&pageSize=
func (s *Server) handleLearnCatalog(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	qp := r.URL.Query()
	page, _ := strconv.Atoi(qp.Get("page"))
	pageSize, _ := strconv.Atoi(qp.Get("pageSize"))
	items, total, err := s.learn.Catalog(r.Context(), userID,
		strings.ToLower(qp.Get("body")), qp.Get("q"), qp.Get("faculty"), qp.Get("itype"), page, pageSize)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_catalog", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": total})
}

// GET /learn/faculties
func (s *Server) handleLearnFaculties(w http.ResponseWriter, r *http.Request) {
	f, err := s.learn.Faculties(r.Context())
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_faculties", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"faculties": f})
}

// GET /learn/departments?itype=University - the department gate list.
func (s *Server) handleLearnDepartments(w http.ResponseWriter, r *http.Request) {
	deps, err := s.learn.Departments(r.Context(), r.URL.Query().Get("itype"))
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_departments", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"departments": deps})
}

// GET /learn/course-desk - the tertiary shelves: general first, then
// the student's department.
func (s *Server) handleLearnCourseDesk(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	shelf, err := s.learn.CourseDesk(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_desk", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, shelf)
}

// GET /learn/search?q= - code / title / key-topic search over the
// tertiary tree.
func (s *Server) handleLearnSearch(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	items, err := s.learn.SearchCourses(r.Context(), userID, r.URL.Query().Get("q"))
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_search", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

// POST /learn/ai-match {text} - the AI course finder: paste your
// course titles, the matcher grounds every line in the real catalogue.
func (s *Server) handleLearnAIMatch(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body learn.AIMatchRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
		return
	}
	lines, err := s.learn.AIMatchCourses(r.Context(), userID, body.Text)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_ai_match", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"lines": lines})
}

// GET /learn/my-courses
func (s *Server) handleLearnMyCourses(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	courses, err := s.learn.MyCourses(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_my_courses", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"courses": courses})
}

// POST /learn/my-courses {courseIds: [...]} - the multi-select picker.
func (s *Server) handleLearnSetMyCourses(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body struct {
		CourseIDs []string `json:"courseIds"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
		return
	}
	if len(body.CourseIDs) > 60 {
		fail(w, http.StatusBadRequest, "learn_too_many", "a course list holds at most 60 courses")
		return
	}
	if err := s.learn.SetMyCourses(r.Context(), userID, body.CourseIDs); err != nil {
		fail(w, http.StatusInternalServerError, "learn_set_courses", err.Error())
		return
	}
	courses, _ := s.learn.MyCourses(r.Context(), userID)
	writeJSON(w, http.StatusOK, map[string]any{"courses": courses})
}

// POST /learn/active-course {courseId}
func (s *Server) handleLearnActiveCourse(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body struct {
		CourseID string `json:"courseId"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil || body.CourseID == "" {
		fail(w, http.StatusBadRequest, "bad_json", "courseId is required")
		return
	}
	if err := s.learn.SetActiveCourse(r.Context(), userID, body.CourseID); err != nil {
		fail(w, http.StatusInternalServerError, "learn_active", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// GET /learn/courses/{id} - the path ladder.
func (s *Server) handleLearnCoursePath(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	path, err := s.learn.CoursePath(r.Context(), userID, r.PathValue("id"))
	if err != nil {
		fail(w, http.StatusNotFound, "learn_course", "course not found")
		return
	}
	writeJSON(w, http.StatusOK, path)
}

// GET /learn/topics/{id}/content?wait=1
func (s *Server) handleLearnLesson(w http.ResponseWriter, r *http.Request) {
	wait := r.URL.Query().Get("wait") == "1"
	doc, err := s.learn.Lesson(r.Context(), r.PathValue("id"), wait)
	if err == learn.ErrGenerating {
		writeJSON(w, http.StatusAccepted, map[string]string{"status": "generating"})
		return
	}
	if err != nil {
		fail(w, http.StatusServiceUnavailable, "learn_lesson", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, doc)
}

// POST /learn/progress
func (s *Server) handleLearnProgress(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var req learn.CompleteRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(&req); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
		return
	}
	res, err := s.learn.Complete(r.Context(), userID, req)
	if err != nil {
		fail(w, http.StatusBadRequest, "learn_progress", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// GET /learn/quests | POST /learn/quests {questKey}
func (s *Server) handleLearnQuests(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	if r.Method == http.MethodPost {
		var body struct {
			QuestKey string `json:"questKey"`
		}
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil || body.QuestKey == "" {
			fail(w, http.StatusBadRequest, "bad_json", "questKey is required")
			return
		}
		gems, err := s.learn.ClaimQuest(r.Context(), userID, body.QuestKey)
		if err != nil {
			fail(w, http.StatusBadRequest, "learn_claim", err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]int{"gems": gems})
		return
	}
	resp, err := s.learn.Quests(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_quests", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

// GET /learn/shop | POST /learn/shop {item}
func (s *Server) handleLearnShop(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	if r.Method == http.MethodPost {
		var body struct {
			Item string `json:"item"`
		}
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil || body.Item == "" {
			fail(w, http.StatusBadRequest, "bad_json", "item is required")
			return
		}
		resp, err := s.learn.Buy(r.Context(), userID, body.Item)
		if err != nil {
			fail(w, http.StatusBadRequest, "learn_shop", err.Error())
			return
		}
		writeJSON(w, http.StatusOK, resp)
		return
	}
	resp, err := s.learn.Shop(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_shop", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

// GET /learn/leaderboard - the weekly league board.
func (s *Server) handleLearnLeague(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	board, err := s.learn.League(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_league", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, board)
}

// POST /learn/chests {chestKey}
func (s *Server) handleLearnChest(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	var body struct {
		ChestKey string `json:"chestKey"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil || body.ChestKey == "" {
		fail(w, http.StatusBadRequest, "bad_json", "chestKey is required")
		return
	}
	res, err := s.learn.OpenChest(r.Context(), userID, body.ChestKey)
	if err != nil {
		fail(w, http.StatusConflict, "learn_chest", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// GET /learn/practice | POST /learn/practice
func (s *Server) handleLearnPractice(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	if r.Method == http.MethodPost {
		var body struct {
			Correct     int      `json:"correct"`
			Total       int      `json:"total"`
			ResolvedIDs []string `json:"resolvedIds"`
		}
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&body); err != nil {
			fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
			return
		}
		res, err := s.learn.GradePractice(r.Context(), userID, body.Correct, body.Total, body.ResolvedIDs)
		if err != nil {
			fail(w, http.StatusBadRequest, "learn_practice", err.Error())
			return
		}
		writeJSON(w, http.StatusOK, res)
		return
	}
	set, err := s.learn.PracticeSet(r.Context(), userID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "learn_practice", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, set)
}

// GET /learn/review?courseId=&unit=
func (s *Server) handleLearnReview(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(ctxUserID).(string)
	qp := r.URL.Query()
	unit, _ := strconv.Atoi(qp.Get("unit"))
	set, err := s.learn.ReviewSet(r.Context(), userID, qp.Get("courseId"), unit)
	if err != nil {
		fail(w, http.StatusBadRequest, "learn_review", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, set)
}
