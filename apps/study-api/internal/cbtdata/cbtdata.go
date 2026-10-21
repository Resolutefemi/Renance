// Package cbtdata loads and verifies the CBT content library at boot.
//
// Content doctrine (founder directive, 2026-09 - supersedes the old
// answer-keys-folder split of ADR-0003):
//   - every bundle in manifest.json must match its sha256 fingerprint
//   - each question file carries its own `answer` / `explanation` (and
//     optional worked-solution image / video) - ONE file per bank
//   - Load() HARVESTS those fields into the server-only key map and
//     SANITIZES the in-memory bundles, so students are served the same
//     answer-free papers as before while grading keeps working
//
// Memory doctrine (Render free plan, 512Mi - founder report 2026-10-14,
// "Out of memory (used over 512Mi)" kill at boot): the library NO LONGER
// parses all 1056 banks (145MB raw JSON, ~600MB of live structs) at
// startup. Boot verifies every fingerprint and probes every bank for
// stats, then banks are parsed ON DEMAND into a bounded LRU. Steady-state
// RSS drops by hundreds of MB while every code path keeps working.
package cbtdata

import (
	"container/list"
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
// harvested from the bank file at parse time and never served raw.
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
	// only during parse: harvest+sanitize blanks these fields before
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

// BundleMeta is the parse-free summary of one bank, recorded by the
// boot probe. Daily pools, arena eligibility and syllabus counts all
// run off metas - none of them needs the full bank in memory.
type BundleMeta struct {
	Code      string
	Body      string
	Title     string
	Questions int // total questions
	Objective int // non-theory, non-text questions (auto-gradable)
	HasKeys   bool
	// Topics maps the bank's topic tags to question counts (the
	// syllabus map's "42 Questions" column). Nil for topic-less banks.
	Topics map[string]int
}

// lruEntry is one parsed bank in the LRU: the student-visible bundle
// (answers stripped) plus its harvested server-only key map. Both are
// dropped together on eviction and re-parsed from disk on demand.
type lruEntry struct {
	code    string
	bundle  *Bundle
	keys    map[string]KeyEntry
	listPtr *list.Element
}

type Library struct {
	// mu guards the mutable maps (registered composites + LRU);
	// manifest, stats and the small loaders are written once at boot
	// and only read after.
	mu           sync.RWMutex
	dataDir      string
	manifest     Manifest
	bundleIndex  map[string]string
	codes        map[string]struct{} // manifest codes, for O(1) existence
	stats        map[string]*BundleMeta
	registered   map[string]*Bundle // runtime-composed papers, always resident
	registerOrd  []string           // FIFO cap order for registered papers
	lru          map[string]*lruEntry
	lruOrd       *list.List // front = most recent
	syllabi      map[string]*Syllabus
	decks        map[string]*Deck
	deckOrder    []string
	lessons      map[string]*Lesson
	lessonOrder  []string
	scholarships []Scholarship
	paths        []CareerPath
}

// Memory budget (Render free plan = 512Mi, shared with Go runtime, DB
// pool, arena hub and the tutor). 48 parsed banks worst-case ~60-80MB;
// composites (custom mocks) are capped FIFO. Tune only with fresh RSS
// numbers from a production-sized boot.
const (
	bundleLRUCap  = 48
	registeredCap = 64
)

// loadBundleIndex reads dataDir/questions/index.json - the code →
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
// are refused - the index is committed content, but paths from it must
// never escape the questions dir.
func bundlePath(dataDir, code string, index map[string]string) string {
	if index != nil {
		if rel, ok := index[code]; ok && rel != "" && !strings.Contains(rel, "..") {
			return filepath.Join(dataDir, "questions", filepath.FromSlash(rel))
		}
	}
	return filepath.Join(dataDir, "questions", code+".json")
}

// Load reads dataDir/manifest.json, verifies every referenced bundle
// fingerprint and probes every bank for stats. Bank CONTENT is parsed
// lazily on first use (memory doctrine, see package comment).
func Load(dataDir string) (*Library, error) {
	raw, err := os.ReadFile(filepath.Join(dataDir, "manifest.json"))
	if err != nil {
		return nil, fmt.Errorf("cbtdata: read manifest: %w", err)
	}
	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, fmt.Errorf("cbtdata: parse manifest: %w", err)
	}
	lib := &Library{
		dataDir: dataDir, manifest: m,
		bundleIndex: loadBundleIndex(dataDir),
		codes:       map[string]struct{}{},
		stats:       map[string]*BundleMeta{},
		registered:  map[string]*Bundle{},
		lru:         map[string]*lruEntry{},
		lruOrd:      list.New(),
		decks:       map[string]*Deck{},
		lessons:     map[string]*Lesson{},
	}
	for _, ex := range m.Exams {
		lib.codes[ex.Code] = struct{}{}
	}
	if err := lib.loadSyllabi(dataDir); err != nil {
		return nil, err
	}
	if err := lib.scanBanks(); err != nil {
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

// probeBundle is the boot-scan view of a bank file: only the fields the
// doctrine checks and the stats need. Stems, options, passages and
// images are skipped by the decoder, so the probe's transient footprint
// is a fraction of a full parse.
type probeBundle struct {
	Code          string `json:"code"`
	Body          string `json:"body"`
	QuestionCount int    `json:"questionCount"`
	Questions     []struct {
		ID          string `json:"id"`
		Type        string `json:"type"`
		Topic       string `json:"topic"`
		Answer      string `json:"answer"`
		Explanation string `json:"explanation"`
		AnswerImage string `json:"answer_image"`
		Video       string `json:"video"`
	} `json:"questions"`
}

// scanBanks walks every manifest exam once: read the file, verify the
// sha256 fingerprint (content doctrine), count questions, objective
// questions, topic tags and answer material. Nothing but the tiny
// BundleMeta is retained, so boot RSS stays flat no matter how large
// the library grows.
func (l *Library) scanBanks() error {
	for _, ex := range l.manifest.Exams {
		path := bundlePath(l.dataDir, ex.Code, l.bundleIndex)
		bundleRaw, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("cbtdata: read bundle %s: %w", ex.Code, err)
		}
		sum := sha256.Sum256(bundleRaw)
		if got := hex.EncodeToString(sum[:]); got != ex.BundleSHA256 {
			return fmt.Errorf("cbtdata: sha256 mismatch for %s (manifest %s, file %s) - republish content",
				ex.Code, ex.BundleSHA256[:12], got[:12])
		}
		var p probeBundle
		if err := json.Unmarshal(bundleRaw, &p); err != nil {
			return fmt.Errorf("cbtdata: parse bundle %s: %w", ex.Code, err)
		}
		if p.Code != ex.Code {
			return fmt.Errorf("cbtdata: bundle %s declares code %q", ex.Code, p.Code)
		}
		if p.QuestionCount != len(p.Questions) {
			return fmt.Errorf("cbtdata: bundle %s declares %d questions, has %d",
				ex.Code, p.QuestionCount, len(p.Questions))
		}
		if p.QuestionCount != ex.QuestionCount {
			return fmt.Errorf("cbtdata: manifest count %d != bundle count %d for %s",
				ex.QuestionCount, p.QuestionCount, ex.Code)
		}
		meta := &BundleMeta{Code: ex.Code, Title: ex.Title, Questions: len(p.Questions)}
		// The bundle's own body is canonical (the old parse-time checks ran
		// off b.Body); the manifest body is the fallback for body-less files.
		meta.Body = p.Body
		if meta.Body == "" {
			meta.Body = ex.Body
		}
		var topics map[string]int
		sy, syOK := l.syllabi[meta.Body]
		var topicSet map[string]struct{}
		if syOK {
			topicSet = sy.TopicSet()
		}
		for _, q := range p.Questions {
			if q.Type != "theory" && q.Type != "text" {
				meta.Objective++
			}
			if q.Answer != "" || q.Explanation != "" || q.AnswerImage != "" || q.Video != "" {
				meta.HasKeys = true
			}
			if q.Topic != "" {
				if topicSet != nil {
					if _, ok := topicSet[q.Topic]; !ok {
						return fmt.Errorf("cbtdata: bundle %s question %s: topic %q is not in the %s syllabus tree (data/syllabus/%s.json) - fix the tag or extend the tree",
							ex.Code, q.ID, q.Topic, meta.Body, Slug(meta.Body))
					}
				}
				if topics == nil {
					topics = map[string]int{}
				}
				topics[q.Topic]++
			}
		}
		meta.Topics = topics
		l.stats[ex.Code] = meta
	}
	return nil
}

// parseBundle fully decodes one bank from disk, verifies its shape,
// harvests the answer material into the server-only key map and
// sanitizes the in-memory questions. This is the LRU-miss slow path of
// Bundle(); every caller-shared map returned here must be treated as
// read-only by consumers.
func (l *Library) parseBundle(code string) (*lruEntry, error) {
	path := bundlePath(l.dataDir, code, l.bundleIndex)
	bundleRaw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("cbtdata: read bundle %s: %w", code, err)
	}
	var b Bundle
	if err := json.Unmarshal(bundleRaw, &b); err != nil {
		return nil, fmt.Errorf("cbtdata: parse bundle %s: %w", code, err)
	}
	if b.Code != code {
		return nil, fmt.Errorf("cbtdata: bundle %s declares code %q", code, b.Code)
	}
	if b.QuestionCount != len(b.Questions) {
		return nil, fmt.Errorf("cbtdata: bundle %s declares %d questions, has %d",
			code, b.QuestionCount, len(b.Questions))
	}
	entry := &lruEntry{code: code, bundle: &b, keys: map[string]KeyEntry{}}
	l.harvestAndSanitize(code, &b, entry.keys)
	return entry, nil
}

// harvestAndSanitize lifts the per-question answer material into the
// server-only key map and blanks it on the in-memory question, so every
// student-facing surface (bundle fetches, composed papers, arena seats)
// serves answer-free content while grading still has its key.
func (l *Library) harvestAndSanitize(code string, b *Bundle, keys map[string]KeyEntry) {
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
}

// Manifest returns the loaded manifest (metadata only - no bank content).
func (l *Library) Manifest() Manifest { return l.manifest }

// KeysFor returns the harvested server-only key map for one bank,
// parsing the bank on demand when it is not resident. The returned map
// is shared - callers must treat it as read-only.
func (l *Library) KeysFor(code string) (map[string]KeyEntry, bool) {
	l.mu.RLock()
	entry, ok := l.lru[code]
	if ok {
		keys := entry.keys
		l.mu.RUnlock()
		return keys, true
	}
	l.mu.RUnlock()
	// Registered composites never carry their own keys under their code.
	if !l.hasManifestCode(code) {
		return nil, false
	}
	parsed, err := l.parseBundle(code)
	if err != nil {
		return nil, false
	}
	l.mu.Lock()
	l.lruPut(parsed)
	l.mu.Unlock()
	return parsed.keys, true
}

// HasKeys reports whether a bank carries answer material, straight from
// the boot probe - no parse. Arena eligibility runs off this so a match
// pick never walks the whole library through the LRU.
func (l *Library) HasKeys(code string) bool {
	l.mu.RLock()
	defer l.mu.RUnlock()
	if m := l.stats[code]; m != nil {
		return m.HasKeys
	}
	return false
}

// KeyedBankCount reports how many banks carry answer material (boot log).
func (l *Library) KeyedBankCount() int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	n := 0
	for _, m := range l.stats {
		if m.HasKeys {
			n++
		}
	}
	return n
}

// hasManifestCode is the cheap existence check (manifest codes only).
func (l *Library) hasManifestCode(code string) bool {
	l.mu.RLock()
	defer l.mu.RUnlock()
	_, ok := l.codes[code]
	return ok
}

// lruPut inserts a parsed bank, evicting the least recently used when
// the cache is full. Caller holds the write lock.
func (l *Library) lruPut(entry *lruEntry) {
	if old, ok := l.lru[entry.code]; ok {
		l.lruOrd.Remove(old.listPtr)
	}
	entry.listPtr = l.lruOrd.PushFront(entry)
	l.lru[entry.code] = entry
	for len(l.lru) > bundleLRUCap {
		oldest := l.lruOrd.Back()
		if oldest == nil {
			break
		}
		evicted := oldest.Value.(*lruEntry)
		l.lruOrd.Remove(oldest)
		delete(l.lru, evicted.code)
	}
}

// Bundle returns a student-visible (answer-free) bundle: registered
// composite first, then the LRU, then disk. A code outside the manifest
// that was never registered resolves to nothing - bogus codes cost one
// map lookup, not a disk read.
func (l *Library) Bundle(code string) (*Bundle, bool) {
	l.mu.RLock()
	if b, ok := l.registered[code]; ok {
		l.mu.RUnlock()
		return b, true
	}
	if entry, ok := l.lru[code]; ok {
		l.lruOrd.MoveToFront(entry.listPtr)
		b := entry.bundle
		l.mu.RUnlock()
		return b, true
	}
	l.mu.RUnlock()
	if !l.hasManifestCode(code) {
		return nil, false
	}
	parsed, err := l.parseBundle(code)
	if err != nil {
		return nil, false
	}
	l.mu.Lock()
	l.lruPut(parsed)
	l.mu.Unlock()
	return parsed.bundle, true
}

// RegisterPaper installs a runtime-composed bundle (composite UTME mock
// papers) so bundle fetches, attempts, grading and review all resolve
// it like any static pack. Composites never enter the manifest.
func (l *Library) RegisterPaper(b *Bundle) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if _, exists := l.registered[b.Code]; !exists {
		l.registerOrd = append(l.registerOrd, b.Code)
	}
	l.registered[b.Code] = b
	for len(l.registerOrd) > registeredCap {
		oldest := l.registerOrd[0]
		l.registerOrd = l.registerOrd[1:]
		if cur, ok := l.registered[oldest]; ok && cur.Code == oldest {
			delete(l.registered, oldest)
		}
	}
}

// WithKeyMaterial returns a serveable copy of the bundle with each
// question's harvested answer material re-attached (founder directive
// 2026-09: the answers and explanations LIVE in the question JSON and
// ship to students, exactly like the web's static bundle shelf, so the
// study reader grades and explains fully offline). The receiver is
// never mutated - the library's in-memory copy stays answer-free for
// every internal consumer (composed papers, arena seats, daily
// rotation), which keeps ADR-0003 intact on those surfaces.
func (b *Bundle) WithKeyMaterial(keys map[string]KeyEntry) *Bundle {
	if b == nil || len(keys) == 0 {
		return b
	}
	out := *b
	out.Questions = make([]Question, len(b.Questions))
	copy(out.Questions, b.Questions)
	for i := range out.Questions {
		k, ok := keys[out.Questions[i].ID]
		if !ok {
			continue
		}
		out.Questions[i].Answer = k.Letter
		out.Questions[i].Explanation = k.Explanation
		out.Questions[i].AnswerImage = k.AnswerImage
		out.Questions[i].Video = k.Video
	}
	return &out
}

// BundlesByBody returns the parse-free metas of every manifest bank
// whose exam body matches (case-insensitive), sorted by code - the
// daily challenge's rotation pool for that body (ROADMAP #20) and any
// other body-shelf walk. The canonical spelling of the body is the
// first meta's own Body field. Composite mock/custom/pick papers never
// join (they are not in the manifest anyway); theory packs (self-
// assessment essays) are excluded too - a daily sprint must be
// auto-gradable.
func (l *Library) BundlesByBody(body string) []BundleMeta {
	want := strings.ToLower(strings.TrimSpace(body))
	if want == "" {
		return nil
	}
	l.mu.RLock()
	defer l.mu.RUnlock()
	var out []BundleMeta
	for _, ex := range l.manifest.Exams {
		code := ex.Code
		m := l.stats[code]
		if m == nil {
			continue
		}
		if strings.ToLower(m.Body) != want {
			continue
		}
		if IsMockPaperCode(code) || IsCustomPaperCode(code) || IsPickPaperCode(code) || strings.HasSuffix(code, "-theory") {
			continue
		}
		out = append(out, *m)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out
}

// Bodies lists the distinct exam bodies across the banks (bundle-declared
// body first, manifest fallback), sorted - the friendly "try one of
// these" list for an unknown-body request.
func (l *Library) Bodies() []string {
	seen := map[string]string{} // lower -> canonical
	l.mu.RLock()
	defer l.mu.RUnlock()
	for _, ex := range l.manifest.Exams {
		m := l.stats[ex.Code]
		body := ""
		if m != nil {
			body = m.Body
		}
		if body == "" {
			body = ex.Body
		}
		if body == "" {
			continue
		}
		key := strings.ToLower(body)
		if _, dup := seen[key]; !dup {
			seen[key] = body
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
