// Package schoolcorpus serves the national curriculum corpus (schemes
// of work + lesson notes) straight out of the codebase's data folder.
//
// Founder directive: the corpus never lands in Neon. The web build
// bakes it into the static export and the app reads the very same
// files through these routes, so git stays the single source and the
// database stays out of the notes business entirely.
package schoolcorpus

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// Stage order keeps the class list reading like a Nigerian school run:
// nursery first, senior secondary last.
var stageOrder = map[string]int{
	"pre-primary": 0, "primary": 1, "junior-secondary": 2, "senior-secondary": 3,
}

var classNames = map[string]string{
	"nursery-1": "Nursery 1", "nursery-2": "Nursery 2", "nursery-3": "Nursery 3",
	"primary-1": "Primary 1", "primary-2": "Primary 2", "primary-3": "Primary 3",
	"primary-4": "Primary 4", "primary-5": "Primary 5", "primary-6": "Primary 6",
	"jss-1": "JSS 1", "jss-2": "JSS 2", "jss-3": "JSS 3",
	"sss-1": "SSS 1", "sss-2": "SSS 2", "sss-3": "SSS 3",
}

var stageNames = map[string]string{
	"pre-primary":      "Pre-primary (Nursery)",
	"primary":          "Primary",
	"junior-secondary": "Junior Secondary",
	"senior-secondary": "Senior Secondary",
}

func stageOf(class string) string {
	switch {
	case strings.HasPrefix(class, "nursery-"):
		return "pre-primary"
	case strings.HasPrefix(class, "primary-"):
		return "primary"
	case strings.HasPrefix(class, "jss-"):
		return "junior-secondary"
	case strings.HasPrefix(class, "sss-"):
		return "senior-secondary"
	}
	return ""
}

// Subject carries one subject's term availability so a client can
// grey out what the corpus does not hold yet.
type Subject struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	SchemeTerms []int  `json:"schemeTerms"`
	NoteTerms   []int  `json:"noteTerms"`
}

// Class is one class level (Nursery 1 through SSS 3).
type Class struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	Stage      string    `json:"stage"`
	StageLabel string    `json:"stageLabel"`
	Subjects   []Subject `json:"subjects"`
}

type entry struct {
	schemeTerms map[string][]int
	noteTerms   map[string][]int
}

// Corpus indexes the on-disk corpus at boot and reads term files on
// demand, so redeploying new content needs no schema migration.
type Corpus struct {
	dataDir string
	classes map[string]*entry
}

// Load scans dataDir/school-schemes/nerdc-2025 and
// dataDir/school-notes/nerdc-2025. A missing corpus boots as empty and
// the routes degrade to a clean empty list; nothing here is fatal.
func Load(dataDir string) *Corpus {
	c := &Corpus{dataDir: dataDir, classes: map[string]*entry{}}
	c.scan("school-schemes", func(e *entry, subject string, term int) {
		e.schemeTerms[subject] = appendInt(e.schemeTerms[subject], term)
	})
	c.scan("school-notes", func(e *entry, subject string, term int) {
		e.noteTerms[subject] = appendInt(e.noteTerms[subject], term)
	})
	return c
}

func (c *Corpus) scan(kind string, into func(*entry, string, int)) {
	root := filepath.Join(c.dataDir, kind, "nerdc-2025")
	classDirs, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, cd := range classDirs {
		class := cd.Name()
		if classNames[class] == "" || !cd.IsDir() {
			continue
		}
		e, ok := c.classes[class]
		if !ok {
			e = &entry{schemeTerms: map[string][]int{}, noteTerms: map[string][]int{}}
			c.classes[class] = e
		}
		files, err := os.ReadDir(filepath.Join(root, class))
		if err != nil {
			continue
		}
		for _, f := range files {
			name := f.Name()
			if !strings.HasSuffix(name, ".json") || name == "index.json" {
				continue
			}
			stem := strings.TrimSuffix(name, ".json")
			idx := strings.LastIndex(stem, "-term")
			if idx <= 0 {
				continue
			}
			subject, tail := stem[:idx], stem[idx+len("-term"):]
			term, err := strconv.Atoi(tail)
			if err != nil {
				continue
			}
			into(e, subject, term)
		}
	}
}

// appendInt keeps the per-subject term list sorted and unique.
func appendInt(list []int, v int) []int {
	for _, x := range list {
		if x == v {
			return list
		}
	}
	list = append(list, v)
	sort.Ints(list)
	return list
}

// Classes returns every class level in school order with subjects
// sorted alphabetically inside.
func (c *Corpus) Classes() []Class {
	out := make([]Class, 0, len(c.classes))
	for class, e := range c.classes {
		subjectSet := map[string]struct{}{}
		for s := range e.schemeTerms {
			subjectSet[s] = struct{}{}
		}
		for s := range e.noteTerms {
			subjectSet[s] = struct{}{}
		}
		subjects := make([]Subject, 0, len(subjectSet))
		for s := range subjectSet {
			subjects = append(subjects, Subject{
				ID:          s,
				Name:        titleSubject(s),
				SchemeTerms: e.schemeTerms[s],
				NoteTerms:   e.noteTerms[s],
			})
		}
		sort.Slice(subjects, func(i, j int) bool { return subjects[i].ID < subjects[j].ID })
		stage := stageOf(class)
		out = append(out, Class{
			ID: class, Name: classNames[class], Stage: stage,
			StageLabel: stageNames[stage], Subjects: subjects,
		})
	}
	sort.Slice(out, func(i, j int) bool {
		si, sj := stageOrder[out[i].Stage], stageOrder[out[j].Stage]
		if si != sj {
			return si < sj
		}
		return out[i].ID < out[j].ID
	})
	return out
}

// Has reports whether a class+subject pair exists in the corpus; the
// handlers use it to reject unknown slugs instead of touching paths.
func (c *Corpus) Has(class, subject string) bool {
	e, ok := c.classes[class]
	if !ok {
		return false
	}
	_, hasScheme := e.schemeTerms[subject]
	_, hasNote := e.noteTerms[subject]
	return hasScheme || hasNote
}

// TermPayload is one term file kept as raw JSON.
type TermPayload struct {
	Term int             `json:"term"`
	Data json.RawMessage `json:"data"`
}

// Terms reads one kind ("school-schemes" or "school-notes") for a
// class+subject and returns {term, data} pairs in term order. The
// payload stays raw so the JSON shape keeps evolving with the corpus
// without any server-side model churn.
func (c *Corpus) Terms(kind, class, subject string) []TermPayload {
	e, ok := c.classes[class]
	if !ok {
		return nil
	}
	var terms []int
	if kind == "school-schemes" {
		terms = e.schemeTerms[subject]
	} else {
		terms = e.noteTerms[subject]
	}
	out := make([]TermPayload, 0, len(terms))
	for _, term := range terms {
		raw, err := os.ReadFile(filepath.Join(c.dataDir, kind, "nerdc-2025", class, subject+"-term"+strconv.Itoa(term)+".json"))
		if err != nil {
			continue
		}
		out = append(out, TermPayload{Term: term, Data: json.RawMessage(raw)})
	}
	return out
}

// titleSubject turns "english-studies" into "English Studies".
func titleSubject(slug string) string {
	parts := strings.Split(slug, "-")
	for i, p := range parts {
		if p == "" {
			continue
		}
		parts[i] = strings.ToUpper(p[:1]) + p[1:]
	}
	return strings.Join(parts, " ")
}
