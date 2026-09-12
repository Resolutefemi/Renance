package cbtdata

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
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
	count := 0
	if qs, ok := bundle["questions"].([]any); ok {
		count = len(qs)
	}
	manifest := Manifest{Version: "test", Exams: []ExamMeta{{
		Code: "test-bank", Title: "Test Bank", QuestionCount: count,
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

func TestLoadHarvestsAnswersAndSanitizes(t *testing.T) {
	// Founder directive (2026-09): the bank file CARRIES its answers;
	// Load harvests them into the server-only key map and the served
	// bundle must come out sanitized.
	b := validBundle()
	b["questions"] = []any{map[string]any{
		"id":          "q1",
		"type":        "mcq",
		"stem":        "s",
		"marks":       1,
		"answer":      "B",
		"explanation": "because two is two",
		"options":     map[string]string{"A": "3", "B": "4"},
	}}
	dir := writeLib(t, b)
	lib, err := Load(dir)
	if err != nil {
		t.Fatalf("load with embedded answers: %v", err)
	}
	served, ok := lib.Bundle("test-bank")
	if !ok {
		t.Fatal("bundle missing")
	}
	q := served.Questions[0]
	if q.Answer != "" || q.Explanation != "" || q.AnswerImage != "" || q.Video != "" {
		t.Fatalf("answer material leaked into served bundle: %+v", q)
	}
	keys, ok := lib.KeysFor("test-bank")
	if !ok {
		t.Fatal("harvested key missing")
	}
	k := keys["q1"]
	if k.Letter != "B" || k.Explanation != "because two is two" {
		t.Fatalf("harvested key wrong: %+v", k)
	}
	if all := lib.AllKeys(); len(all) != 1 || len(all["test-bank"]) != 1 {
		t.Fatalf("AllKeys wrong: %+v", all)
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

func TestLoadResolvesThroughIndex(t *testing.T) {
	dir := t.TempDir()
	// Grouped layout: the bank lives renamed inside WAEC/, its code unchanged.
	raw, _ := json.Marshal(validBundle())
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
	if err := os.MkdirAll(filepath.Join(dir, "questions", "WAEC"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "questions", "WAEC", "math.json"), raw, 0o644); err != nil {
		t.Fatal(err)
	}
	idxRaw, _ := json.Marshal(map[string]string{"test-bank": "WAEC/math.json"})
	if err := os.WriteFile(filepath.Join(dir, "questions", "index.json"), idxRaw, 0o644); err != nil {
		t.Fatal(err)
	}
	lib, err := Load(dir)
	if err != nil {
		t.Fatalf("load via index: %v", err)
	}
	if b, ok := lib.Bundle("test-bank"); !ok || b.QuestionCount != 1 {
		t.Fatalf("bundle wrong: %+v ok=%v", b, ok)
	}

	// A ".." escape in the index must be refused, not followed: resolution
	// falls back to the flat layout, which misses here and fails the boot.
	evil, _ := json.Marshal(map[string]string{"test-bank": "../secrets/answers.json"})
	if err := os.WriteFile(filepath.Join(dir, "questions", "index.json"), evil, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(dir); err == nil || !strings.Contains(err.Error(), "read bundle") {
		t.Fatalf("want flat-fallback read failure for .. path, got %v", err)
	}
}
