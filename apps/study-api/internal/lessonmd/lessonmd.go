// Package lessonmd parses Renance lesson markdown into cbtdata.Lesson
// bundles (ROADMAP #8).
//
// Source format: YAML front-matter (slug, title, subject, body, tags,
// minutes, summary) then a markdown body restricted to the lesson
// subset:
//
//	## Section heading        -> starts a section (required first)
//	### Sub-heading           -> h3 block
//	- item / * item           -> bullet list
//	1. item                   -> numbered list
//	> text                    -> callout (key-point)
//	plain text                -> paragraph (soft-wrapped lines merge)
//
// Inline markers (**bold**, *italic*, `code`) are preserved as-is; the
// apps render them with their own inline renderers. Raw HTML is
// REJECTED at lint time — lesson text never becomes markup, so no
// injection surface exists anywhere downstream.
package lessonmd

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"

	"renance.dev/study-api/internal/cbtdata"
)

var slugRE = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
var olRE = regexp.MustCompile(`^\d+\. `)
var htmlRE = regexp.MustCompile(`<[/!a-zA-Z]`)

// Meta is the YAML front-matter contract. Unknown keys are rejected.
type Meta struct {
	Slug    string   `yaml:"slug"`
	Title   string   `yaml:"title"`
	Subject string   `yaml:"subject"`
	Body    string   `yaml:"body"`
	Tags    []string `yaml:"tags"`
	Minutes int      `yaml:"minutes"`
	Summary string   `yaml:"summary"`
}

// Parse converts one markdown source into a Lesson bundle.
func Parse(src []byte) (cbtdata.Lesson, error) {
	lines := strings.Split(strings.ReplaceAll(string(src), "\r\n", "\n"), "\n")
	if len(lines) == 0 || strings.TrimSpace(lines[0]) != "---" {
		return cbtdata.Lesson{}, fmt.Errorf("source must start with YAML front-matter (---)")
	}
	end := -1
	for i := 1; i < len(lines); i++ {
		if strings.TrimSpace(lines[i]) == "---" {
			end = i
			break
		}
	}
	if end < 0 {
		return cbtdata.Lesson{}, fmt.Errorf("front-matter is never closed (expected ---)")
	}
	var meta Meta
	dec := yaml.NewDecoder(strings.NewReader(strings.Join(lines[1:end], "\n")))
	dec.KnownFields(true)
	if err := dec.Decode(&meta); err != nil {
		return cbtdata.Lesson{}, fmt.Errorf("front-matter: %w", err)
	}

	les, err := parseBody(lines[end+1:])
	if err != nil {
		return cbtdata.Lesson{}, err
	}
	les.Slug = strings.TrimSpace(meta.Slug)
	les.Title = strings.TrimSpace(meta.Title)
	les.Subject = strings.TrimSpace(meta.Subject)
	les.Body = strings.TrimSpace(meta.Body)
	les.Tags = meta.Tags
	les.Minutes = meta.Minutes
	les.Summary = strings.TrimSpace(meta.Summary)
	if err := validate(&les); err != nil {
		return cbtdata.Lesson{}, err
	}
	return les, nil
}

func parseBody(lines []string) (cbtdata.Lesson, error) {
	var les cbtdata.Lesson
	var para, quote []string
	var items []string
	itemType := ""
	flushPara := func() {
		if len(para) > 0 && len(les.Sections) > 0 {
			les.Sections[len(les.Sections)-1].Blocks = append(
				les.Sections[len(les.Sections)-1].Blocks,
				cbtdata.Block{Type: "p", Text: strings.Join(para, " ")})
			para = nil
		}
	}
	flushItems := func() {
		if len(items) > 0 && len(les.Sections) > 0 {
			les.Sections[len(les.Sections)-1].Blocks = append(
				les.Sections[len(les.Sections)-1].Blocks,
				cbtdata.Block{Type: itemType, Items: items})
			items = nil
			itemType = ""
		}
	}
	flushQuote := func() {
		if len(quote) > 0 && len(les.Sections) > 0 {
			les.Sections[len(les.Sections)-1].Blocks = append(
				les.Sections[len(les.Sections)-1].Blocks,
				cbtdata.Block{Type: "callout", Text: strings.Join(quote, " ")})
			quote = nil
		}
	}
	flushAll := func() { flushPara(); flushItems(); flushQuote() }

	for i, raw := range lines {
		lineNo := fmt.Sprintf("line %d", i+1)
		line := strings.TrimRight(raw, " \t")
		switch {
		case strings.TrimSpace(line) == "":
			flushAll()
		case strings.HasPrefix(line, "```"):
			return cbtdata.Lesson{}, fmt.Errorf("%s: code fences are not supported - use inline `code` markers", lineNo)
		case strings.HasPrefix(line, "## "):
			flushAll()
			les.Sections = append(les.Sections, cbtdata.Section{
				Heading: strings.TrimSpace(line[3:]),
				Blocks:  []cbtdata.Block{},
			})
		case strings.HasPrefix(line, "### "):
			flushAll()
			if len(les.Sections) == 0 {
				return cbtdata.Lesson{}, fmt.Errorf("%s: sub-heading before the first ## section", lineNo)
			}
			les.Sections[len(les.Sections)-1].Blocks = append(
				les.Sections[len(les.Sections)-1].Blocks,
				cbtdata.Block{Type: "h3", Text: strings.TrimSpace(line[4:])})
		case strings.HasPrefix(line, "#"):
			return cbtdata.Lesson{}, fmt.Errorf("%s: only ## sections and ### sub-headings are allowed (got %q)", lineNo, line)
		case strings.HasPrefix(line, "> "):
			flushPara()
			flushItems()
			quote = append(quote, strings.TrimSpace(line[2:]))
		case strings.HasPrefix(line, "- "), strings.HasPrefix(line, "* "):
			flushPara()
			flushQuote()
			if itemType == "ol" {
				flushItems()
			}
			itemType = "ul"
			items = append(items, strings.TrimSpace(line[2:]))
		case olRE.MatchString(line):
			flushPara()
			flushQuote()
			if itemType == "ul" {
				flushItems()
			}
			itemType = "ol"
			items = append(items, strings.TrimSpace(line[olRE.FindStringIndex(line)[1]:]))
		default:
			flushItems()
			flushQuote()
			para = append(para, strings.TrimSpace(line))
		}
	}
	flushAll()
	if len(les.Sections) == 0 {
		return cbtdata.Lesson{}, fmt.Errorf("no sections found - start the body with a '## Heading' line")
	}
	return les, nil
}

func validate(les *cbtdata.Lesson) error {
	if !slugRE.MatchString(les.Slug) {
		return fmt.Errorf("slug %q must be lowercase-dash (a-z, 0-9, -)", les.Slug)
	}
	if les.Title == "" {
		return fmt.Errorf("title is required")
	}
	if les.Summary == "" {
		return fmt.Errorf("summary is required (one line for list views and SEO)")
	}
	if les.Minutes < 1 || les.Minutes > 120 {
		return fmt.Errorf("minutes must be 1..120 (got %s)", strconv.Itoa(les.Minutes))
	}
	if len(les.Sections) == 0 {
		return fmt.Errorf("lesson needs at least one ## section")
	}
	for i, sec := range les.Sections {
		if strings.TrimSpace(sec.Heading) == "" {
			return fmt.Errorf("section %d has an empty heading", i+1)
		}
		if len(sec.Blocks) == 0 {
			return fmt.Errorf("section %q has no content", sec.Heading)
		}
		for j, b := range sec.Blocks {
			switch b.Type {
			case "p", "callout", "h3":
				if strings.TrimSpace(b.Text) == "" {
					return fmt.Errorf("section %q block %d (%s) is empty", sec.Heading, j+1, b.Type)
				}
				if err := noHTML(b.Text); err != nil {
					return fmt.Errorf("section %q block %d: %w", sec.Heading, j+1, err)
				}
			case "ul", "ol":
				if len(b.Items) == 0 {
					return fmt.Errorf("section %q block %d (%s) has no items", sec.Heading, j+1, b.Type)
				}
				for k, it := range b.Items {
					if strings.TrimSpace(it) == "" {
						return fmt.Errorf("section %q block %d item %d is empty", sec.Heading, j+1, k+1)
					}
					if err := noHTML(it); err != nil {
						return fmt.Errorf("section %q block %d item %d: %w", sec.Heading, j+1, k+1, err)
					}
				}
			default:
				return fmt.Errorf("section %q block %d has unknown type %q", sec.Heading, j+1, b.Type)
			}
		}
	}
	return nil
}

func noHTML(s string) error {
	if htmlRE.MatchString(s) {
		return fmt.Errorf("raw HTML is not allowed in lesson text (found %q) - use **bold**, *italic*, `code`", htmlRE.FindString(s))
	}
	return nil
}

// EncodeJSON renders a lesson as final bundle bytes: indented, no HTML
// escaping of text content (clients render the inline markers).
func EncodeJSON(les cbtdata.Lesson) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(les); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
