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

// BlobHit is one topic's bucket-coverage answer (the course-ladder
// "this lesson is live on the CDN" badge and the content response's
// public url).
type BlobHit struct {
        Exists    bool   // the bucket serves this topic today
        PerTopic  bool   // it rides its own key (a public url is meaningful)
        PublicURL string // the R2_PUBLIC_BASE url of the per-topic object ("")
}

// BlobProber is the optional coverage surface a blob store can expose
// (r2store.Client does): "which of these course topics resolve from
// the bucket right now?" The course path turns it into per-unit
// blobReady flags; the lesson content response turns it into blobUrl.
// Optional - probed via type assertion, so alternate LessonBlobs
// implementations (tests, future stores) keep working untouched.
type BlobProber interface {
        ProbeBlobs(ctx context.Context, topicIDs []string) map[string]BlobHit
}

// LessonBlob is the stable on-bucket envelope, one object per topic
// (key: <prefix><topic_id>.json, default prefix "lessons/"). The four
// content columns ride as raw JSON so the byte shape matches the
// learn.lessons columns exactly - the same envelope the dbsplit
// r2-push / r2-restore commands read and write, no marshal drift.
// NOT stored: hit_count (a database-only serving statistic) and the
// CourseID/Course/Cached serve-time decorations (rebuilt per request).
type LessonBlob struct {
        TopicID         string          `json:"topic_id"`
        Title           string          `json:"title"`
        Summary         string          `json:"summary"`
        Notes           json.RawMessage `json:"notes"`
        KeyPoints       json.RawMessage `json:"key_points"`
        Quiz            json.RawMessage `json:"quiz"`
        TheoryQuestions json.RawMessage `json:"theory_questions,omitempty"`
        Drawings        json.RawMessage `json:"drawings"`
        Source          string          `json:"source"`
        GeneratedAt     string          `json:"generated_at,omitempty"`
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
        theory, _ := json.Marshal(doc.TheoryQuestions)
        // Content hash over the already marshalled columns plus the
        // short header fields. generated_at is deliberately outside:
        // the stamp churns on every call and would defeat the guard.
        sum := sha256.New()
        for _, part := range [][]byte{notes, kp, quiz, draw, theory} {
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
                TopicID:         doc.TopicID,
                Title:           doc.Title,
                Summary:         doc.Summary,
                Notes:           notes,
                KeyPoints:       kp,
                Quiz:            quiz,
                TheoryQuestions: theory,
                Drawings:        draw,
                Source:          doc.Source,
                GeneratedAt:     time.Now().UTC().Format(time.RFC3339),
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
	if !ok || len(payload) == 0 {
		return nil, false
	}
	var blob struct {
		TopicID     string          `json:"topic_id"`
		Title       string          `json:"title"`
		Topic       string          `json:"topic"`
		Summary     string          `json:"summary"`
		ShortSum    string          `json:"s"`
		Notes       json.RawMessage `json:"notes"`
		KeyPoints   json.RawMessage `json:"key_points"`
		ShortKP     json.RawMessage `json:"kp"`
		Quiz        json.RawMessage `json:"quiz"`
		Theory      json.RawMessage `json:"theory_questions"`
		Drawings    json.RawMessage `json:"drawings"`
		Source      string          `json:"source"`
		GeneratedAt string          `json:"generated_at,omitempty"`
	}
	if json.Unmarshal(payload, &blob) != nil {
		return nil, false
	}
	title := blob.Title
	if title == "" {
		title = blob.Topic
	}
	if blob.TopicID == "" && title == "" {
		return nil, false
	}
	summary := blob.Summary
	if summary == "" {
		summary = blob.ShortSum
	}
	source := blob.Source
	if source == "" {
		source = CuratedSource
	}
	doc := &LessonDoc{Title: title, Summary: summary, Source: source}
	if len(blob.Notes) > 0 {
		var rawNotes []struct {
			Heading  string `json:"heading"`
			Body     string `json:"body"`
			H        string `json:"h"`
			B        string `json:"b"`
			Image    string `json:"image,omitempty"`
			ImageAlt string `json:"imageAlt,omitempty"`
		}
		if json.Unmarshal(blob.Notes, &rawNotes) == nil {
			doc.Notes = make([]LessonNote, 0, len(rawNotes))
			for _, rn := range rawNotes {
				h := rn.Heading
				if h == "" {
					h = rn.H
				}
				b := rn.Body
				if b == "" {
					b = rn.B
				}
				if b != "" {
					doc.Notes = append(doc.Notes, LessonNote{Heading: h, Body: b, Image: rn.Image, ImageAlt: rn.ImageAlt})
				}
			}
		}
	}
	kpRaw := blob.KeyPoints
	if len(kpRaw) == 0 {
		kpRaw = blob.ShortKP
	}
	if len(kpRaw) > 0 {
		_ = json.Unmarshal(kpRaw, &doc.KeyPoints)
	}
	if len(blob.Quiz) > 0 {
		var rawQuiz []struct {
			ID          string            `json:"id"`
			Type        string            `json:"type"`
			Stem        string            `json:"stem"`
			Q           string            `json:"q"`
			Options     map[string]string `json:"options"`
			O           []string          `json:"o"`
			Answer      string            `json:"answer"`
			A           *int              `json:"a"`
			Explanation string            `json:"explanation"`
			E           string            `json:"e"`
			Year        int               `json:"year,omitempty"`
			FromBank    bool              `json:"fromBank,omitempty"`
		}
		if json.Unmarshal(blob.Quiz, &rawQuiz) == nil {
			letters := []string{"A", "B", "C", "D", "E"}
			doc.Quiz = make([]LessonQuizQ, 0, len(rawQuiz))
			for idx, rq := range rawQuiz {
				stem := rq.Stem
				if stem == "" {
					stem = rq.Q
				}
				if stem == "" {
					continue
				}
				qtype := rq.Type
				if qtype == "" {
					qtype = "mcq"
				}
				opts := rq.Options
				if len(opts) == 0 && len(rq.O) > 0 {
					opts = make(map[string]string, len(rq.O))
					for oi, ov := range rq.O {
						if oi < len(letters) {
							opts[letters[oi]] = ov
						}
					}
				}
				ans := rq.Answer
				if ans == "" && rq.A != nil && *rq.A >= 0 && *rq.A < len(letters) {
					ans = letters[*rq.A]
				}
				exp := rq.Explanation
				if exp == "" {
					exp = rq.E
				}
				qid := rq.ID
				if qid == "" {
					qid = topicID + "-q" + string(rune('1'+idx))
				}
				doc.Quiz = append(doc.Quiz, LessonQuizQ{
					ID:          qid,
					Type:        qtype,
					Stem:        stem,
					Options:     opts,
					Answer:      ans,
					Explanation: exp,
					Year:        rq.Year,
					FromBank:    rq.FromBank,
				})
			}
		}
	}
	if len(blob.Theory) > 0 {
		_ = json.Unmarshal(blob.Theory, &doc.TheoryQuestions)
	}
	if len(blob.Drawings) > 0 {
		_ = json.Unmarshal(blob.Drawings, &doc.Drawings)
	}
	return doc, true
}

func (s *Service) logWarn(msg string, args ...any) {
        if s.Log != nil {
                s.Log.Warn(msg, args...)
        }
}
