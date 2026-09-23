package httpapi

// Bulk import endpoints for the school content house. Management pours
// a harvested corpus (schemes of work, exam questions) through one call
// each; the endpoints compose existing store primitives so upsert
// semantics stay identical to the single-item paths: schemes draft only
// where the term's plan is still empty (or overwrite is asked), topics
// merge by title, exam questions dedupe on their text.

import (
        "encoding/json"
        "net/http"
        "strings"

        "renance.dev/study-api/internal/store"
)

// ---------------------------------------------------------- bulk schemes

type bulkSchemeWeek struct {
        Week    int    `json:"week"`
        Topic   string `json:"topic"`
        Content string `json:"content"`
}

// POST /school/bulk-schemes - management pours a scheme-of-work corpus
// into one class+subject+term. Every week with content bullets also
// lands as a topic, so a poured scheme doubles as a syllabus draft the
// teachers can flesh out instead of a blank page.
func (s *Server) handleSchoolBulkSchemes(w http.ResponseWriter, r *http.Request) {
        m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
        if !ok {
                return
        }
        if !s.requireManagement(w, m) {
                return
        }
        var req struct {
                ClassID   string           `json:"classId"`
                SubjectID string           `json:"subjectId"`
                Term      int              `json:"term"`
                Session   string           `json:"session"`
                Overwrite bool             `json:"overwrite"`
                Weeks     []bulkSchemeWeek `json:"weeks"`
        }
        if !decodeJSON(w, r, &req) {
                return
        }
        req.ClassID = strings.TrimSpace(req.ClassID)
        req.SubjectID = strings.TrimSpace(req.SubjectID)
        req.Session = strings.TrimSpace(req.Session)
        if req.ClassID == "" || req.SubjectID == "" || req.Term < 1 || req.Term > 3 {
                fail(w, http.StatusBadRequest, "invalid_body", "classId, subjectId and term (1-3) are required")
                return
        }
        if len(req.Weeks) == 0 {
                fail(w, http.StatusBadRequest, "invalid_body", "weeks list is empty")
                return
        }
        if len(req.Weeks) > 60 {
                fail(w, http.StatusBadRequest, "too_many", "import at most 60 weeks per call")
                return
        }

        // Founder content rule: the long hyphen never ships.
        rows := make([]map[string]any, 0, len(req.Weeks))
        topics := make([]store.BulkTopic, 0, len(req.Weeks))
        for i := range req.Weeks {
                wk := req.Weeks[i]
                wk.Topic = normalizeHyphens(strings.TrimSpace(wk.Topic))
                wk.Content = normalizeHyphens(strings.TrimSpace(wk.Content))
                if wk.Topic == "" {
                        continue
                }
                if wk.Week < 1 || wk.Week > 20 {
                        wk.Week = i + 1
                }
                rows = append(rows, map[string]any{"week": wk.Week, "topic": wk.Topic})
                if wk.Content != "" {
                        if len(wk.Content) > 80_000 {
                                wk.Content = wk.Content[:80_000]
                        }
                        topics = append(topics, store.BulkTopic{
                                Title: wk.Topic, Week: wk.Week, Content: wk.Content, Source: "scheme-import",
                        })
                }
        }
        if len(rows) == 0 {
                fail(w, http.StatusBadRequest, "invalid_body", "every week is missing a topic")
                return
        }

        written := 0
        if len(topics) > 0 {
                n, err := s.store.BulkUpsertTopics(r.Context(), m.SchoolID, req.ClassID, req.SubjectID,
                        req.Term, req.Session, false, topics)
                if err != nil {
                        s.log.Error("bulk schemes: topic pour", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not pour the topic bullets")
                        return
                }
                written = n
        }

        syl, err := s.store.EnsureSyllabus(r.Context(), m.SchoolID, req.ClassID, req.SubjectID, req.Term, req.Session)
        if err != nil || syl == nil {
                s.log.Error("bulk schemes: ensure syllabus", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not open the term syllabus")
                return
        }
        empty := len(syl.SchemeOfWork) == 0 || string(syl.SchemeOfWork) == "[]" || string(syl.SchemeOfWork) == "null"
        if req.Overwrite || empty {
                raw, err := json.Marshal(rows)
                if err == nil {
                        if err := s.store.UpdateSchemeOfWork(r.Context(), syl.ID,
                                normalizeHyphensInScheme(raw), m.UserID); err != nil {
                                s.log.Error("bulk schemes: scheme write", "err", err)
                        }
                }
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "received": len(req.Weeks), "weeks": len(rows), "topicsWritten": written,
        })
}

// ------------------------------------------------------- bulk exam bank

// POST /school/bulk-exam-questions - management pours a question corpus
// into the school bank. Answer keys may be absent from a harvested
// source; answerIndex -1 means "key pending, a teacher must set it",
// and the pool marks such rows so nothing silently auto-grades them.
func (s *Server) handleSchoolBulkExamQuestions(w http.ResponseWriter, r *http.Request) {
        m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
        if !ok {
                return
        }
        if !s.requireManagement(w, m) {
                return
        }
        var req struct {
                SubjectID string `json:"subjectId"`
                Band      string `json:"band"`
                Term      int    `json:"term"`
                Session   string `json:"session"`
                Source    string `json:"source"`
                Questions []struct {
                        Question    string   `json:"question"`
                        Options     []string `json:"options"`
                        AnswerIndex int      `json:"answerIndex"`
                        Explanation string   `json:"explanation"`
                        Marks       int      `json:"marks"`
                // Provenance fields the corpora carry per question; accepted so
                // a pour can post its rows verbatim. The corpus-level source is
                // what the bank stores.
                Source    string `json:"source"`
                SourceURL string `json:"sourceUrl"`
                } `json:"questions"`
        }
        if !decodeJSON(w, r, &req) {
                return
        }
        req.SubjectID = strings.TrimSpace(req.SubjectID)
        req.Session = strings.TrimSpace(req.Session)
        req.Source = strings.TrimSpace(req.Source)
        req.Band = strings.TrimSpace(req.Band)
        if !validBand(req.Band) {
                fail(w, http.StatusBadRequest, "invalid_band", "band must be primary, junior or senior")
                return
        }
        if req.SubjectID == "" || req.Term < 1 || req.Term > 3 {
                fail(w, http.StatusBadRequest, "invalid_body", "subjectId and term (1-3) are required")
                return
        }
        if len(req.Questions) == 0 {
                fail(w, http.StatusBadRequest, "invalid_body", "questions list is empty")
                return
        }
        if len(req.Questions) > 500 {
                fail(w, http.StatusBadRequest, "too_many", "import at most 500 questions per call")
                return
        }
        source := req.Source
        if source == "" {
                source = "import"
        }
        if len(source) > 80 {
                source = source[:80]
        }

        written := 0
        lastErr := ""
        for i := range req.Questions {
                q := &req.Questions[i]
                q.Question = stripDoubleDashes(strings.TrimSpace(q.Question))
                q.Explanation = stripDoubleDashes(strings.TrimSpace(q.Explanation))
                if q.Question == "" {
                        continue
                }
                cleaned := make([]string, 0, len(q.Options))
                for _, o := range q.Options {
                        o = stripDoubleDashes(strings.TrimSpace(o))
                        if o == "" || len(o) > 400 {
                                continue
                        }
                        cleaned = append(cleaned, o)
                }
                if len(cleaned) < 2 || len(cleaned) > 6 {
                        continue
                }
                if q.AnswerIndex < -1 || q.AnswerIndex >= len(cleaned) {
                        q.AnswerIndex = -1
                }
                if q.Marks < 1 || q.Marks > 100 {
                        q.Marks = 1
                }
                if _, err := s.store.AddExamQuestion(r.Context(), &store.SchoolExamQuestion{
                        SchoolID:    m.SchoolID,
                        SubjectID:   req.SubjectID,
                        Band:        req.Band,
                        Term:        req.Term,
                        Session:     req.Session,
                        Question:    q.Question,
                        Options:     cleaned,
                        AnswerIndex: q.AnswerIndex,
                        Explanation: q.Explanation,
                        Marks:       q.Marks,
                        Source:      source,
                }); err != nil {
                        s.log.Error("bulk exam question", "err", err)
                        if lastErr == "" {
                                lastErr = err.Error()
                        }
                        continue
                }
                written++
        }
        resp := map[string]any{
                "received": len(req.Questions), "written": written,
        }
        // Surface the first store failure so a pour can debug without
        // server logs; empty when every row landed.
        if lastErr != "" {
                resp["lastError"] = lastErr
        }
        writeJSON(w, http.StatusOK, resp)
}
