// Flashcard endpoints (ROADMAP #7).
//
// GET  /flashcards           , deck list (meta only)
// GET  /flashcards/{code}    , one deck with its cards (server-held
//
//	content, same doctrine as bundles)
//
// GET  /me/cards/progress    , the student's Leitner state
// POST /me/cards/progress    , batch grade, updated rows back
package httpapi

import (
	"net/http"

	"renance.dev/study-api/internal/store"
)

func (s *Server) handleFlashcardDecks(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"decks": s.lib.Decks()})
}

func (s *Server) handleFlashcardDeck(w http.ResponseWriter, r *http.Request) {
	deck, ok := s.lib.Deck(r.PathValue("code"))
	if !ok {
		fail(w, http.StatusNotFound, "unknown_deck", "no flashcard deck with code "+r.PathValue("code"))
		return
	}
	writeJSON(w, http.StatusOK, deck)
}

func (s *Server) handleCardProgress(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	progress, err := s.store.CardsByUser(r.Context(), uid)
	if err != nil {
		s.log.Error("card progress lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not read card progress")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"progress": progress})
}

type gradeCardsRequest struct {
	Grades []struct {
		CardID   string `json:"cardId"`
		DeckCode string `json:"deckCode,omitempty"`
		Grade    string `json:"grade"`
	} `json:"grades"`
}

func (s *Server) handleGradeCards(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req gradeCardsRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.Grades) == 0 {
		fail(w, http.StatusBadRequest, "empty_grades", "grades must hold at least one card")
		return
	}
	if len(req.Grades) > 200 {
		fail(w, http.StatusBadRequest, "too_many_grades", "grade at most 200 cards per call")
		return
	}
	grades := make([]store.CardGrade, 0, len(req.Grades))
	for _, g := range req.Grades {
		if g.CardID == "" {
			fail(w, http.StatusBadRequest, "invalid_grade", "every grade needs a cardId")
			return
		}
		switch g.Grade {
		case "again", "hard", "good":
			// ok
		default:
			fail(w, http.StatusBadRequest, "invalid_grade",
				"grade must be again, hard or good (got "+g.Grade+")")
			return
		}
		grades = append(grades, store.CardGrade{CardID: g.CardID, DeckCode: g.DeckCode, Grade: g.Grade})
	}

	progress, err := s.store.GradeCards(r.Context(), uid, grades)
	if err != nil {
		s.log.Error("grade cards failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save card progress")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"progress": progress})
}
