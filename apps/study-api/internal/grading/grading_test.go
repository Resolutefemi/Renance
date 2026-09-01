package grading

import (
	"testing"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/store"
)

func intPtr(n int) *int { return &n }

func testBundle() *cbtdata.Bundle {
	return &cbtdata.Bundle{
		Code: "b1", QuestionCount: 4, DurationMinutes: intPtr(10),
		Questions: []cbtdata.Question{
			{ID: "q1", Type: "mcq", Stem: "s1", Marks: 1, Topic: "Algebra"},
			{ID: "q2", Type: "mcq", Stem: "s2", Marks: 1, Topic: "Algebra"},
			{ID: "q3", Type: "mcq", Stem: "s3", Marks: 1, Topic: "Geometry"},
			{ID: "q4", Type: "mcq", Stem: "s4", Marks: 1}, // no topic → General
		},
	}
}

func testKey() map[string]store.KeyEntry {
	return map[string]store.KeyEntry{
		"q1": {Letter: "A"}, "q2": {Letter: "B"}, "q3": {Letter: "C"}, "q4": {Letter: "D"},
	}
}

func TestScoreAllCorrect(t *testing.T) {
	ans := []store.Picked{{QuestionID: "q1", Selected: "A"}, {QuestionID: "q2", Selected: "B"}, {QuestionID: "q3", Selected: "C"}, {QuestionID: "q4", Selected: "D"}}
	r := Score(testBundle(), testKey(), ans)
	if r.Score != 4 || r.Total != 4 {
		t.Fatalf("want 4/4, got %d/%d", r.Score, r.Total)
	}
	if len(r.Breakdown) != 3 {
		t.Fatalf("want 3 topics, got %d", len(r.Breakdown))
	}
}

func TestScorePartialWithUnanswered(t *testing.T) {
	ans := []store.Picked{{QuestionID: "q1", Selected: "A"}, {QuestionID: "q3", Selected: "A"}} // q2, q4 unanswered
	r := Score(testBundle(), testKey(), ans)
	if r.Score != 1 || r.Total != 4 {
		t.Fatalf("want 1/4, got %d/%d", r.Score, r.Total)
	}
	got := map[string]TopicRow{}
	for _, row := range r.Breakdown {
		got[row.Topic] = row
	}
	if got["Algebra"].Correct != 1 || got["Algebra"].Total != 2 {
		t.Fatalf("algebra wrong: %+v", got["Algebra"])
	}
	if got["Geometry"].Correct != 0 || got["Geometry"].Total != 1 {
		t.Fatalf("geometry wrong: %+v", got["Geometry"])
	}
	if got["General"].Total != 1 {
		t.Fatalf("general wrong: %+v", got["General"])
	}
}

func TestScoreIgnoresUnknownQuestionIDs(t *testing.T) {
	ans := []store.Picked{{QuestionID: "q1", Selected: "A"}, {QuestionID: "ghost", Selected: "A"}}
	r := Score(testBundle(), testKey(), ans)
	if r.Score != 1 || r.Total != 4 {
		t.Fatalf("want 1/4, got %d/%d", r.Score, r.Total)
	}
}

func TestScoreEmptySubmission(t *testing.T) {
	r := Score(testBundle(), testKey(), nil)
	if r.Score != 0 || r.Total != 4 {
		t.Fatalf("want 0/4, got %d/%d", r.Score, r.Total)
	}
}

func TestStaticKeyCache(t *testing.T) {
	c := NewStaticKeyCache(map[string]map[string]store.KeyEntry{"b1": testKey()})
	k, ok := c.Get("b1")
	if !ok || k["q1"].Letter != "A" {
		t.Fatalf("cache get: %+v ok=%v", k, ok)
	}
	if _, ok := c.Get("nope"); ok {
		t.Fatal("expected miss")
	}
	c.Replace(map[string]map[string]store.KeyEntry{"b2": {"z": {Letter: "A"}}})
	if _, ok := c.Get("b1"); ok {
		t.Fatal("old bank should be gone")
	}
	if _, ok := c.Get("b2"); !ok {
		t.Fatal("new bank missing")
	}
}
