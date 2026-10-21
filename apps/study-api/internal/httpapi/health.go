package httpapi

import (
        "context"
        "net/http"
        "os"
        "time"

        "renance.dev/study-api/internal/store"
)

// buildVersion reports the git commit this binary was built from.
// Render injects RENDER_GIT_COMMIT at build/run time; anything else
// (local runs, CI) reads as "dev". Surfaced by /healthz so a DB-free
// GET proves which deploy is live.
var buildVersion = func() string {
        if c := os.Getenv("RENDER_GIT_COMMIT"); len(c) >= 7 {
                return c[:7]
        }
        return "dev"
}()

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
//      GET /healthz  - PROCESS health only. ZERO database calls. Any
//                      monitor, cron or keep-warm pinger may hammer this
//                      as often as it likes without ever waking Neon.
//      GET /readyz   - the REAL Postgres probe. Humans and CI use it;
//                      keep-warm pingers must NOT point here.
//
// Deploy-time safety is unchanged: store.Connect still pings Postgres
// once at boot, so a broken DATABASE_URL fails the deploy exactly as
// loudly as before - no handler needs to re-verify it per request.

// handleHealth answers the process-level probe: instantly, and never
// by touching Postgres. Uptime monitors and keep-warm pingers point
// HERE (or at /app-version) - both are DB-free, so Neon can actually
// scale to zero between real student traffic.
//
// The response also echoes the git commit the binary was built from
// (Render injects RENDER_GIT_COMMIT), so a DB-free GET proves WHICH
// deploy is live - "is the fix actually shipped?" without waking Neon.
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
        // The blob tier is a pure memory check (no bucket call, no
        // database call) - still DB-free by doctrine.
        blobs := "off"
        if s.learn != nil && s.learn.Blobs != nil {
                blobs = "r2"
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "status":  "ok",
                "service": "renance-study-api",
                "db":      "not-probed (see /readyz)",
                "blobs":   blobs,
                "version": buildVersion,
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
        // The split-horizon domains report individually: the user
        // database gates readiness (the split router degrades content and
        // cache onto it), while a lagging catalog or lesson cache shows
        // here without failing the probe.
        report := map[string]any{
                "status":  "ok",
                "service": "renance-study-api",
                "db":      "ok",
                "time":    time.Now().UTC().Format(time.RFC3339),
        }
        probe := func(name string, pool store.Pool) {
                if pool == nil {
                        return
                }
                pctx, pcancel := context.WithTimeout(context.Background(), 3*time.Second)
                defer pcancel()
                if err := pool.Ping(pctx); err != nil {
                        report[name] = "unreachable: " + truncateErr(err)
                        return
                }
                report[name] = "ok"
        }
        if sp, ok := s.store.Pool.(*store.Split); ok {
                probe("content", sp.Content)
                probe("cache", sp.Cache)
        }
        writeJSON(w, http.StatusOK, report)
}
