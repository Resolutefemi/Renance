// packs.go - the packed shard tier of the lesson archive (founder
// directive, October 2026: "manage the Class A free tier 500k
// operations for all the remaining 1.23 million topics").
//
// One object per topic burned one Class A PUT per lesson, which at
// 1.3 million remaining topics is roughly three times the founder's
// line. A pack collapses many lessons into ONE object: the remaining
// catalog is hashed into PackShardCount shards, and every lesson a
// shard owns rides inside that shard's single object. The upload of
// the whole remaining catalog costs at most PackShardCount PUTs, no
// matter how many million topics it carries.
//
// The scheme is fully deterministic and index free: shard(tid) =
// fnv1a32(tid) % PackShardCount. A reader that wants topic T fetches
// exactly one object, packs/p-NNNNN.json, and unpacks T from it. No
// manifest, no LIST, no second hop. Per topic keys keep winning on
// read: Get tries lessons/<tid>.json first (free Class B), then the
// pack. A heal write back lands on the per topic key and shadows the
// pack copy forever after, still one PUT per content version.
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
)

// PackShardCount is the number of pack objects the archive spreads
// over. 60,000 shards at 1.23M remaining lessons average 20+ lessons
// (roughly 470 KB) per pack and cap the whole pack upload at 60,000
// Class A PUTs, which keeps the founder's full operation under the
// 500k line together with the per topic pushes already spent.
const PackShardCount = 60000

// packKeyPrefix is where pack objects live. The lessons/ listing
// (ListLessons) filters on the lesson prefix, so packs never pollute
// the per topic inventory.
const packKeyPrefix = "packs/"

// packMemoCap bounds the in process pack cache (packs are Class B to
// re-fetch, so the cache is pure latency sugar; a plain forget-all on
// overflow keeps the code honest and the memory bounded).
const packMemoCap = 768

// LessonPack is the on bucket pack envelope: version 1 carries every
// lesson envelope of the shard keyed by topic id. Each value is the
// EXACT bytes of the per topic LessonBlob object, so a lesson reads
// identically from either home.
type LessonPack struct {
	Version int                        `json:"v"`
	Lessons map[string]json.RawMessage `json:"lessons"`
}

// PackShard maps a topic id onto its shard. Must stay byte identical
// with cmd/r2fill (which imports this symbol, so drift is impossible).
func PackShard(topicID string) uint32 {
	h := fnv.New32a()
	_, _ = h.Write([]byte(topicID))
	return h.Sum32() % PackShardCount
}

// PackKey renders the object key of one shard: packs/p-00042.json.
func PackKey(shard uint32) string {
	return fmt.Sprintf("%sp-%05d.json", packKeyPrefix, shard)
}

// packLessons fetches one shard's map, through the memo when warm.
// ok=false covers transport trouble and a shard that is not uploaded
// yet - the caller treats it exactly like the clean miss it is.
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
	// Forget-all on overflow: simplest correct bound on memory.
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

// PutPack stores one packed shard. ONE Class A PUT per shard, ever:
// a shard is complete when it is uploaded (the fill tool assembles
// the full membership before the call), so there is no rewrite churn.
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
