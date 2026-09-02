package main

// Source parsing: YAML or CSV → Spec. Pure functions, unit-testable.

import (
	"encoding/csv"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Spec is one pack's full definition straight from source.
type Spec struct {
	Code            string
	Title           string
	Category        string
	Body            string
	DurationMinutes *int
	Version         int
	Questions       []QSpec
	Source          string // file the spec came from (for messages)
}

// QSpec is one question from source. Options holds uppercase letters A-H.
type QSpec struct {
	Stem        string
	Options     map[string]string
	Answer      string // uppercase letter; key-only
	Explanation string // key-only
	Topic       string
	Difficulty  string
	Marks       int // 0 → default 1 at lint/emit time
}

// parseSource reads a .yaml/.yml/.csv file into a Spec, applying optional
// CLI flag overrides (used mainly for CSV, whose questions carry no metadata).
func parseSource(path string, meta packMeta) (*Spec, []Issue, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, err
	}
	raw = stripBOM(raw)
	var spec *Spec
	var issues []Issue
	switch ext := strings.ToLower(filepath.Ext(path)); ext {
	case ".yaml", ".yml":
		spec, issues, err = parseYAML(raw)
	case ".csv":
		spec, issues, err = parseCSV(raw)
	default:
		return nil, nil, fmt.Errorf("unsupported source type %q (want .yaml/.yml/.csv)", ext)
	}
	if err != nil {
		return nil, nil, err
	}
	spec.Source = path
	spec.applyMeta(meta)
	return spec, issues, nil
}

type packMeta struct {
	Code, Title, Category, Body string
	Duration                    int // 0 = leave as parsed
	Version                     int // 0 = leave as parsed
}

func (s *Spec) applyMeta(m packMeta) {
	if m.Code != "" {
		s.Code = m.Code
	}
	if m.Title != "" {
		s.Title = m.Title
	}
	if m.Category != "" {
		s.Category = m.Category
	}
	if m.Body != "" {
		s.Body = m.Body
	}
	if m.Duration > 0 {
		s.DurationMinutes = &m.Duration
	}
	if m.Version > 0 {
		s.Version = m.Version
	}
}

func stripBOM(b []byte) []byte {
	if len(b) >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF {
		return b[3:]
	}
	return b
}

// ---- YAML ----

type yspec struct {
	Code            string      `yaml:"code"`
	Title           string      `yaml:"title"`
	Category        string      `yaml:"category"`
	Body            string      `yaml:"body"`
	DurationMinutes *int        `yaml:"durationMinutes"`
	Version         int         `yaml:"version"`
	Questions       []yaml.Node `yaml:"questions"`
}

func parseYAML(raw []byte) (*Spec, []Issue, error) {
	var ys yspec
	if err := yaml.Unmarshal(raw, &ys); err != nil {
		return nil, nil, fmt.Errorf("yaml: %w", err)
	}
	spec := &Spec{
		Code:            ys.Code,
		Title:           ys.Title,
		Category:        ys.Category,
		Body:            ys.Body,
		DurationMinutes: ys.DurationMinutes,
		Version:         ys.Version,
	}
	for i, node := range ys.Questions {
		var m map[string]yaml.Node
		if err := node.Decode(&m); err != nil {
			return nil, nil, fmt.Errorf("yaml question %d: %w", i+1, err)
		}
		qs, err := mapToQSpec(m, i)
		if err != nil {
			return nil, nil, err
		}
		spec.Questions = append(spec.Questions, qs)
	}
	return spec, nil, nil
}

// mapToQSpec accepts both `options: {A: .., B: ..}` and the shorthand keys
// a/b/c/d, merging into one uppercase-lettered option set. Scalars are read
// from the node's raw text so `1.0` stays "1.0" (no float re-formatting).
func mapToQSpec(m map[string]yaml.Node, idx int) (QSpec, error) {
	get := func(k string) string {
		n, ok := m[k]
		if !ok || n.Kind != yaml.ScalarNode {
			return ""
		}
		return strings.TrimSpace(n.Value)
	}
	qs := QSpec{
		Stem:        get("stem"),
		Answer:      strings.ToUpper(get("answer")),
		Explanation: get("explanation"),
		Topic:       get("topic"),
		Difficulty:  strings.ToLower(get("difficulty")),
		Marks:       1,
	}
	if t := strings.ToLower(get("type")); t != "" && t != "mcq" {
		return qs, fmt.Errorf("question %d: type %q unsupported — qbuild v1 emits MCQ-only packs", idx+1, t)
	}
	if v := get("marks"); v != "" {
		fmt.Sscanf(v, "%d", &qs.Marks)
	}
	qs.Options = map[string]string{}
	if optsNode, ok := m["options"]; ok && optsNode.Kind == yaml.MappingNode {
		var opts map[string]yaml.Node
		if err := optsNode.Decode(&opts); err != nil {
			return qs, fmt.Errorf("question %d: options: %w", idx+1, err)
		}
		for letter, textNode := range opts {
			lu := strings.ToUpper(strings.TrimSpace(letter))
			if lu != "" && textNode.Kind == yaml.ScalarNode && strings.TrimSpace(textNode.Value) != "" {
				qs.Options[lu] = strings.TrimSpace(textNode.Value)
			}
		}
	}
	for _, k := range []string{"a", "b", "c", "d"} {
		if v := get(k); v != "" {
			qs.Options[strings.ToUpper(k)] = v
		}
	}
	return qs, nil
}

// ---- CSV ----

// CSV header aliases (lowercased, BOM-stripped). One question per row.
var csvAliases = map[string]string{
	"stem": "stem", "question": "stem",
	"a": "A", "optiona": "A", "option_a": "A",
	"b": "B", "optionb": "B", "option_b": "B",
	"c": "C", "optionc": "C", "option_c": "C",
	"d": "D", "optiond": "D", "option_d": "D",
	"answer": "answer", "correct": "answer", "correctletter": "answer", "correct_letter": "answer",
	"explanation": "explanation", "rationale": "explanation",
	"topic": "topic", "difficulty": "difficulty",
	"marks": "marks", "mark": "marks",
}

func parseCSV(raw []byte) (*Spec, []Issue, error) {
	r := csv.NewReader(strings.NewReader(string(raw)))
	r.FieldsPerRecord = -1
	rows, err := r.ReadAll()
	if err != nil {
		return nil, nil, fmt.Errorf("csv: %w", err)
	}
	if len(rows) < 2 {
		return nil, nil, fmt.Errorf("csv: need a header row plus at least one question row")
	}
	// Map header columns → canonical fields.
	col := map[int]string{} // column index → canonical name
	for i, h := range rows[0] {
		key := strings.ToLower(strings.TrimSpace(h))
		if key == "" {
			continue
		}
		can, ok := csvAliases[key]
		if !ok {
			return nil, nil, fmt.Errorf("csv: unknown column %q (allowed: stem,a,b,c,d,answer,explanation,topic,difficulty,marks)", h)
		}
		col[i] = can
	}
	for _, need := range []string{"stem", "A", "B", "answer"} {
		found := false
		for _, can := range col {
			if can == need {
				found = true
			}
		}
		if !found {
			return nil, nil, fmt.Errorf("csv: header missing required column %q", need)
		}
	}

	spec := &Spec{}
	var issues []Issue
	seenStems := map[string]int{}
	for n, row := range rows[1:] {
		allEmpty := true
		for _, cell := range row {
			if strings.TrimSpace(cell) != "" {
				allEmpty = false
				break
			}
		}
		if allEmpty {
			continue // tolerate trailing blank lines
		}
		if len(row) != len(rows[0]) {
			return nil, nil, fmt.Errorf("csv row %d: %d fields, header has %d", n+2, len(row), len(rows[0]))
		}
		qs := QSpec{Options: map[string]string{}, Marks: 1}
		for i, can := range col {
			cell := strings.TrimSpace(row[i])
			switch can {
			case "stem":
				qs.Stem = cell
			case "A", "B", "C", "D":
				if cell != "" {
					qs.Options[can] = cell
				}
			case "answer":
				qs.Answer = strings.ToUpper(cell)
			case "explanation":
				qs.Explanation = cell
			case "topic":
				qs.Topic = cell
			case "difficulty":
				qs.Difficulty = strings.ToLower(cell)
			case "marks":
				if cell != "" {
					if _, err := fmt.Sscanf(cell, "%d", &qs.Marks); err != nil {
						return nil, nil, fmt.Errorf("csv row %d: marks %q is not a number", n+2, cell)
					}
				}
			}
		}
		if prev, dup := seenStems[strings.ToLower(qs.Stem)]; dup {
			issues = append(issues, Issue{Level: "warn", Where: fmt.Sprintf("row %d", n+2),
				Msg: fmt.Sprintf("duplicate stem (same as row %d)", prev+2)})
		}
		seenStems[strings.ToLower(qs.Stem)] = n
		spec.Questions = append(spec.Questions, qs)
	}
	return spec, issues, nil
}
