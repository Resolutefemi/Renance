package main

// Emit: Spec → pack JSON + key JSON + manifest, mirroring tools/cbt-build
// conventions exactly (indent 2, trailing newline, manifest key order).

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// forbiddenInPack: keys that must never appear anywhere in a student-visible
// bundle (mirrors tools/cbt-build/build.py FORBIDDEN_IN_BUNDLE; ADR-0003).
var forbiddenInPack = map[string]bool{
	"answer": true, "answers": true, "correct": true, "correct_letter": true,
	"correctletter": true, "correctoption": true, "explanation": true, "is_correct": true,
}

type qJSON struct {
	ID         string            `json:"id"`
	Type       string            `json:"type"`
	Stem       string            `json:"stem"`
	Options    map[string]string `json:"options,omitempty"`
	Marks      int               `json:"marks"`
	Topic      string            `json:"topic,omitempty"`
	Difficulty string            `json:"difficulty,omitempty"`
}

type bundleJSON struct {
	Code            string  `json:"code"`
	Title           string  `json:"title"`
	Version         int     `json:"version"`
	QuestionCount   int     `json:"questionCount"`
	TotalMarks      int     `json:"totalMarks"`
	DurationMinutes *int    `json:"durationMinutes,omitempty"`
	Category        string  `json:"category,omitempty"`
	Body            string  `json:"body,omitempty"`
	Questions       []qJSON `json:"questions"`
}

type kEntry struct {
	Type        string `json:"type"`
	Letter      string `json:"letter"`
	Explanation string `json:"explanation,omitempty"`
}

type keyJSON struct {
	Code    string            `json:"code"`
	Answers map[string]kEntry `json:"answers"`
}

// buildArtifacts renders the pack + key bytes for a lint-clean Spec.
func buildArtifacts(s *Spec) (pack []byte, key []byte, err error) {
	b := bundleJSON{
		Code:            s.Code,
		Title:           s.Title,
		Version:         s.Version,
		QuestionCount:   len(s.Questions),
		DurationMinutes: s.DurationMinutes,
		Category:        s.Category,
		Body:            s.Body,
		Questions:       make([]qJSON, 0, len(s.Questions)),
	}
	k := keyJSON{Code: s.Code, Answers: map[string]kEntry{}}
	for i, q := range s.Questions {
		marks := q.Marks
		if marks == 0 {
			marks = 1
		}
		b.Questions = append(b.Questions, qJSON{
			ID:         fmt.Sprintf("%s-%04d", s.Code, i+1),
			Type:       "mcq",
			Stem:       q.Stem,
			Options:    q.Options,
			Marks:      marks,
			Topic:      q.Topic,
			Difficulty: q.Difficulty,
		})
		b.TotalMarks += marks
		k.Answers[fmt.Sprintf("%s-%04d", s.Code, i+1)] = kEntry{
			Type:        "mcq",
			Letter:      q.Answer,
			Explanation: q.Explanation,
		}
	}
	if b.Version == 0 {
		b.Version = 1
	}
	pack, err = marshalJSON(b)
	if err != nil {
		return nil, nil, err
	}
	key, err = marshalJSON(k)
	if err != nil {
		return nil, nil, err
	}
	if err := scanForForbidden(s.Code, pack); err != nil {
		return nil, nil, err
	}
	return pack, key, nil
}

func marshalJSON(v any) ([]byte, error) {
	out, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}

// scanForForbidden walks the marshaled pack and refuses answer material,
// the same doctrine the API enforces at boot (scanForAnswerMaterial).
func scanForForbidden(code string, pack []byte) error {
	var node any
	if err := json.Unmarshal(pack, &node); err != nil {
		return err
	}
	var walk func(n any, path string) error
	walk = func(n any, path string) error {
		switch v := n.(type) {
		case map[string]any:
			for k, sub := range v {
				norm := strings.ToLower(strings.ReplaceAll(k, "-", "_"))
				if forbiddenInPack[norm] {
					return fmt.Errorf("%s: forbidden key %q in pack (answer material leak)", code, k)
				}
				if err := walk(sub, path+"."+k); err != nil {
					return err
				}
			}
		case []any:
			for _, sub := range v {
				if err := walk(sub, path); err != nil {
					return err
				}
			}
		}
		return nil
	}
	return walk(node, code)
}

// ---- manifest ----

type examMeta struct {
	Code            string `json:"code"`
	Title           string `json:"title"`
	QuestionCount   int    `json:"questionCount"`
	TotalMarks      int    `json:"totalMarks"`
	DurationMinutes *int   `json:"durationMinutes,omitempty"`
	Category        string `json:"category,omitempty"`
	Body            string `json:"body,omitempty"`
	BundleSHA256    string `json:"bundleSha256"`
	SizeBytes       int64  `json:"sizeBytes"`
}

type manifestJSON struct {
	GeneratedAt string     `json:"generatedAt"`
	Version     string     `json:"version"`
	Exams       []examMeta `json:"exams"`
}

// writeManifest rebuilds data/manifest.json over EVERY pack in
// <outdir>/questions/*.json (self-healing, like cbt-build) and returns the
// number of packs fingerprinted.
func writeManifest(outdir, version string) (int, error) {
	if version == "" {
		version = existingVersion(outdir)
	}
	entries, err := os.ReadDir(filepath.Join(outdir, "questions"))
	if err != nil {
		return 0, err
	}
	var names []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".json") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)

	var exams []examMeta
	for _, name := range names {
		path := filepath.Join(outdir, "questions", name)
		raw, err := os.ReadFile(path)
		if err != nil {
			return 0, err
		}
		var b struct {
			Code            string `json:"code"`
			Title           string `json:"title"`
			QuestionCount   int    `json:"questionCount"`
			TotalMarks      int    `json:"totalMarks"`
			DurationMinutes *int   `json:"durationMinutes"`
			Category        string `json:"category"`
			Body            string `json:"body"`
		}
		if err := json.Unmarshal(raw, &b); err != nil {
			return 0, fmt.Errorf("manifest: %s: %w", name, err)
		}
		if b.Title == "" {
			b.Title = b.Code
		}
		sum := sha256.Sum256(raw)
		exams = append(exams, examMeta{
			Code:            b.Code,
			Title:           b.Title,
			QuestionCount:   b.QuestionCount,
			TotalMarks:      b.TotalMarks,
			DurationMinutes: b.DurationMinutes,
			Category:        b.Category,
			Body:            b.Body,
			BundleSHA256:    hex.EncodeToString(sum[:]),
			SizeBytes:       int64(len(raw)),
		})
	}
	if exams == nil {
		exams = []examMeta{}
	}
	m := manifestJSON{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Version:     version,
		Exams:       exams,
	}
	out, err := marshalJSON(m)
	if err != nil {
		return 0, err
	}
	return len(exams), os.WriteFile(filepath.Join(outdir, "manifest.json"), out, 0o644)
}

func existingVersion(outdir string) string {
	raw, err := os.ReadFile(filepath.Join(outdir, "manifest.json"))
	if err != nil {
		return "era2-g1"
	}
	var m struct {
		Version string `json:"version"`
	}
	if json.Unmarshal(raw, &m) != nil || m.Version == "" {
		return "era2-g1"
	}
	return m.Version
}
