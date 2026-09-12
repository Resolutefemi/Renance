package httpapi

import (
	"strings"
	"testing"
)

func TestParseAIBatch(t *testing.T) {
	raw := "Here you go!\n```json\n" + `[
		{"stem":"What is photosynthesis?","options":{"A":"Food making","B":"Breathing","C":"Running","D":"Sleeping"},"answer":"A","explanation":"Green plants make food."},
		{"stem":"Bad one, no real answer","options":{"A":"x","B":"y"},"answer":"D","explanation":"broken"},
		{"stem":"Answer given as text","options":{"A":"Lagos","B":"Abuja","C":"Kano","D":"Ibadan"},"answer":"Abuja","explanation":"FCT."}
	]` + "\n```"
	qs, err := parseAIBatch(raw, []string{"Biology"}, "Easy")
	if err != nil {
		t.Fatalf("parseAIBatch: %v", err)
	}
	if len(qs) != 2 {
		t.Fatalf("want 2 valid questions (invalid dropped), got %d", len(qs))
	}
	if qs[0].Answer != "A" || len(qs[0].Options) != 4 {
		t.Fatalf("q0 wrong: %+v", qs[0])
	}
	// answer-as-text resolves to its letter
	if qs[1].Answer != "B" {
		t.Fatalf("text answer not resolved to letter: %+v", qs[1])
	}
	if qs[1].Topic != "Biology" || qs[1].Difficulty != "Easy" {
		t.Fatalf("anchor fields missing: %+v", qs[1])
	}
}

func TestParseAIBatchRejectsGarbage(t *testing.T) {
	if _, err := parseAIBatch("no json here at all", []string{"X"}, "Easy"); err == nil {
		t.Fatal("want error for reply without array")
	}
	if _, err := parseAIBatch(`[{"stem":"s","options":{"A":"1"},"answer":"A"}]`, []string{"X"}, "Easy"); err == nil {
		t.Fatal("want error when nothing valid decodes")
	}
}

func TestAISystemPrompt(t *testing.T) {
	p := aiSystemPrompt([]string{"Calculus I", "Vectors"}, "Hard", 3)
	for _, want := range []string{"exactly 3 question(s)", "hard difficulty", "Calculus I; Vectors", `"answer"`} {
		if !strings.Contains(p, want) {
			t.Fatalf("prompt missing %q:\n%s", want, p)
		}
	}
}
