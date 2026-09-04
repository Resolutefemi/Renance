// Fatigue telemetry (ROADMAP #6): server-side log of study sittings.
//
// The same design law as review.go — the rules live in the pure fatigue
// package; these methods only persist what the rules computed. Clients
// POST one row per sitting (best-effort); GET /me/fatigue aggregates the
// recent window for the home-screen "take a break" banner.
package store

import (
	"context"
	"time"
)

// SessionLog is one persisted sitting.
type SessionLog struct {
	ID             string
	AttemptID      *string
	Code           string
	StartedAt      time.Time
	EndedAt        time.Time
	DurationMs     int64
	AnswerCount    int
	MedianFirst5   int64
	MedianLast5    int64
	DriftRatio     float64
	FatigueLevel   string
	SuggestedBreak bool
	CreatedAt      time.Time
}

// LogSession stores one sitting's telemetry. attemptID is optional
// (flashcard runs and practice sessions log without a paper).
func (s *Store) LogSession(ctx context.Context, userID string, lg SessionLog) error {
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO study.sessions
			(user_id, attempt_id, code, started_at, ended_at, duration_ms,
			 answer_count, median_first5, median_last5, drift_ratio,
			 fatigue_level, suggested_break)
		VALUES ($1, NULLIF($2,''), $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		userID, lg.AttemptID, lg.Code, lg.StartedAt, lg.EndedAt, lg.DurationMs,
		lg.AnswerCount, lg.MedianFirst5, lg.MedianLast5, lg.DriftRatio,
		lg.FatigueLevel, lg.SuggestedBreak,
	)
	return err
}

// FatigueState is the current advisory the home screens render.
type FatigueState struct {
	Level         string  `json:"level"`        // none | mild | high
	SuggestBreak  bool    `json:"suggestBreak"` // render the banner
	Reason        string  `json:"reason,omitempty"`
	MinutesToday  float64 `json:"minutesToday"`  // study minutes today (UTC day)
	MinutesLast3h float64 `json:"minutesLast3h"` // study minutes in the last 3 h
	SessionsToday int     `json:"sessionsToday"` // logged sittings today
}

// FatigueNow aggregates the student's recent sittings into a banner state.
// Three explainable thresholds (mirror of the pure rules, applied to the
// log instead of one sitting):
//
//	high — a high-fatigue sitting ended less than 30 min ago, OR
//	       45+ study minutes inside the last 3 hours;
//	mild — 90+ study minutes today with nothing heavier triggered.
func (s *Store) FatigueNow(ctx context.Context, userID string) (*FatigueState, error) {
	rows, err := s.Pool.Query(ctx, `
		SELECT duration_ms, fatigue_level, suggested_break, ended_at
		FROM study.sessions
		WHERE user_id = $1
		  AND ended_at >= now() - interval '24 hours'
		ORDER BY ended_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	st := &FatigueState{Level: "none"}
	now := time.Now().UTC()
	for rows.Next() {
		var (
			durMs   int64
			level   string
			suggest bool
			endedAt time.Time
		)
		if err := rows.Scan(&durMs, &level, &suggest, &endedAt); err != nil {
			return nil, err
		}
		mins := float64(durMs) / 60000.0
		age := now.Sub(endedAt)
		if sameUTCDay(now, endedAt) {
			st.MinutesToday += mins
			st.SessionsToday++
		}
		if age <= 3*time.Hour {
			st.MinutesLast3h += mins
		}
		if suggest && age <= 30*time.Minute && st.Level != "high" {
			st.Level = level
			st.Reason = "You just finished an intense sitting"
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	switch {
	case st.MinutesLast3h >= 45:
		st.Level = "high"
		st.Reason = "You have studied 45+ minutes in the last 3 hours"
	case st.MinutesToday >= 90 && st.Level == "none":
		st.Level = "mild"
		st.Reason = "That is 90 minutes of study today"
	}

	st.SuggestBreak = st.Level != "none"
	if !st.SuggestBreak {
		st.Reason = ""
	}
	return st, nil
}

func sameUTCDay(a, b time.Time) bool {
	ay, am, ad := a.UTC().Date()
	by, bm, bd := b.UTC().Date()
	return ay == by && am == bm && ad == bd
}
