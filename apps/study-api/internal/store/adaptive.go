// Adaptive ordering (ROADMAP #5): weak-topic-first question order.
//
// The insight the whole feature rides on: the review queue (ROADMAP #3)
// already maintains a per-topic memory model — SM-2 ease, lapses, the
// last paper's accuracy and the due date. This file turns that signal
// into an ordering with ONE pure, unit-tested rule (AdaptiveOrder); the
// store method below it only reads the state the rule needs, and the
// handler persists the result onto the attempt row.
//
// Ordering law, deterministic and explainable:
//   - topics sort weakest-first by a weakness score; ties break
//     alphabetically so the same state always yields the same paper;
//   - within a topic, questions walk easy -> medium -> hard (unlabeled
//     last), original pack order breaking remaining ties;
//   - topics with no history sit at UnseenWeakness: new material comes
//     AFTER actively-struggling topics but BEFORE further drilling of
//     mastered ones.
package store

import (
	"context"
	"sort"
	"time"
)

// UnseenWeakness places never-practiced topics between struggling
// (weakness > 1.25 whenever ease dips or accuracy drops) and strong
// mastered ones (weakness ~0).
const UnseenWeakness = 1.25

// OrderItem is the minimal question view the ordering rule needs —
// no dependency on cbtdata keeps the store layer self-contained.
type OrderItem struct {
	QuestionID string
	Topic      string // "" buckets into "General", same as grading
	Difficulty string // easy | medium | hard | "" | anything else
}

// TopicState is the mastery signal for one topic, straight from the
// review_queue row the grading engine maintains.
type TopicState struct {
	SM2         SM2Item
	LastCorrect int
	LastTotal   int
	DueOn       time.Time
}

// Weakness scores one SEEN topic (a review_queue row exists). Higher =
// more urgent:
//
//	ease deficit (2.5 floor)  0..1.2   — the SM-2 memory strength
//	+ (1 - lastAccuracy) * 2  0..2     — how the last paper went
//	+ 0.5 * min(lapses, 4)    0..2     — repeated forgetting history
//	+ 0.75 if due/overdue     0/0.75   — the queue says it's time
func Weakness(st TopicState, today time.Time) float64 {
	acc := 1.0
	if st.LastTotal > 0 {
		acc = float64(st.LastCorrect) / float64(st.LastTotal)
	}
	w := InitialEase - st.SM2.Ease
	if w < 0 {
		w = 0
	}
	w += (1 - acc) * 2
	lapses := st.SM2.Lapses
	if lapses > 4 {
		lapses = 4
	}
	w += 0.5 * float64(lapses)
	if !st.DueOn.After(today) {
		w += 0.75
	}
	return w
}

// AdaptiveOrder returns the question ids in weak-topic-first order.
// Pure: same inputs, same paper — grading, review and forensics all
// replay the exact sequence. Unanswered/unknown topics keep stable
// relative order (sort.SliceStable + original index as final key).
func AdaptiveOrder(items []OrderItem, state map[string]TopicState, today time.Time) []string {
	type entry struct {
		id    string
		topic string
		rank  int // difficulty ladder position
		idx   int // original pack position
		w     float64
	}
	diffRank := map[string]int{"easy": 0, "medium": 1, "hard": 2}
	entries := make([]entry, 0, len(items))
	for i, it := range items {
		topic := it.Topic
		if topic == "" {
			topic = "General"
		}
		r, ok := diffRank[it.Difficulty]
		if !ok {
			r = 3
		}
		w := UnseenWeakness
		if st, seen := state[topic]; seen {
			w = Weakness(st, today)
		}
		entries = append(entries, entry{it.QuestionID, topic, r, i, w})
	}
	sort.SliceStable(entries, func(a, b int) bool {
		ea, eb := entries[a], entries[b]
		if ea.topic != eb.topic {
			if ea.w != eb.w {
				return ea.w > eb.w // weakest topic first
			}
			return ea.topic < eb.topic // deterministic topic tie
		}
		if ea.rank != eb.rank {
			return ea.rank < eb.rank // easy -> hard inside a topic
		}
		return ea.idx < eb.idx
	})
	out := make([]string, 0, len(entries))
	for _, e := range entries {
		out = append(out, e.id)
	}
	return out
}

// ReviewStates loads the user's review_queue rows for the given topics.
// Missing rows simply stay absent from the map (= unseen to the orderer).
func (s *Store) ReviewStates(ctx context.Context, userID string, topics []string) (map[string]TopicState, error) {
	out := map[string]TopicState{}
	if len(topics) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
		SELECT topic, ease, interval_days, repetitions, lapses, due_on, last_correct, last_total
		FROM study.review_queue
		WHERE user_id = $1 AND topic = ANY($2)`, userID, topics)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var topic string
		var st TopicState
		var due time.Time
		if err := rows.Scan(&topic, &st.SM2.Ease, &st.SM2.IntervalDays,
			&st.SM2.Repetitions, &st.SM2.Lapses, &due, &st.LastCorrect, &st.LastTotal); err != nil {
			return nil, err
		}
		st.DueOn = due
		out[topic] = st
	}
	return out, rows.Err()
}
