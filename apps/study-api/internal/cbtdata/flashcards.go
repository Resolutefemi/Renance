// Flashcards (ROADMAP #7) — curated front/back decks served like exam
// packs: data/flashcards/{code}.json, loaded and validated at boot.
//
// Flashcards carry their answers by design (the back IS the point), so
// the ADR-0003 answer-leak scan does NOT apply to this namespace. What
// DOES apply is the mechanical-validation doctrine: a malformed deck, a
// card without a front or back, or a duplicate card id anywhere in the
// library refuses the boot, exactly like a sha mismatch on a bundle.
package cbtdata

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Card is one flashcard. Hint is optional spoken/read support.
type Card struct {
	ID    string `json:"id"`
	Front string `json:"front"`
	Back  string `json:"back"`
	Hint  string `json:"hint,omitempty"`
}

// Deck is one studyable stack of cards.
type Deck struct {
	Code      string `json:"code"`
	Title     string `json:"title"`
	Subject   string `json:"subject,omitempty"`
	Body      string `json:"body,omitempty"` // JAMB | WAEC | ... (display only)
	CardCount int    `json:"cardCount"`
	Cards     []Card `json:"cards"`
}

// FlashcardMeta is the list-view row (no cards attached).
type FlashcardMeta struct {
	Code      string `json:"code"`
	Title     string `json:"title"`
	Subject   string `json:"subject,omitempty"`
	Body      string `json:"body,omitempty"`
	CardCount int    `json:"cardCount"`
}

// loadFlashcards scans dataDir/flashcards/*.json. The directory is
// optional — an install with no decks boots fine and serves an empty
// list, but a deck that IS present must be fully valid.
func (l *Library) loadFlashcards(dataDir string) error {
	dir := filepath.Join(dataDir, "flashcards")
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("cbtdata: scan flashcards: %w", err)
	}
	seen := map[string]string{} // card id -> deck code (dup detection)
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			return fmt.Errorf("cbtdata: read deck %s: %w", e.Name(), err)
		}
		var d Deck
		if err := json.Unmarshal(raw, &d); err != nil {
			return fmt.Errorf("cbtdata: parse deck %s: %w", e.Name(), err)
		}
		code := strings.TrimSuffix(e.Name(), ".json")
		if d.Code != code {
			return fmt.Errorf("cbtdata: deck file %s declares code %q", e.Name(), d.Code)
		}
		if strings.TrimSpace(d.Title) == "" {
			return fmt.Errorf("cbtdata: deck %s has no title", d.Code)
		}
		if len(d.Cards) == 0 {
			return fmt.Errorf("cbtdata: deck %s ships zero cards", d.Code)
		}
		for _, c := range d.Cards {
			if strings.TrimSpace(c.ID) == "" {
				return fmt.Errorf("cbtdata: deck %s has a card without an id", d.Code)
			}
			if strings.TrimSpace(c.Front) == "" || strings.TrimSpace(c.Back) == "" {
				return fmt.Errorf("cbtdata: deck %s card %s needs front and back", d.Code, c.ID)
			}
			if prev, dup := seen[c.ID]; dup {
				return fmt.Errorf("cbtdata: card id %s appears in %s and %s", c.ID, prev, d.Code)
			}
			seen[c.ID] = d.Code
		}
		d.CardCount = len(d.Cards)
		l.decks[d.Code] = &d
		l.deckOrder = append(l.deckOrder, d.Code)
	}
	sort.Strings(l.deckOrder)
	return nil
}

// Decks lists every deck in stable (sorted) order.
func (l *Library) Decks() []FlashcardMeta {
	out := make([]FlashcardMeta, 0, len(l.deckOrder))
	for _, code := range l.deckOrder {
		d := l.decks[code]
		out = append(out, FlashcardMeta{
			Code:      d.Code,
			Title:     d.Title,
			Subject:   d.Subject,
			Body:      d.Body,
			CardCount: d.CardCount,
		})
	}
	return out
}

// Deck finds one deck with its full card stack.
func (l *Library) Deck(code string) (*Deck, bool) {
	d, ok := l.decks[code]
	return d, ok
}
