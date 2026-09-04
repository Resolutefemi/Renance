package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"renance.dev/study-api/internal/cbtdata"
)

func TestLintSpecRejectsBadAnswerLetter(t *testing.T) {
	s := &Spec{Code: "x-mock", Title: "X", Questions: []QSpec{{
		Stem:    "2+2?",
		Options: map[string]string{"A": "3", "B": "4"},
		Answer:  "C", // not among options
	}}}
	iss := lintSpec(s, nil)
	if !hasError(iss) {
		t.Fatalf("want error for answer not in options, got %v", iss)
	}
}

func TestLintSpecRejectsBrokenLadder(t *testing.T) {
	s := &Spec{Code: "x-mock", Title: "X", Questions: []QSpec{{
		Stem:    "pick",
		Options: map[string]string{"A": "1", "C": "2"}, // B missing
		Answer:  "A",
	}}}
	if !hasError(lintSpec(s, nil)) {
		t.Fatal("want error for gap in option ladder")
	}
}

func TestLintSpecRejectsBadCode(t *testing.T) {
	s := &Spec{Code: "X_Mock", Title: "X", Questions: []QSpec{{
		Stem: "q", Options: map[string]string{"A": "1", "B": "2"}, Answer: "A",
	}}}
	if !hasError(lintSpec(s, nil)) {
		t.Fatal("want error for non-kebab code")
	}
}

func TestLintSpecWarnsOnMissingTopic(t *testing.T) {
	s := &Spec{Code: "x-mock", Title: "X", Questions: []QSpec{{
		Stem: "q", Options: map[string]string{"A": "1", "B": "2"}, Answer: "A",
		Explanation: "because", Marks: 1,
	}}}
	iss := lintSpec(s, nil)
	if hasError(iss) {
		t.Fatalf("clean question must not error: %v", iss)
	}
	if !hasWarn(iss, "no topic") {
		t.Fatalf("want topic warning, got %v", iss)
	}
}

func TestParseCSVWithAliases(t *testing.T) {
	csvSrc := "Question,Option_A,Option_B,optionc,OPTIOND,correct,rationale,topic,difficulty,mark\n" +
		"\"What is 2+2?\",\"3\",\"4\",\"5\",\"22\",\"B\",\"basic arithmetic\",\"Maths\",easy,\n"
	spec, issues, err := parseCSV([]byte(csvSrc))
	if err != nil {
		t.Fatalf("parseCSV: %v", err)
	}
	if len(issues) != 0 {
		t.Fatalf("unexpected issues %v", issues)
	}
	q := spec.Questions[0]
	if q.Stem != "What is 2+2?" || q.Answer != "B" || q.Topic != "Maths" ||
		q.Difficulty != "easy" || q.Marks != 1 || q.Explanation != "basic arithmetic" {
		t.Fatalf("bad parse: %+v", q)
	}
	if q.Options["A"] != "3" || q.Options["D"] != "22" {
		t.Fatalf("bad options: %v", q.Options)
	}
}

func TestParseYAMLShorthandAndOptions(t *testing.T) {
	y := `
code: jamb-chem-mock
title: JAMB Chemistry
category: secondary
body: JAMB
durationMinutes: 60
questions:
  - stem: avogadro
    options: {A: "6.02e23", B: "3.14"}
    answer: a
    explanation: mol
    topic: Mole
    marks: 2
  - stem: ph of 7
    a: neutral
    b: acidic
    c: basic
    d: none
    answer: A
`
	spec, _, err := parseYAML([]byte(y))
	if err != nil {
		t.Fatalf("parseYAML: %v", err)
	}
	if len(spec.Questions) != 2 || spec.DurationMinutes == nil || *spec.DurationMinutes != 60 {
		t.Fatalf("bad spec: %+v", spec)
	}
	if spec.Questions[0].Answer != "A" || spec.Questions[0].Options["B"] != "3.14" {
		t.Fatalf("bad q0: %+v", spec.Questions[0])
	}
	if len(spec.Questions[1].Options) != 4 {
		t.Fatalf("shorthand options lost: %+v", spec.Questions[1].Options)
	}
}

func TestBuildRoundTripBootsRealLoader(t *testing.T) {
	dir := t.TempDir()
	spec := &Spec{
		Code: "round-trip-mock", Title: "Round Trip", Category: "secondary", Body: "JAMB",
		Questions: []QSpec{
			{Stem: "one", Options: map[string]string{"A": "1", "B": "2"}, Answer: "B",
				Explanation: "two", Topic: "Numbers", Difficulty: "easy", Marks: 1},
			{Stem: "two", Options: map[string]string{"A": "3", "B": "4"}, Answer: "A",
				Explanation: "three", Topic: "Numbers", Difficulty: "medium", Marks: 2},
		},
	}
	if hasError(lintSpec(spec, nil)) {
		t.Fatal("fixture must lint clean")
	}
	pack, key, err := buildArtifacts(spec)
	if err != nil {
		t.Fatalf("buildArtifacts: %v", err)
	}
	for _, d := range []string{"questions", filepath.Join("answer-keys", "mock")} {
		if err := os.MkdirAll(filepath.Join(dir, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "questions", spec.Code+".json"), pack, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "answer-keys", "mock", spec.Code+".json"), key, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := writeManifest(dir, "test-v1"); err != nil {
		t.Fatalf("writeManifest: %v", err)
	}
	lib, err := cbtdata.Load(dir) // the REAL boot loader
	if err != nil {
		t.Fatalf("cbtdata.Load: %v", err)
	}
	b, ok := lib.Bundle(spec.Code)
	if !ok || b.QuestionCount != 2 || b.TotalMarks != 3 {
		t.Fatalf("bundle mismatch: %+v ok=%v", b, ok)
	}
}

func TestScanForForbiddenCatchesLeak(t *testing.T) {
	leaky := []byte(`{"code":"x","questions":[{"id":"x-0001","type":"mcq","stem":"s","options":{"A":"1","B":"2"},"marks":1,"explanation":"oops"}]}`)
	if err := scanForForbidden("x", leaky); err == nil {
		t.Fatal("expected forbidden-key rejection")
	} else if !strings.Contains(err.Error(), "forbidden key") {
		t.Fatalf("wrong error: %v", err)
	}
}

func hasError(iss []Issue) bool {
	for _, i := range iss {
		if i.Level == "error" {
			return true
		}
	}
	return false
}

func hasWarn(iss []Issue, substr string) bool {
	for _, i := range iss {
		if i.Level == "warn" && strings.Contains(i.Msg, substr) {
			return true
		}
	}
	return false
}
