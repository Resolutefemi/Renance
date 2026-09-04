// Rate limiting + baseline security headers (founder security directive:
// "work on the security along the way, make it impenetrable").
//
// Threat model for a free-tier public API:
//   - credential stuffing / brute force on /auth/login
//   - CPU exhaustion via bcrypt register+login floods (cost 12 ≈ 250ms)
//   - AI cost exhaustion on the tutor route once a key is configured
//   - junk-traffic probing of every other route
//
// The limiter is an in-memory token bucket keyed by (class, subject):
// auth routes are throttled per client IP plus one global bucket so a
// distributed flood still hits a wall; the tutor is throttled per user.
// It needs no shared state — single-binary deployment, per Render spec.
package httpapi

import (
	"math"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

type tokenBucket struct {
	tokens float64
	last   time.Time
}

type rateLimiter struct {
	mu      sync.Mutex
	rate    float64 // tokens per second
	burst   float64
	buckets map[string]*tokenBucket
	now     func() time.Time
}

func newRateLimiter(perMinute int, burst int) *rateLimiter {
	if perMinute <= 0 {
		perMinute = 1
	}
	if burst < 1 {
		burst = 1
	}
	return &rateLimiter{
		rate:    float64(perMinute) / 60.0,
		burst:   float64(burst),
		buckets: map[string]*tokenBucket{},
		now:     time.Now,
	}
}

// allow spends one token for key. First use starts full.
func (l *rateLimiter) allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	if len(l.buckets) > 8192 {
		l.sweepLocked(now)
	}
	b, ok := l.buckets[key]
	if !ok {
		l.buckets[key] = &tokenBucket{tokens: l.burst - 1, last: now}
		return true
	}
	elapsed := now.Sub(b.last).Seconds()
	if elapsed > 0 {
		b.tokens = math.Min(l.burst, b.tokens+elapsed*l.rate)
		b.last = now
	}
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// sweepLocked drops buckets idle for over 30 minutes so key churn
// (spoofed IPs, botnet floods) cannot grow memory without bound.
func (l *rateLimiter) sweepLocked(now time.Time) {
	cutoff := now.Add(-30 * time.Minute)
	for k, b := range l.buckets {
		if b.last.Before(cutoff) {
			delete(l.buckets, k)
		}
	}
}

// clientIP resolves the calling IP behind Render's proxy. The proxy sets
// X-Forwarded-For; the first hop is the client. Direct connections fall
// back to RemoteAddr. Spoofed XFF only rotates a key the attacker
// already owns — the global auth bucket still caps total flood pressure.
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if i := strings.IndexByte(xff, ','); i >= 0 {
			xff = xff[:i]
		}
		if ip := strings.TrimSpace(xff); ip != "" {
			return ip
		}
	}
	if xri := strings.TrimSpace(r.Header.Get("X-Real-Ip")); xri != "" {
		return xri
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// ipLimit gates one handler behind the per-IP limiter class.
func (s *Server) ipLimit(class string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.limiter.allow(class + ":ip:" + clientIP(r)) {
			w.Header().Set("Retry-After", "15")
			fail(w, http.StatusTooManyRequests, "rate_limited", "too many requests — slow down and retry shortly")
			return
		}
		next(w, r)
	}
}

// userLimit gates one handler behind the per-user limiter class
// (auth-required routes; identity comes from the JWT context).
func (s *Server) userLimit(class string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		uid, err := userIDFrom(r)
		if err != nil || uid == "" {
			fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
			return
		}
		if !s.limiter.allow(class + ":user:" + uid) {
			w.Header().Set("Retry-After", "15")
			fail(w, http.StatusTooManyRequests, "rate_limited", "tutor cooling down — retry in a few seconds")
			return
		}
		next(w, r)
	}
}

// authLimit gates the credential routes behind BOTH a per-IP bucket and
// one global bucket. Per-IP alone is weak against botnets and Render's
// proxy makes XFF partially attacker-controlled; the global bucket caps
// total bcrypt CPU burn no matter how the source IPs are rotated.
func (s *Server) authLimit(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.authGlobal.allow("auth:global") || !s.authIP.allow("auth:ip:"+clientIP(r)) {
			w.Header().Set("Retry-After", "15")
			fail(w, http.StatusTooManyRequests, "rate_limited", "too many attempts - try again shortly")
			return
		}
		next(w, r)
	}
}

// securityHeaders applies the API's baseline response headers to every
// reply. The API serves JSON only, so the CSP locks everything down.
func (s *Server) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "strict-origin-when-cross-origin")
		h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		h.Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}
