// Renance study-api, ERA-2 walking skeleton entrypoint.
//
// Boot order: config → content library (doctrine enforcement) → store +
// migrations → in-memory key cache → grading engine → HTTP server.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"runtime/debug"
	"strconv"
	"syscall"
	"time"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/config"
	"renance.dev/study-api/internal/grading"
	"renance.dev/study-api/internal/httpapi"
	"renance.dev/study-api/internal/learn"
	"renance.dev/study-api/internal/plans"
	"renance.dev/study-api/internal/store"
	"renance.dev/study-api/internal/syncer"
)

func main() {
	// Render free plan ceiling is 512Mi and the instance shares it with
	// the OS + health checker. A soft Go heap limit turns the last
	// ~90Mi into aggressive GC instead of an OOM kill (founder report
	// 2026-10-14: "Out of memory (used over 512Mi)" at boot).
	debug.SetMemoryLimit(420 << 20)

	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	cfg, err := config.Load()
	if err != nil {
		log.Error("config", "err", err)
		os.Exit(1)
	}

	dataDir := cfg.DataDir
	if dataDir == "" {
		wd, _ := os.Getwd()
		dataDir = cbtdata.FindDataDir(wd)
		if dataDir == "" {
			log.Error("content: no data/ directory with manifest.json found (set DATA_DIR)")
			os.Exit(1)
		}
	}
	lib, err := cbtdata.Load(dataDir)
	if err != nil {
		log.Error("content", "err", err)
		os.Exit(1)
	}
	log.Info("content library loaded", "dataDir", dataDir, "packs", len(lib.Manifest().Exams))

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	// The multi-database fallback (founder directive 2026-10-15: "can
	// the project share two databases, or use another as a backup when
	// the first one's free trial ends?"): DATABASE_URL (Neon) first,
	// then FALLBACK_DATABASE_URLS (the founder's Supabase + InsForge
	// DSNs). The first candidate that connects AND pings wins - a
	// suspended primary boots straight onto the fallback, and the
	// migrations + curriculum seed below provision it automatically.
	// The runtime half (dbwatch, CU-aware) rides inside the HTTP
	// handler chain (internal/httpapi/dbwatch.go).
	st, err := store.ConnectWithFallback(ctx, cfg.DatabaseURL, cfg.FallbackDatabaseURLs, log)
	if err != nil {
		log.Error("db", "err", err)
		os.Exit(1)
	}
	defer st.Close()
	if err := st.Migrate(ctx); err != nil {
		log.Error("migrate", "err", err)
		os.Exit(1)
	}
	log.Info("database ready (study schema current)")

	// The learn curriculum seeds itself once, in the background
	// (founder directive 2026-10-14: Supreme merges into Renance).
	// First boot pays the ~140k-row insert; every later boot
	// returns on the count check. Boot never blocks on it.
	go func() {
		seedCtx, seedCancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer seedCancel()
		if err := learn.SeedIfEmpty(seedCtx, st.Pool, log); err != nil {
			log.Error("learn: curriculum seed failed", "err", err)
		}
	}()

	// Founder directive, 2026-09-28: student subscriptions are PAUSED -
	// everyone rides premium for free. Every boot, any entitlement row
	// that is not premium-active (new signups since last boot, expired
	// grants) is stamped premium for a year so the DATABASE itself
	// says premium - the blue tick, the wallet and the console all
	// agree with the gate. Lifetime grants are never pulled back.
	if !plans.StudentBillingEnabled {
		upgraded, err := st.GrantEveryonePremium(ctx)
		if err != nil {
			log.Error("open-door premium backfill", "err", err)
		} else {
			log.Info("student billing paused: everyone rides premium",
				"rowsUpgraded", upgraded)
		}
	}

	// The content library is the single source of truth for sealed keys
	// (founder directive, 2026-09). Keys live in memory only - the
	// database no longer stores 84.5k+ key rows, so restarts cannot
	// bloat the database with repeated seed upserts. Since the memory
	// doctrine (2026-10-14) the keys are LAZY: they parse from the bank
	// file on first use into a bounded cache, so boot no longer holds
	// all 1009 banks' answer material in RAM.
	keyCache := grading.NewLazyKeyCache(lib)
	log.Info("answer keys lazy cache ready",
		"banks", len(lib.Manifest().Exams),
		"keyed", lib.KeyedBankCount(),
		"source", "content library (on demand)")

	engine := grading.Start(st, keyCache, lib, cfg.GradeWorkers, cfg.GradeQueue, log)
	defer engine.Stop()

	srv := httpapi.NewServer(cfg, log, st, lib, engine, syncer.New(st, lib.Manifest(), log), keyCache)
	// The arena hub owns live sockets and match goroutines; it must
	// release both before the process exits.
	if hub := srv.Hub(); hub != nil {
		defer hub.Stop()
	}

	httpServer := &http.Server{
		Addr:              ":" + strconv.Itoa(cfg.Port),
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Info("study-api listening", "port", cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("http server", "err", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	log.Info("shutting down")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	_ = httpServer.Shutdown(shutdownCtx)
}
