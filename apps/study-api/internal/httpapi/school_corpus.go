// National-curriculum corpus routes: schemes of work + lesson notes
// read straight from the data folder baked into the deploy. Read-only,
// signed-in like the exam bundles, and never touching Neon.
package httpapi

import (
	"net/http"

	"renance.dev/study-api/internal/schoolcorpus"
)

// GET /school/corpus/classes - every class level with subjects and the
// terms each one holds, so the pickers can grey out missing content.
func (s *Server) handleCorpusClasses(w http.ResponseWriter, r *http.Request) {
	if s.corpus == nil {
		writeJSON(w, http.StatusOK, map[string]any{"classes": []schoolcorpus.Class{}})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"classes": s.corpus.Classes()})
}

// GET /school/corpus/schemes/{class}/{subject} - all three term
// schemes for one subject, week by week.
func (s *Server) handleCorpusSchemes(w http.ResponseWriter, r *http.Request) {
	s.serveCorpusTerms(w, r, "school-schemes")
}

// GET /school/corpus/notes/{class}/{subject} - the lesson notes for
// every term under one subject, keyed to the scheme's weeks.
func (s *Server) handleCorpusNotes(w http.ResponseWriter, r *http.Request) {
	s.serveCorpusTerms(w, r, "school-notes")
}

func (s *Server) serveCorpusTerms(w http.ResponseWriter, r *http.Request, kind string) {
	class := r.PathValue("class")
	subject := r.PathValue("subject")
	if class == "" || subject == "" || s.corpus == nil || !s.corpus.Has(class, subject) {
		fail(w, http.StatusNotFound, "not_found", "the corpus does not hold that class and subject yet")
		return
	}
	terms := s.corpus.Terms(kind, class, subject)
	if terms == nil {
		terms = []schoolcorpus.TermPayload{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"class":   class,
		"subject": subject,
		"terms":   terms,
	})
}
