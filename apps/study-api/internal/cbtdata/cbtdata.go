// Package cbtdata loads and verifies the CBT content library at boot.
//
// Content doctrine (founder directive, 2026-09 — supersedes the old
// answer-keys-folder split of ADR-0003):
//   - every bundle in manifest.json must match its sha256 fingerprint
//   - each question file carries its own `answer` / `explanation` (and
//     optional worked-solution image / video) — ONE file per bank
//   - Load() HARVESTS those fields into the server-only key map and
//     SANITIZES the in-memory bundles, so students are served the same
//     answer-free papers as before while grading keeps working
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
	"sort"
	"strings"
	"sync"
)

var ErrAnswerLeak = errors.New("cbtdata: answer material found in student content")

// forbiddenKeys are key-side concepts that must never appear in
// student content that never carries answers (career/lessons uploads).
var forbiddenKeys = map[string]struct{}{
	"answer": {}, "answers": {}, "answer_key": {}, "answerkey": {},
	"correct": {}, "correct_answer": {}, "correctletter": {},
	"correct_letter": {}, "correctoption": {}, "correct_option": {},
	"explanation": {}, "explanations": {}, "iscorrect": {}, "is_correct": {},
}

// KeyEntry is the server-only answer material for one question,
// harvested from the bank file at Load and never served to students.
type KeyEntry struct {
	Letter      string
	Explanation string
	// AnswerImage is an optional worked-solution diagram for the
	// review screen (server-only, served after grading).
	AnswerImage string
	// Video is an optional walkthrough link carried with the key.
	Video string
}

type Question struct {
	ID         string            `json:"id"`
	Type       string            `json:"type"` // "mcq" | "text" | "theory"
	Stem       string            `json:"stem"`
	Options    map[string]string `json:"options,omitempty"` // letter -> text
	Marks      int               `json:"marks"`
	Topic      string            `json:"topic,omitempty"`
	Difficulty string            `json:"difficulty,omitempty"`
	Year       int               `json:"year,omitempty"` // exam year of the past question, 0 when unknown
	// Group marks question families the player treats specially
	// ("comprehension" = passage-based English questions); empty for
	// ordinary questions.
	Group string `json:"group,omitempty"`
	// Image is the question's diagram/figure, served from the web
	// app's /qimages/ directory (or an absolute URL). Diagram-based
	// past questions (maths/physics/chemistry) carry it so the
	// player renders the picture the stem refers to.
	Image string `json:"image,omitempty"`
	// Passage is the shared comprehension text the question belongs
	// to. Carried per-question so any member of the group can render
	// the passage it was cut from.
	Passage string `json:"passage,omitempty"`
	// ---- answer material (ON DISK by founder directive, IN MEMORY
	// only during Load: harvest+sanitize blanks these fields before
	// the bundle becomes student-visible) ----
	// Answer is the correct option letter for MCQs ("A".."H");
	// empty for theory questions (their model answer is the
	// Explanation).
	Answer string `json:"answer,omitempty"`
	// Explanation is the worked solution; for theory questions the
	// full model answer the review screen unlocks.
	Explanation string `json:"explanation,omitempty"`
	// AnswerImage is an optional worked-solution diagram path/URL.
	AnswerImage string `json:"answer_image,omitempty"`
	// Video is an optional walkthrough link.
	Video string `json:"video,omitempty"`
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
	// Sections groups a paper's questions under exam subjects. Static
	// packs leave it empty; composite UTME mock papers (paper.go) fill
	// it so the client can render subject tabs like the real CBT player.
	Sections []PaperSection `json:"sections,omitempty"`
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
	// Years lists the exam years present in the pack (sorted), the
	// year pickers' source of truth. Empty when unknown.
	Years []int `json:"years,omitempty"`
}

type Manifest struct {
	GeneratedAt string     `json:"generatedAt"`
	Version     string     `json:"version"`
	Exams       []ExamMeta `json:"exams"`
}

type Library struct {
	// mu guards bundles against the runtime composite-paper registration;
	// everything else is written once at boot and only read after.
	mu           sync.RWMutex
	manifest     Manifest
	bundles      map[string]*Bundle
	bundleIndex  map[string]string
	keys         map[string]map[string]KeyEntry
	syllabi      map[string]*Syllabus
	decks        map[string]*Deck
	deckOrder    []string
	lessons      map[string]*Lesson
	lessonOrder  []string
	scholarships []Scholarship
	paths        []CareerPath
}

// loadBundleIndex reads dataDir/questions/index.json — the code →
// slash-relative-path map tools/cbt-build/build.py writes beside the
// manifest. It lets banks live in grouped subfolders (WAEC/mathematics.json,
// All_tertiary_Q/futa/BIO101.json, POST_UTME/…) while their codes stay
// unchanged everywhere (manifest, URLs, composite-paper grammar). A missing
// or corrupt index returns nil and resolution falls back to the flat
// dataDir/questions/<code>.json layout.
func loadBundleIndex(dataDir string) map[string]string {
	raw, err := os.ReadFile(filepath.Join(dataDir, "questions", "index.json"))
	if err != nil {
		return nil
	}
	var idx map[string]string
	if json.Unmarshal(raw, &idx) != nil {
		return nil
	}
	return idx
}

// bundlePath resolves a bundle code to its file under dataDir/questions,
// index first, flat layout as the fallback. Index entries containing ".."
// are refused — the index is committed content, but paths from it must
// never escape the questions dir.
func bundlePath(dataDir, code string, index map[string]string) string {
	if index != nil {
		if rel, ok := index[code]; ok && rel != "" && !strings.Contains(rel, "..") {
			return filepath.Join(dataDir, "questions", filepath.FromSlash(rel))
		}
	}
	return filepath.Join(dataDir, "questions", code+".json")
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
	lib := &Library{manifest: m, bundles: map[string]*Bundle{}, keys: map[string]map[string]KeyEntry{}, decks: map[string]*Deck{}, lessons: map[string]*Lesson{}}
	lib.bundleIndex = loadBundleIndex(dataDir)
	for _, ex := range m.Exams {
		path := bundlePath(dataDir, ex.Code, lib.bundleIndex)
		bundleRaw, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("cbtdata: read bundle %s: %w", ex.Code, err)
		}
		sum := sha256.Sum256(bundleRaw)
		if got := hex.EncodeToString(sum[:]); got != ex.BundleSHA256 {
			return nil, fmt.Errorf("cbtdata: sha256 mismatch for %s (manifest %s, file %s) — republish content",
				ex.Code, ex.BundleSHA256[:12], got[:12])
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
		lib.harvestAndSanitize(ex.Code, &b)
		lib.bundles[ex.Code] = &b
	}
	if err := lib.loadSyllabi(dataDir); err != nil {
		return nil, err
	}
	if err := lib.validateTopics(); err != nil {
		return nil, err
	}
	if err := lib.loadFlashcards(dataDir); err != nil {
		return nil, err
	}
	if err := lib.loadLessons(dataDir); err != nil {
		return nil, err
	}
	if err := lib.loadCareer(dataDir); err != nil {
		return nil, err
	}
	return lib, nil
}

// harvestAndSanitize lifts the per-question answer material into the
// server-only key map and blanks it on the in-memory question, so every
// student-facing surface (bundle fetches, composed papers, arena seats)
// serves answer-free content while grading still has its key.
func (l *Library) harvestAndSanitize(code string, b *Bundle) {
	keys := make(map[string]KeyEntry, len(b.Questions))
	for i := range b.Questions {
		q := &b.Questions[i]
		if q.Answer != "" || q.Explanation != "" || q.AnswerImage != "" || q.Video != "" {
			keys[q.ID] = KeyEntry{
				Letter:      q.Answer,
				Explanation: q.Explanation,
				AnswerImage: q.AnswerImage,
				Video:       q.Video,
			}
			q.Answer, q.Explanation, q.AnswerImage, q.Video = "", "", "", ""
		}
	}
	if len(keys) > 0 {
		l.keys[code] = keys
	}
}

// KeysFor returns the harvested server-only key map for one bank.
func (l *Library) KeysFor(code string) (map[string]KeyEntry, bool) {
	keys, ok := l.keys[code]
	return keys, ok
}

// AllKeys returns every harvested key map, grouped by bank code — the
// boot-time answer-key seed's source of truth.
func (l *Library) AllKeys() map[string]map[string]KeyEntry {
	return l.keys
}

func (l *Library) Manifest() Manifest { return l.manifest }

func (l *Library) Bundle(code string) (*Bundle, bool) {
	l.mu.RLock()
	defer l.mu.RUnlock()
	b, ok := l.bundles[code]
	return b, ok
}

// RegisterPaper installs a runtime-composed bundle (composite UTME mock
// papers) so bundle fetches, attempts, grading and review all resolve
// it like any static pack. Composites never enter the manifest.
func (l *Library) RegisterPaper(b *Bundle) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.bundles[b.Code] = b
}

// BundlesByBody returns every loaded bundle whose exam body matches
// (case-insensitive), sorted by code — the daily challenge's rotation
// pool for that body (ROADMAP #20). The canonical spelling of the body
// is the first bundle's own Body field.
func (l *Library) BundlesByBody(body string) []*Bundle {
	want := strings.ToLower(strings.TrimSpace(body))
	if want == "" {
		return nil
	}
	var out []*Bundle
	l.mu.RLock()
	for _, b := range l.bundles {
		// Composite mock papers carry a body but never join rotation
		// pools: the daily challenge and the arena draw from the static
		// library only. Theory packs (self-assessment essays) are
		// excluded too — a daily sprint must be auto-gradable.
		if IsMockPaperCode(b.Code) || IsCustomPaperCode(b.Code) || IsPickPaperCode(b.Code) || strings.HasSuffix(b.Code, "-theory") {
			continue
		}
		if strings.ToLower(b.Body) == want {
			out = append(out, b)
		}
	}
	l.mu.RUnlock()
	sort.Slice(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out
}

// Bodies lists the distinct exam bodies across loaded bundles, sorted —
// the friendly "try one of these" list for an unknown-body request.
func (l *Library) Bodies() []string {
	seen := map[string]string{} // lower -> canonical
	for _, b := range l.bundles {
		if b.Body == "" {
			continue
		}
		key := strings.ToLower(b.Body)
		if _, dup := seen[key]; !dup {
			seen[key] = b.Body
		}
	}
	out := make([]string, 0, len(seen))
	for _, canonical := range seen {
		out = append(out, canonical)
	}
	sort.Strings(out)
	return out
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
