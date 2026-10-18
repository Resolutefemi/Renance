// packs.go - pack mode for r2fill (founder directive, October 2026:
// "don't use up to 500k requests for the class A operation when
// uploading all the 1.23 million topics").
//
// Per topic pushes burned one PUT per lesson; the remaining catalog
// would need roughly 1.3 million of them, three times the founder's
// line. Pack mode collapses the same catalog into r2store.PackShardCount
// shard objects: the queue is scanned once to assign every still
// missing topic to its shard (shard = fnv1a32(tid) % PackShardCount,
// the exact function the API's read path runs), then each shard is
// assembled in memory and uploaded with ONE PUT. The whole remaining
// archive lands in at most 60,000 PUTs, whatever it carries.
//
// Resume discipline: every landed shard appends its id to the pack
// done ledger, so a killed chunk re-runs with zero re-PUTs and zero
// LISTs. Reads stay Class B free: the API tries the per topic key
// first, then the shard object.
package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"renance.dev/study-api/internal/r2store"
)

type packEntry struct {
	tid string
	off int64
}

type packOpts struct {
	queue      string
	statePath  string
	workers    int
	maxShards  int
	every      int
	maxSeconds int
}

func runPacks(ctx context.Context, blobs *r2store.Client, skip map[string]bool, o packOpts) {
	packDonePath := strings.TrimSuffix(o.statePath, ".json") + "_pack_done.txt"
	packDone := map[uint32]bool{}
	if raw, err := os.ReadFile(packDonePath); err == nil {
		for _, line := range strings.Split(string(raw), "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			var id uint32
			if _, err := fmt.Sscanf(line, "%d", &id); err == nil {
				packDone[id] = true
			}
		}
	}

	// Pass 1: one sequential scan of the queue, zero network. Every
	// still missing topic lands on its shard with the byte offset of
	// its queue row, so pass 2 never re-parses the whole file and the
	// memory bill stays at a few tens of megabytes.
	qf, err := os.Open(o.queue)
	if err != nil {
		fmt.Fprintf(os.Stderr, "r2fill: open queue: %v\n", err)
		os.Exit(1)
	}
	defer qf.Close()

	shards := map[uint32][]packEntry{}
	scanned, skipped := 0, 0
	var off int64
	br := bufio.NewReaderSize(qf, 1<<20)
	for {
		line, rerr := br.ReadBytes('\n')
		if len(line) > 0 {
			var r qRow
			if json.Unmarshal(line, &r) == nil && r.TID != "" {
				scanned++
				if _, done := skip[r.TID]; !done {
					s := r2store.PackShard(r.TID)
					shards[s] = append(shards[s], packEntry{tid: r.TID, off: off})
				} else {
					skipped++
				}
			}
			off += int64(len(line))
		}
		if rerr != nil {
			break
		}
	}

	ids := make([]uint32, 0, len(shards))
	totalLessons := 0
	for s, entries := range shards {
		totalLessons += len(entries)
		if !packDone[s] {
			ids = append(ids, s)
		}
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	fmt.Printf("r2fill packs: scanned %d rows, %d already per topic, %d lessons to carry, %d/%d shards already packed, %d shards to PUT\n",
		scanned, skipped, totalLessons, len(packDone), len(shards), len(ids))

	doneFile, derr := os.OpenFile(packDonePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if derr != nil {
		fmt.Fprintf(os.Stderr, "r2fill: open pack done ledger: %v\n", derr)
		os.Exit(1)
	}
	defer doneFile.Close()
	var doneMu sync.Mutex
	markShard := func(id uint32) {
		doneMu.Lock()
		fmt.Fprintf(doneFile, "%d\n", id)
		doneMu.Unlock()
	}

	var shardsPut, lessonsPut, failed atomic.Int64
	var bytesPut atomic.Int64
	var stop atomic.Bool
	start := time.Now()
	if o.maxSeconds > 0 {
		deadline := start.Add(time.Duration(o.maxSeconds) * time.Second)
		go func() {
			<-time.After(time.Until(deadline))
			stop.Store(true)
		}()
	}

	work := make(chan uint32, o.workers*4)
	var producers sync.WaitGroup
	producers.Add(1)
	go func() {
		defer producers.Done()
		defer close(work)
		for _, s := range ids {
			if stop.Load() {
				return
			}
			if o.maxShards > 0 && int(shardsPut.Load()) >= o.maxShards {
				return
			}
			// Stop aware send: a producer parked on a full channel
			// would hang the run at the deadline, so wake up every
			// 100ms and re-check instead.
			sent := false
			for !sent {
				if stop.Load() {
					return
				}
				select {
				case work <- s:
					sent = true
				case <-time.After(100 * time.Millisecond):
				}
			}
		}
	}()

	every := int64(o.every)
	if every < 1 {
		every = 1
	}
	var wg sync.WaitGroup
	for i := 0; i < o.workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for s := range work {
				if stop.Load() {
					return
				}
				n, bytes, ok := buildAndPutShard(ctx, blobs, s, qf, shards[s])
				if !ok {
					failed.Add(1)
					continue
				}
				markShard(s)
				done := shardsPut.Add(1)
				carried := lessonsPut.Add(int64(n))
				total := bytesPut.Add(bytes)
				if done%every == 0 {
					elapsed := time.Since(start).Seconds()
					fmt.Printf("  ... %d shards (%d lessons, %.1f MB this run), %d failed, %.0f shards/s\n",
						done, carried, float64(total)/1048576, failed.Load(), float64(done)/elapsed)
				}
			}
		}()
	}
	producers.Wait()
	wg.Wait()

	fmt.Printf("r2fill packs done: %d shards PUT (%d lessons, %.1f MB), %d failed, in %.1f min\n",
		shardsPut.Load(), lessonsPut.Load(), float64(bytesPut.Load())/1048576, failed.Load(), time.Since(start).Minutes())
	if failed.Load() > 0 {
		fmt.Println("re-run r2fill -packs to retry the failed shards (they stayed eligible)")
	}
}

// buildAndPutShard assembles one shard's lessons from the queue rows
// at their recorded offsets and uploads the pack with a single PUT.
// One transport retry, then the shard stays eligible for the next run
// - a doomed PUT is never hammered.
func buildAndPutShard(ctx context.Context, blobs *r2store.Client, shard uint32, qf *os.File, entries []packEntry) (int, int64, bool) {
	lessons := make(map[string]json.RawMessage, len(entries))
	for _, e := range entries {
		chunk := make([]byte, 4096)
		n, err := qf.ReadAt(chunk, e.off)
		if err != nil && err != io.EOF {
			fmt.Fprintf(os.Stderr, "  read %s: %v\n", e.tid, err)
			return 0, 0, false
		}
		line := chunk[:n]
		if i := bytes.IndexByte(line, '\n'); i >= 0 {
			line = line[:i]
		}
		var r qRow
		if json.Unmarshal(line, &r) != nil || r.TID == "" {
			fmt.Fprintf(os.Stderr, "  parse %s: bad queue row\n", e.tid)
			return 0, 0, false
		}
		payload, perr := buildPayload(r)
		if perr != nil {
			fmt.Fprintf(os.Stderr, "  marshal %s: %v\n", r.TID, perr)
			return 0, 0, false
		}
		lessons[r.TID] = payload
	}
	raw, err := json.Marshal(r2store.LessonPack{Version: 1, Lessons: lessons})
	if err != nil {
		fmt.Fprintf(os.Stderr, "  marshal pack %d: %v\n", shard, err)
		return 0, 0, false
	}
	if err := blobs.PutPack(ctx, shard, raw); err != nil {
		time.Sleep(time.Second)
		if err := blobs.PutPack(ctx, shard, raw); err != nil {
			fmt.Fprintf(os.Stderr, "  put pack %d: %v\n", shard, err)
			return 0, 0, false
		}
	}
	return len(lessons), int64(len(raw)), true
}
