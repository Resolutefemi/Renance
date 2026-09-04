// Flashcard progress (ROADMAP #7): Leitner boxes over card ids.
//
// Boxes 1..5 with fixed intervals, simple, explainable, and identical on
// every client because the rule is pure and mirrored verbatim in the app
// and on the web page. "again" resets to box 1 (due immediately),
// "hard" holds the box (due tomorrow), "good" climbs one box.
package store

import (
	"context"
	"time"
)

// CardBoxIntervals are the review gaps (days) per box. Box 1 is due
// immediately, the card just failed or is brand new.
var CardBoxIntervals = [6]int{0, 0, 1, 2, 4, 7} // index 0 unused

// NextCardBox is the pure Leitner update rule.
// grade is "again" | "hard" | "good" (anything else holds the box).
func NextCardBox(box int, grade string) int {
	switch grade {
	case "again":
		return 1
	case "good":
		if box >= 5 {
			return 5
		}
		return box + 1
	default: // "hard" and unknown grades hold position
		if box < 1 {
			return 1
		}
		return box
	}
}

// CardIntervalDays is the pure interval lookup for a box.
func CardIntervalDays(box int) int {
	if box < 1 {
		box = 1
	}
	if box > 5 {
		box = 5
	}
	return CardBoxIntervals[box]
}

// CardProgress is one card's study state as the API returns it.
type CardProgress struct {
	CardID    string `json:"cardId"`
	DeckCode  string `json:"deckCode"`
	Box       int    `json:"box"`
	Correct   int    `json:"correct"`
	Wrong     int    `json:"wrong"`
	DueOn     string `json:"dueOn"` // YYYY-MM-DD (UTC)
	LastGrade string `json:"lastGrade"`
}

// CardGrade is one client-reported answer inside a batch.
type CardGrade struct {
	CardID   string `json:"cardId"`
	DeckCode string `json:"deckCode"`
	Grade    string `json:"grade"` // again | hard | good
}

// GradeCards applies a batch of grades in one transaction and returns the
// updated rows in input order. Unknown cards start from box 1 (new card).
// Card ids are client-held strings, no FK by design: progress for a deck
// that later rotates out of the content library simply fades unused.
func (s *Store) GradeCards(ctx context.Context, userID string, grades []CardGrade) ([]CardProgress, error) {
	out := make([]CardProgress, 0, len(grades))
	if len(grades) == 0 {
		return out, nil
	}

	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	for _, g := range grades {
		var (
			box      int
			correct  int
			wrong    int
			deckCode string
		)
		err := tx.QueryRow(ctx, `
			SELECT box, correct, wrong, deck_code
			FROM study.card_progress
			WHERE user_id = $1 AND card_id = $2
			FOR UPDATE`, userID, g.CardID).
			Scan(&box, &correct, &wrong, &deckCode)
		if err != nil {
			box, correct, wrong, deckCode = 1, 0, 0, g.DeckCode
		}
		if g.DeckCode != "" {
			deckCode = g.DeckCode
		}

		nextBox := NextCardBox(box, g.Grade)
		correctTotal, wrongTotal := correct, wrong
		switch g.Grade {
		case "again":
			wrongTotal++
		case "good", "hard":
			correctTotal++
		}

		due := time.Now().UTC().Truncate(24*time.Hour).
			AddDate(0, 0, CardIntervalDays(nextBox))
		if _, err := tx.Exec(ctx, `
			INSERT INTO study.card_progress
				(user_id, card_id, deck_code, box, correct, wrong, due_on, last_grade, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
			ON CONFLICT (user_id, card_id) DO UPDATE SET
				deck_code  = EXCLUDED.deck_code,
				box        = EXCLUDED.box,
				correct    = EXCLUDED.correct,
				wrong      = EXCLUDED.wrong,
				due_on     = EXCLUDED.due_on,
				last_grade = EXCLUDED.last_grade,
				updated_at = now()`,
			userID, g.CardID, deckCode, nextBox, correctTotal, wrongTotal,
			due, g.Grade,
		); err != nil {
			return nil, err
		}

		out = append(out, CardProgress{
			CardID:    g.CardID,
			DeckCode:  deckCode,
			Box:       nextBox,
			Correct:   correctTotal,
			Wrong:     wrongTotal,
			DueOn:     due.Format("2006-01-02"),
			LastGrade: g.Grade,
		})
	}
	return out, tx.Commit(ctx)
}

// CardsByUser returns every card progress row the student holds.
func (s *Store) CardsByUser(ctx context.Context, userID string) ([]CardProgress, error) {
	rows, err := s.Pool.Query(ctx, `
		SELECT card_id, deck_code, box, correct, wrong, due_on, last_grade
		FROM study.card_progress
		WHERE user_id = $1
		ORDER BY deck_code ASC, card_id ASC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []CardProgress{}
	for rows.Next() {
		var p CardProgress
		var due time.Time
		if err := rows.Scan(&p.CardID, &p.DeckCode, &p.Box, &p.Correct,
			&p.Wrong, &due, &p.LastGrade); err != nil {
			return nil, err
		}
		p.DueOn = due.Format("2006-01-02")
		out = append(out, p)
	}
	return out, rows.Err()
}
