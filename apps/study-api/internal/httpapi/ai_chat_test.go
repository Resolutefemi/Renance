package httpapi

// The AI chat doctrine, pinned (founder directive 2026-10-12: "remove
// the fallback feature completely, make sure the AI answers directly
// or do like normal AI does"):
//
//   1. a healthy provider answers with a REAL reply, mode "ai";
//   2. a provider that fails the grounded first attempt is retried
//      once on the lean prompt and still lands a real answer;
//   3. a provider that fails BOTH attempts gets an honest, retryable
//      503 ai_unavailable - and the old canned study-guide text
//      ("I cannot give you a full answer this minute...") can never
//      appear again, in any mode, ever.

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"renance.dev/study-api/internal/config"
	"renance.dev/study-api/internal/jwtx"
	"renance.dev/study-api/internal/tutor"
)

// scriptedProvider answers from a per-call script: each Complete call
// consumes one entry; fewer entries than calls means "error".
type scriptedProvider struct {
	outs  []string
	errs  []error
	calls int
}

func (p *scriptedProvider) Complete(_ context.Context, system string, _ []tutor.Message, _ int) (string, error) {
	i := p.calls
	p.calls++
	if i < len(p.errs) && p.errs[i] != nil {
		return "", p.errs[i]
	}
	if i < len(p.outs) {
		return p.outs[i], nil
	}
	return "", errors.New("provider exhausted")
}

func chatServer(t *testing.T, p tutor.Provider) (*Server, http.Handler, string) {
	t.Helper()
	cfg := &config.Config{
		JWTSecret: "ai-chat-test-secret-0123456789", WebOrigin: "*",
		AIAPIKey: "test-key", AIBaseURL: "http://127.0.0.1:1", AIModel: "test-model",
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewServer(cfg, log, nil, nil, nil, nil, nil)
	s.tutor.Provider = p
	tok, err := jwtx.Issue("u1", "Student One", cfg.JWTSecret)
	if err != nil {
		t.Fatal(err)
	}
	return s, s.Handler(), tok
}

func postChat(h http.Handler, tok, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/ai/chat", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestAIChatAnswersDirectlyWithHealthyProvider(t *testing.T) {
	p := &scriptedProvider{outs: []string{"Osmosis is the movement of water across a semi-permeable membrane."}}
	_, h, tok := chatServer(t, p)
	rec := postChat(h, tok, `{"messages":[{"role":"user","content":"What is osmosis?"}]}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body: %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	for _, want := range []string{`"mode":"ai"`, `"reply":`, "Osmosis is"} {
		if !strings.Contains(body, want) {
			t.Fatalf("reply missing %q: %s", want, body)
		}
	}
}

func TestAIChatLeanRetryRecoversAfterGroundedFailure(t *testing.T) {
	// Attempt 1 (grounded prompt) blows up; the lean retry lands.
	p := &scriptedProvider{
		errs: []error{errors.New("upstream 503")},
		outs: []string{"", "The correct answer is B - semi-permeable membrane."},
	}
	_, h, tok := chatServer(t, p)
	rec := postChat(h, tok, `{"messages":[{"role":"user","content":"Why did I get Q4 wrong?"}]}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (retry must recover); body: %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `"mode":"ai"`) {
		t.Fatalf("recovered reply must be mode ai: %s", rec.Body.String())
	}
	if p.calls != 2 {
		t.Fatalf("provider calls = %d, want 2 (grounded + lean retry)", p.calls)
	}
}

func TestAIChatFailsHonestlyWhenProviderDoublyFails(t *testing.T) {
	p := &scriptedProvider{errs: []error{errors.New("boom"), errors.New("boom again")}}
	_, h, tok := chatServer(t, p)
	rec := postChat(h, tok, `{"messages":[{"role":"user","content":"Explain photosynthesis"}]}`)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503; body: %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !strings.Contains(body, "ai_unavailable") {
		t.Fatalf("error code must be ai_unavailable: %s", body)
	}
	// The canned non-answer is dead and must stay dead.
	for _, banned := range []string{
		"cannot give you a full answer",
		"ask me again shortly",
		"here is how to keep moving",
		`"mode":"guide"`,
	} {
		if strings.Contains(strings.ToLower(body), strings.ToLower(banned)) {
			t.Fatalf("canned fallback text resurrected: %q in %s", banned, body)
		}
	}
}

func TestAIChatWithoutProviderFailsHonestlyToo(t *testing.T) {
	cfg := &config.Config{
		JWTSecret: "ai-chat-test-secret-0123456789", WebOrigin: "*",
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewServer(cfg, log, nil, nil, nil, nil, nil)
	h := s.Handler()
	tok, err := jwtx.Issue("u1", "Student One", cfg.JWTSecret)
	if err != nil {
		t.Fatal(err)
	}
	rec := postChat(h, tok, `{"messages":[{"role":"user","content":"hello"}]}`)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503; body: %s", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), `"mode":"guide"`) {
		t.Fatalf("guide mode must be gone even without a provider: %s", rec.Body.String())
	}
}
