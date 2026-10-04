// Package syncer is the silent background asset-sync worker.
//
// When a student completes their profile, a goroutine per user "pulls" the
// localized pack set (past questions, notes, syllabus) for them without
// blocking any request. In G2/G3 this worker graduates from simulating the
// pull (per-pack progress rows) to actually pushing manifests/bundles to
// object storage and mobile push targets. One job per user at a time ,
// re-kicks while running are no-ops.
package syncer

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/store"
)

const perPackDelay = 350 * time.Millisecond

type Syncer struct {
	store    *store.Store
	manifest cbtdata.Manifest
	log      *slog.Logger
	inFlight sync.Map // userID -> struct{}
}

func New(st *store.Store, manifest cbtdata.Manifest, log *slog.Logger) *Syncer {
	return &Syncer{store: st, manifest: manifest, log: log}
}

// Kick starts (or no-ops) a sync job for the user.
func (s *Syncer) Kick(userID string) {
	if _, busy := s.inFlight.LoadOrStore(userID, struct{}{}); busy {
		s.log.Debug("sync already running", "user", userID)
		return
	}
	go func() {
		defer s.inFlight.Delete(userID)
		if err := s.run(userID); err != nil {
			s.log.Error("sync job failed", "user", userID, "err", err)
		}
	}()
}

func (s *Syncer) run(userID string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	exams := s.manifest.Exams
	jobID, err := s.store.CreateSyncJob(ctx, userID, len(exams))
	if err != nil {
		return err
	}
	s.log.Info("sync started", "user", userID, "job", jobID, "packs", len(exams))

	totalBytes := int64(0)
	for i, ex := range exams {
		// G2: replace with real asset pull (R2/CDN → device targets).
		time.Sleep(perPackDelay)
		totalBytes += ex.SizeBytes
		progress := (i + 1) * 100 / len(exams)
		if err := s.store.UpdateSyncJobProgress(ctx, jobID, progress, map[string]any{
			"packsTotal": len(exams), "packsSynced": i + 1, "lastPack": ex.Code,
		}); err != nil {
			return err
		}
	}
	if err := s.store.FinishSyncJob(ctx, jobID, map[string]any{
		"packsSynced": len(exams), "bytes": totalBytes,
	}); err != nil {
		return err
	}
	s.log.Info("sync done", "user", userID, "job", jobID, "packs", len(exams))
	return nil
}
