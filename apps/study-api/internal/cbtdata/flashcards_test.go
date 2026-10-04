package cbtdata

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// writeDeck is a helper that materialises a deck file in a temp library.
func writeDeck(t *testing.T, name, body string) string {
	t.Helper()
	dir := t.TempDir()
	fc := filepath.Join(dir, "flashcards")
	if err := os.MkdirAll(fc, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(fc, name), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

func TestLoadFlashcardsDirect(t *testing.T) {
	l := &Library{decks: map[string]*Deck{}}
	dir := writeDeck(t, "bio.json", `{
		"code": "bio", "title": "Biology", "subject": "Biology", "body": "JAMB",
		"cards": [
			{"id": "b1", "front": "F1", "back": "B1"},
			{"id": "b2", "front": "F2", "back": "B2", "hint": "H"}
		]}`)
	if err := l.loadFlashcards(dir); err != nil {
		t.Fatalf("valid deck refused: %v", err)
	}
	if len(l.deckOrder) != 1 || l.deckOrder[0] != "bio" {
		t.Fatalf("deckOrder = %v", l.deckOrder)
	}
	d, ok := l.Deck("bio")
	if !ok || d.CardCount != 2 || d.Title != "Biology" {
		t.Fatalf("deck lookup wrong: %+v ok=%v", d, ok)
	}
	metas := l.Decks()
	if len(metas) != 1 || metas[0].CardCount != 2 || metas[0].Code != "bio" {
		t.Fatalf("metas wrong: %+v", metas)
	}
}

func TestLoadFlashcardsMissingDirOptional(t *testing.T) {
	l := &Library{decks: map[string]*Deck{}}
	if err := l.loadFlashcards(t.TempDir()); err != nil {
		t.Fatalf("missing flashcards dir must be optional: %v", err)
	}
	if len(l.Decks()) != 0 {
		t.Fatalf("expected zero decks")
	}
}

func TestLoadFlashcardsCodeMustMatchFilename(t *testing.T) {
	l := &Library{decks: map[string]*Deck{}}
	dir := writeDeck(t, "bio.json", `{
		"code": "chem", "title": "X",
		"cards": [{"id": "c1", "front": "F", "back": "B"}]}`)
	err := l.loadFlashcards(dir)
	if err == nil || !strings.Contains(err.Error(), "declares code") {
		t.Fatalf("mismatched code must refuse boot, got %v", err)
	}
}

func TestLoadFlashcardsEmptyCardRefused(t *testing.T) {
	l := &Library{decks: map[string]*Deck{}}
	dir := writeDeck(t, "bio.json", `{
		"code": "bio", "title": "X",
		"cards": [{"id": "c1", "front": "", "back": "B"}]}`)
	err := l.loadFlashcards(dir)
	if err == nil || !strings.Contains(err.Error(), "front and back") {
		t.Fatalf("empty front must refuse boot, got %v", err)
	}
}

func TestLoadFlashcardsDuplicateIDRefused(t *testing.T) {
	l := &Library{decks: map[string]*Deck{}}
	dir := t.TempDir()
	fc := filepath.Join(dir, "flashcards")
	if err := os.MkdirAll(fc, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, f := range []struct{ name, body string }{
		{"a.json", `{"code":"a","title":"A","cards":[{"id":"dup","front":"F","back":"B"}]}`},
		{"b.json", `{"code":"b","title":"B","cards":[{"id":"dup","front":"F","back":"B"}]}`},
	} {
		if err := os.WriteFile(filepath.Join(fc, f.name), []byte(f.body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	err := l.loadFlashcards(dir)
	if err == nil || !strings.Contains(err.Error(), "appears in") {
		t.Fatalf("duplicate card id across decks must refuse boot, got %v", err)
	}
}

func TestLoadFlashcardsMalformedJSONRefused(t *testing.T) {
	l := &Library{decks: map[string]*Deck{}}
	dir := writeDeck(t, "bad.json", `{ not json `)
	if err := l.loadFlashcards(dir); err == nil {
		t.Fatalf("malformed deck must refuse boot")
	}
}
