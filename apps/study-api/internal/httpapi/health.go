package httpapi

import (
	"context"
	"net/http"
	"time"
)

// NEON COMPUTE BUDGET (founder report 2026-10-14: Neon "81% of the 100
// CU-hour monthly allowance" by mid-month). The math: 80.5 CU-hours over
// 13.4 days is EXACTLY 0.25 CU x 24h - the database never slept once,
// because something pings an endpoint that touches Postgres every few
// minutes (uptime monitors, keep-warm crons) and Neon's scale-to-zero
// only fires after 5 query-free minutes. Every wake costs the same as
// running all day.
//
// The doctrine, therefore:
//
//	GET /healthz  - PROCESS health only. ZERO database calls. Any
//	                monitor, cron or keep-warm pinger may hammer this
//	                as often as it likes without ever waking Neon.
//	GET /readyz   - the REAL Postgres probe. Humans and CI use it;
//	                keep-warm pingers must NOT point here.
//
// Deploy-time safety is unchanged: store.Connect still pings Postgres
// once at boot, so a broken DATABASE_URL fails the deploy exactly as
// loudly as before - no handler needs to re-verify it per request.

// handleHealth answers the process-level probe: instantly, and never
// by touching Postgres. Uptime monitors and keep-warm pingers point
// HERE (or at /app-version) - both are DB-free, so Neon can actually
// scale to zero between real student traffic.
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "renance-study-api",
		"db":      "not-probed (see /readyz)",
		"time":    time.Now().UTC().Format(time.RFC3339),
	})
}

// handleReady answers the database probe: one real Pool.Ping against
// Postgres. CI E2E and humans on a browser use it to confirm the Neon
// connection is alive. It is deliberately NOT whitelisted for tools in
// the bot shield, and no monitor or keep-warm cron should point here -
// every call wakes the database and burns compute hours.
func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	if err := s.store.Pool.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"status":  "degraded",
			"service": "renance-study-api",
			"db":      "unreachable: " + truncateErr(err),
			"time":    time.Now().UTC().Format(time.RFC3339),
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "renance-study-api",
		"db":      "ok",
		"time":    time.Now().UTC().Format(time.RFC3339),
	})
}
