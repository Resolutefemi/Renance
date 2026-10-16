// Package grading is the concurrent CBT engine: a buffered channel feeding
// a pool of worker goroutines that grade attempts off the request path.
//
// Handlers flip an attempt to 'grading' and return 202 immediately; the
// engine owns everything after that. A stalled or panic-ing grade job can
// never wedge an HTTP handler, and one slow bank never delays another.
package grading

import (
        "context"
        "fmt"
        "log/slog"
        "math"
        "sort"
        "strings"
        "sync"

        "renance.dev/study-api/internal/cbtdata"
        "renance.dev/study-api/internal/daily"
        "renance.dev/study-api/internal/social"
        "renance.dev/study-api/internal/store"
)

// KeySource resolves the server-only answer key for a bank.
type KeySource interface {
        Get(code string) (map[string]store.KeyEntry, bool)
}

// StreakToucher is the learn module's quiz bridge (founder directive
// 2026-10-17: a streak grows on any quiz OR lesson attempt - never on
// app opens). The engine calls it after every graded paper so quiz
//-only students keep their flame alive; learn.Service implements it.
type StreakToucher interface {
        TouchStreakForQuiz(ctx context.Context, userID string)
}

type Job struct {
        AttemptID string
        UserID    string // owner of the attempt - feeds gamification after the grade
        Code      string
        // DailyDay is "2006-01-02" when the attempt is that day's daily
        // challenge (ROADMAP #20); empty for ordinary papers. DurationMs
        // rides along so the daily seat can show the honest sitting time.
        DailyDay   string
        DurationMs *int
        // QuestionMs is the per-question dwell map the client banked during
        // the sitting (pacing telemetry). Grading folds it into the official
        // UTME subject ledger so the result slip can print time per subject.
        QuestionMs map[string]int64
}

type Engine struct {
        jobs    chan Job
        store   *store.Store
        keys    KeySource
        lib     *cbtdata.Library
        streaks StreakToucher // optional; nil skips the learn-streak bridge
        log     *slog.Logger
        wg      sync.WaitGroup
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

// SetStreakToucher wires the learn module's quiz bridge after
// construction (the learn service is built inside httpapi.NewServer,
// after the engine). Nil restores the no-bridge behaviour used by
// tests that never touch learn routes.
func (e *Engine) SetStreakToucher(t StreakToucher) {
        e.streaks = t
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
        result := Score(bundle, key, answers, job.QuestionMs)
        if err := e.store.WriteResult(ctx, job.AttemptID, result); err != nil {
                e.log.Error("grading: write result", "err", err, "attempt", job.AttemptID)
                _ = e.store.SetAttemptStatus(ctx, job.AttemptID, "error")
                return
        }
        // Daily challenge ledger (ROADMAP #20) is best-effort like the rest:
        // the board can miss one seat; a graded paper must never fail for
        // it. Score is already fair (the submit handler pinned answers to
        // the day's selection), but Total is the PACK's size - the seat
        // records the challenge's real size so "7/10" means 7 of 10. It
        // runs FIRST after the grade so the seat is visible as soon as the
        // attempt reads graded.
        if job.DailyDay != "" && job.UserID != "" && bundle.Body != "" {
                challengeTotal := len(daily.QuestionIDs(job.DailyDay, bundle.Body, daily.IDs(bundle)))
                if _, err := e.store.RecordDailyResult(ctx, job.DailyDay, bundle.Body, job.UserID,
                        job.AttemptID, job.Code, result.Score, challengeTotal, job.DurationMs); err != nil {
                        e.log.Error("grading: daily ledger", "err", err, "attempt", job.AttemptID)
                }
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
                // The learn-streak bridge (founder 2026-10-17): the graded
                // paper just became today's streak activity.
                if e.streaks != nil {
                        e.streaks.TouchStreakForQuiz(ctx, job.UserID)
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

        // Feed milestone (founder directive 2026-10-14): a strong mock
        // score is a feed-worthy moment - "Joy scored 360 in JAMB".
        // Daily sprints keep their own board and never post here.
        if job.UserID != "" && job.DailyDay == "" {
                e.postScoreMilestone(ctx, job.UserID, job.Code, bundle.Body, result)
        }
}

// postScoreMilestone announces strong mock results on the Renance feed:
// composite UTME mocks at 250+/400, other banks at 75%+. The milestone
// key carries the score, so beating your best posts again - improving
// students keep their feed alive, repeating a score does not spam it.
func (e *Engine) postScoreMilestone(ctx context.Context, userID, code, body string, result *store.Result) {
        defer func() { _ = recover() }() // a feed hiccup never breaks grading
        if result == nil || result.Total == 0 {
                return
        }
        if strings.HasPrefix(code, "jamb-mock-") && len(result.Subjects) > 0 {
                utme := 0.0
                for _, s := range result.Subjects {
                        utme += s.Score
                }
                score := int(math.Round(utme))
                if score >= 250 {
                        social.Milestone(ctx, e.store.Pool, userID, fmt.Sprintf("jamb_%d", score),
                                fmt.Sprintf("scored %d in JAMB! 🎯", score),
                                map[string]any{"score": score, "exam": "JAMB"})
                }
                return
        }
        pct := 100 * float64(result.Score) / float64(result.Total)
        if pct >= 75 && (body == "WAEC" || body == "NECO" || body == "POST-UTME") {
                score := int(math.Round(pct))
                social.Milestone(ctx, e.store.Pool, userID, fmt.Sprintf("%s_%d", strings.ToLower(body), score),
                        fmt.Sprintf("scored %d%% in %s! 🎯", score, body),
                        map[string]any{"score": score, "exam": body})
        }
}

// TopicRow is one row of the per-topic breakdown.
type TopicRow = store.TopicRow

// Score is a PURE function: bundle + key + picked answers → result.
// Unanswered questions count as wrong; unknown question ids are ignored
// (the submit handler rejects them, this stays forgiving for forensics).
// Theory (essay) questions are self-assessed: they never count toward
// score or total - the model answer unlocks in review instead.
//
// Composite papers (jamb-mock-*) additionally get the official UTME
// subject ledger: every section becomes a SubjectRow whose score is the
// subject's mark out of 100. Use of English divides its correct count by
// its 60-question section, every other subject by its 40-question
// section (2.5 marks per question) - the four subject marks then add to
// the final score out of 400. questionMs (the client's per-question
// dwell map) feeds each subject's time-used column; a nil map simply
// leaves the column at zero.
func Score(bundle *cbtdata.Bundle, key map[string]store.KeyEntry, answers []store.Picked, questionMs map[string]int64) *store.Result {
        picked := make(map[string]string, len(answers))
        for _, a := range answers {
                picked[a.QuestionID] = a.Selected
        }
        score := 0
        total := 0
        perTopic := map[string]*[2]int{} // topic -> [correct, total]
        // Official per-subject ledgers: subject -> row. Only filled when the
        // bundle carries sections (composite papers).
        perSubject := map[string]*store.SubjectRow{}
        subjectOf := map[string]string{}
        if len(bundle.Sections) > 0 {
                for _, sec := range bundle.Sections {
                        row := &store.SubjectRow{Subject: sec.Subject}
                        perSubject[sec.Subject] = row
                        for _, id := range sec.QuestionIDs {
                                subjectOf[id] = sec.Subject
                        }
                }
        }
        for _, q := range bundle.Questions {
                if q.Type == "theory" {
                        continue
                }
                total++
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
                row, onPaper := perSubject[subjectOf[q.ID]]
                if onPaper {
                        row.Total++
                        if picked[q.ID] != "" {
                                row.Attempted++
                        }
                        if ms := questionMs[q.ID]; ms > 0 {
                                row.TimeMs += ms
                        }
                }
                k, ok := key[q.ID]
                if !ok {
                        continue
                }
                if picked[q.ID] == k.Letter {
                        score++
                        bucket[0]++
                        if onPaper {
                                row.Correct++
                        }
                }
        }
        // Subject marks out of 100: correct answers over the section's own
        // question count, times 100 (the standard UTME sections compose at
        // 60 English + 40 per other subject, so this lands on the official
        // divide-by-60 / divide-by-40 rule and stays fair when a bank runs
        // short and the section is smaller).
        subjects := make([]store.SubjectRow, 0, len(perSubject))
        for _, row := range perSubject {
                if row.Total > 0 {
                        row.Score = math.Round((float64(row.Correct)/float64(row.Total))*100*100) / 100
                }
                subjects = append(subjects, *row)
        }
        sort.Slice(subjects, func(i, j int) bool { return subjects[i].Subject < subjects[j].Subject })
        breakdown := make([]TopicRow, 0, len(perTopic))
        for topic, b := range perTopic {
                breakdown = append(breakdown, TopicRow{Topic: topic, Correct: b[0], Total: b[1]})
        }
        sort.Slice(breakdown, func(i, j int) bool { return breakdown[i].Topic < breakdown[j].Topic })
        res := &store.Result{Score: score, Total: total, Breakdown: breakdown}
        if len(subjects) > 0 {
                res.Subjects = subjects
        }
        return res
}

// StaticKeyCache is an eager snapshot of sealed answer keys (tests and
// tiny deployments). Production rides LazyKeyCache below.
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

// Put installs one bank's key at runtime (composite UTME mock papers
// get their sealed key assembled from the banks' keys at composition
// time). Part of KeySource consumers that need to grow the cache.
func (c *StaticKeyCache) Put(code string, keys map[string]store.KeyEntry) {
        c.mu.Lock()
        defer c.mu.Unlock()
        c.keys[code] = keys
}

// LazyKeyCache resolves answer keys ON DEMAND from the content library
// instead of holding all 1009 banks' keys resident at boot (memory
// doctrine, 2026-10-14: the eager boot cache pushed the Render free
// instance over its 512Mi ceiling the moment the content library grew).
// Static-bank keys parse from disk on first Get and live in a bounded
// FIFO; composed-paper keys arrive via Put and are pinned (a graded
// sitting must always find its key until the process restarts, and the
// paper itself re-registers on demand - the pin rides the same cap).
type LazyKeyCache struct {
        lib    *cbtdata.Library
        mu     sync.Mutex
        lazy   map[string]map[string]store.KeyEntry
        lazyQ  []string
        pinned map[string]map[string]store.KeyEntry
        pinQ   []string
}

const (
        lazyKeyCap = 128 // static banks cached after a Get miss
        pinKeyCap  = 256 // composed papers (bounded like registered papers)
)

func NewLazyKeyCache(lib *cbtdata.Library) *LazyKeyCache {
        return &LazyKeyCache{
                lib:    lib,
                lazy:   map[string]map[string]store.KeyEntry{},
                pinned: map[string]map[string]store.KeyEntry{},
        }
}

func (c *LazyKeyCache) Get(code string) (map[string]store.KeyEntry, bool) {
        c.mu.Lock()
        if keys, ok := c.pinned[code]; ok {
                c.mu.Unlock()
                return keys, true
        }
        if keys, ok := c.lazy[code]; ok {
                c.mu.Unlock()
                return keys, true
        }
        c.mu.Unlock()
        // Parse the bank (or lift its keys from the library's bundle LRU).
        raw, ok := c.lib.KeysFor(code)
        if !ok {
                return nil, false
        }
        keys := make(map[string]store.KeyEntry, len(raw))
        for qid, k := range raw {
                keys[qid] = store.KeyEntry{Letter: k.Letter, Explanation: k.Explanation, AnswerImage: k.AnswerImage, Video: k.Video}
        }
        c.mu.Lock()
        if _, exists := c.lazy[code]; !exists {
                c.lazy[code] = keys
                c.lazyQ = append(c.lazyQ, code)
                for len(c.lazyQ) > lazyKeyCap {
                        oldest := c.lazyQ[0]
                        c.lazyQ = c.lazyQ[1:]
                        delete(c.lazy, oldest)
                }
        }
        c.mu.Unlock()
        return keys, true
}

// Put installs one bank's key at runtime (composite UTME mock papers).
func (c *LazyKeyCache) Put(code string, keys map[string]store.KeyEntry) {
        c.mu.Lock()
        defer c.mu.Unlock()
        if _, exists := c.pinned[code]; !exists {
                c.pinQ = append(c.pinQ, code)
        }
        c.pinned[code] = keys
        for len(c.pinQ) > pinKeyCap {
                oldest := c.pinQ[0]
                c.pinQ = c.pinQ[1:]
                delete(c.pinned, oldest)
        }
}
