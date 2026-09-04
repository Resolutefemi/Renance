// Syllabus map (ROADMAP #4): the curriculum tree annotated with the one
// truth the product trusts, the student's own SM-2 memory state.
//
// GET /syllabus/{body} walks data/syllabus/<slug>.json and overlays, per
// topic: how many questions the packs carry, the last paper's accuracy,
// the mastery bucket (unseen / learning / mastered) and the weakness
// score that drives adaptive ordering (ROADMAP #5). The score report's
// weak-topic links, the launcher's syllabus tile and both UIs' mastery
// dots all read from this single endpoint.
package httpapi

import (
	"net/http"
	"sort"
	"time"

	"renance.dev/study-api/internal/store"
)

// syllabusTopic is one node of the map. Accuracy is deliberately the
// LAST paper's accuracy, fresh and honest, not a lifetime average the
// student can dilute.
type syllabusTopic struct {
	Topic       string  `json:"topic"`
	Questions   int     `json:"questions"`
	Seen        bool    `json:"seen"`
	LastCorrect int     `json:"lastCorrect"`
	LastTotal   int     `json:"lastTotal"`
	Accuracy    float64 `json:"accuracy"` // 0 when unseen
	Status      string  `json:"status"`   // unseen | learning | mastered
	DueOn       string  `json:"dueOn,omitempty"`
	Weakness    float64 `json:"weakness"`
}

type syllabusSection struct {
	Title   string          `json:"title"`
	Mastery float64         `json:"mastery"` // 0..1, mean of per-topic mastery
	Topics  []syllabusTopic `json:"topics"`
}

type syllabusSubject struct {
	Subject  string            `json:"subject"`
	Sections []syllabusSection `json:"sections"`
}

type syllabusStats struct {
	Topics   int `json:"topics"`
	Mastered int `json:"mastered"`
	Learning int `json:"learning"`
	Unseen   int `json:"unseen"`
	Due      int `json:"due"`
}

type syllabusPayload struct {
	Body     string            `json:"body"`
	Stats    syllabusStats     `json:"stats"`
	Weakest  []syllabusTopic   `json:"weakest"`
	Subjects []syllabusSubject `json:"subjects"`
}

// masteredTopic is the maturity rule shared with the review stats: a
// mature SM-2 interval AND a strong last paper.
const masteredInterval = store.MatureInterval

func (s *Server) handleSyllabus(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	sy, ok := s.lib.SyllabusForBody(r.PathValue("body"))
	if !ok {
		fail(w, http.StatusNotFound, "unknown_body",
			"no syllabus tree for "+r.PathValue("body"))
		return
	}
	counts := s.lib.TopicCounts(sy.Body)

	review, err := s.store.ReviewByUser(r.Context(), uid)
	if err != nil {
		s.log.Error("syllabus: review state", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load your mastery state")
		return
	}
	state := map[string]store.TopicState{}
	for i := range review.Due {
		it := &review.Due[i]
		state[it.Topic] = store.TopicState{
			SM2:         store.SM2Item{Ease: it.Ease, IntervalDays: it.IntervalDays, Repetitions: it.Repetitions, Lapses: it.Lapses},
			LastCorrect: it.LastCorrect, LastTotal: it.LastTotal, DueOn: parseDay(it.DueOn),
		}
	}
	for i := range review.Upcoming {
		it := &review.Upcoming[i]
		state[it.Topic] = store.TopicState{
			SM2:         store.SM2Item{Ease: it.Ease, IntervalDays: it.IntervalDays, Repetitions: it.Repetitions, Lapses: it.Lapses},
			LastCorrect: it.LastCorrect, LastTotal: it.LastTotal, DueOn: parseDay(it.DueOn),
		}
	}
	today := time.Now().UTC().Truncate(24 * time.Hour)

	build := func(topic string) syllabusTopic {
		t := syllabusTopic{Topic: topic, Questions: counts[topic], Status: "unseen"}
		if st, seen := state[topic]; seen {
			t.Seen = true
			t.LastCorrect, t.LastTotal = st.LastCorrect, st.LastTotal
			if st.LastTotal > 0 {
				t.Accuracy = float64(st.LastCorrect) / float64(st.LastTotal)
			}
			t.DueOn = st.DueOn.Format("2006-01-02")
			t.Weakness = store.Weakness(st, today)
			if st.SM2.IntervalDays >= masteredInterval && t.Accuracy >= 0.8 {
				t.Status = "mastered"
			} else {
				t.Status = "learning"
			}
		} else {
			t.Weakness = store.UnseenWeakness
		}
		return t
	}

	payload := syllabusPayload{
		Body:     sy.Body,
		Weakest:  []syllabusTopic{},
		Subjects: make([]syllabusSubject, 0, len(sy.Subjects)),
	}
	seenTopics := map[string]struct{}{}
	for _, sub := range sy.Subjects {
		sOut := syllabusSubject{Subject: sub.Subject, Sections: make([]syllabusSection, 0, len(sub.Sections))}
		for _, sec := range sub.Sections {
			secOut := syllabusSection{Title: sec.Title, Topics: make([]syllabusTopic, 0, len(sec.Topics))}
			masterySum := 0.0
			for _, topic := range sec.Topics {
				t := build(topic)
				secOut.Topics = append(secOut.Topics, t)
				seenTopics[topic] = struct{}{}
				switch t.Status {
				case "mastered":
					masterySum += 1
					payload.Stats.Mastered++
				case "learning":
					masterySum += t.Accuracy
					payload.Stats.Learning++
				default:
					payload.Stats.Unseen++
				}
				payload.Stats.Topics++
			}
			if n := len(sec.Topics); n > 0 {
				secOut.Mastery = masterySum / float64(n)
			}
			sOut.Sections = append(sOut.Sections, secOut)
		}
		payload.Subjects = append(payload.Subjects, sOut)
	}
	payload.Stats.Due = review.Stats.Due

	// Weak-topic links: seen topics the last paper exposed, worst first.
	var weak []syllabusTopic
	for topic := range state {
		if _, inTree := seenTopics[topic]; !inTree {
			continue // history from packs this tree no longer serves
		}
		t := build(topic)
		if t.Status == "mastered" || t.LastTotal == 0 {
			continue
		}
		weak = append(weak, t)
	}
	sort.Slice(weak, func(a, b int) bool {
		if weak[a].Weakness != weak[b].Weakness {
			return weak[a].Weakness > weak[b].Weakness
		}
		return weak[a].Topic < weak[b].Topic
	})
	if len(weak) > 3 {
		weak = weak[:3]
	}
	payload.Weakest = weak

	writeJSON(w, http.StatusOK, payload)
}

func parseDay(day string) time.Time {
	t, err := time.Parse("2006-01-02", day)
	if err != nil {
		return time.Time{}
	}
	return t
}
