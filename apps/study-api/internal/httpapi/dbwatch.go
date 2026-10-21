// dbwatch.go - the CU-aware database-down detector (founder directive
// 2026-10-15, the runtime half of the multi-database fallback).
//
// THE PROBLEM IT SOLVES: when the primary database dies under a warm
// process (the Neon free allowance running out, the project
// suspending), every query starts failing but nothing crashes - the
// API keeps answering 500s ("Could not save that - check your
// connection") forever, and the boot fallback never gets a chance.
//
// WHY NOT A SCHEDULED PING: a periodic pool.Ping is exactly the
// pattern the /healthz doctrine (2026-10-14) bans - it keeps a
// serverless Neon compute awake around the clock and burns the
// 100 CU-hour free allowance in days. This watchdog NEVER touches the
// database on a schedule.
//
// HOW IT WORKS INSTEAD: the middleware below counts 5xx responses the
// API itself produces. Only when a BURST of them appears (real
// students really failing) does it probe the pool twice, 30 seconds
// apart. A database that answers either probe is alive - a bug storm,
// an AI-provider outage - and the process stays up. A database that
// fails both probes is down: the watchdog exits non-zero so Render
// restarts the service, and the boot fallback
// (store.ConnectWithFallback) re-routes to the next live DSN.
//
// CU cost of the probes themselves: they only ever run while requests
// are already failing en masse. If the database is alive the failing
// traffic has it awake anyway; if it is suspended the probes cannot
// wake anything (connection refused, no compute hours spent).
package httpapi

import (
	"bufio"
	"context"
	"errors"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"
)

const (
	dbwatchWindow    = 5 * time.Minute // failures inside this window count as a burst
	dbwatchThreshold = 5               // 5xx responses inside the window that arm the probe
	dbwatchProbeGap  = 30 * time.Second
	dbwatchProbeWait = 8 * time.Second
)

// dbwatchdog is the counting + probing state. All fields are safe for
// concurrent use: the middleware runs on every request goroutine, the
// sampler on one background goroutine.
type dbwatchdog struct {
	// failures is the ring of recent 5xx timestamps, guarded by mu (a
	// buffered channel of 1 used as a binary semaphore: acquire =
	// send, release = receive - stdlib-only, no contention surprises).
	failures []time.Time
	mu       chan struct{}
	// recent5xx is the lock-free mirror of len(failures) the sampler
	// reads without touching the ring.
	recent5xx atomic.Int64
}

func newDBWatchdog() *dbwatchdog {
	// mu is a buffered channel of 1 used as a mutex: acquire = send,
	// release = receive. stdlib-only, zero allocation contention.
	return &dbwatchdog{mu: make(chan struct{}, 1), failures: make([]time.Time, 0, 64)}
}

func (d *dbwatchdog) lock()   { d.mu <- struct{}{} }
func (d *dbwatchdog) unlock() { <-d.mu }

// noteFailure records one 5xx response.
func (d *dbwatchdog) noteFailure() {
	now := time.Now()
	d.lock()
	d.failures = append(d.failures, now)
	// Trim entries older than the window while we hold the lock.
	cut := 0
	for cut < len(d.failures) && now.Sub(d.failures[cut]) > dbwatchWindow {
		cut++
	}
	if cut > 0 {
		d.failures = d.failures[cut:]
	}
	burst := int64(len(d.failures))
	d.unlock()
	d.recent5xx.Store(burst)
}

// burstCount returns how many 5xx landed inside the window.
func (d *dbwatchdog) burstCount() int64 { return d.recent5xx.Load() }

// dbWatch wraps the whole router: every 5xx response the API writes is
// counted; the sampler goroutine decides what to do about it.
func (s *Server) dbWatch(next http.Handler) http.Handler {
	wd := newDBWatchdog()
	if s.store == nil || s.store.Pool == nil || s.log == nil {
		// No database or no logger at all (unit tests): pass through
		// untouched - the sampler must never nil-panic.
		return next
	}
	// DB_FAIL_EXIT=0 keeps the watchdog counting but never exiting -
	// the founder's kill switch for a paranoid deploy.
	exitEnabled := envBoolDefault("DB_FAIL_EXIT", true)
	go wd.sampler(s, exitEnabled)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		if rec.status >= 500 {
			wd.noteFailure()
		}
	})
}

// sampler is the one background goroutine: every 30 seconds it looks
// at the burst count and, when a burst is armed, probes the pool.
func (d *dbwatchdog) sampler(s *Server, exitEnabled bool) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		burst := d.burstCount()
		if burst < dbwatchThreshold {
			continue
		}
		// A burst of real failures: probe the database (twice, 30s
		// apart). Alive at any point -> reset and stay up.
		if d.probeOK(s) {
			d.reset(s, burst, "probe answered - staying up")
			continue
		}
		time.Sleep(dbwatchProbeGap)
		if d.probeOK(s) {
			d.reset(s, burst, "second probe answered - staying up")
			continue
		}
		if !exitEnabled {
			s.log.Error("dbwatch: database probes failing but DB_FAIL_EXIT=0 - staying up",
				"recent5xx", burst)
			continue
		}
		s.log.Error("dbwatch: the active database is down - exiting so the platform restart re-routes to a fallback DSN",
			"recent5xx", burst)
		os.Exit(1)
	}
}

func (d *dbwatchdog) probeOK(s *Server) bool {
	ctx, cancel := context.WithTimeout(context.Background(), dbwatchProbeWait)
	defer cancel()
	return s.store.Pool.Ping(ctx) == nil
}

func (d *dbwatchdog) reset(s *Server, burst int64, why string) {
	d.lock()
	d.failures = d.failures[:0]
	d.unlock()
	d.recent5xx.Store(0)
	s.log.Warn("dbwatch: 5xx burst but database is alive",
		"recent5xx", burst, "verdict", why)
}

// statusRecorder captures the response status so the middleware can
// count server errors. It deliberately passes Flush, Hijack and
// Unwrap through: the arena websocket route upgrades via
// gorilla/websocket (http.Hijacker), SSE handlers Flush, and net/http
// itself probes for the underlying writer.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	if r.status == 0 {
		r.status = code
	}
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}
	return r.ResponseWriter.Write(b)
}

func (r *statusRecorder) Flush() {
	if f, ok := r.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if h, ok := r.ResponseWriter.(http.Hijacker); ok {
		return h.Hijack()
	}
	return nil, nil, errors.New("dbwatch: underlying writer is not hijackable")
}

// envBoolDefault reads a boolean switch; DB_FAIL_EXIT=0/false/no/off
// disables the exit, anything else keeps the default.
func envBoolDefault(key string, def bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	if n, err := strconv.Atoi(v); err == nil {
		return n != 0
	}
	switch v {
	case "0", "f", "false", "no", "off", "OFF", "False", "FALSE":
		return false
	default:
		return true
	}
}
