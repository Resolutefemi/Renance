// blobs.go - the object-storage tier of the lesson cache (founder
// 2026-10-17, "how do we move to cloudflare r2"). The bucket is the
// DURABLE home of whole lesson documents; the cache database stays the
// INDEX (review sets, arena pools, the prefetch probe and hit_count
// all read learn.lessons). Three tiers on read - bucket, database,
// generation - with clean falls between them, and every one of them
// optional: Blobs == nil is today's single-home posture, byte for byte.
package learn

import (
        "context"
        "crypto/sha256"
        "encoding/hex"
        "encoding/json"
        "time"
)

// LessonBlobs is the narrow object-storage surface the learn module
// needs. A *r2store.Client satisfies it directly; nil keeps every
// path on the cache database alone.
type LessonBlobs interface {
        // Get returns the raw lesson envelope for a topic id. ok=false
        // with a nil error is a clean miss (no object) - the caller falls
        // through to the next tier; an error is transport trouble and is
        // ALSO treated as a miss (the database tier still serves).
        Get(ctx context.Context, topicID string) (payload []byte, ok bool, err error)
        // Put stores one lesson envelope. Best-effort at runtime: a
        // bucket failure never fails a lesson whose database write landed.
        Put(ctx context.Context, topicID string, payload []byte) error
        // Has probes which topic ids already hold a bucket object (the
        // prefetch look-ahead's cache probe rides this once the database
        // index has been trimmed or lost).
        Has(ctx context.Context, topicIDs []string) (map[string]bool, error)
}

// LessonBlob is the stable on-bucket envelope, one object per topic
// (key: <prefix><topic_id>.json, default prefix "lessons/"). The four
// content columns ride as raw JSON so the byte shape matches the
// learn.lessons columns exactly - the same envelope the dbsplit
// r2-push / r2-restore commands read and write, no marshal drift.
// NOT stored: hit_count (a database-only serving statistic) and the
// CourseID/Course/Cached serve-time decorations (rebuilt per request).
type LessonBlob struct {
        TopicID     string          `json:"topic_id"`
        Title       string          `json:"title"`
        Summary     string          `json:"summary"`
        Notes       json.RawMessage `json:"notes"`
        KeyPoints   json.RawMessage `json:"key_points"`
        Quiz        json.RawMessage `json:"quiz"`
        Drawings    json.RawMessage `json:"drawings"`
        Source      string          `json:"source"`
        GeneratedAt string          `json:"generated_at,omitempty"`
}

// blobSave marshals a lesson doc into the envelope and PUTs it.
// Best-effort by doctrine: a bucket outage is a log line, never a
// failed lesson - the database write in persistLesson still lands.
//
// Class A discipline (founder, October 2026, "manage my class A
// operation"): R2 charges for writes and listings, not for reads, so
// every avoidable PUT is budget burned. The memo on Service.blobMemo
// hashes the content of the envelope with the timestamp excluded, and
// one content version gets exactly ONE PUT attempt per process,
// success or failure alike. A heal write back on a lesson served ten
// times costs one PUT, not ten; a deterministic agent lesson
// regenerated after a cache loss costs one PUT; and a payload whose
// upload failed is not hammered again on every serve. The student
// still sees the healed form from memory; the next boot retries once.
func (s *Service) blobSave(ctx context.Context, doc *LessonDoc) {
        if s.Blobs == nil || doc == nil || doc.TopicID == "" {
                return
        }
        notes, _ := json.Marshal(doc.Notes)
        kp, _ := json.Marshal(doc.KeyPoints)
        quiz, _ := json.Marshal(doc.Quiz)
        draw, _ := json.Marshal(doc.Drawings)
        // Content hash over the already marshalled columns plus the
        // short header fields. generated_at is deliberately outside:
        // the stamp churns on every call and would defeat the guard.
        sum := sha256.New()
        for _, part := range [][]byte{notes, kp, quiz, draw} {
                sum.Write(part)
                sum.Write([]byte{0})
        }
        for _, field := range []string{doc.TopicID, doc.Title, doc.Summary, doc.Source} {
                sum.Write([]byte(field))
                sum.Write([]byte{0})
        }
        contentHash := hex.EncodeToString(sum.Sum(nil))
        // LoadOrStore is the claim on the single PUT attempt. When the
        // slot already held this exact content the attempt happened
        // earlier this boot and the bucket must not be touched again;
        // when the content changed the new hash replaces the old and a
        // fresh attempt is correct.
        if prev, loaded := s.blobMemo.LoadOrStore(doc.TopicID, contentHash); loaded && prev == contentHash {
                return
        }
        payload, err := json.Marshal(LessonBlob{
                TopicID:     doc.TopicID,
                Title:       doc.Title,
                Summary:     doc.Summary,
                Notes:       notes,
                KeyPoints:   kp,
                Quiz:        quiz,
                Drawings:    draw,
                Source:      doc.Source,
                GeneratedAt: time.Now().UTC().Format(time.RFC3339),
        })
        if err != nil {
                s.logWarn("lesson blob marshal failed", "topic", doc.TopicID, "err", err.Error())
                return
        }
        if err := s.Blobs.Put(ctx, doc.TopicID, payload); err != nil {
                s.logWarn("lesson blob put failed - the database copy still serves", "topic", doc.TopicID, "err", err.Error())
        }
}

// blobLesson fetches one lesson doc from the bucket. ok=false covers
// both the clean miss and every decode trouble - the caller falls
// through to the database tier either way.
func (s *Service) blobLesson(ctx context.Context, topicID string) (*LessonDoc, bool) {
        if s.Blobs == nil {
                return nil, false
        }
        payload, ok, err := s.Blobs.Get(ctx, topicID)
        if err != nil {
                s.logWarn("lesson blob get failed - falling through to the cache database", "topic", topicID, "err", err.Error())
                return nil, false
        }
        if !ok {
                return nil, false
        }
        var blob LessonBlob
        if json.Unmarshal(payload, &blob) != nil || blob.TopicID == "" {
                // A torn or foreign object: pretend it is not there.
                return nil, false
        }
        doc := &LessonDoc{Title: blob.Title, Summary: blob.Summary, Source: blob.Source}
        for _, pair := range []struct {
                raw json.RawMessage
                dst any
        }{
                {blob.Notes, &doc.Notes},
                {blob.KeyPoints, &doc.KeyPoints},
                {blob.Quiz, &doc.Quiz},
                {blob.Drawings, &doc.Drawings},
        } {
                if len(pair.raw) > 0 {
                        if json.Unmarshal(pair.raw, pair.dst) != nil {
                                // Column-level tolerance, same as the database scan.
                                // A bad notes array must not kill a good quiz.
                        }
                }
        }
        return doc, true
}

func (s *Service) logWarn(msg string, args ...any) {
        if s.Log != nil {
                s.Log.Warn(msg, args...)
        }
}
