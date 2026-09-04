package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRateLimiterAllowsBurstThenDenies(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)
	l := newRateLimiter(60, 3) // 1 token/sec, burst 3
	l.now = func() time.Time { return now }
	for i := 0; i < 3; i++ {
		if !l.allow("k") {
			t.Fatalf("request %d in burst should pass", i)
		}
	}
	if l.allow("k") {
		t.Fatal("4th immediate request should be denied")
	}
	now = now.Add(2 * time.Second) // refill 2 tokens
	if !l.allow("k") {
		t.Fatal("refilled request should pass")
	}
	if !l.allow("k") {
		t.Fatal("second refilled request should pass")
	}
	if l.allow("k") {
		t.Fatal("bucket should be empty again")
	}
}

func TestRateLimiterKeysAreIndependent(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)
	l := newRateLimiter(60, 1)
	l.now = func() time.Time { return now }
	if !l.allow("a") {
		t.Fatal("first key should pass")
	}
	if l.allow("a") {
		t.Fatal("same key should now deny")
	}
	if !l.allow("b") {
		t.Fatal("different key should be independent")
	}
}

func TestRateLimiterSweepsIdleBuckets(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)
	l := newRateLimiter(60, 1)
	l.now = func() time.Time { return now }
	l.allow("ephemeral")
	now = now.Add(31 * time.Minute)
	l.allow("trigger-sweep") // crosses the 8192 threshold? no — force via size guard
	// sweep only runs above 8192 buckets; call it directly for the test
	l.mu.Lock()
	l.sweepLocked(l.now())
	l.mu.Unlock()
	if len(l.buckets) != 1 {
		t.Fatalf("idle bucket should be swept, have %d", len(l.buckets))
	}
}

func TestClientIPPrefersForwardedFor(t *testing.T) {
	r := httptest.NewRequest(http.MethodPost, "/auth/login", nil)
	r.RemoteAddr = "10.0.0.1:5555"
	if got := clientIP(r); got != "10.0.0.1" {
		t.Fatalf("direct = %s", got)
	}
	r.Header.Set("X-Forwarded-For", "203.0.113.7, 10.0.0.2")
	if got := clientIP(r); got != "203.0.113.7" {
		t.Fatalf("xff = %s", got)
	}
	r.Header.Set("X-Real-Ip", "198.51.100.9")
	r.Header.Del("X-Forwarded-For")
	if got := clientIP(r); got != "198.51.100.9" {
		t.Fatalf("real-ip = %s", got)
	}
}

func TestSecurityHeadersOnEveryResponse(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	s := &Server{}
	h := s.securityHeaders(next)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	want := map[string]string{
		"X-Content-Type-Options": "nosniff",
		"X-Frame-Options":        "DENY",
		"Referrer-Policy":        "strict-origin-when-cross-origin",
		"Cache-Control":          "no-store",
	}
	for k, v := range want {
		if got := rec.Header().Get(k); got != v {
			t.Fatalf("%s = %q, want %q", k, got, v)
		}
	}
	if csp := rec.Header().Get("Content-Security-Policy"); csp == "" {
		t.Fatal("CSP header missing")
	}
}
