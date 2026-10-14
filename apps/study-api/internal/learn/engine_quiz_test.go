package learn

import (
	"strings"
	"testing"
)

// The founder's 2026-10-14 bug report: a quiz question rendered its stem
// with a BLANK answer area. Root cause: normalizeQuiz re-labelled every
// unknown AI type "mcq" without options, and an mcq with fewer than two
// usable options can never be answered on screen. Every shape the AI can
// emit must normalize to a question the client can actually render.
func TestNormalizeQuizNeverShipsUnanswerable(t *testing.T) {
	e := &Engine{}
	corpus := []string{
		"Osmosis is the movement of water across a semipermeable membrane.",
		"Diffusion moves particles from high to low concentration.",
		"Plasma is the liquid portion of blood.",
	}
	in := []aiQuizQ{
		// honest mcq with options: must stay mcq, letters uppercased
		{Type: "mcq", Stem: "Which is a fruit?", Options: map[string]string{"a": "Mango", "B": "Stone", "c": "Water", "": ""}, Answer: "A"},
		// mcq whose options all vanished: must degrade to a type-in
		{Type: "mcq", Stem: "What pigment makes leaves green?", Answer: "Chlorophyll"},
		// mcq with one empty option and one real one: still unanswerable
		{Type: "mcq", Stem: "Define osmosis.", Options: map[string]string{"A": ""}, Answer: "Osmosis"},
		// unknown exotic type: must never pass through raw
		{Type: "match_pairs", Stem: "Match the pairs.", Answer: "Chlorophyll"},
		// unknown type with a boolean answer: true_false
		{Type: "ordering", Stem: "Water boils at 100C at sea level.", Answer: "true"},
		// fill_blank: word_bank with harvested distractors
		{Type: "fill_blank", Stem: "The liquid portion of blood is ____.", Answer: "plasma"},
		// true/false aliases normalize the answer text
		{Type: "true/false", Stem: "Sound travels in vacuum.", Answer: "False"},
	}
	out := e.normalizeQuiz(in, "T-TEST", corpus)
	if len(out) != len(in) {
		t.Fatalf("want %d questions, got %d", len(in), len(out))
	}
	for i, q := range out {
		switch q.Type {
		case "mcq":
			if len(q.Options) < 2 {
				t.Errorf("q%d: mcq shipped with %d options (%v)", i, len(q.Options), q.Options)
			}
			for letter, text := range q.Options {
				if strings.TrimSpace(text) == "" {
					t.Errorf("q%d: mcq option %q is empty", i, letter)
				}
				if letter != strings.ToUpper(letter) {
					t.Errorf("q%d: option letter %q not uppercased", i, letter)
				}
			}
		case "true_false":
			if q.Answer != "true" && q.Answer != "false" {
				t.Errorf("q%d: true_false answer %q not normalized", i, q.Answer)
			}
		case "word_bank":
			// a type-in is always answerable; the bank carries the answer
			found := false
			for _, w := range q.Options {
				if strings.EqualFold(w, q.Answer) {
					found = true
				}
			}
			if !found {
				t.Errorf("q%d: word_bank %v missing the answer %q", i, q.Options, q.Answer)
			}
		default:
			t.Errorf("q%d: unrenderable type %q leaked through", i, q.Type)
		}
	}
	// spot checks
	if out[0].Type != "mcq" || out[0].Options["A"] != "Mango" {
		t.Errorf("q0: honest mcq mangled: %+v", out[0])
	}
	if out[1].Type != "word_bank" {
		t.Errorf("q1: option-less mcq should degrade to word_bank, got %s", out[1].Type)
	}
	if out[2].Type != "word_bank" {
		t.Errorf("q2: single-empty-option mcq should degrade to word_bank, got %s", out[2].Type)
	}
	if out[3].Type != "word_bank" {
		t.Errorf("q3: exotic type should become word_bank, got %s", out[3].Type)
	}
	if out[4].Type != "true_false" || out[4].Answer != "true" {
		t.Errorf("q4: boolean answer should become true_false/true, got %s/%s", out[4].Type, out[4].Answer)
	}
	if out[5].Type != "word_bank" {
		t.Errorf("q5: fill_blank should become word_bank, got %s", out[5].Type)
	}
	if out[6].Type != "true_false" || out[6].Answer != "false" {
		t.Errorf("q6: true/false alias mangled: %s/%s", out[6].Type, out[6].Answer)
	}
}

// Bank questions must be touched by none of this: the injection path
// stamps them "mcq" directly (bankQuestions), and the filter already
// demands >= 2 options - but the type-in fallback above must never fire
// for a well-formed mcq, which the spot checks above cover.
func TestNormalizeQuizStampsTopicIDs(t *testing.T) {
	e := &Engine{}
	out := e.normalizeQuiz([]aiQuizQ{{Type: "mcq", Stem: "s", Options: map[string]string{"A": "x", "B": "y"}, Answer: "A"}}, "SEC-T-001", nil)
	if out[0].ID != "SEC-T-001-ai-1" {
		t.Errorf("id stamp wrong: %q", out[0].ID)
	}
}
