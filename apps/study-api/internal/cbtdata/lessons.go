// Lessons (ROADMAP #8), mdx-built study lessons served like exam packs:
// data/lessons/{slug}.json, loaded and validated at boot.
//
// Lessons are authored prose (no answer material by construction), so the
// ADR-0003 answer-leak scan applies unchanged: any forbidden key in a
// lesson bundle refuses the boot exactly like a leaking exam bundle.
// What mdx guarantees at build time, the boot re-checks mechanically:
// slug/filename match, required fields, non-empty sections, unique slugs.
package cbtdata

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var lessonSlugRE = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)

// Block is one paragraph-level piece of lesson content. Type is one of
// "p" (paragraph), "ul" (bullet list), "ol" (numbered list), "callout"
// (key-point quote) or "h3" (sub-heading). Text and items carry
// lightweight inline markers (**bold**, *italic*, `code`) that clients
// render with their own inline renderer, never raw HTML.
type Block struct {
	Type  string   `json:"type"`
	Text  string   `json:"text,omitempty"`
	Items []string `json:"items,omitempty"`
}

// Section is one ## heading and everything under it.
type Section struct {
	Heading string  `json:"heading"`
	Blocks  []Block `json:"blocks"`
}

// Lesson is one studyable reading. Summary feeds list views and SEO
// cards; minutes drives the "x min read" pill.
type Lesson struct {
	Slug          string    `json:"slug"`
	Title         string    `json:"title"`
	Subject       string    `json:"subject,omitempty"`
	Body          string    `json:"body,omitempty"` // JAMB | WAEC | University Modules | …
	Tags          []string  `json:"tags,omitempty"`
	Minutes       int       `json:"minutes"`
	Summary       string    `json:"summary"`
	ContentSha256 string    `json:"contentSha256,omitempty"` // provenance, stamped by mdx
	Sections      []Section `json:"sections"`
}

// LessonMeta is the list-view row (no sections attached).
type LessonMeta struct {
	Slug    string   `json:"slug"`
	Title   string   `json:"title"`
	Subject string   `json:"subject,omitempty"`
	Body    string   `json:"body,omitempty"`
	Tags    []string `json:"tags,omitempty"`
	Minutes int      `json:"minutes"`
	Summary string   `json:"summary"`
}

// loadLessons scans dataDir/lessons/*.json. The directory is optional ,
// an install with no lessons boots fine and serves an empty list, but a
// lesson that IS present must be fully valid.
func (l *Library) loadLessons(dataDir string) error {
	dir := filepath.Join(dataDir, "lessons")
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("cbtdata: scan lessons: %w", err)
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			return fmt.Errorf("cbtdata: read lesson %s: %w", e.Name(), err)
		}
		if err := scanForAnswerMaterial("lesson/"+e.Name(), raw); err != nil {
			return err
		}
		var les Lesson
		if err := json.Unmarshal(raw, &les); err != nil {
			return fmt.Errorf("cbtdata: parse lesson %s: %w", e.Name(), err)
		}
		slug := strings.TrimSuffix(e.Name(), ".json")
		if les.Slug != slug {
			return fmt.Errorf("cbtdata: lesson file %s declares slug %q", e.Name(), les.Slug)
		}
		if !lessonSlugRE.MatchString(slug) {
			return fmt.Errorf("cbtdata: lesson slug %q must be lowercase-dash (a-z 0-9 -)", slug)
		}
		if strings.TrimSpace(les.Title) == "" {
			return fmt.Errorf("cbtdata: lesson %s has no title", slug)
		}
		if strings.TrimSpace(les.Summary) == "" {
			return fmt.Errorf("cbtdata: lesson %s has no summary", slug)
		}
		if les.Minutes < 1 || les.Minutes > 120 {
			return fmt.Errorf("cbtdata: lesson %s needs minutes in 1..120 (got %d)", slug, les.Minutes)
		}
		if len(les.Sections) == 0 {
			return fmt.Errorf("cbtdata: lesson %s ships zero sections", slug)
		}
		for i, sec := range les.Sections {
			if strings.TrimSpace(sec.Heading) == "" {
				return fmt.Errorf("cbtdata: lesson %s section %d has no heading", slug, i+1)
			}
			if len(sec.Blocks) == 0 {
				return fmt.Errorf("cbtdata: lesson %s section %q has no content blocks", slug, sec.Heading)
			}
			for j, b := range sec.Blocks {
				switch b.Type {
				case "p", "callout", "h3":
					if strings.TrimSpace(b.Text) == "" {
						return fmt.Errorf("cbtdata: lesson %s section %q block %d (%s) is empty",
							slug, sec.Heading, j+1, b.Type)
					}
				case "ul", "ol":
					if len(b.Items) == 0 {
						return fmt.Errorf("cbtdata: lesson %s section %q block %d (%s) has no items",
							slug, sec.Heading, j+1, b.Type)
					}
					for k, it := range b.Items {
						if strings.TrimSpace(it) == "" {
							return fmt.Errorf("cbtdata: lesson %s section %q block %d item %d is empty",
								slug, sec.Heading, j+1, k+1)
						}
					}
				default:
					return fmt.Errorf("cbtdata: lesson %s section %q block %d has unknown type %q",
						slug, sec.Heading, j+1, b.Type)
				}
			}
		}
		if _, dup := l.lessons[slug]; dup {
			return fmt.Errorf("cbtdata: lesson slug %s appears twice", slug)
		}
		l.lessons[slug] = &les
		l.lessonOrder = append(l.lessonOrder, slug)
	}
	sort.Strings(l.lessonOrder)
	return nil
}

// Lessons lists every lesson in stable (sorted) order.
func (l *Library) Lessons() []LessonMeta {
	out := make([]LessonMeta, 0, len(l.lessonOrder))
	for _, slug := range l.lessonOrder {
		les := l.lessons[slug]
		out = append(out, LessonMeta{
			Slug:    les.Slug,
			Title:   les.Title,
			Subject: les.Subject,
			Body:    les.Body,
			Tags:    les.Tags,
			Minutes: les.Minutes,
			Summary: les.Summary,
		})
	}
	return out
}

// Lesson finds one lesson with its full sections.
func (l *Library) Lesson(slug string) (*Lesson, bool) {
	les, ok := l.lessons[slug]
	return les, ok
}
