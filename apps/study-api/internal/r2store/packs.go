// packs.go - the packed shard tier and per-course pack tier of the lesson archive.
package r2store

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"hash/fnv"
	"net/http"
	"strings"
	"time"
)

const PackShardCount = 60000
const packKeyPrefix = "packs/"
const coursePackPrefix = "courses/"
const packMemoCap = 768
const courseMemoCap = 128
const courseMissTTL = 2 * time.Minute

type LessonPack struct {
	Version int                        `json:"v"`
	Course  string                     `json:"course_id,omitempty"`
	Lessons map[string]json.RawMessage `json:"lessons"`
}

func PackShard(topicID string) uint32 {
	h := fnv.New32a()
	_, _ = h.Write([]byte(topicID))
	return h.Sum32() % PackShardCount
}

func PackKey(shard uint32) string {
	return fmt.Sprintf("%sp-%05d.json", packKeyPrefix, shard)
}

func CoursePackKey(courseID string) string {
	return coursePackPrefix + sanitizeKey(courseID) + ".json"
}

// CourseIDFromTopic extracts the course ID ("CRS-00002") from a tertiary unit ID ("CRS-00002-EU0201").
func CourseIDFromTopic(topicID string) string {
	if idx := strings.Index(topicID, "-EU"); idx > 0 {
		return topicID[:idx]
	}
	if idx := strings.LastIndex(topicID, "-T"); idx > 0 && strings.HasPrefix(topicID, "SEC-") {
		return topicID[:idx]
	}
	return ""
}

// coursePackLessons fetches one course pack (courses/<course_id>.json) and memoizes its 140 lessons.
func (c *Client) coursePackLessons(ctx context.Context, courseID string) (map[string]json.RawMessage, bool) {
	if courseID == "" {
		return nil, false
	}
	if v, hit := c.courseMemo.Load(courseID); hit {
		return v.(map[string]json.RawMessage), true
	}
	if v, miss := c.courseMissMemo.Load(courseID); miss {
		if exp, ok := v.(time.Time); ok && time.Now().Before(exp) {
			return nil, false
		}
		c.courseMissMemo.Delete(courseID)
	}
	status, body, err := c.roundTrip(ctx, http.MethodGet, "", nil, "", nil, CoursePackKey(courseID))
	if err != nil || status != http.StatusOK {
		if status == http.StatusNotFound {
			c.courseMissMemo.Store(courseID, time.Now().Add(courseMissTTL))
		}
		return nil, false
	}
	var pack LessonPack
	if json.Unmarshal(body, &pack) != nil || pack.Lessons == nil {
		return nil, false
	}
	if c.courseMemoN.Add(1) > courseMemoCap {
		c.courseMemo.Range(func(k, _ any) bool {
			c.courseMemo.Delete(k)
			return true
		})
		c.courseMemoN.Store(0)
	}
	c.courseMemo.Store(courseID, pack.Lessons)
	return pack.Lessons, true
}

func (c *Client) PutCoursePack(ctx context.Context, courseID string, payload []byte) error {
	if c == nil {
		return errors.New("r2store: client not configured")
	}
	sum := sha256.Sum256(payload)
	status, body, err := c.roundTrip(ctx, http.MethodPut, "application/json", payload, hex.EncodeToString(sum[:]), nil, CoursePackKey(courseID))
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return fmt.Errorf("r2store: put course pack %s: status %d: %s", courseID, status, snippet(body))
	}
	c.courseMissMemo.Delete(courseID)
	return nil
}

func (c *Client) packLessons(ctx context.Context, topicID string) (map[string]json.RawMessage, bool) {
	shard := PackShard(topicID)
	if v, hit := c.packMemo.Load(shard); hit {
		return v.(map[string]json.RawMessage), true
	}
	status, body, err := c.roundTrip(ctx, http.MethodGet, "", nil, "", nil, PackKey(shard))
	if err != nil || status != http.StatusOK {
		return nil, false
	}
	var pack LessonPack
	if json.Unmarshal(body, &pack) != nil || pack.Lessons == nil {
		return nil, false
	}
	if c.packMemoN.Add(1) > packMemoCap {
		c.packMemo.Range(func(k, _ any) bool {
			c.packMemo.Delete(k)
			return true
		})
		c.packMemoN.Store(0)
	}
	c.packMemo.Store(shard, pack.Lessons)
	return pack.Lessons, true
}

func (c *Client) PutPack(ctx context.Context, shard uint32, payload []byte) error {
	if c == nil {
		return errors.New("r2store: client not configured")
	}
	sum := sha256.Sum256(payload)
	status, body, err := c.roundTrip(ctx, http.MethodPut, "application/json", payload, hex.EncodeToString(sum[:]), nil, PackKey(shard))
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return fmt.Errorf("r2store: put pack %d: status %d: %s", shard, status, snippet(body))
	}
	return nil
}
