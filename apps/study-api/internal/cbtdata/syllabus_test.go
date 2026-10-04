package cbtdata

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSlug(t *testing.T) {
	cases := map[string]string{
		"JAMB":                "jamb",
		"University Modules":  "university-modules",
		"  WAEC  ":            "waec",
		"Body -- With!! Junk": "body-with-junk",
	}
	for in, want := range cases {
		if got := Slug(in); got != want {
			t.Fatalf("Slug(%q) = %q, want %q", in, got, want)
		}
	}
}

// writeSyllabus drops a tree into the data dir produced by writeLib.
func writeSyllabus(t *testing.T, dir string, raw string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(dir, "syllabus"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "syllabus", "testbody.json"), []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
}

func syllabusBundle() map[string]any {
	return map[string]any{
		"code": "test-bank", "title": "Test Bank", "version": 1,
		"questionCount": 2, "totalMarks": 2, "body": "TestBody",
		"questions": []any{
			map[string]any{"id": "q1", "type": "mcq", "stem": "2+2?", "marks": 1,
				"options": map[string]string{"A": "3", "B": "4"}, "topic": "Algebra"},
			map[string]any{"id": "q2", "type": "mcq", "stem": "3+3?", "marks": 1,
				"options": map[string]string{"A": "5", "B": "6"}, "topic": "Geometry"},
		},
	}
}

const testTree = `{"body":"TestBody","subjects":[{"subject":"Maths","sections":[
	{"title":"Algebra","topics":["Algebra"]},
	{"title":"Geometry","topics":["Geometry"]}]}]}`

func TestLoadSyllabusOKAndLookup(t *testing.T) {
	dir := writeLib(t, syllabusBundle())
	writeSyllabus(t, dir, testTree)
	lib, err := Load(dir)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	sy, ok := lib.SyllabusForBody("TestBody")
	if !ok || sy.TopicCount() != 2 {
		t.Fatalf("exact lookup failed: ok=%v count=%d", ok, sy.TopicCount())
	}
	if _, ok := lib.SyllabusForBody("testbody"); !ok {
		t.Fatal("slug lookup failed")
	}
	if got := lib.TopicCounts("TestBody")["Algebra"]; got != 1 {
		t.Fatalf("TopicCounts(Algebra) = %d, want 1", got)
	}
	if got := lib.TopicCounts("TestBody")["General"]; got != 0 {
		t.Fatalf("unexpected General count: %d", got)
	}
	if bodies := lib.SyllabusBodies(); len(bodies) != 1 || bodies[0] != "TestBody" {
		t.Fatalf("SyllabusBodies = %v", bodies)
	}
}

func TestLoadRejectsTopicOutsideTree(t *testing.T) {
	b := syllabusBundle()
	// q2's topic becomes an orphan the tree does not know.
	qs := b["questions"].([]any)
	(qs[1].(map[string]any))["topic"] = "Bogus"
	dir := writeLib(t, b)
	writeSyllabus(t, dir, testTree)
	_, err := Load(dir)
	if err == nil || !strings.Contains(err.Error(), "not in the TestBody syllabus tree") {
		t.Fatalf("want syllabus refusal, got %v", err)
	}
}

func TestLoadAllowsBodyWithoutTree(t *testing.T) {
	// No syllabus dir at all: legacy/test content keeps booting.
	dir := writeLib(t, syllabusBundle())
	if _, err := Load(dir); err != nil {
		t.Fatalf("load without tree: %v", err)
	}
}

func TestLoadRejectsMalformedSyllabus(t *testing.T) {
	dir := writeLib(t, syllabusBundle())
	writeSyllabus(t, dir, `{"body":`)
	if _, err := Load(dir); err == nil || !strings.Contains(err.Error(), "parse syllabus") {
		t.Fatalf("want parse refusal, got %v", err)
	}
}

func TestLoadRejectsDuplicateBodyTree(t *testing.T) {
	dir := writeLib(t, syllabusBundle())
	writeSyllabus(t, dir, testTree)
	if err := os.WriteFile(filepath.Join(dir, "syllabus", "testbody2.json"), []byte(testTree), 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := Load(dir)
	if err == nil || !strings.Contains(err.Error(), "re-declares body") {
		t.Fatalf("want duplicate refusal, got %v", err)
	}
}

func TestEmptyTopicBypassesTree(t *testing.T) {
	b := syllabusBundle()
	qs := b["questions"].([]any)
	delete(qs[1].(map[string]any), "topic")
	dir := writeLib(t, b)
	writeSyllabus(t, dir, testTree)
	lib, err := Load(dir)
	if err != nil {
		t.Fatalf("empty topic should boot: %v", err)
	}
	if got := lib.TopicCounts("TestBody")["General"]; got != 1 {
		t.Fatalf("General bucket = %d, want 1", got)
	}
}
