package httpapi

// Composite papers: the "Standard UTME Mock", "Custom Practice" and
// carved practice-subset backends.
//
// The client POSTs /attempts with a canonical composed code (papercode.go
// grammar) — jamb-mock-…, jamb-custom-… or jamb-pick-…. The server parses
// the spec, composes that paper on demand — deterministically from the
// subject banks or the base pack — registers it in the library, assembles
// its sealed answer key from the source keys, seeds the key store (so
// grading survives a restart) and hands the ordinary attempt pipeline a
// bundle like any static pack. No new storage, no migration, no doctrine
// change: the composite never enters the manifest and never carries
// answers.

import (
	"context"
	"net/http"
	"time"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/store"
)

// ensurePaper resolves any pack code to a servable bundle, composing and
// registering mock/custom/pick papers on first use (double-checked under
// the lock so concurrent first requests compose exactly once).
func (s *Server) ensurePaper(ctx context.Context, code string) (*cbtdata.Bundle, bool) {
	if b, ok := s.lib.Bundle(code); ok {
		return b, true
	}
	if !cbtdata.IsComposedPaperCode(code) {
		return nil, false
	}
	s.mockMu.Lock()
	defer s.mockMu.Unlock()
	if b, ok := s.lib.Bundle(code); ok { // a raced winner already composed it
		return b, true
	}
	spec, err := s.lib.ParsePaper(code)
	if err != nil {
		s.log.Error("paper code parse", "code", code, "err", err)
		return nil, false
	}

	var paper *cbtdata.Bundle
	var keys map[string]store.KeyEntry
	switch spec.Family {
	case cbtdata.PaperFamilyMock, cbtdata.PaperFamilyCustom:
		banks := map[string]*cbtdata.Bundle{}
		for _, slug := range spec.Subjects {
			bank, ok := s.lib.Bundle("jamb-" + slug + "-bank")
			if !ok {
				return nil, false
			}
			banks[slug] = bank
		}
		paper, err = cbtdata.ComposePaper(spec, banks)
		if err != nil {
			s.log.Error("paper compose", "code", code, "err", err)
			return nil, false
		}
		// The sealed key is the union of the banks' keys. A missing bank
		// key is a content defect — refuse the paper loudly rather than
		// strand an ungradable attempt.
		keys = map[string]store.KeyEntry{}
		for _, bank := range banks {
			bankKeys, ok := s.keys.Get(bank.Code)
			if !ok {
				s.log.Error("composed paper: bank key missing", "code", code, "bank", bank.Code)
				return nil, false
			}
			for _, q := range bank.Questions {
				if k, ok := bankKeys[q.ID]; ok {
					keys[q.ID] = k
				}
			}
		}
	case cbtdata.PaperFamilyPick:
		base, ok := s.lib.Bundle(spec.Base)
		if !ok {
			return nil, false
		}
		paper, err = cbtdata.ComposePickPaper(spec, base)
		if err != nil {
			s.log.Error("pick compose", "code", code, "err", err)
			return nil, false
		}
		baseKeys, ok := s.keys.Get(base.Code)
		if !ok {
			s.log.Error("pick paper: base key missing", "code", code, "base", base.Code)
			return nil, false
		}
		keys = map[string]store.KeyEntry{}
		for _, q := range base.Questions {
			if k, ok := baseKeys[q.ID]; ok {
				keys[q.ID] = k
			}
		}
	}

	// Persist first (best-effort: the in-memory cache below already
	// covers the running process; the seed covers a restart mid-paper),
	// then publish the key atomically enough for every reader.
	if _, err := s.store.SeedKeys(ctx, code, keys); err != nil {
		s.log.Error("composed paper: seed keys", "code", code, "err", err)
	}
	if putter, ok := s.keys.(interface {
		Put(code string, keys map[string]store.KeyEntry)
	}); ok {
		putter.Put(code, keys)
	} else {
		s.log.Error("composed paper: key source cannot grow", "code", code)
		return nil, false
	}
	s.lib.RegisterPaper(paper)
	s.log.Info("composed paper ready", "code", code,
		"questions", paper.QuestionCount, "family", spec.Family)
	return paper, true
}

// mockComposeTimeout bounds the composition+key-seed DB work.
const mockComposeTimeout = 15 * time.Second

// ensurePaperRequest wraps ensurePaper with a request-scoped timeout.
func (s *Server) ensurePaperRequest(r *http.Request, code string) (*cbtdata.Bundle, bool) {
	ctx, cancel := context.WithTimeout(r.Context(), mockComposeTimeout)
	defer cancel()
	return s.ensurePaper(ctx, code)
}
