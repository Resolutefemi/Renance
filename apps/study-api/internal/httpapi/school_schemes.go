// Scheme-seed HTTP surface: one management action installs the
// national curriculum into the school. With the corpus baked into the
// deploy (the norm), it pours the real NERDC week-by-week schemes and
// the lesson notes into every matching class+subject, creating the
// three syllabus terms as it goes; the tiny built-in seed table stays
// as the fallback for deploys without a corpus.

package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

	"renance.dev/study-api/internal/schoolcorpus"
	"renance.dev/study-api/internal/store"
)

// POST /school/seed-schemes?schoolId= - management pours the drafts.
func (s *Server) handleSchoolSeedSchemes(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Session string `json:"session"`
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
	req.Session = strings.TrimSpace(req.Session)
	if req.Session == "" {
		fail(w, http.StatusBadRequest, "missing_params", "session is required")
		return
	}

	if s.corpus != nil {
		filled, err := s.store.SeedSchemesCorpus(r.Context(), m.SchoolID, req.Session, corpusSeeds(s.corpus))
		if err != nil {
			s.log.Error("corpus scheme seed", "err", err)
			fail(w, http.StatusInternalServerError, "internal", "could not install the national curriculum")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"filled": filled, "source": "corpus"})
		return
	}

	filled, err := s.store.SeedSchemes(r.Context(), m.SchoolID, req.Session)
	if err != nil {
		s.log.Error("seed schemes", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not draft the schemes")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"filled": filled, "source": "builtin"})
}

// corpusSeeds converts the baked corpus into store-ready seeds: for
// every class+subject the scheme weeks (terms 1-3) and the lesson-note
// topics. Long hyphens are normalized away here, on the way in, per
// the founder content rule.
func corpusSeeds(c *schoolcorpus.Corpus) []store.CorpusSeed {
	out := make([]store.CorpusSeed, 0, 64)
	for _, class := range c.Classes() {
		for _, sub := range class.Subjects {
			seed := store.CorpusSeed{ClassName: class.Name, SubjectName: sub.Name}
			byTerm := map[int]*store.CorpusSeedTerm{}
			term := func(t int) *store.CorpusSeedTerm {
				if byTerm[t] == nil {
					byTerm[t] = &store.CorpusSeedTerm{Term: t}
				}
				return byTerm[t]
			}
			for _, tp := range c.Terms("school-schemes", class.ID, sub.ID) {
				var f struct {
					Weeks []struct {
						Week  int    `json:"week"`
						Topic string `json:"topic"`
					} `json:"weeks"`
				}
				if json.Unmarshal(tp.Data, &f) != nil {
					continue
				}
				st := term(tp.Term)
				for _, wk := range f.Weeks {
					topic := strings.TrimSpace(wk.Topic)
					if topic == "" {
						continue
					}
					week := wk.Week
					if week < 1 || week > 20 {
						week = len(st.Weeks) + 1
					}
					st.Weeks = append(st.Weeks, map[string]any{"week": week, "topic": normalizeHyphens(topic)})
				}
			}
			for _, tp := range c.Terms("school-notes", class.ID, sub.ID) {
				var f struct {
					Topics []struct {
						Week    int    `json:"week"`
						Title   string `json:"title"`
						Content string `json:"content"`
					} `json:"topics"`
				}
				if json.Unmarshal(tp.Data, &f) != nil {
					continue
				}
				st := term(tp.Term)
				for _, t := range f.Topics {
					title := strings.TrimSpace(t.Title)
					content := strings.TrimSpace(t.Content)
					if title == "" || content == "" {
						continue
					}
					if len(content) > 80_000 {
						content = content[:80_000]
					}
					st.Topics = append(st.Topics, store.BulkTopic{
						Title:   normalizeHyphens(title),
						Week:    t.Week,
						Content: normalizeHyphens(content),
						Source:  "renance-corpus",
					})
				}
			}
			if len(byTerm) == 0 {
				continue
			}
			for t, st := range byTerm {
				if len(st.Weeks) == 0 && len(st.Topics) == 0 {
					delete(byTerm, t)
				}
			}
			if len(byTerm) == 0 {
				continue
			}
			for t := 1; t <= 3; t++ {
				if st := byTerm[t]; st != nil {
					seed.Terms = append(seed.Terms, *st)
				}
			}
			if len(seed.Terms) > 0 {
				out = append(out, seed)
			}
		}
	}
	return out
}
