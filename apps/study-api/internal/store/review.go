// Spaced repetition (ROADMAP #3): SM-2 scheduling over attempt topics.
//
// The same design law as gamification.go applies — every rule lives in
// pure, unit-testable functions (QualityFor, NextSM2); the store methods
// only persist their output. The grading engine calls ScheduleReview once
// per graded attempt, and GET /me/review serves the due-today view.
package store

import (
	"context"
	"errors"
	"math"
	"time"

	"github.com/jackc/pgx/v5"
)

// SM-2 constants (SuperMemo-2, 1987). Mature topics survive 21+ day gaps.
const (
	// InitialEase is the ease factor every new topic starts at.
	InitialEase = 2.5
	// MinEase is the floor — a memory that keeps failing never drops below it.
	MinEase = 1.3
	// MaxInterval caps a single interval at a year.
	MaxInterval = 365
	// MatureInterval marks the learning/mature boundary in the stats.
	MatureInterval = 21
)

// SM2Item is the scheduling state of one topic.
type SM2Item struct {
	Ease         float64
	IntervalDays int
	Repetitions  int
	Lapses       int
}

// QualityFor maps a graded topic performance to an SM-2 quality 0..5.
// Accuracy 90%+ is a perfect recall, 60% is the pass line, anything below
// 20% counts as a blackout.
func QualityFor(correct, total int) int {
	if total <= 0 {
		return 0
	}
	acc := float64(correct) / float64(total)
	switch {
	case acc >= 0.90:
		return 5
	case acc >= 0.80:
		return 4
	case acc >= 0.60:
		return 3
	case acc >= 0.40:
		return 2
	case acc >= 0.20:
		return 1
	default:
		return 0
	}
}

// NextSM2 is the classic SuperMemo-2 update rule (pure):
//
//	q < 3   → lapse: repetitions reset, the topic comes back tomorrow.
//	q >= 3  → repetitions++, interval walks 1d → 6d → prev*ease and the
//	          ease itself drifts with recall quality (clamped at 1.3).
func NextSM2(item SM2Item, quality int) SM2Item {
	q := quality
	if q < 0 {
		q = 0
	}
	if q > 5 {
		q = 5
	}
	if item.Ease < MinEase {
		item.Ease = MinEase
	}

	ease := item.Ease + (0.1 - float64(5-q)*(0.08+float64(5-q)*0.02))
	if ease < MinEase {
		ease = MinEase
	}

	if q < 3 {
		return SM2Item{Ease: ease, IntervalDays: 1, Repetitions: 0, Lapses: item.Lapses + 1}
	}

	rep := item.Repetitions + 1
	interval := 1
	switch rep {
	case 1:
		interval = 1
	case 2:
		interval = 6
	default:
		// Canonical SM-2: the interval grows with the ease the topic held
		// AT review time; this repetition's ease drift applies next time.
		interval = int(math.Round(float64(item.IntervalDays) * item.Ease))
		if interval <= item.IntervalDays {
			interval = item.IntervalDays + 1 // monotonic guard at the ease floor
		}
	}
	if interval > MaxInterval {
		interval = MaxInterval
	}
	return SM2Item{Ease: ease, IntervalDays: interval, Repetitions: rep, Lapses: item.Lapses}
}

// ReviewItem is one queued topic as the API returns it.
type ReviewItem struct {
	Topic        string  `json:"topic"`
	Ease         float64 `json:"ease"`
	IntervalDays int     `json:"intervalDays"`
	Repetitions  int     `json:"repetitions"`
	Lapses       int     `json:"lapses"`
	DueOn        string  `json:"dueOn"` // YYYY-MM-DD (UTC)
	LastCorrect  int     `json:"lastCorrect"`
	LastTotal    int     `json:"lastTotal"`
}

// Due, Overdue or neither — the preview status the UIs render.
func (it ReviewItem) Status(today time.Time) string {
	due, err := time.Parse("2006-01-02", it.DueOn)
	if err != nil {
		return "due"
	}
	days := int(today.Truncate(24*time.Hour).Sub(due.Truncate(24*time.Hour)) / (24 * time.Hour))
	switch {
	case days > 0:
		return "overdue"
	case days == 0:
		return "due"
	default:
		return "later"
	}
}

// ReviewStats summarises the queue for hero cards and badges.
type ReviewStats struct {
	Tracked  int `json:"tracked"`
	Due      int `json:"due"`
	Mature   int `json:"mature"`
	Learning int `json:"learning"`
}

// ReviewSummary is the GET /me/review payload. Due holds everything with
// due_on <= today (oldest first); Upcoming holds the rest (soonest first)
// so clients can render the design's "Next up" preview directly.
type ReviewSummary struct {
	Due      []ReviewItem `json:"due"`
	Upcoming []ReviewItem `json:"upcoming"`
	Stats    ReviewStats  `json:"stats"`
}

// ScheduleReview advances the SM-2 state of every topic in a graded
// attempt's breakdown, in one transaction. Rows that do not exist yet
// start from the fresh SM-2 defaults. Called from the grading engine.
func (s *Store) ScheduleReview(ctx context.Context, userID string, breakdown []TopicRow) error {
	rows := make([]TopicRow, 0, len(breakdown))
	for _, b := range breakdown {
		if b.Topic != "" && b.Total > 0 {
			rows = append(rows, b)
		}
	}
	if len(rows) == 0 {
		return nil
	}

	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	today := time.Now().UTC().Truncate(24 * time.Hour)
	for _, b := range rows {
		var item SM2Item
		err := tx.QueryRow(ctx, `
                        SELECT ease, interval_days, repetitions, lapses
                        FROM study.review_queue
                        WHERE user_id = $1 AND topic = $2
                        FOR UPDATE`, userID, b.Topic).
			Scan(&item.Ease, &item.IntervalDays, &item.Repetitions, &item.Lapses)
		if err != nil {
			if !errors.Is(err, pgx.ErrNoRows) {
				return err
			}
			item = SM2Item{Ease: InitialEase}
		}

		next := NextSM2(item, QualityFor(b.Correct, b.Total))
		due := today.AddDate(0, 0, next.IntervalDays)
		if _, err := tx.Exec(ctx, `
                        INSERT INTO study.review_queue
                                (user_id, topic, ease, interval_days, repetitions, lapses, due_on, last_correct, last_total, updated_at)
                        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, now())
                        ON CONFLICT (user_id, topic) DO UPDATE SET
                                ease          = EXCLUDED.ease,
                                interval_days = EXCLUDED.interval_days,
                                repetitions   = EXCLUDED.repetitions,
                                lapses        = EXCLUDED.lapses,
                                due_on        = EXCLUDED.due_on,
                                last_correct  = EXCLUDED.last_correct,
                                last_total    = EXCLUDED.last_total,
                                updated_at    = now()`,
			userID, b.Topic, next.Ease, next.IntervalDays, next.Repetitions,
			next.Lapses, due, b.Correct, b.Total,
		); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// ReviewByUser returns the full queue split into due / upcoming plus stats.
// A scholar with no graded topics yet simply gets empty lists — never 404.
func (s *Store) ReviewByUser(ctx context.Context, userID string) (*ReviewSummary, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT topic, ease, interval_days, repetitions, lapses, due_on, last_correct, last_total
                FROM study.review_queue
                WHERE user_id = $1
                ORDER BY due_on ASC, topic ASC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	today := time.Now().UTC().Truncate(24 * time.Hour)
	sum := &ReviewSummary{Due: []ReviewItem{}, Upcoming: []ReviewItem{}}
	for rows.Next() {
		var it ReviewItem
		var due time.Time
		if err := rows.Scan(&it.Topic, &it.Ease, &it.IntervalDays, &it.Repetitions,
			&it.Lapses, &due, &it.LastCorrect, &it.LastTotal); err != nil {
			return nil, err
		}
		it.DueOn = due.Format("2006-01-02")
		sum.Stats.Tracked++
		if it.IntervalDays >= MatureInterval {
			sum.Stats.Mature++
		} else {
			sum.Stats.Learning++
		}
		if !due.After(today) {
			sum.Due = append(sum.Due, it)
			sum.Stats.Due++
		} else {
			sum.Upcoming = append(sum.Upcoming, it)
		}
	}
	return sum, rows.Err()
}

// ReviewHealth is the /internal/review/tick report: queue-wide counters.
type ReviewHealth struct {
	Users    int `json:"users"`
	Items    int `json:"items"`
	DueToday int `json:"dueToday"`
}

// ReviewHealth tallies the whole queue. Idempotent, read-only — the cron
// endpoint's job is monitoring (and doubling as a keep-warm ping target).
func (s *Store) ReviewHealth(ctx context.Context) (*ReviewHealth, error) {
	h := &ReviewHealth{}
	err := s.Pool.QueryRow(ctx, `
                SELECT COUNT(*), COUNT(DISTINCT user_id),
                       COUNT(*) FILTER (WHERE due_on <= current_date)
                FROM study.review_queue`).
		Scan(&h.Items, &h.Users, &h.DueToday)
	if err != nil {
		return nil, err
	}
	return h, nil
}
