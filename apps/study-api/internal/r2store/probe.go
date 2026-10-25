package r2store

// ProbeBlobs - the course-coverage surface (founder 2026-10-26, "link
// the lessons on Cloudflare R2 to the courses on Renance Mobile and the
// website"): which of these topic ids actually resolve from the bucket?
//
// The API's read path (learn.Service.cachedLesson) resolves a lesson
// R2-first - per-topic key, then the topic's pack shard - so the probe
// answers the EXACT same way Get does: a topic counts as "ready" when a
// student opening it right now would be served from the bucket. The
// mobile app and the website turn the answer into the little
// cloud-ready badge on the course ladder and prefetch the ready lessons
// so an open is instant (and works offline).
//
// Positive hits are memoized in-process (lesson objects are
// write-once-per-version content, so a hit stays a hit); misses are
// NOT memoized - r2fill keeps landing new lessons and a course page
// opened tomorrow must see them.

import (
	"context"
	"net/http"
	"sync"
)

// BlobHit is one topic's probe answer. Exists mirrors what Get would
// return; PerTopic is true when the lesson rides its own key (so a
// public CDN url is meaningful); PublicURL carries the public
// R2_PUBLIC_BASE url of the per-topic object ("" when the bucket has
// no public base or the lesson is pack-stored).
type BlobHit struct {
	Exists    bool
	PerTopic  bool
	PublicURL string
}

// ProbeBlobs resolves which topic ids the bucket can serve. Never
// returns an error: transport failures simply leave a topic absent
// (the caller renders "not ready", the API path still works). A nil
// client (R2 off) yields an empty map so callers can skip the badge
// entirely.
func (c *Client) ProbeBlobs(ctx context.Context, topicIDs []string) map[string]BlobHit {
	out := map[string]BlobHit{}
	if c == nil || len(topicIDs) == 0 {
		return out
	}
	pending := make([]string, 0, len(topicIDs))
	for _, id := range topicIDs {
		if id == "" {
			continue
		}
		if v, ok := c.probeMemo.Load(id); ok {
			if hit, ok := v.(BlobHit); ok && hit.Exists {
				out[id] = hit
			}
			continue
		}
		pending = append(pending, id)
	}
	const lanes = 4
	sem := make(chan struct{}, lanes)
	var mu sync.Mutex
	var wg sync.WaitGroup
	for _, id := range pending {
		wg.Add(1)
		go func(id string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			hit := c.probeOne(ctx, id)
			mu.Lock()
			if hit.Exists {
				out[id] = hit
			}
			mu.Unlock()
			if hit.Exists {
				c.probeMemo.Store(id, hit)
			}
		}(id)
	}
	wg.Wait()
	return out
}

// probeOne resolves one topic exactly like Get does - per-topic HEAD
// first (cheap, no body), then the pack shard the topic hashes into.
func (c *Client) probeOne(ctx context.Context, topicID string) BlobHit {
	status, _, err := c.roundTrip(ctx, http.MethodHead, "", nil, "", nil, c.lessonKey(topicID))
	if err == nil && status == http.StatusOK {
		return BlobHit{
			Exists:    true,
			PerTopic:  true,
			PublicURL: c.PublicURL(c.lessonKey(topicID)),
		}
	}
	// Pack tier: the shard is fetched (and memoized by packLessons),
	// then the membership check is pure map work.
	if lessons, packed := c.packLessons(ctx, topicID); packed {
		if raw, found := lessons[topicID]; found && len(raw) > 0 {
			return BlobHit{Exists: true, PerTopic: false}
		}
	}
	return BlobHit{}
}
