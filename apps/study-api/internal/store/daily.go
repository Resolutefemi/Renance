// Daily challenge persistence (ROADMAP #20): one ranked row per
// student per exam body per UTC day. The ledger is written best-effort
// by the grading engine; a missing row never breaks a graded paper.
package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// DailyResult is a student's seated score for one day's challenge.
type DailyResult struct {
	AttemptID   string    `json:"attemptId"`
	Code        string    `json:"code"`
	Score       int       `json:"score"`
	Total       int       `json:"total"`
	DurationMs  *int      `json:"durationMs,omitempty"`
	SubmittedAt time.Time `json:"submittedAt"`
}

// DailyBoardEntry is one ranked line of a day's challenge board.
type DailyBoardEntry struct {
	UserID      string    `json:"-"`
	Rank        int       `json:"rank"`
	Username    string    `json:"username"`
	Score       int       `json:"score"`
	Total       int       `json:"total"`
	DurationMs  *int      `json:"durationMs,omitempty"`
	SubmittedAt time.Time `json:"submittedAt"`
}

// RecordDailyResult seats a graded daily attempt on the day's board.
// First write wins the PRIMARY KEY (day, body, user_id): replays stay
// practice-only. The reported moment is the attempt's own submission,
// not grading time, so tie-breaks stay honest even when the queue
// reorders work. Returns true when THIS call took the seat.
func (s *Store) RecordDailyResult(ctx context.Context, day, body, userID, attemptID, code string, score, total int, durationMs *int) (bool, error) {
	tag, err := s.Pool.Exec(ctx, `
		INSERT INTO study.daily_results
			(day, body, user_id, attempt_id, code, score, total, duration_ms, submitted_at)
		SELECT $1::date, $2, $3, $4, $5, $6, $7, $8,
		       COALESCE((SELECT submitted_at FROM study.attempts WHERE id = $4), now())
		ON CONFLICT (day, body, user_id) DO NOTHING`,
		day, body, userID, attemptID, code, score, total, durationMs)
	if err != nil {
		return false, fmt.Errorf("store: record daily result: %w", err)
	}
	return tag.RowsAffected() == 1, nil
}

// DailyResultFor returns the caller's seated result for a day's
// challenge, or nil when they have not claimed it yet.
func (s *Store) DailyResultFor(ctx context.Context, day, body, userID string) (*DailyResult, error) {
	r := &DailyResult{}
	err := s.Pool.QueryRow(ctx, `
		SELECT attempt_id, code, score, total, duration_ms, submitted_at
		FROM study.daily_results
		WHERE day = $1::date AND body = $2 AND user_id = $3`,
		day, body, userID,
	).Scan(&r.AttemptID, &r.Code, &r.Score, &r.Total, &r.DurationMs, &r.SubmittedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("store: daily result for: %w", err)
	}
	return r, nil
}

// dailyBoardOrder is the shared ordering behind the top list and the
// single-student rank lookup: score first, then the EARLIEST honest
// submission wins the tie, then username for full determinism.
const dailyBoardOrder = `ORDER BY dr.score DESC, dr.submitted_at ASC, u.username ASC`

const dailyBoardSelect = `
		SELECT dr.user_id::text, u.username,
		       dr.score::int, dr.total::int, dr.duration_ms, dr.submitted_at
		FROM study.daily_results dr
		JOIN study.users u ON u.id = dr.user_id
		WHERE dr.day = $1::date AND dr.body = $2
`

// DailyLeaderboard returns the top scorers of one day's challenge.
func (s *Store) DailyLeaderboard(ctx context.Context, day, body string, limit int) ([]DailyBoardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}
	rows, err := s.Pool.Query(ctx, dailyBoardSelect+" "+dailyBoardOrder+" LIMIT $3", day, body, limit)
	if err != nil {
		return nil, fmt.Errorf("store: daily leaderboard: %w", err)
	}
	defer rows.Close()

	out := make([]DailyBoardEntry, 0, limit)
	for rows.Next() {
		var e DailyBoardEntry
		if err := rows.Scan(&e.UserID, &e.Username, &e.Score, &e.Total, &e.DurationMs, &e.SubmittedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// DailyRank returns the caller's row with its absolute rank on the same
// ordering as DailyLeaderboard. ok is false when the student has no
// seated result for that day yet.
func (s *Store) DailyRank(ctx context.Context, day, body, userID string) (DailyBoardEntry, bool, error) {
	row := s.Pool.QueryRow(ctx, `
		WITH ranked AS (
`+dailyBoardSelect+`		`+dailyBoardOrder+`
		)
		SELECT user_id, ROW_NUMBER() OVER (ORDER BY score DESC, submitted_at ASC, username ASC)::int,
		       username, score, total, duration_ms, submitted_at
		FROM ranked
		WHERE user_id = $3
	`, day, body, userID)

	var e DailyBoardEntry
	if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.Score, &e.Total, &e.DurationMs, &e.SubmittedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return e, false, nil
		}
		return e, false, err
	}
	return e, true, nil
}
