package store

import (
        "context"
        "errors"

        "github.com/jackc/pgx/v5"
)

// Leaderboards: read-only aggregates over data the product already
// writes - arena outcomes (0008) and gamification streaks (0003). No
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
        // Premium rides the row so the board can print the blue tick.
        Premium bool `json:"premium"`
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
        Premium       bool   `json:"premium"`
}

// FocusBoardEntry is one ranked line of a focus leaderboard (JAMB, WAEC,
// NECO). BestScore means the body's own currency: for JAMB it is the
// official UTME aggregate out of 400 (the four subject marks out of 100
// the sealed grading ledger already stores); for WAEC and NECO it is the
// student's best paper percentage. ScoreOutOf carries the denominator so
// the client never has to guess (400 for JAMB, 100 for the rest).
type FocusBoardEntry struct {
        UserID     string  `json:"-"`
        Rank       int     `json:"rank"`
        Username   string  `json:"username"`
        BestScore  float64 `json:"bestScore"`
        ScoreOutOf float64 `json:"scoreOutOf"`
        Papers     int     `json:"papers"`
        Premium    bool    `json:"premium"`
}

// StreakBoardEntry is one ranked line of the streak ladder: the students
// still studying day after day, ranked by the streak they are holding
// right now, with their all-time best as the tiebreaker.
type StreakBoardEntry struct {
        UserID        string `json:"-"`
        Rank          int    `json:"rank"`
        Username      string `json:"username"`
        CurrentStreak int    `json:"currentStreak"`
        BestStreak    int    `json:"bestStreak"`
        Attempts      int    `json:"attempts"`
        Premium       bool   `json:"premium"`
}

// focusBoardSQL ranks one exam focus. $1 is the attempt code prefix
// (jamb-mock-, waec-, neco-). For JAMB the board reads the official
// per-subject ledger the grading engine seals into study.results.subjects
// and sums the four subject marks out of 100 into the aggregate out of
// 400; every other focus falls back to the paper percentage.
const focusBoardSelect = `
                WITH scored AS (
                        SELECT r.attempt_id,
                               a.user_id,
                               CASE WHEN $1::text = 'jamb-mock-' AND r.subjects IS NOT NULL THEN
                                        (SELECT COALESCE(SUM((s->>'score')::numeric), 0)
                                         FROM jsonb_array_elements(r.subjects) s)
                                    ELSE ROUND(100.0 * r.score / GREATEST(r.total, 1), 1)
                               END AS best_score,
                               CASE WHEN $1::text = 'jamb-mock-' AND r.subjects IS NOT NULL THEN 400.0
                                    ELSE 100.0 END AS score_out_of
                        FROM study.results r
                        JOIN study.attempts a ON a.id = r.attempt_id
                        WHERE a.status = 'graded'
                          AND r.total > 0
                          AND a.code LIKE $1::text || '%'
                ),
                agg AS (
                        SELECT s.user_id::text AS user_id,
                               u.username,
                               MAX(s.best_score) AS best_score,
                               MAX(s.score_out_of) AS score_out_of,
                               COUNT(*)::int AS papers,
                               COALESCE(BOOL_OR(e.premium_role
                                        AND (e.premium_expires_at IS NULL
                                             OR e.premium_expires_at > now())), false) AS premium
                        FROM scored s
                        JOIN study.users u ON u.id = s.user_id
                        LEFT JOIN study.entitlements e ON e.user_id = s.user_id
                        GROUP BY s.user_id, u.username
                )
`

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
// $1 filters the arena body ("" = every focus ranks on its own board via
// the ?body= param; the combined board stays available for "any" plays).
// Ordering is deterministic: Ren Points (a win is worth 1) first, then
// efficiency (fewer matches for the same record ranks higher), then
// username.
const arenaBoardSelect = `
                SELECT p.user_id::text,
                       u.username,
                       COUNT(*)::int                                             AS matches,
                       COUNT(*) FILTER (WHERE m.winner_user_id = p.user_id)::int AS wins,
                       COALESCE(SUM(p.score), 0)::int                            AS points,
                       COALESCE(SUM(p.correct), 0)::int                          AS correct,
                       COALESCE(BOOL_OR(e.premium_role
                                AND (e.premium_expires_at IS NULL
                                     OR e.premium_expires_at > now())), false) AS premium
                FROM arena.participants p
                JOIN arena.matches m ON m.id = p.match_id
                JOIN study.users u   ON u.id = p.user_id
                LEFT JOIN study.entitlements e ON e.user_id = p.user_id
                WHERE m.status = 'finished'
                  AND p.is_bot = false
                  AND ($1 = '' OR m.body = $1)
        `

const arenaBoardOrder = `
                GROUP BY p.user_id, u.username
                ORDER BY wins DESC, matches ASC, u.username ASC
        `

// ArenaLeaderboard returns the top human arena players. period is
// "week" or "all" (the handler validates; anything else means all);
// body scopes the board to one focus ("" = every focus combined).
func (s *Store) ArenaLeaderboard(ctx context.Context, period, body string, limit int) ([]ArenaBoardEntry, error) {
        if limit <= 0 || limit > 100 {
                limit = 25
        }
        rows, err := s.Pool.Query(ctx, arenaBoardSelect+" "+
                arenaBoardPeriod(period)+" "+
                arenaBoardOrder+" LIMIT $2", body, limit)
        if err != nil {
                return nil, err
        }
        defer rows.Close()

        out := make([]ArenaBoardEntry, 0, limit)
        for rows.Next() {
                var e ArenaBoardEntry
                if err := rows.Scan(&e.UserID, &e.Username, &e.Matches, &e.Wins, &e.Points, &e.Correct, &e.Premium); err != nil {
                        return nil, err
                }
                out = append(out, e)
        }
        return out, rows.Err()
}

// ArenaRank returns the caller's row with its absolute rank on the same
// ordering as ArenaLeaderboard. ok is false when the student has not
// finished a single arena match in the period yet.
func (s *Store) ArenaRank(ctx context.Context, userID, period, body string) (ArenaBoardEntry, bool, error) {
        row := s.Pool.QueryRow(ctx, `
                WITH agg AS (
`+arenaBoardSelect+" "+
                arenaBoardPeriod(period)+" "+
                arenaBoardOrder+`
                )
                SELECT user_id, ROW_NUMBER() OVER (ORDER BY wins DESC, matches ASC, username ASC)::int,
                       username, wins, matches, points, correct, premium
                FROM agg
                WHERE user_id = $2
        `, body, userID)

        var e ArenaBoardEntry
        if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.Wins, &e.Matches, &e.Points, &e.Correct, &e.Premium); err != nil {
                if errors.Is(err, pgx.ErrNoRows) {
                        return e, false, nil
                }
                return e, false, err
        }
        return e, true, nil
}

// ArenaWinsByUser returns each named student's all-time arena win count
// (their Ren Points), zero for unknown ids. Powers the lobby's
// "active now" list so presence and standing read off one screen.
func (s *Store) ArenaWinsByUser(ctx context.Context, userIDs []string) (map[string]int, error) {
        out := make(map[string]int, len(userIDs))
        if len(userIDs) == 0 {
                return out, nil
        }
        rows, err := s.Pool.Query(ctx, `
                SELECT p.user_id::text, COUNT(*) FILTER (WHERE m.winner_user_id = p.user_id)::int
                FROM arena.participants p
                JOIN arena.matches m ON m.id = p.match_id
                WHERE p.is_bot = false
                  AND m.status = 'finished'
                  AND p.user_id = ANY($1::uuid[])
                GROUP BY p.user_id`, userIDs)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        for rows.Next() {
                var id string
                var wins int
                if err := rows.Scan(&id, &wins); err != nil {
                        return nil, err
                }
                out[id] = wins
        }
        return out, rows.Err()
}

// FocusLeaderboard returns the top students on one focus ladder. body is
// the attempt-code prefix: "jamb-mock-" (official UTME mocks ranked by
// the sealed aggregate out of 400), "waec-" or "neco-" (ranked by best
// paper percentage).
func (s *Store) FocusLeaderboard(ctx context.Context, body string, limit int) ([]FocusBoardEntry, error) {
        if limit <= 0 || limit > 100 {
                limit = 25
        }
        rows, err := s.Pool.Query(ctx, focusBoardSelect+`
                SELECT user_id, username, best_score, score_out_of, papers, premium
                FROM agg
                ORDER BY best_score DESC, papers ASC, username ASC
                LIMIT $2
        `, body, limit)
        if err != nil {
                return nil, err
        }
        defer rows.Close()

        out := make([]FocusBoardEntry, 0, limit)
        for rows.Next() {
                var e FocusBoardEntry
                if err := rows.Scan(&e.UserID, &e.Username, &e.BestScore, &e.ScoreOutOf, &e.Papers, &e.Premium); err != nil {
                        return nil, err
                }
                out = append(out, e)
        }
        return out, rows.Err()
}

// FocusRank returns the caller's absolute rank on one focus ladder, the
// same ordering FocusLeaderboard prints. ok is false when the student
// has not graded a paper in that focus yet.
func (s *Store) FocusRank(ctx context.Context, userID, body string) (FocusBoardEntry, bool, error) {
        row := s.Pool.QueryRow(ctx, focusBoardSelect+`
                SELECT user_id,
                       ROW_NUMBER() OVER (ORDER BY best_score DESC, papers ASC, username ASC)::int,
                       username, best_score, score_out_of, papers, premium
                FROM agg
                WHERE user_id = $2
        `, body, userID)

        var e FocusBoardEntry
        if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.BestScore, &e.ScoreOutOf, &e.Papers, &e.Premium); err != nil {
                if errors.Is(err, pgx.ErrNoRows) {
                        return e, false, nil
                }
                return e, false, err
        }
        return e, true, nil
}

// StreakLeaderboard ranks the students still showing up: current streak
// first, all-time best as the tiebreaker, then the lighter paper count.
func (s *Store) StreakLeaderboard(ctx context.Context, limit int) ([]StreakBoardEntry, error) {
        if limit <= 0 || limit > 100 {
                limit = 25
        }
        rows, err := s.Pool.Query(ctx, `
                SELECT st.user_id::text, u.username,
                       st.current_streak::int, st.best_streak::int, st.attempts_count::int,
                       COALESCE(e.premium_role
                                AND (e.premium_expires_at IS NULL
                                     OR e.premium_expires_at > now()), false) AS premium
                FROM study.streaks st
                JOIN study.users u ON u.id = st.user_id
                LEFT JOIN study.entitlements e ON e.user_id = st.user_id
                ORDER BY st.current_streak DESC, st.best_streak DESC, st.attempts_count ASC, u.username ASC
                LIMIT $1
        `, limit)
        if err != nil {
                return nil, err
        }
        defer rows.Close()

        out := make([]StreakBoardEntry, 0, limit)
        for rows.Next() {
                var e StreakBoardEntry
                if err := rows.Scan(&e.UserID, &e.Username, &e.CurrentStreak, &e.BestStreak, &e.Attempts, &e.Premium); err != nil {
                        return nil, err
                }
                out = append(out, e)
        }
        return out, rows.Err()
}

// StreakRank returns the caller's absolute streak rank, the same
// ordering StreakLeaderboard prints. ok is false when the student has
// no study streak recorded yet.
func (s *Store) StreakRank(ctx context.Context, userID string) (StreakBoardEntry, bool, error) {
        row := s.Pool.QueryRow(ctx, `
                WITH ranked AS (
                        SELECT st.user_id::text AS user_id, u.username,
                               st.current_streak, st.best_streak, st.attempts_count,
                               COALESCE(e.premium_role
                                        AND (e.premium_expires_at IS NULL
                                             OR e.premium_expires_at > now()), false) AS premium,
                               ROW_NUMBER() OVER (ORDER BY st.current_streak DESC, st.best_streak DESC,
                                                  st.attempts_count ASC, u.username ASC)::int AS rank
                        FROM study.streaks st
                        JOIN study.users u ON u.id = st.user_id
                        LEFT JOIN study.entitlements e ON e.user_id = st.user_id
                )
                SELECT user_id, rank, username, current_streak, best_streak, attempts_count, premium
                FROM ranked
                WHERE user_id = $1
        `, userID)

        var e StreakBoardEntry
        if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.CurrentStreak, &e.BestStreak, &e.Attempts, &e.Premium); err != nil {
                if errors.Is(err, pgx.ErrNoRows) {
                        return e, false, nil
                }
                return e, false, err
        }
        return e, true, nil
}

// GemsBoardEntry: one row of the diamond leaderboard - the learners
// richest in gems (founder directive 2026-10-17: "rank users with
// diamond too"). Gems are the learn economy's only currency.
type GemsBoardEntry struct {
	Rank     int    `json:"rank"`
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Gems     int    `json:"gems"`
	XP       int    `json:"xp"`
	Streak   int    `json:"streak"`
	Premium  bool   `json:"premium"`
}

// GemsLeaderboard: the top gem holders, real accounts only (the learn
// tables never held bots, but the JOIN keeps the board honest if one
// ever lands).
func (s *Store) GemsLeaderboard(ctx context.Context, limit int) ([]GemsBoardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}
	rows, err := s.Pool.Query(ctx, `
		SELECT l.user_id::text, u.username,
		       l.gems::int, l.xp::int, COALESCE(l.streak_count, 0)::int,
		       COALESCE(e.premium_role
		                AND (e.premium_expires_at IS NULL
		                     OR e.premium_expires_at > now()), false) AS premium
		FROM learn.learners l
		JOIN study.users u ON u.id = l.user_id
		LEFT JOIN study.entitlements e ON e.user_id = l.user_id
		WHERE l.gems > 0
		ORDER BY l.gems DESC, l.xp DESC, u.username ASC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]GemsBoardEntry, 0, limit)
	for rows.Next() {
		var e GemsBoardEntry
		if err := rows.Scan(&e.UserID, &e.Username, &e.Gems, &e.XP, &e.Streak, &e.Premium); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// GemsRank returns the caller's absolute gem rank (same ordering as
// GemsLeaderboard). ok is false when the learner has no gem balance.
func (s *Store) GemsRank(ctx context.Context, userID string) (GemsBoardEntry, bool, error) {
	row := s.Pool.QueryRow(ctx, `
		WITH ranked AS (
			SELECT l.user_id::text AS user_id, u.username,
			       l.gems::int AS gems, l.xp::int AS xp,
			       COALESCE(l.streak_count, 0)::int AS streak,
			       COALESCE(e.premium_role
			                AND (e.premium_expires_at IS NULL
			                     OR e.premium_expires_at > now()), false) AS premium,
			       ROW_NUMBER() OVER (ORDER BY l.gems DESC, l.xp DESC, u.username ASC)::int AS rank
			FROM learn.learners l
			JOIN study.users u ON u.id = l.user_id
			LEFT JOIN study.entitlements e ON e.user_id = l.user_id
			WHERE l.gems > 0
		)
		SELECT user_id, rank, username, gems, xp, streak, premium
		FROM ranked
		WHERE user_id = $1
	`, userID)

	var e GemsBoardEntry
	if err := row.Scan(&e.UserID, &e.Rank, &e.Username, &e.Gems, &e.XP, &e.Streak, &e.Premium); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return e, false, nil
		}
		return e, false, err
	}
	return e, true, nil
}
