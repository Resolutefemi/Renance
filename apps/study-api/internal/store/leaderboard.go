package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

// Leaderboards: read-only aggregates over data the product already
// writes — arena outcomes (0008) and gamification streaks (0003). No
// migration here on purpose: both boards are answerable from existing
// tables and indexes, and the arena board filters on
// arena.matches.finished_at which arena_matches_finished_idx covers.
//
// Bots never rank: arena.participants rows with is_bot are excluded and
// the join on study.users drops the rest anyway (bot user_id IS NULL).

// ArenaBoardEntry is one ranked line of the arena leaderboard. UserID is
// internal (json:"-"): the handler uses it to find the caller's row.
type ArenaBoardEntry struct {
	UserID   string `json:"-"`
	Rank     int    `json:"rank"`
	Username string `json:"username"`
	Wins     int    `json:"wins"`
	Matches  int    `json:"matches"`
	Points   int    `json:"points"`
	Correct  int    `json:"correct"`
}

// StudyBoardEntry is one ranked line of the study (XP) leaderboard.
type StudyBoardEntry struct {
	UserID        string `json:"-"`
	Rank          int    `json:"rank"`
	Username      string `json:"username"`
	XP            int    `json:"xp"`
	BestStreak    int    `json:"bestStreak"`
	CurrentStreak int    `json:"currentStreak"`
	Attempts      int    `json:"attempts"`
}

// arenaBoardPeriod maps the API period to the SQL time filter. "week"
// ranks the last 7 days; "all" ranks forever.
func arenaBoardPeriod(period string) string {
	if period == "week" {
		return `AND m.finished_at >= now() - interval '7 days'`
	}
	return ""
}

// arenaBoardSelect is the shared aggregate behind the top-25 list and the
// single-student rank lookup, so both can never disagree about ordering.
// Ordering is deterministic: wins, then points, then efficiency (fewer
// matches for the same record ranks higher), then username.
const arenaBoardSelect = `
                SELECT p.user_id::text,
                       u.username,
                       COUNT(*)::int                                             AS matches,
                       COUNT(*) FILTER (WHERE m.winner_user_id = p.user_id)::int AS wins,
                       COALESCE(SUM(p.score), 0)::int                            AS points,
                       COALESCE(SUM(p.correct), 0)::int                          AS correct
                FROM arena.participants p
                JOIN arena.matches m ON m.id = p.match_id
                JOIN study.users u   ON u.id = p.user_id
                WHERE m.status = 'finished'
                  AND p.is_bot = false
        `

const arenaBoardOrder = `
                GROUP BY p.user_id, u.username
                ORDER BY wins DESC, points DESC, matches ASC, u.username ASC
        `

// ArenaLeaderboard returns the top human arena players. period is
// "week" or "all" (the handler validates; anything else means all).
func (s *Store) ArenaLeaderboard(ctx context.Context, period string, limit int) ([]ArenaBoardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}
	rows, err := s.Pool.Query(ctx, arenaBoardSelect+" "+
		arenaBoardPeriod(period)+" "+
		arenaBoardOrder+" LIMIT $1", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]ArenaBoardEntry, 0, limit)
	for rows.Next() {
		var e ArenaBoardEntry
		if err := rows.Scan(&e.UserID, &e.Username, &e.Matches, &e.Wins, &e.Points, &e.Correct); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ArenaRank returns the caller's row with its absolute rank on the same
// ordering as ArenaLeaderboard. ok is false when the student has not
// finished a single arena match in the period yet.
func (s *Store) ArenaRank(ctx context.Context, userID, period string) (ArenaBoardEntry, bool, error) {
	row := s.Pool.QueryRow(ctx, `
                WITH agg AS (
`+arenaBoardSelect+" "+
		arenaBoardPeriod(period)+" "+
		arenaBoardOrder+`
                )
                SELECT user_id, ROW_NUMBER() OVER (ORDER BY wins DESC, points DESC, matches ASC, username ASC)::int,
                       username, wins, matches, points, correct
                FROM agg
                WHERE user_id = $1
        `, userID)

	var e ArenaBoardEntry
	if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.Wins, &e.Matches, &e.Points, &e.Correct); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return e, false, nil
		}
		return e, false, err
	}
	return e, true, nil
}

// StudyLeaderboard returns the top students by total XP, then best
// streak. It reads study.streaks, which ApplyGrade upserts on every
// graded attempt — students appear the moment their first paper grades.
func (s *Store) StudyLeaderboard(ctx context.Context, limit int) ([]StudyBoardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT st.user_id::text, u.username,
                       st.total_xp::int, st.best_streak::int, st.current_streak::int, st.attempts_count::int
                FROM study.streaks st
                JOIN study.users u ON u.id = st.user_id
                ORDER BY st.total_xp DESC, st.best_streak DESC, st.attempts_count ASC, u.username ASC
                LIMIT $1
        `, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]StudyBoardEntry, 0, limit)
	for rows.Next() {
		var e StudyBoardEntry
		if err := rows.Scan(&e.UserID, &e.Username, &e.XP, &e.BestStreak, &e.CurrentStreak, &e.Attempts); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// StudyRank returns the caller's row with its absolute XP rank. ok is
// false when the student has no graded attempts yet.
func (s *Store) StudyRank(ctx context.Context, userID string) (StudyBoardEntry, bool, error) {
	row := s.Pool.QueryRow(ctx, `
                WITH ranked AS (
                        SELECT st.user_id::text AS user_id, u.username,
                               st.total_xp, st.best_streak, st.current_streak, st.attempts_count,
                               ROW_NUMBER() OVER (ORDER BY st.total_xp DESC, st.best_streak DESC,
                                                  st.attempts_count ASC, u.username ASC)::int AS rank
                        FROM study.streaks st
                        JOIN study.users u ON u.id = st.user_id
                )
                SELECT user_id, rank, username, total_xp, best_streak, current_streak, attempts_count
                FROM ranked
                WHERE user_id = $1
        `, userID)

	var e StudyBoardEntry
	if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.XP, &e.BestStreak, &e.CurrentStreak, &e.Attempts); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return e, false, nil
		}
		return e, false, err
	}
	return e, true, nil
}
