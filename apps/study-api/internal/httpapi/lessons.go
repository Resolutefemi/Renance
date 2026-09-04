// Lesson endpoints (ROADMAP #8).
//
// GET /lessons        — lesson list (meta only, list views + SEO cards)
// GET /lessons/{slug} — one lesson with full sections
package httpapi

import (
	"net/http"
)

func (s *Server) handleLessons(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"lessons": s.lib.Lessons()})
}

func (s *Server) handleLesson(w http.ResponseWriter, r *http.Request) {
	slug := r.PathValue("slug")
	lesson, ok := s.lib.Lesson(slug)
	if !ok {
		fail(w, http.StatusNotFound, "unknown_lesson", "no lesson with slug "+slug)
		return
	}
	writeJSON(w, http.StatusOK, lesson)
}
