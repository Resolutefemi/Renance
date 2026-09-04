// Gamification: streaks, XP and badge awards (ROADMAP #2).
//
// Design: the DB row is the single source of truth; the pure helpers below
// (NextStreak, BadgesFor) carry all rules so they are unit-testable without
// a database. ApplyGrade applies them transactionally on every graded
// attempt, called from the grading engine, never from the request path.
package store

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// XP per correct answer. Deliberately simple: v1 of the economy.
const XPPerCorrect = 10

// StreakState is the gamification summary for one scholar.
type StreakState struct {
	CurrentStreak int    `json:"currentStreak"`
	BestStreak    int    `json:"bestStreak"`
	TotalXP       int    `json:"totalXp"`
	TotalCorrect  int    `json:"totalCorrect"`
	Attempts      int    `json:"attempts"`
	Level         int    `json:"level"`
	LastActive    string `json:"lastActive,omitempty"` // YYYY-MM-DD
}

// Award is one badge in the ledger.
type Award struct {
	Code     string          `json:"code"`
	Meta     json.RawMessage `json:"meta,omitempty"`
	EarnedAt time.Time       `json:"earnedAt"`
}

// GradeOutcome is what ApplyGrade returns: fresh state + badges earned NOW.
type GradeOutcome struct {
	State     StreakState
	NewAwards []Award
}

// NextStreak is the pure streak rule: same day → unchanged; yesterday → +1;
// anything older (or first ever) → reset to 1.
func NextStreak(current int, lastActive, today time.Time) int {
	if lastActive.IsZero() {
		return 1
	}
	days := today.Truncate(24*time.Hour).Sub(lastActive.Truncate(24*time.Hour)) / (24 * time.Hour)
	switch days {
	case 0:
		return current
	case 1:
		return current + 1
	default:
		return 1
	}
}

// LevelFor: a light curve, 500 XP per level, never below 1.
func LevelFor(totalXP int) int {
	if totalXP < 0 {
		totalXP = 0
	}
	return 1 + totalXP/500
}

// BadgesFor is the pure badge rule set, evaluated against the post-grade
// state. Returns codes that SHOULD be held after this grade; the caller
// (ApplyGrade) inserts only the ones not already in the ledger.
func BadgesFor(s StreakState, lastScore, lastTotal int) []string {
	var codes []string
	add := func(c string, cond bool) {
		if cond {
			codes = append(codes, c)
		}
	}
	add("first_blood", s.Attempts >= 1)
	add("perfect_paper", lastTotal > 0 && lastScore == lastTotal)
	add("century", s.TotalCorrect >= 100)
	add("xp_500", s.TotalXP >= 500)
	add("xp_2000", s.TotalXP >= 2000)
	add("streak_3", s.CurrentStreak >= 3)
	add("streak_7", s.CurrentStreak >= 7)
	add("streak_30", s.CurrentStreak >= 30)
	return codes
}

// ApplyGrade records one graded attempt's gamification effects in a single
// transaction: upsert streaks, insert any newly-earned badges, and return
// the fresh state plus the awards earned by THIS grade.
func (s *Store) ApplyGrade(ctx context.Context, userID string, lastScore, lastTotal int) (*GradeOutcome, error) {
	today := time.Now().UTC()
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var (
		current, best, xp, correct, attempts int
		lastActive                           *time.Time
	)
	err = tx.QueryRow(ctx, `
                SELECT current_streak, best_streak, total_xp, total_correct, attempts_count, last_active
                FROM study.streaks WHERE user_id = $1
                FOR UPDATE`, userID).Scan(&current, &best, &xp, &correct, &attempts, &lastActive)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return nil, err
		}
		// First ever grade, zeroed state.
		current, best, xp, correct, attempts = 0, 0, 0, 0, 0
	}

	streak := NextStreak(current, timeOrZero(lastActive), today)
	state := StreakState{
		CurrentStreak: streak,
		BestStreak:    max(best, streak),
		TotalXP:       xp + lastScore*XPPerCorrect,
		TotalCorrect:  correct + lastScore,
		Attempts:      attempts + 1,
		Level:         LevelFor(xp + lastScore*XPPerCorrect),
		LastActive:    today.Format("2006-01-02"),
	}

	_, err = tx.Exec(ctx, `
                INSERT INTO study.streaks
                        (user_id, current_streak, best_streak, total_xp, total_correct, attempts_count, last_active, updated_at)
                VALUES ($1,$2,$3,$4,$5,$6,$7, now())
                ON CONFLICT (user_id) DO UPDATE SET
                        current_streak = EXCLUDED.current_streak,
                        best_streak    = EXCLUDED.best_streak,
                        total_xp       = EXCLUDED.total_xp,
                        total_correct  = EXCLUDED.total_correct,
                        attempts_count = EXCLUDED.attempts_count,
                        last_active    = EXCLUDED.last_active,
                        updated_at     = now()`,
		userID, state.CurrentStreak, state.BestStreak, state.TotalXP,
		state.TotalCorrect, state.Attempts, today)
	if err != nil {
		return nil, err
	}

	out := &GradeOutcome{State: state}
	for _, code := range BadgesFor(state, lastScore, lastTotal) {
		var (
			earned time.Time
			meta   []byte
		)
		err := tx.QueryRow(ctx, `
                        INSERT INTO study.awards (user_id, code) VALUES ($1,$2)
                        ON CONFLICT (user_id, code) DO NOTHING
                        RETURNING earned_at, meta`, userID, code).Scan(&earned, &meta)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue // already held (no row returned) - not an error case
			}
			return nil, err // real DB failure: abort the transaction
		}
		out.NewAwards = append(out.NewAwards, Award{Code: code, Meta: json.RawMessage(meta), EarnedAt: earned})
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return out, nil
}

// GamificationByUser returns the current state + full badge ledger.
func (s *Store) GamificationByUser(ctx context.Context, userID string) (*StreakState, []Award, error) {
	var st StreakState
	var lastActive *time.Time
	err := s.Pool.QueryRow(ctx, `
                SELECT current_streak, best_streak, total_xp, total_correct, attempts_count, last_active
                FROM study.streaks WHERE user_id = $1`, userID).
		Scan(&st.CurrentStreak, &st.BestStreak, &st.TotalXP, &st.TotalCorrect, &st.Attempts, &lastActive)
	if err != nil {
		return nil, nil, err // pgx.ErrNoRows → handler renders a zero state
	}
	st.Level = LevelFor(st.TotalXP)
	if lastActive != nil {
		st.LastActive = lastActive.Format("2006-01-02")
	}

	rows, err := s.Pool.Query(ctx, `
                SELECT code, meta, earned_at FROM study.awards WHERE user_id = $1 ORDER BY earned_at DESC`, userID)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	var awards []Award
	for rows.Next() {
		var a Award
		var meta []byte
		if err := rows.Scan(&a.Code, &meta, &a.EarnedAt); err != nil {
			return nil, nil, err
		}
		a.Meta = json.RawMessage(meta)
		awards = append(awards, a)
	}
	return &st, awards, rows.Err()
}

func timeOrZero(t *time.Time) time.Time {
	if t == nil {
		return time.Time{}
	}
	return *t
}
