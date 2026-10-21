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
        l.allow("trigger-sweep") // crosses the 8192 threshold? no, force via size guard
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
        // Render's proxy APPENDS the real client IP: "spoofed, real". The
        // bucket key must be the proxy-appended (last) entry, never the
        // client-controlled first one.
        r.Header.Set("X-Forwarded-For", "203.0.113.7, 10.0.0.2")
        if got := clientIP(r); got != "10.0.0.2" {
                t.Fatalf("xff (proxy-appended last) = %s, want 10.0.0.2", got)
        }
        r.Header.Set("X-Forwarded-For", "198.51.100.9")
        if got := clientIP(r); got != "198.51.100.9" {
                t.Fatalf("xff single entry = %s", got)
        }
        // X-Real-Ip is client-controlled on Render (the proxy never sets
        // it): trusting it would let a scraper pick its own bucket key.
        // It must be ignored in favor of RemoteAddr.
        r.Header.Set("X-Real-Ip", "6.6.6.6")
        r.Header.Del("X-Forwarded-For")
        if got := clientIP(r); got != "10.0.0.1" {
                t.Fatalf("spoofed X-Real-Ip must be ignored, got %s", got)
        }
}

// TestClientIPSpoofCannotRotateBuckets pins the 2026-10-12 audit fix:
// a scraper that rotates fake FIRST X-Forwarded-For entries must NOT
// get fresh per-IP rate buckets - all requests land on the ONE
// proxy-appended real IP.
func TestClientIPSpoofCannotRotateBuckets(t *testing.T) {
        l := newRateLimiter(60, 3) // tiny bucket: 3 requests then denial
        for i := 0; i < 3; i++ {
                r := httptest.NewRequest(http.MethodGet, "/bundles/key", nil)
                r.RemoteAddr = "10.9.9.9:1234" // the Render proxy's direct peer
                r.Header.Set("X-Forwarded-For", "1.2.3."+string(rune('a'+i))+", 203.0.113.7")
                if !l.allow("t:" + clientIP(r)) {
                        t.Fatalf("honest request %d should pass", i)
                }
        }
        r := httptest.NewRequest(http.MethodGet, "/bundles/key", nil)
        r.RemoteAddr = "10.9.9.9:1234"
        r.Header.Set("X-Forwarded-For", "9.9.9.9, 203.0.113.7")
        if l.allow("t:" + clientIP(r)) {
                t.Fatal("rotated spoofed first entries must NOT buy a fresh bucket - 4th request must be denied")
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
