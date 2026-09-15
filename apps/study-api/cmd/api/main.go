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
        "strconv"
        "syscall"
        "time"

        "renance.dev/study-api/internal/cbtdata"
        "renance.dev/study-api/internal/config"
        "renance.dev/study-api/internal/grading"
        "renance.dev/study-api/internal/httpapi"
        "renance.dev/study-api/internal/store"
        "renance.dev/study-api/internal/syncer"
)

func main() {
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
        st, err := store.Connect(ctx, cfg.DatabaseURL)
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

        // The content library is the single source of truth for sealed keys
        // (founder directive, 2026-09). Keys live in memory only — the
        // database no longer stores 84.5k+ key rows, so restarts cannot
        // bloat the database with repeated seed upserts.
        keysRaw := buildKeyCache(lib)
        keyCache := grading.NewStaticKeyCache(keysRaw)
        log.Info("answer keys cached", "banks", len(keysRaw), "source", "content library")

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

// buildKeyCache converts the content library's harvested key maps into
// the store-shaped entries the grading cache serves. Sealed keys stay
// server-side in memory; nothing is persisted to the database anymore.
func buildKeyCache(lib *cbtdata.Library) map[string]map[string]store.KeyEntry {
        out := make(map[string]map[string]store.KeyEntry)
        for code, keys := range lib.AllKeys() {
                if len(keys) == 0 {
                        continue
                }
                entries := make(map[string]store.KeyEntry, len(keys))
                for qid, k := range keys {
                        entries[qid] = store.KeyEntry{
                                Letter:      k.Letter,
                                Explanation: k.Explanation,
                                AnswerImage: k.AnswerImage,
                                Video:       k.Video,
                        }
                }
                out[code] = entries
        }
        return out
}
