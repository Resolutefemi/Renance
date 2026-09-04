package cbtdata

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeLessonDataDir(t *testing.T, lessonJSON string) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"),
		[]byte(`{"generatedAt":"t","version":"t","exams":[]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if lessonJSON != "" {
		if err := os.MkdirAll(filepath.Join(dir, "lessons"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "lessons", "cell-structure.json"),
			[]byte(lessonJSON), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

const validLesson = `{
  "slug": "cell-structure",
  "title": "Cell Structure and Organisation",
  "subject": "Biology",
  "body": "JAMB",
  "tags": ["cell"],
  "minutes": 8,
  "summary": "Organelles and what each one does.",
  "sections": [
    {"heading": "The cell theory", "blocks": [
      {"type": "p", "text": "All living things are made of cells."},
      {"type": "ul", "items": ["Schwann", "Schleiden"]}
    ]}
  ]
}`

func TestLoadLessonsHappyPath(t *testing.T) {
	lib, err := Load(writeLessonDataDir(t, validLesson))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	all := lib.Lessons()
	if len(all) != 1 || all[0].Slug != "cell-structure" || all[0].Minutes != 8 {
		t.Fatalf("Lessons() = %+v", all)
	}
	les, ok := lib.Lesson("cell-structure")
	if !ok || les.Title != "Cell Structure and Organisation" || len(les.Sections) != 1 {
		t.Fatalf("Lesson() = %+v ok=%v", les, ok)
	}
	if len(les.Sections[0].Blocks) != 2 || les.Sections[0].Blocks[1].Type != "ul" {
		t.Fatalf("sections = %+v", les.Sections)
	}
}

func TestLoadLessonsEmptyDirBoots(t *testing.T) {
	lib, err := Load(writeLessonDataDir(t, ""))
	if err != nil {
		t.Fatalf("empty lessons dir should boot: %v", err)
	}
	if len(lib.Lessons()) != 0 {
		t.Fatal("expected zero lessons")
	}
}

func TestLoadLessonsRefusesBadBundles(t *testing.T) {
	cases := map[string]string{
		"slug mismatch": strings.Replace(validLesson, `"slug": "cell-structure"`, `"slug": "other"`, 1),
		"no title":      strings.Replace(validLesson, `"title": "Cell Structure and Organisation",`, `"title": "",`, 1),
		"no summary":    strings.Replace(validLesson, `"summary": "Organelles and what each one does.",`, `"summary": "",`, 1),
		"minutes zero":  strings.Replace(validLesson, `"minutes": 8`, `"minutes": 0`, 1),
		"zero sections": strings.Replace(validLesson, `"sections": [`, `"sectionsX": [`, 1),
		"empty block":   strings.Replace(validLesson, `"text": "All living things are made of cells."`, `"text": "  "`, 1),
		"empty items":   strings.Replace(validLesson, `["Schwann", "Schleiden"]`, `[]`, 1),
		"bad type":      strings.Replace(validLesson, `"type": "p"`, `"type": "script"`, 1),
		"bad slug":      strings.Replace(validLesson, `"slug": "cell-structure"`, `"slug": "Cell Structure"`, 1),
	}
	for name, raw := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := Load(writeLessonDataDir(t, raw)); err == nil {
				t.Fatalf("%s: expected boot refusal", name)
			}
		})
	}
}

func TestLoadLessonsRefusesAnswerMaterial(t *testing.T) {
	leak := strings.Replace(validLesson, `"tags": ["cell"]`, `"tags": ["cell"], "explanation": "leak"`, 1)
	if _, err := Load(writeLessonDataDir(t, leak)); err == nil {
		t.Fatal("lessons must pass the ADR-0003 answer-leak scan")
	}
}
