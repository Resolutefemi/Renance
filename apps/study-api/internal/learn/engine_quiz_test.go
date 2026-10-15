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
		// honest mcq with options: must stay mcq, letters uppercased,
		// option count untouched (founder reversal 2026-10-15)
		{Type: "mcq", Stem: "Which is a fruit?", Options: map[string]string{"a": "Mango", "B": "Stone", "c": "Water", "d": "Orange", "": ""}, Answer: "A"},
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
	// THE REVERSAL (founder 2026-10-15): a 4-option mcq must arrive at
	// the student with all four options intact - never trimmed.
	if len(out[0].Options) != 4 {
		t.Errorf("q0: 4-option mcq lost options, got %d (%v)", len(out[0].Options), out[0].Options)
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
	out := e.normalizeQuiz([]aiQuizQ{{Type: "mcq", Stem: "s", Options: map[string]string{"A": "x", "B": "y", "C": "z", "D": "w"}, Answer: "A"}}, "SEC-T-001", nil)
	if out[0].ID != "SEC-T-001-ai-1" {
		t.Errorf("id stamp wrong: %q", out[0].ID)
	}
}

// ─── The answer-alignment doctrine (founder 2026-10-15) ───────────────────
//
// "There will be questions in some and the options will not be three, or
// the right answer will be picked and it will mark the user wrong."
// The doctrine is REVERSED: option counts are never rewritten - only the
// answer's alignment with the visible options is healed. Every scenario
// below is one the founder actually screenshotted.

// The pH past question from the screenshots: four bank options A-D must
// arrive at the student as FOUR options, answer still B (8.0 - litmus
// blue), unchanged and reported clean.
func TestSanitizeQuizKeepsBankOptionCount(t *testing.T) {
	in := []LessonQuizQ{{
		ID:   "jamb-chemistry-bank-0100",
		Type: "mcq",
		Stem: "In a series of solutions with pH 2.5, 3.5, 7.0 and 8.0, which is likely to turn red moist litmus paper blue?",
		Options: map[string]string{
			"A": "3.5", "B": "8.0", "C": "2.5", "D": "7.0",
		},
		Answer:      "B",
		Explanation: "Alkaline solutions turn red litmus blue.",
		Year:        2025, FromBank: true,
	}}
	out, changed := sanitizeQuiz(in)
	if changed {
		t.Fatalf("a clean 4-option letter-answer question reported a change")
	}
	if len(out) != 1 {
		t.Fatalf("want 1 question, got %d", len(out))
	}
	q := out[0]
	if len(q.Options) != 4 {
		t.Fatalf("the 4-option bank question must keep all four options, got %d (%v)", len(q.Options), q.Options)
	}
	if q.Answer != "B" || q.Options[q.Answer] != "8.0" {
		t.Fatalf("answer %q must stay B pointing at \"8.0\", options %v", q.Answer, q.Options)
	}
}

// Five-option questions (A-E, WAEC/NECO obj shape) keep all five.
func TestSanitizeQuizKeepsFiveOptions(t *testing.T) {
	in := []LessonQuizQ{{
		ID:   "waec-biology-bank-0007",
		Type: "mcq",
		Stem: "The organ that produces bile is the",
		Options: map[string]string{
			"A": "kidney", "B": "pancreas", "C": "liver", "D": "spleen", "E": "gall bladder",
		},
		Answer: "C",
	}}
	out, changed := sanitizeQuiz(in)
	if changed {
		t.Fatalf("clean 5-option question reported a change")
	}
	if len(out) != 1 || len(out[0].Options) != 5 {
		t.Fatalf("5-option question must keep five options, got %d", len(out[0].Options))
	}
}

// The "Anion" misgrade: an mcq whose stored answer is the option TEXT
// (or a letter that no longer exists) must resolve to its own option -
// never ship a letter the client cannot match, never mark a correct
// student wrong. The option count stays as stored.
func TestSanitizeQuizResolvesTextAnswerToLetter(t *testing.T) {
	in := []LessonQuizQ{{
		ID:     "T-X-ai-6",
		Type:   "mcq",
		Stem:   "Which particle has a negative charge?",
		Options: map[string]string{"A": "Proton", "B": "Neutron", "C": "Electron", "D": "Anion"},
		Answer: "Anion",
	}}
	out, changed := sanitizeQuiz(in)
	if !changed {
		t.Fatalf("expected the text answer to be resolved to a letter")
	}
	if len(out) != 1 {
		t.Fatalf("want 1 question, got %d", len(out))
	}
	q := out[0]
	if len(q.Options) != 4 {
		t.Fatalf("option count must be untouched, got %d", len(q.Options))
	}
	if q.Answer != "D" || q.Options[q.Answer] != "Anion" {
		t.Fatalf("answer must resolve to D - the Anion option, got %q (%v)", q.Answer, q.Options)
	}
}

// The 1..N index quirk some banks carry: "2" means the second letter.
func TestSanitizeQuizResolvesIndexAnswer(t *testing.T) {
	in := []LessonQuizQ{{
		ID:     "neco-physics-bank-0042",
		Type:   "mcq",
		Stem:   "The SI unit of force is the",
		Options: map[string]string{"A": "joule", "B": "newton", "C": "watt", "D": "pascal"},
		Answer: "2",
	}}
	out, changed := sanitizeQuiz(in)
	if !changed {
		t.Fatalf("expected the index answer to be resolved to a letter")
	}
	if out[0].Answer != "B" {
		t.Fatalf("index 2 must resolve to B, got %q", out[0].Answer)
	}
}

// A stored answer that matches NO option (the "Answer: D" with no
// options case) is a misgrade waiting to happen - the sweep drops it
// rather than serving a question that can never be answered right.
func TestSanitizeQuizDropsDeadAnswer(t *testing.T) {
	in := []LessonQuizQ{
		{ID: "dead", Type: "mcq", Stem: "Broken", Options: map[string]string{"A": "x", "B": "y"}, Answer: "D"},
		{ID: "live", Type: "mcq", Stem: "Fine", Options: map[string]string{"A": "x", "B": "y", "C": "z"}, Answer: "A"},
	}
	out, changed := sanitizeQuiz(in)
	if !changed {
		t.Fatalf("expected the dead question to be dropped")
	}
	if len(out) != 1 || out[0].ID != "live" {
		t.Fatalf("want only the live question, got %+v", out)
	}
	if len(out[0].Options) != 3 {
		t.Fatalf("the 3-option live question keeps its three options, got %d", len(out[0].Options))
	}
}

// True/false answers must land folded to true/false so the client's
// True/False grading compares words, not letters.
func TestSanitizeQuizFoldsTrueFalse(t *testing.T) {
	in := []LessonQuizQ{{
		ID: "tf", Type: "true_false", Stem: "The word 'dem' is a standard English pronoun.",
		Options: nil, Answer: "False",
	}}
	out, _ := sanitizeQuiz(in)
	if out[0].Answer != "false" {
		t.Fatalf("answer must fold to lowercase false, got %q", out[0].Answer)
	}
	if out[0].Options != nil {
		t.Fatalf("true_false carries no options map, got %v", out[0].Options)
	}
}

// A doctrine-clean lesson (mcqs with letter answers, mixed option
// counts of 3, 4 or 5) passes untouched and reports NO change - the
// cache write only ever happens once.
func TestSanitizeQuizLeavesCleanQuizAlone(t *testing.T) {
	in := []LessonQuizQ{
		{ID: "q1", Type: "mcq", Stem: "s1", Options: map[string]string{"A": "1", "B": "2", "C": "3"}, Answer: "B"},
		{ID: "q2", Type: "mcq", Stem: "s2", Options: map[string]string{"A": "4", "B": "5", "C": "6", "D": "7"}, Answer: "C"},
		{ID: "q3", Type: "mcq", Stem: "s3", Options: map[string]string{"A": "8", "B": "9", "C": "10", "D": "11", "E": "12"}, Answer: "E"},
		{ID: "q4", Type: "true_false", Stem: "s4", Answer: "true"},
	}
	out, changed := sanitizeQuiz(in)
	if changed {
		t.Fatalf("clean quiz reported a change")
	}
	if len(out) != len(in) {
		t.Fatalf("want %d questions, got %d", len(in), len(out))
	}
	for i, q := range out {
		if in[i].ID != q.ID || in[i].Answer != q.Answer {
			t.Fatalf("question %d mutated: %+v -> %+v", i, in[i], q)
		}
	}
}
