package httpapi

import (
	"encoding/hex"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/config"
	"renance.dev/study-api/internal/jwtx"
)

// Bulk-extraction hardening (founder directive 2026-11-05, superseding
// the 2026-10-11 "no caps" posture for the bundle routes): a signed-in
// account may study freely at human speed, but may not walk the whole
// bank catalogue in one sitting, and every served copy carries a
// per-account option-order fingerprint that survives plain-text copying
// (zero-width watermarks alone are stripped by most re-typing).

func extractionServer(t *testing.T, perHour, distinctPerDay int) (http.Handler, string) {
	t.Helper()
	lib := writeAnswerBank(t)
	master, _ := hex.DecodeString("8a2f1c4e19b76d3f5e8a0c2b4d6f8a1c3e5b7d9f1a3c5e7b9d1f3a5c7e9b1d3f")
	cfg := &config.Config{
		JWTSecret: "shield-test-secret-0123456789", WebOrigin: "*",
		BundleMasterKey: master, BundleKeyID: "t1", BundleAnonKey: false,
		BundleUserPerHour: perHour, BundleUserDistinctPerDay: distinctPerDay,
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewServer(cfg, log, nil, lib, nil, nil, nil)
	tok, err := jwtx.Issue("u1", "Student One", cfg.JWTSecret)
	if err != nil {
		t.Fatal(err)
	}
	return s.Handler(), tok
}

func TestBundleExtractionHourlyCap(t *testing.T) {
	h, tok := extractionServer(t, 3, 40)
	for i := 0; i < 3; i++ {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, mustReq(t, tok, "/bundles/test-bank"))
		if rec.Code != http.StatusOK {
			t.Fatalf("fetch %d: want 200, got %d %s", i, rec.Code, rec.Body.String())
		}
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, mustReq(t, tok, "/bundles/test-bank"))
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("over hourly cap: want 429, got %d %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "extraction_limit") {
		t.Fatalf("cap body must name extraction_limit: %s", rec.Body.String())
	}
}

func TestBundleExtractionCapIsPerAccount(t *testing.T) {
	h, tok := extractionServer(t, 2, 40)
	for i := 0; i < 2; i++ {
		h.ServeHTTP(httptest.NewRecorder(), mustReq(t, tok, "/bundles/test-bank"))
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, mustReq(t, tok, "/bundles/test-bank"))
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("u1 over cap: want 429, got %d", rec.Code)
	}
	// A second account keeps its own budget.
	cfg := &config.Config{JWTSecret: "shield-test-secret-0123456789"}
	tok2, err := jwtx.Issue("u2", "Student Two", cfg.JWTSecret)
	if err != nil {
		t.Fatal(err)
	}
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, mustReq(t, tok2, "/bundles/test-bank"))
	if rec.Code != http.StatusOK {
		t.Fatalf("u2 must not inherit u1's cap: got %d %s", rec.Code, rec.Body.String())
	}
}

func TestOptionFingerprintPreservesAnswer(t *testing.T) {
	s, _, _, uid := shieldServer(t)
	qs := make([]cbtdata.Question, 0, 12)
	for i := 0; i < 12; i++ {
		qs = append(qs, cbtdata.Question{
			ID: "q" + string(rune('a'+i)), Type: "mcq",
			Stem:    "Which of the following statements about photosynthesis is correct and complete?",
			Options: map[string]string{"A": "alpha", "B": "bravo", "C": "charlie", "D": "delta"},
			Answer:  "B", Marks: 1,
		})
	}
	b := &cbtdata.Bundle{Code: "test-bank", Questions: qs}
	wm1 := s.watermarkBundle(b, uid)
	wm2 := s.watermarkBundle(b, "u2")
	differ := false
	for i := range wm1.Questions {
		q := wm1.Questions[i]
		// Options are a permutation of the originals.
		seen := map[string]bool{}
		for _, v := range q.Options {
			seen[v] = true
		}
		if len(seen) != 4 || !seen["alpha"] || !seen["bravo"] || !seen["charlie"] || !seen["delta"] {
			t.Fatalf("q%d options not a permutation: %v", i, q.Options)
		}
		// The answer letter still points at the same answer TEXT.
		if q.Options[q.Answer] != "bravo" {
			t.Fatalf("q%d answer remap wrong: answer=%s options=%v", i, q.Answer, q.Options)
		}
		if wm2.Questions[i].Options["A"] != q.Options["A"] ||
			wm2.Questions[i].Options["B"] != q.Options["B"] {
			differ = true
		}
	}
	if !differ {
		t.Fatal("option order must vary by account (per-account fingerprint)")
	}
	// The library copy is untouched.
	if b.Questions[0].Options["B"] != "bravo" || b.Questions[0].Answer != "B" {
		t.Fatalf("original bundle mutated: %+v", b.Questions[0])
	}
}
