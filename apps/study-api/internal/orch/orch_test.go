// orch_test.go - the validation gates of the six-key pipeline: level
// parsing, assessment contracts, answer scattering, note floors.
package orch

import (
        "fmt"
        "strings"
        "testing"
)

func TestParseLevel(t *testing.T) {
        cases := map[string]int{
                "100 Level": 100, "200 Level": 200, "300 Level": 300,
                "400 Level": 400, "500 Level": 500, "600 Level": 600,
                "NCE I": 100, "NCE II": 200, "NCE III": 300,
                "ND I": 100, "ND II": 200, "HND I": 200, "HND II": 300,
                "": 200, "Special": 200,
        }
        for in, want := range cases {
                if got := ParseLevel(in); got != want {
                        t.Errorf("ParseLevel(%q) = %d, want %d", in, got, want)
                }
        }
}

func TestIsCalcCourse(t *testing.T) {
        if !IsCalcCourse("Elementary Mathematics I", "Mathematics", "Sets") {
                t.Error("maths course must be calc")
        }
        if !IsCalcCourse("Computer Programming II (Java/C++)", "Computer Science", "Arrays in Java") {
                t.Error("programming course must be calc")
        }
        if IsCalcCourse("Introduction to Nigerian Literature", "English", "The Novel") {
                t.Error("literature course must not be calc")
        }
}

func mcqJSON(n int, letter string) string {
        var b strings.Builder
        b.WriteString(`{"summary":"s","key_points":["a","b","c","d","e"],"quiz":[`)
        for i := 0; i < n; i++ {
                if i > 0 {
                        b.WriteString(",")
                }
                fmt.Fprintf(&b, `{"type":"mcq","stem":"q %d","options":{"A":"1","B":"2","C":"3","D":"4"},"answer":"%s","explanation":"because"}`, i, letter)
        }
        b.WriteString(`]}`)
        return b.String()
}

func TestParseAssessment100Level(t *testing.T) {
        a, err := parseAssessment(mcqJSON(20, "B"), 100)
        if err != nil {
                t.Fatalf("100L parse: %v", err)
        }
        if len(a.Quiz) != 20 {
                t.Fatalf("100L quiz = %d, want 20", len(a.Quiz))
        }
        if len(a.Theory) != 0 {
                t.Fatalf("100L theory = %d, want 0", len(a.Theory))
        }
        // All-B input must be scattered by the rebalancer.
        counts := map[string]int{}
        for _, q := range a.Quiz {
                counts[q.Answer]++
        }
        for l, n := range counts {
                if n > 8 {
                        t.Errorf("letter %s carries %d answers, scattering cap is 8", l, n)
                }
        }
        // The rebalance must keep answers aligned with their options.
        for _, q := range a.Quiz {
                if _, ok := q.Options[q.Answer]; !ok {
                        t.Fatalf("answer %q not in options after rebalance", q.Answer)
                }
        }
}

func TestParseAssessment200Level(t *testing.T) {
        raw := `{"summary":"s","key_points":["a","b","c","d","e"],"quiz":[` +
                strings.TrimSuffix(strings.Repeat(`{"type":"mcq","stem":"q","options":{"A":"1","B":"2","C":"3","D":"4"},"answer":"A","explanation":"e"},`, 15), ",") +
                `],"theory_questions":[` +
                strings.TrimSuffix(strings.Repeat(`{"question":"why?","key_points":"p1; p2","answer":"because"},`, 5), ",") +
                `]}`
        a, err := parseAssessment(raw, 200)
        if err != nil {
                t.Fatalf("200L parse: %v", err)
        }
        if len(a.Quiz) != 15 || len(a.Theory) != 5 {
                t.Fatalf("200L = %d quiz + %d theory, want 15 + 5", len(a.Quiz), len(a.Theory))
        }
}

func TestParseAssessmentRejectsThin100Level(t *testing.T) {
        if _, err := parseAssessment(mcqJSON(10, "A"), 100); err == nil {
                t.Fatal("10-item 100L assessment must fail validation")
        }
        if _, err := parseAssessment(mcqJSON(20, "A"), 100); err != nil {
                t.Fatalf("valid 100L assessment rejected: %v", err)
        }
}

func TestParseNoteFloors(t *testing.T) {
        thin := `{"heading":"Part 1: X","body":"too short"}`
        if _, err := parseNote(thin, 1, nonCalcWordFloor); err == nil {
                t.Fatal("thin note must fail the floor")
        }
        words := strings.TrimSuffix(strings.Repeat("word ", nonCalcWordFloor+10), " ")
        ok := `{"heading":"Part 1: X","body":"` + words + `"}`
        if _, err := parseNote(ok, 1, nonCalcWordFloor); err != nil {
                t.Fatalf("valid note rejected: %v", err)
        }
        // Fenced output survives.
        fenced := "```json\n" + ok + "\n```"
        if _, err := parseNote(fenced, 1, nonCalcWordFloor); err != nil {
                t.Fatalf("fenced note rejected: %v", err)
        }
}

func TestSalvageJSON(t *testing.T) {
        truncated := `{"heading":"Part 1: X","body":"$\\frac{dy}{dx}$ and more text that never clo`
        salvaged := salvageJSON(extractJSON(truncated))
        if !strings.HasSuffix(salvaged, "}") {
                t.Fatalf("salvage did not close the object: %q", salvaged)
        }
}

func TestPromptsCarryTheContract(t *testing.T) {
        sys := notesSystemPrompt(2, true)
        for _, want := range []string{"Key 2", "MORE THAN 300 words", "KaTeX", "STRICT JSON", "CORE PRINCIPLES I"} {
                if !strings.Contains(sys, want) {
                        t.Errorf("calc part prompt missing %q", want)
                }
        }
        sysNC := notesSystemPrompt(5, false)
        if !strings.Contains(sysNC, "MORE THAN 200 words") {
                t.Error("non-calc part prompt missing its depth rule")
        }
        q100 := quizSystemPrompt(100)
        if !strings.Contains(q100, "EXACTLY 20 objective") || !strings.Contains(q100, "ZERO theory") {
                t.Error("100L quiz prompt missing its contract")
        }
        q200 := quizSystemPrompt(200)
        if !strings.Contains(q200, "EXACTLY 15 objective") || !strings.Contains(q200, "EXACTLY 5 theory") {
                t.Error("200L quiz prompt missing its contract")
        }
}
