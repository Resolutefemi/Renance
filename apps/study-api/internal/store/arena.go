package store

import (
	"context"
	"time"
)

// Arena persistence: the DURABLE half of ROADMAP #14. The live match
// (timers, answers, presence) lives in the hub's memory; this file only
// records outcomes (best-effort by contract) and serves match history.

// ArenaParticipant is one player's final line of a match. UserID is ""
// for the house bot (is_bot marks those rows; user_id stays NULL).
type ArenaParticipant struct {
	UserID   string
	Username string
	Score    int
	Correct  int
	Answered int
	IsBot    bool
}

// ArenaMatchRecord is the outcome the hub reports when a match ends.
type ArenaMatchRecord struct {
	MatchID      string
	Code         string
	Body         string
	Status       string // "finished" | "aborted"
	WinnerUserID string // "" = draw or aborted
	Participants []ArenaParticipant
}

// SaveArenaMatch upserts the match row and replaces its participants in
// one transaction. The hub may report a match twice only in pathological
// shutdown races; the upsert keeps that harmless.
func (s *Store) SaveArenaMatch(ctx context.Context, m ArenaMatchRecord) error {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	winner := m.WinnerUserID
	if winner != "" && len(winner) > 4 && winner[:4] == "bot:" {
		winner = "" // bots never own a user row; a bot win is a NULL winner
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO arena.matches (id, code, body, status, winner_user_id, player_count, finished_at)
		VALUES ($1, $2, $3, $4, NULLIF($5, '')::uuid, $6, now())
		ON CONFLICT (id) DO UPDATE SET
			status = EXCLUDED.status,
			winner_user_id = EXCLUDED.winner_user_id,
			finished_at = EXCLUDED.finished_at
	`, m.MatchID, m.Code, m.Body, m.Status, winner, len(m.Participants))
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `DELETE FROM arena.participants WHERE match_id = $1`, m.MatchID)
	if err != nil {
		return err
	}
	for _, p := range m.Participants {
		if _, err := tx.Exec(ctx, `
			INSERT INTO arena.participants
				(match_id, user_id, username, score, correct, answered, is_bot, finished_at)
			VALUES ($1, NULLIF($2, '')::uuid, $3, $4, $5, $6, $7, now())
			ON CONFLICT (match_id, user_id) DO NOTHING
		`, m.MatchID, p.UserID, p.Username, p.Score, p.Correct, p.Answered, p.IsBot); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// ArenaHistoryRow is one finished match, as it appears to one student.
type ArenaHistoryRow struct {
	MatchID    string     `json:"matchId"`
	Code       string     `json:"code"`
	Body       string     `json:"body"`
	Status     string     `json:"status"`
	Score      int        `json:"score"`
	Correct    int        `json:"correct"`
	Answered   int        `json:"answered"`
	Won        bool       `json:"won"`
	Opponent   string     `json:"opponent"`
	FinishedAt *time.Time `json:"finishedAt"`
}

// ArenaHistory returns the student's recent matches, newest first.
func (s *Store) ArenaHistory(ctx context.Context, userID string, limit int) ([]ArenaHistoryRow, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	rows, err := s.Pool.Query(ctx, `
		SELECT p.match_id, m.code, m.body, m.status,
		       p.score, p.correct, p.answered,
		       COALESCE(m.winner_user_id = p.user_id, false) AS won,
		       COALESCE(opp.username, '')                    AS opponent,
		       m.finished_at
		FROM arena.participants p
		JOIN arena.matches m
		  ON m.id = p.match_id
		LEFT JOIN arena.participants opp
		  ON opp.match_id = p.match_id
		 AND opp.user_id IS DISTINCT FROM p.user_id
		WHERE p.user_id = $1
		ORDER BY m.finished_at DESC NULLS LAST
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]ArenaHistoryRow, 0, limit)
	for rows.Next() {
		var r ArenaHistoryRow
		if err := rows.Scan(&r.MatchID, &r.Code, &r.Body, &r.Status,
			&r.Score, &r.Correct, &r.Answered, &r.Won, &r.Opponent, &r.FinishedAt); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
