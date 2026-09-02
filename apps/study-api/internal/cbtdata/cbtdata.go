// Package cbtdata loads and verifies the CBT content library at boot.
//
// ADR-0003 doctrine, enforced mechanically:
//   - every bundle in manifest.json must match its sha256 fingerprint
//   - every bundle is recursively scanned for answer-material keys
//     ("answer", "correct", "explanation", ...) and the service REFUSES
//     to boot if any leak into student-visible content
package cbtdata

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

var ErrAnswerLeak = errors.New("cbtdata: answer material found in student bundle")

// forbiddenKeys are key-side concepts that must never appear in a bundle,
// at any depth, case-insensitive (ADR-0003).
var forbiddenKeys = map[string]struct{}{
	"answer": {}, "answers": {}, "answer_key": {}, "answerkey": {},
	"correct": {}, "correct_answer": {}, "correctletter": {},
	"correct_letter": {}, "correctoption": {}, "correct_option": {},
	"explanation": {}, "explanations": {}, "iscorrect": {}, "is_correct": {},
}

type Question struct {
	ID         string            `json:"id"`
	Type       string            `json:"type"` // "mcq" | "text"
	Stem       string            `json:"stem"`
	Options    map[string]string `json:"options,omitempty"` // letter -> text
	Marks      int               `json:"marks"`
	Topic      string            `json:"topic,omitempty"`
	Difficulty string            `json:"difficulty,omitempty"`
}

type Bundle struct {
	Code            string     `json:"code"`
	Title           string     `json:"title"`
	Version         int        `json:"version"`
	QuestionCount   int        `json:"questionCount"`
	TotalMarks      int        `json:"totalMarks"`
	DurationMinutes *int       `json:"durationMinutes,omitempty"`
	Category        string     `json:"category,omitempty"` // secondary | university | …
	Body            string     `json:"body,omitempty"`     // JAMB | WAEC | NECO | University Modules
	Questions       []Question `json:"questions"`
}

type ExamMeta struct {
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

type Manifest struct {
	GeneratedAt string     `json:"generatedAt"`
	Version     string     `json:"version"`
	Exams       []ExamMeta `json:"exams"`
}

type Library struct {
	manifest Manifest
	bundles  map[string]*Bundle
}

// Load reads dataDir/manifest.json and verifies every referenced bundle.
func Load(dataDir string) (*Library, error) {
	raw, err := os.ReadFile(filepath.Join(dataDir, "manifest.json"))
	if err != nil {
		return nil, fmt.Errorf("cbtdata: read manifest: %w", err)
	}
	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, fmt.Errorf("cbtdata: parse manifest: %w", err)
	}
	lib := &Library{manifest: m, bundles: map[string]*Bundle{}}
	for _, ex := range m.Exams {
		path := filepath.Join(dataDir, "questions", ex.Code+".json")
		bundleRaw, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("cbtdata: read bundle %s: %w", ex.Code, err)
		}
		sum := sha256.Sum256(bundleRaw)
		if got := hex.EncodeToString(sum[:]); got != ex.BundleSHA256 {
			return nil, fmt.Errorf("cbtdata: sha256 mismatch for %s (manifest %s, file %s) — republish content",
				ex.Code, ex.BundleSHA256[:12], got[:12])
		}
		if err := scanForAnswerMaterial(ex.Code, bundleRaw); err != nil {
			return nil, err
		}
		var b Bundle
		if err := json.Unmarshal(bundleRaw, &b); err != nil {
			return nil, fmt.Errorf("cbtdata: parse bundle %s: %w", ex.Code, err)
		}
		if b.Code != ex.Code {
			return nil, fmt.Errorf("cbtdata: bundle %s declares code %q", ex.Code, b.Code)
		}
		if b.QuestionCount != len(b.Questions) {
			return nil, fmt.Errorf("cbtdata: bundle %s declares %d questions, has %d",
				ex.Code, b.QuestionCount, len(b.Questions))
		}
		if b.QuestionCount != ex.QuestionCount {
			return nil, fmt.Errorf("cbtdata: manifest count %d != bundle count %d for %s",
				ex.QuestionCount, b.QuestionCount, ex.Code)
		}
		lib.bundles[ex.Code] = &b
	}
	return lib, nil
}

func (l *Library) Manifest() Manifest { return l.manifest }

func (l *Library) Bundle(code string) (*Bundle, bool) {
	b, ok := l.bundles[code]
	return b, ok
}

// Question finds one question inside the bundle by id.
func (b *Bundle) Question(id string) (Question, bool) {
	for _, q := range b.Questions {
		if q.ID == id {
			return q, true
		}
	}
	return Question{}, false
}

// scanForAnswerMaterial walks the raw decoded JSON of a student-facing
// bundle and fails if any forbidden key appears at any depth.
func scanForAnswerMaterial(code string, raw []byte) error {
	var tree any
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	if err := dec.Decode(&tree); err != nil {
		return fmt.Errorf("cbtdata: bundle %s is not valid JSON: %w", code, err)
	}
	var path []string
	var walk func(v any) error
	walk = func(v any) error {
		switch t := v.(type) {
		case map[string]any:
			for k, child := range t {
				norm := strings.ToLower(strings.ReplaceAll(k, "-", "_"))
				if _, bad := forbiddenKeys[norm]; bad {
					return fmt.Errorf("%w: %s at %s", ErrAnswerLeak, k, strings.Join(append(path, k), "."))
				}
				path = append(path, k)
				if err := walk(child); err != nil {
					return err
				}
				path = path[:len(path)-1]
			}
		case []any:
			for _, child := range t {
				if err := walk(child); err != nil {
					return err
				}
			}
		}
		return nil
	}
	if err := walk(tree); err != nil {
		return fmt.Errorf("cbtdata: bundle %s: %w", code, err)
	}
	return nil
}

// FindDataDir walks up from dir looking for a data/ directory containing
// manifest.json, so the binary works whether launched from apps/study-api,
// the repo root, or scripts/. Returns "" if nothing is found.
func FindDataDir(dir string) string {
	for i := 0; i < 6; i++ {
		candidate := filepath.Join(dir, "data")
		if st, err := os.Stat(filepath.Join(candidate, "manifest.json")); err == nil && !st.IsDir() {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	_ = fs.ErrNotExist
	return ""
}
