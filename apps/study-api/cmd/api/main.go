// Renance study-api, ERA-2 walking skeleton entrypoint.
//
// Boot order: config → content library (doctrine enforcement) → store +
// migrations → key cache + seed → grading engine → HTTP server.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
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

	if err := seedKeys(st, lib, dataDir, log); err != nil {
		log.Error("seed keys", "err", err)
		os.Exit(1)
	}
	keysRaw, err := st.AllKeys(ctx)
	if err != nil {
		log.Error("load keys", "err", err)
		os.Exit(1)
	}
	keyCache := grading.NewStaticKeyCache(keysRaw)
	log.Info("answer keys cached", "banks", len(keysRaw))

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

// seedKeys upserts the boot-time answer keys into the store. Since the
// founder directive merged answers into the question banks (2026-09),
// the library's harvested key map is the primary source; a legacy
// <dataDir>/answer-keys/**.json tree is still honored when present for
// mid-transition deployments.
func seedKeys(st *store.Store, lib *cbtdata.Library, dataDir string, log *slog.Logger) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	if err := seedKeyFilesIfPresent(ctx, st, dataDir, log); err != nil {
		return err
	}
	banks := 0
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
		if _, err := st.SeedKeys(ctx, code, entries); err != nil {
			return fmt.Errorf("seed keys %s: %w", code, err)
		}
		banks++
	}
	log.Info("answer keys seeded", "banks", banks, "source", "question banks")
	return nil
}

// seedKeyFilesIfPresent upserts keys from <dataDir>/answer-keys/**.json
// when that legacy folder exists (subdirectories organize key
// generations). Absent folder → no-op, the banks carry their answers.
func seedKeyFilesIfPresent(ctx context.Context, st *store.Store, dataDir string, log *slog.Logger) error {
	dir := filepath.Join(dataDir, "answer-keys")
	if _, err := os.Stat(dir); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	var files []string
	err := filepath.WalkDir(dir, func(path string, d os.DirEntry, werr error) error {
		if werr != nil {
			return werr
		}
		if !d.IsDir() && filepath.Ext(d.Name()) == ".json" {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		return err
	}
	for _, file := range files {
		raw, err := os.ReadFile(file)
		if err != nil {
			return err
		}
		var parsed struct {
			Code    string `json:"code"`
			Answers map[string]struct {
				Letter      string `json:"letter"`
				Explanation string `json:"explanation"`
				AnswerImage string `json:"answer_image"`
				Video       string `json:"video"`
			} `json:"answers"`
		}
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return err
		}
		if parsed.Code == "" || len(parsed.Answers) == 0 {
			log.Warn("skipping key file without code/answers", "file", filepath.Base(file))
			continue
		}
		keys := map[string]store.KeyEntry{}
		for qid, k := range parsed.Answers {
			keys[qid] = store.KeyEntry{Letter: k.Letter, Explanation: k.Explanation, AnswerImage: k.AnswerImage, Video: k.Video}
		}
		n, err := st.SeedKeys(ctx, parsed.Code, keys)
		if err != nil {
			return err
		}
		log.Info("seeded answer keys", "code", parsed.Code, "keys", n, "file", filepath.Base(file))
	}
	return nil
}
