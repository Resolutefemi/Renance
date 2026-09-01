package cbtdata

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeLib(t *testing.T, bundle map[string]any) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "questions"), 0o755); err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(bundle)
	sum := sha256.Sum256(raw)
	manifest := Manifest{Version: "test", Exams: []ExamMeta{{
		Code: "test-bank", Title: "Test Bank", QuestionCount: 1,
		BundleSHA256: hex.EncodeToString(sum[:]),
		SizeBytes:    int64(len(raw)),
	}}}
	mRaw, _ := json.Marshal(manifest)
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"), mRaw, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "questions", "test-bank.json"), raw, 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

func validBundle() map[string]any {
	return map[string]any{
		"code": "test-bank", "title": "Test Bank", "version": 1,
		"questionCount": 1, "totalMarks": 1,
		"questions": []any{map[string]any{
			"id": "q1", "type": "mcq", "stem": "2+2?", "marks": 1,
			"options": map[string]string{"A": "3", "B": "4"},
		}},
	}
}

func TestLoadOK(t *testing.T) {
	dir := writeLib(t, validBundle())
	lib, err := Load(dir)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	b, ok := lib.Bundle("test-bank")
	if !ok || b.QuestionCount != 1 || b.Questions[0].Stem != "2+2?" {
		t.Fatalf("bundle wrong: %+v ok=%v", b, ok)
	}
}

func TestLoadRejectsAnswerLeak(t *testing.T) {
	cases := map[string]map[string]any{
		"top-level answer": {
			"code": "test-bank", "title": "T", "version": 1, "questionCount": 1, "totalMarks": 1,
			"questions": []any{map[string]any{
				"id": "q1", "type": "mcq", "stem": "s", "marks": 1, "answer": "B",
				"options": map[string]string{"A": "3", "B": "4"},
			}},
		},
		"nested correct_letter": {
			"code": "test-bank", "title": "T", "version": 1, "questionCount": 1, "totalMarks": 1,
			"questions": []any{map[string]any{
				"id": "q1", "type": "mcq", "stem": "s", "marks": 1,
				"options": map[string]string{"A": "3", "B": "4"},
				"meta":    map[string]any{"correct_letter": "A"},
			}},
		},
		"explanation": {
			"code": "test-bank", "title": "T", "version": 1, "questionCount": 1, "totalMarks": 1,
			"questions": []any{map[string]any{
				"id": "q1", "type": "mcq", "stem": "s", "marks": 1,
				"options":     map[string]string{"A": "3", "B": "4"},
				"explanation": "because",
			}},
		},
	}
	for name, b := range cases {
		dir := writeLib(t, b)
		_, err := Load(dir)
		if !errors.Is(err, ErrAnswerLeak) {
			t.Fatalf("%s: want ErrAnswerLeak, got %v", name, err)
		}
	}
}

func TestLoadRejectsSHAMismatch(t *testing.T) {
	dir := writeLib(t, validBundle())
	// tamper with the bundle after the manifest was written
	path := filepath.Join(dir, "questions", "test-bank.json")
	raw, _ := os.ReadFile(path)
	raw = append(raw, ' ')
	if err := os.WriteFile(path, raw, 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := Load(dir)
	if err == nil || !strings.Contains(err.Error(), "sha256 mismatch") {
		t.Fatalf("want sha mismatch, got %v", err)
	}
}

func TestLoadRejectsCountMismatch(t *testing.T) {
	b := validBundle()
	b["questionCount"] = 5
	dir := writeLib(t, b)
	_, err := Load(dir)
	if err == nil || !strings.Contains(err.Error(), "declares 5 questions, has 1") {
		t.Fatalf("want count mismatch, got %v", err)
	}
}

func TestFindDataDir(t *testing.T) {
	root := t.TempDir()
	dataDir := filepath.Join(root, "data")
	if err := os.MkdirAll(filepath.Join(dataDir, "questions"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dataDir, "manifest.json"), []byte(`{"exams":[]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	deep := filepath.Join(dataDir, "a", "b", "c")
	if err := os.MkdirAll(deep, 0o755); err != nil {
		t.Fatal(err)
	}
	if got := FindDataDir(deep); got != dataDir {
		t.Fatalf("FindDataDir = %q, want %q", got, dataDir)
	}
	if got := FindDataDir(t.TempDir()); got != "" {
		t.Fatalf("expected empty, got %q", got)
	}
}
