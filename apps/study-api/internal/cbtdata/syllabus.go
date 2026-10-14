// Syllabus trees (ROADMAP #4): the curriculum spine that gives every
// question's topic a home. One static JSON per exam body lives in
// data/syllabus/<slug>.json; Load() reads them at boot and ENFORCES the
// join, when a tree exists for a bundle's body, every non-empty topic
// on its questions must be a node of that tree. A typo'd topic refuses
// the boot loudly (same doctrine as the sha256 and answer-leak checks):
// silent orphans would poison the syllabus map, the review queue and
// adaptive ordering all at once.
package cbtdata

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"unicode"
)

// SyllabusSection groups topics the way the brochure does ("Algebra",
// "Number & Numeration", ...). Topics are exact match keys against
// Question.Topic, one source of truth, no aliasing.
type SyllabusSection struct {
	Title  string   `json:"title"`
	Topics []string `json:"topics"`
}

type SyllabusSubject struct {
	Subject  string            `json:"subject"`
	Sections []SyllabusSection `json:"sections"`
}

// Syllabus is one body's curriculum tree: JAMB, WAEC, ...
type Syllabus struct {
	Body     string            `json:"body"`
	Subjects []SyllabusSubject `json:"subjects"`
}

// TopicSet flattens the tree into the exact-match set of topic names.
func (sy *Syllabus) TopicSet() map[string]struct{} {
	set := make(map[string]struct{})
	for _, s := range sy.Subjects {
		for _, sec := range s.Sections {
			for _, t := range sec.Topics {
				set[t] = struct{}{}
			}
		}
	}
	return set
}

// TopicCount reports how many nodes the tree carries.
func (sy *Syllabus) TopicCount() int { return len(sy.TopicSet()) }

// Slug normalizes a body name to the filename used under data/syllabus/:
// "University Modules" -> "university-modules", "JAMB" -> "jamb".
func Slug(body string) string {
	var b strings.Builder
	lastDash := true // never lead with a dash
	for _, r := range strings.ToLower(body) {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			b.WriteRune(r)
			lastDash = false
		default:
			if !lastDash {
				b.WriteByte('-')
				lastDash = true
			}
		}
	}
	return strings.Trim(b.String(), "-")
}

// loadSyllabi reads every data/syllabus/*.json into the library, keyed by
// the tree's own Body field. A malformed file refuses the boot.
func (l *Library) loadSyllabi(dataDir string) error {
	dir := filepath.Join(dataDir, "syllabus")
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // no trees shipped yet, validation becomes a no-op
		}
		return fmt.Errorf("cbtdata: read syllabus dir: %w", err)
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		names = append(names, e.Name())
	}
	sort.Strings(names)
	l.syllabi = map[string]*Syllabus{}
	for _, name := range names {
		raw, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return fmt.Errorf("cbtdata: read syllabus %s: %w", name, err)
		}
		var sy Syllabus
		if err := json.Unmarshal(raw, &sy); err != nil {
			return fmt.Errorf("cbtdata: parse syllabus %s: %w", name, err)
		}
		if sy.Body == "" {
			return fmt.Errorf("cbtdata: syllabus %s declares no body", name)
		}
		if prev, dup := l.syllabi[sy.Body]; dup {
			return fmt.Errorf("cbtdata: syllabus %s re-declares body %q (first in %s)",
				name, sy.Body, Slug(prev.Body)+".json")
		}
		l.syllabi[sy.Body] = &sy
	}
	return nil
}

// validateTopics no longer exists as a pass over parsed bundles: the
// topic join is enforced by the boot probe in scanBanks (cbtdata.go),
// which walks every question's topic tag while the file bytes are
// already in hand. Same contract, zero resident question structs.

// SyllabusForBody looks a tree up by exact body name or slug.
func (l *Library) SyllabusForBody(body string) (*Syllabus, bool) {
	if sy, ok := l.syllabi[body]; ok {
		return sy, true
	}
	slug := Slug(body)
	for _, sy := range l.syllabi {
		if Slug(sy.Body) == slug {
			return sy, true
		}
	}
	return nil, false
}

// SyllabusBodies lists the shipped trees, alphabetically.
func (l *Library) SyllabusBodies() []string {
	out := make([]string, 0, len(l.syllabi))
	for _, sy := range l.syllabi {
		out = append(out, sy.Body)
	}
	sort.Strings(out)
	return out
}

// TopicCounts counts the questions per topic across every bundle of one
// body, the "42 Questions" column of the syllabus map. Empty topics
// bucket into "General". Bodies without packs return an empty map. The
// counts come straight from the boot probe - no bank is parsed.
func (l *Library) TopicCounts(body string) map[string]int {
	counts := map[string]int{}
	l.mu.RLock()
	defer l.mu.RUnlock()
	for _, ex := range l.manifest.Exams {
		m := l.stats[ex.Code]
		if m == nil || m.Body != body {
			continue
		}
		if len(m.Topics) == 0 {
			counts["General"] += m.Questions
			continue
		}
		for t, n := range m.Topics {
			counts[t] += n
		}
		counts["General"] += m.Questions - topicTagged(m)
	}
	return counts
}

// topicTagged counts the questions a bank's probe tagged with a topic.
func topicTagged(m *BundleMeta) int {
	n := 0
	for _, c := range m.Topics {
		n += c
	}
	return n
}

// PackBodies lists the distinct bodies actually served by packs.
func (l *Library) PackBodies() []string {
	seen := map[string]struct{}{}
	l.mu.RLock()
	defer l.mu.RUnlock()
	for _, ex := range l.manifest.Exams {
		body := ""
		if m := l.stats[ex.Code]; m != nil {
			body = m.Body
		}
		if body == "" {
			body = ex.Body
		}
		if body != "" {
			seen[body] = struct{}{}
		}
	}
	out := make([]string, 0, len(seen))
	for body := range seen {
		out = append(out, body)
	}
	sort.Strings(out)
	return out
}
