package r2store

import (
	"context"
	"net/http"
	"sync"
)

type BlobHit struct {
	Exists    bool
	PerTopic  bool
	PublicURL string
}

func (c *Client) ProbeBlobs(ctx context.Context, topicIDs []string) map[string]BlobHit {
	out := map[string]BlobHit{}
	if c == nil || len(topicIDs) == 0 {
		return out
	}
	// Pre-resolve unique course packs (courses/<course_id>.json) once per course
	// so a 140-unit tertiary course resolves in 1 R2 GET instead of 140 HEADs.
	seenCourses := map[string]bool{}
	for _, id := range topicIDs {
		if cid := CourseIDFromTopic(id); cid != "" && !seenCourses[cid] {
			seenCourses[cid] = true
			if lessons, packed := c.coursePackLessons(ctx, cid); packed {
				for tid, raw := range lessons {
					if len(raw) > 0 {
						c.probeMemo.Store(tid, BlobHit{Exists: true, PerTopic: false})
					}
				}
			}
		}
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
	if len(pending) == 0 {
		return out
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

func (c *Client) probeOne(ctx context.Context, topicID string) BlobHit {
	if cid := CourseIDFromTopic(topicID); cid != "" {
		if lessons, packed := c.coursePackLessons(ctx, cid); packed {
			if raw, found := lessons[topicID]; found && len(raw) > 0 {
				return BlobHit{Exists: true, PerTopic: false}
			}
		}
	}
	status, _, err := c.roundTrip(ctx, http.MethodHead, "", nil, "", nil, c.lessonKey(topicID))
	if err == nil && status == http.StatusOK {
		return BlobHit{
			Exists:    true,
			PerTopic:  true,
			PublicURL: c.PublicURL(c.lessonKey(topicID)),
		}
	}
	if lessons, packed := c.packLessons(ctx, topicID); packed {
		if raw, found := lessons[topicID]; found && len(raw) > 0 {
			return BlobHit{Exists: true, PerTopic: false}
		}
	}
	return BlobHit{}
}
