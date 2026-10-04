package school

import (
	"strings"
	"testing"
)

// TestExamBankIntegrity guards the starter bank: every question must
// have options, an in-range answer, three terms of coverage per
// subject, no duplicate question text per subject+term, and no long
// dashes anywhere. It is the automated half of the founder rule.
func TestExamBankIntegrity(t *testing.T) {
	bank := ExamBank()
	if len(bank) < 200 {
		t.Fatalf("bank looks too small: %d questions", len(bank))
	}
	seen := map[string]bool{}
	subjects := map[string]map[int]int{}
	for _, q := range bank {
		if q.SubjectCode == "" || q.Question == "" {
			t.Fatalf("empty subject or question: %+v", q)
		}
		if len(q.Options) < 2 {
			t.Fatalf("question needs >=2 options: %s", q.Question)
		}
		if q.AnswerIndex < 0 || q.AnswerIndex >= len(q.Options) {
			t.Fatalf("answer out of range: %s", q.Question)
		}
		if q.Term < 1 || q.Term > 3 {
			t.Fatalf("term out of range: %s", q.Question)
		}
		key := q.SubjectCode + "|" + q.Question
		if seen[key] {
			t.Fatalf("duplicate question: %s", key)
		}
		seen[key] = true
		if subjects[q.SubjectCode] == nil {
			subjects[q.SubjectCode] = map[int]int{}
		}
		subjects[q.SubjectCode][q.Term]++
		// Escape sequences only: the file itself must stay clean of
		// the dash characters it forbids.
		for _, bad := range []string{"--", "\u2014", "\u2013", "\u2012", "\u2010", "\u2015"} {
			if strings.Contains(q.Question, bad) || strings.Contains(q.Explanation, bad) {
				t.Fatalf("dash rule violated in: %s", q.Question)
			}
			for _, o := range q.Options {
				if strings.Contains(o, bad) {
					t.Fatalf("dash rule violated in option of: %s", q.Question)
				}
			}
		}
	}
	// Every banked subject must carry all three terms.
	for code, terms := range subjects {
		for term := 1; term <= 3; term++ {
			if terms[term] == 0 {
				t.Errorf("subject %s has no term %d questions", code, term)
			}
		}
	}
}
