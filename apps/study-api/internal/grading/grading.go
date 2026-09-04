// Package grading is the concurrent CBT engine: a buffered channel feeding
// a pool of worker goroutines that grade attempts off the request path.
//
// Handlers flip an attempt to 'grading' and return 202 immediately; the
// engine owns everything after that. A stalled or panic-ing grade job can
// never wedge an HTTP handler, and one slow bank never delays another.
package grading

import (
	"context"
	"log/slog"
	"sort"
	"sync"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/store"
)

// KeySource resolves the server-only answer key for a bank.
type KeySource interface {
	Get(code string) (map[string]store.KeyEntry, bool)
}

type Job struct {
	AttemptID string
	UserID    string // owner of the attempt - feeds gamification after the grade
	Code      string
}

type Engine struct {
	jobs  chan Job
	store *store.Store
	keys  KeySource
	lib   *cbtdata.Library
	log   *slog.Logger
	wg    sync.WaitGroup
}

// Start spins up workers. Stop() drains and joins them.
func Start(st *store.Store, keys KeySource, lib *cbtdata.Library, workers, queue int, log *slog.Logger) *Engine {
	e := &Engine{
		jobs:  make(chan Job, queue),
		store: st,
		keys:  keys,
		lib:   lib,
		log:   log,
	}
	for i := 0; i < workers; i++ {
		e.wg.Add(1)
		go e.worker(i)
	}
	return e
}

// Enqueue submits a grading job; false means the queue is saturated
// (handlers translate that to 503).
func (e *Engine) Enqueue(j Job) bool {
	select {
	case e.jobs <- j:
		return true
	default:
		return false
	}
}

func (e *Engine) Stop() {
	close(e.jobs)
	e.wg.Wait()
}

func (e *Engine) worker(n int) {
	defer e.wg.Done()
	for job := range e.jobs {
		func() {
			defer func() {
				if r := recover(); r != nil {
					e.log.Error("grading panic", "worker", n, "attempt", job.AttemptID, "panic", r)
					_ = e.store.SetAttemptStatus(context.Background(), job.AttemptID, "error")
				}
			}()
			e.grade(context.Background(), job, n)
		}()
	}
}

func (e *Engine) grade(ctx context.Context, job Job, worker int) {
	bundle, ok := e.lib.Bundle(job.Code)
	if !ok {
		e.log.Error("grading: unknown bank", "code", job.Code, "attempt", job.AttemptID)
		_ = e.store.SetAttemptStatus(ctx, job.AttemptID, "error")
		return
	}
	key, ok := e.keys.Get(job.Code)
	if !ok {
		e.log.Error("grading: no answer key", "code", job.Code, "attempt", job.AttemptID)
		_ = e.store.SetAttemptStatus(ctx, job.AttemptID, "error")
		return
	}
	answers, err := e.store.AnswersForAttempt(ctx, job.AttemptID)
	if err != nil {
		e.log.Error("grading: load answers", "err", err, "attempt", job.AttemptID)
		_ = e.store.SetAttemptStatus(ctx, job.AttemptID, "error")
		return
	}
	result := Score(bundle, key, answers)
	if err := e.store.WriteResult(ctx, job.AttemptID, result); err != nil {
		e.log.Error("grading: write result", "err", err, "attempt", job.AttemptID)
		_ = e.store.SetAttemptStatus(ctx, job.AttemptID, "error")
		return
	}
	// Gamification is best-effort: a badge/streak failure must never
	// turn a successfully graded attempt into an error.
	if job.UserID != "" {
		if out, err := e.store.ApplyGrade(ctx, job.UserID, result.Score, result.Total); err != nil {
			e.log.Error("grading: gamification", "err", err, "attempt", job.AttemptID)
		} else if len(out.NewAwards) > 0 {
			codes := make([]string, 0, len(out.NewAwards))
			for _, a := range out.NewAwards {
				codes = append(codes, a.Code)
			}
			e.log.Info("badges awarded", "user", job.UserID, "codes", codes)
		}
	}
	// Spaced repetition (ROADMAP #3) is best-effort too: a scheduling
	// failure must never turn a successfully graded attempt into an
	// error - the topic simply keeps its previous due date.
	if job.UserID != "" {
		if err := e.store.ScheduleReview(ctx, job.UserID, result.Breakdown); err != nil {
			e.log.Error("grading: review schedule", "err", err, "attempt", job.AttemptID)
		}
	}
	e.log.Info("graded", "worker", worker, "attempt", job.AttemptID,
		"code", job.Code, "score", result.Score, "total", result.Total)
}

// TopicRow is one row of the per-topic breakdown.
type TopicRow = store.TopicRow

// Score is a PURE function: bundle + key + picked answers → result.
// Unanswered questions count as wrong; unknown question ids are ignored
// (the submit handler rejects them, this stays forgiving for forensics).
func Score(bundle *cbtdata.Bundle, key map[string]store.KeyEntry, answers []store.Picked) *store.Result {
	picked := make(map[string]string, len(answers))
	for _, a := range answers {
		picked[a.QuestionID] = a.Selected
	}
	score := 0
	perTopic := map[string]*[2]int{} // topic -> [correct, total]
	for _, q := range bundle.Questions {
		topic := q.Topic
		if topic == "" {
			topic = "General"
		}
		bucket, ok := perTopic[topic]
		if !ok {
			bucket = &[2]int{}
			perTopic[topic] = bucket
		}
		bucket[1]++
		k, ok := key[q.ID]
		if !ok {
			continue
		}
		if picked[q.ID] == k.Letter {
			score++
			bucket[0]++
		}
	}
	breakdown := make([]TopicRow, 0, len(perTopic))
	for topic, b := range perTopic {
		breakdown = append(breakdown, TopicRow{Topic: topic, Correct: b[0], Total: b[1]})
	}
	sort.Slice(breakdown, func(i, j int) bool { return breakdown[i].Topic < breakdown[j].Topic })
	return &store.Result{Score: score, Total: len(bundle.Questions), Breakdown: breakdown}
}

// StaticKeyCache is the boot-time snapshot of study.answer_keys.
type StaticKeyCache struct {
	mu   sync.RWMutex
	keys map[string]map[string]store.KeyEntry
}

func NewStaticKeyCache(keys map[string]map[string]store.KeyEntry) *StaticKeyCache {
	return &StaticKeyCache{keys: keys}
}

func (c *StaticKeyCache) Get(code string) (map[string]store.KeyEntry, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	k, ok := c.keys[code]
	return k, ok
}

// Replace swaps the cache (future: content pipeline hot reload).
func (c *StaticKeyCache) Replace(keys map[string]map[string]store.KeyEntry) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.keys = keys
}
