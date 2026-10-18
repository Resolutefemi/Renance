// r2fill - the founder's 8GB archive filler (October 2026): stream the
// catalog queue, synthesize every remaining lesson with the app's own
// deterministic engine (internal/learn/synth, the same code the API's
// agent path runs, NO LLM in the loop), and PUT one blob per topic into
// the R2 bucket. Stops cleanly the moment the bucket reaches the byte
// target, so the archive never crosses the founder's line. The time
// budget flag makes every run a clean resumable chunk: re-run and the
// fresh LIST skips everything the last chunk landed.
//
// Class A discipline: exactly one PUT per generated lesson plus one
// LIST page per 1000 existing keys at startup. No re-PUTs (existing
// keys skip), no chunked uploads, no probes. Everything else in the
// run is CPU.
//
// Inputs:
//
//	-queue  JSONL rows {"tid","title","course","dept","faculty","unit"}
//	        (produced by scripts/dump_queue.py from the Supabase catalog)
//	-target-mb  stop when (startup bytes + bytes pushed) reaches it
//
// Environment: R2_ACCOUNT_ID (or R2_ENDPOINT), R2_BUCKET,
// R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, optional R2_PREFIX - the same
// variables the API boots with.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"renance.dev/study-api/internal/learn"
	"renance.dev/study-api/internal/learn/synth"
	"renance.dev/study-api/internal/r2store"
)

type qRow struct {
	TID     string `json:"tid"`
	Title   string `json:"title"`
	Course  string `json:"course"`
	Dept    string `json:"dept"`
	Faculty string `json:"faculty"`
	Unit    int    `json:"unit"`
}

func main() {
	queuePath := flag.String("queue", "/home/z/my-project/scripts/queue.jsonl", "catalog queue JSONL")
	targetMB := flag.Int("target-mb", 8192, "stop when bucket bytes reach this many MB")
	workers := flag.Int("workers", 12, "concurrent PUT lanes")
	firstN := flag.Int("n", 0, "process at most this many eligible rows (0 = all)")
	every := flag.Int("every", 500, "progress line every N pushes")
	maxSeconds := flag.Int("max-seconds", 0, "stop cleanly after this many seconds (0 = run to the target)")
	statePath := flag.String("state", "/home/z/my-project/scripts/.r2fill_state.json", "resume state file")
	verify := flag.Bool("verify", false, "force a fresh full bucket LIST and rebuild the state from it")
	packs := flag.Bool("packs", false, "pack mode: many lessons per object, ONE PUT per shard - the whole remaining archive lands in at most 60k Class A PUTs (the 500k budget path)")
	flag.Parse()

	log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelWarn}))
	blobs := r2store.FromEnv(log)
	if blobs == nil {
		fmt.Fprintln(os.Stderr, "r2fill: set R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY first")
		os.Exit(1)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Pack mode takes a different spine entirely: no verify LIST,
	// no per topic pipeline - skip set, shard scan, one PUT per
	// shard. See packs.go for the budget math.
	if *packs {
		skip := loadSkipSet(strings.TrimSuffix(*statePath, ".json")+"_existing.json", strings.TrimSuffix(*statePath, ".json")+"_done.txt")
		runPacks(ctx, blobs, skip, packOpts{
			queue:      *queuePath,
			statePath:  *statePath,
			workers:    *workers,
			maxShards:  *firstN,
			every:      *every,
			maxSeconds: *maxSeconds,
		})
		return
	}

	// Startup cost discipline: a full LIST is sequential at roughly one
	// second per 1000 objects, so at archive scale it would eat minutes
	// of every chunk. The bucket is verified ONCE into the state file;
	// every later chunk resumes from the state plus the append-only done
	// ledger (one line per landed PUT) and spends zero LIST operations.
	type fillState struct {
		VerifiedObjects int64  `json:"verified_objects"`
		VerifiedBytes   int64  `json:"verified_bytes"`
		ExistingFile    string `json:"existing_file"`
		PushedTotal     int64  `json:"pushed_total"`
		PushedBytes     int64  `json:"pushed_bytes"`
	}
	type sizeMap map[string]int64
	existingFile := strings.TrimSuffix(*statePath, ".json") + "_existing.json"
	donePath := strings.TrimSuffix(*statePath, ".json") + "_done.txt"

	var existing sizeMap
	var startBytes, carryPushed, carryPushedBytes int64
	var err error
	st, serr := func() (*fillState, error) {
		raw, err := os.ReadFile(*statePath)
		if err != nil {
			return nil, err
		}
		var s fillState
		err = json.Unmarshal(raw, &s)
		return &s, err
	}()
	if *verify || serr != nil || st == nil {
		existing, err = blobs.ListLessons(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "r2fill: list bucket: %v\n", err)
			os.Exit(1)
		}
		for _, sz := range existing {
			startBytes += sz
		}
		raw, _ := json.Marshal(existing)
		if werr := os.WriteFile(existingFile, raw, 0644); werr != nil {
			fmt.Fprintf(os.Stderr, "r2fill: write existing cache: %v\n", werr)
			os.Exit(1)
		}
		st = &fillState{VerifiedObjects: int64(len(existing)), VerifiedBytes: startBytes, ExistingFile: existingFile}
		if raw, err := json.Marshal(st); err == nil {
			_ = os.WriteFile(*statePath, raw, 0644)
		}
		if cerr := os.WriteFile(donePath, nil, 0644); cerr != nil {
			fmt.Fprintf(os.Stderr, "r2fill: reset done ledger: %v\n", cerr)
			os.Exit(1)
		}
		fmt.Printf("r2fill: verified %d objects (%.1f MB) into %s\n", len(existing), float64(startBytes)/1048576, *statePath)
	} else {
		existing = sizeMap{}
		raw, rerr := os.ReadFile(st.ExistingFile)
		if rerr != nil {
			fmt.Fprintf(os.Stderr, "r2fill: read existing cache: %v\n", rerr)
			os.Exit(1)
		}
		if uerr := json.Unmarshal(raw, &existing); uerr != nil {
			fmt.Fprintf(os.Stderr, "r2fill: parse existing cache: %v\n", uerr)
			os.Exit(1)
		}
		doneRaw, derr := os.ReadFile(donePath)
		if derr != nil {
			fmt.Fprintf(os.Stderr, "r2fill: read done ledger: %v\n", derr)
			os.Exit(1)
		}
		for _, line := range strings.Split(string(doneRaw), "\n") {
			if id := strings.TrimSpace(line); id != "" {
				existing[id] = 1
			}
		}
		startBytes, carryPushed, carryPushedBytes = st.VerifiedBytes, st.PushedTotal, st.PushedBytes
		fmt.Printf("r2fill: resuming after %d carried pushes (%.1f MB carried); skip set %d ids; no LIST spent\n",
			carryPushed, float64(carryPushedBytes)/1048576, len(existing))
	}
	target := int64(*targetMB) << 20
	fmt.Printf("r2fill: bucket at %.1f MB; target %d MB; %d lanes\n",
		float64(startBytes+carryPushedBytes)/1048576, *targetMB, *workers)

	doneFile, derr := os.OpenFile(donePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if derr != nil {
		fmt.Fprintf(os.Stderr, "r2fill: open done ledger: %v\n", derr)
		os.Exit(1)
	}
	defer doneFile.Close()
	var doneMu sync.Mutex
	markDone := func(id string) {
		doneMu.Lock()
		doneFile.WriteString(id + "\n")
		doneMu.Unlock()
	}

	f, err := os.Open(*queuePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "r2fill: open queue: %v\n", err)
		os.Exit(1)
	}
	defer f.Close()

	var pushed, failed, skipped, scanned atomic.Int64
	var pushedBytes atomic.Int64
	var stop atomic.Bool
	start := time.Now()
	if *maxSeconds > 0 {
		deadline := start.Add(time.Duration(*maxSeconds) * time.Second)
		go func() {
			<-time.After(time.Until(deadline))
			stop.Store(true)
		}()
	}

	rows := make(chan qRow, *workers*8)
	var producers sync.WaitGroup
	producers.Add(1)
	go func() {
		defer producers.Done()
		defer close(rows)
		sc := bufio.NewScanner(f)
		sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if line == "" {
				continue
			}
			var r qRow
			if json.Unmarshal([]byte(line), &r) != nil || r.TID == "" {
				continue
			}
			scanned.Add(1)
			if _, done := existing[r.TID]; done {
				skipped.Add(1)
				continue
			}
			if stop.Load() {
				return
			}
			if *firstN > 0 && int(pushed.Load()+failed.Load()) >= *firstN {
				return
			}
			// Stop aware send: when the deadline fires the workers walk
			// away, so a producer parked on a full channel would hang the
			// run forever. Wake up every 100ms and re-check instead.
			sent := false
			for !sent {
				if stop.Load() {
					return
				}
				select {
				case rows <- r:
					sent = true
				case <-time.After(100 * time.Millisecond):
				}
			}
		}
		if err := sc.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "r2fill: queue read: %v\n", err)
		}
	}()

	var wg sync.WaitGroup
	for i := 0; i < *workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for r := range rows {
				if stop.Load() {
					return
				}
				ok, pb := buildAndPut(ctx, blobs, r)
				if !ok {
					failed.Add(1)
					continue
				}
				markDone(r.TID)
				total := pushedBytes.Add(pb)
				nPushed := pushed.Add(1)
				if startBytes+carryPushedBytes+total >= target {
					stop.Store(true)
				}
				if nPushed%int64(*every) == 0 {
					elapsed := time.Since(start).Seconds()
					rate := float64(nPushed) / elapsed
					remaining := target - (startBytes + carryPushedBytes + total)
					eta := time.Duration(float64(remaining)/(float64(total)/elapsed)) * time.Second
					fmt.Printf("  ... %d pushed (%.1f MB this run), %d failed, %.0f lessons/s, ETA %s\n",
						nPushed, float64(total)/1048576, failed.Load(), rate, eta.Round(time.Second))
				}
			}
		}()
	}
	producers.Wait()
	wg.Wait()

	thisPushed, thisBytes := pushed.Load(), pushedBytes.Load()
	totalBucket := startBytes + carryPushedBytes + thisBytes
	fmt.Printf("r2fill done: pushed %d (%.1f MB, %.0f B avg), skipped %d existing, failed %d, scanned %d rows in %.1f min\n",
		thisPushed, float64(thisBytes)/1048576, avg(thisBytes, thisPushed), skipped.Load(), failed.Load(), scanned.Load(), time.Since(start).Minutes())
	fmt.Printf("bucket now: %.1f MB of %d MB target (%.1f%%)\n",
		float64(totalBucket)/1048576, *targetMB, float64(totalBucket)/float64(target)*100)
	if failed.Load() > 0 {
		fmt.Println("re-run r2fill to retry the failed rows (they stayed eligible)")
	}
	// Carry the run into the state so the next chunk resumes without a LIST.
	if thisPushed > 0 {
		st.PushedTotal, st.PushedBytes = carryPushed+thisPushed, carryPushedBytes+thisBytes
		if raw, err := json.Marshal(st); err == nil {
			_ = os.WriteFile(*statePath, raw, 0644)
		}
	}
}

func avg(total, n int64) float64 {
	if n == 0 {
		return 0
	}
	return float64(total) / float64(n)
}

// buildPayload synthesizes one lesson and marshals the exact per
// topic envelope bytes both upload modes share (the pack tier embeds
// these verbatim, so a lesson reads identically from either home).
func buildPayload(r qRow) ([]byte, error) {
	out := synth.BuildLesson(r.TID, r.Course, r.Dept, r.Faculty, r.Title, r.Unit)
	notes, _ := json.Marshal(out.Notes)
	kp, _ := json.Marshal(out.KeyPoints)
	quiz, _ := json.Marshal(out.Quiz)
	return json.Marshal(learn.LessonBlob{
		TopicID:     r.TID,
		Title:       out.Title,
		Summary:     out.Summary,
		Notes:       notes,
		KeyPoints:   kp,
		Quiz:        quiz,
		Drawings:    json.RawMessage("[]"),
		Source:      learn.AgentSource,
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	})
}

// loadSkipSet merges the pre existing keys cache and the append-only
// done ledger into one skip map (pack mode reuses it so already
// pushed topics never ride a pack).
func loadSkipSet(existingPath, donePath string) map[string]bool {
	skip := map[string]bool{}
	if raw, err := os.ReadFile(existingPath); err == nil {
		var existing map[string]int64
		if json.Unmarshal(raw, &existing) == nil {
			for id := range existing {
				skip[id] = true
			}
		}
	}
	if raw, err := os.ReadFile(donePath); err == nil {
		for _, line := range strings.Split(string(raw), "\n") {
			if id := strings.TrimSpace(line); id != "" {
				skip[id] = true
			}
		}
	}
	return skip
}

// buildAndPut synthesizes one lesson and uploads it. One retry on a
// transport error, then give up (the row stays eligible for the next
// run) - a doomed PUT is never hammered.
func buildAndPut(ctx context.Context, blobs *r2store.Client, r qRow) (bool, int64) {
	payload, err := buildPayload(r)
	if err != nil {
		fmt.Fprintf(os.Stderr, "  marshal %s: %v\n", r.TID, err)
		return false, 0
	}
	if err := blobs.Put(ctx, r.TID, payload); err != nil {
		time.Sleep(time.Second)
		if err := blobs.Put(ctx, r.TID, payload); err != nil {
			fmt.Fprintf(os.Stderr, "  put %s: %v\n", r.TID, err)
			return false, 0
		}
	}
	return true, int64(len(payload))
}
