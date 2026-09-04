package main

// Lint rules: a Spec is buildable only when zero "error" issues remain.
// "warn" issues never block a build, they surface judgment calls.

import (
	"fmt"
	"regexp"
	"sort"
	"strings"

	"renance.dev/study-api/internal/cbtdata"
)

type Issue struct {
	Level string // "error" | "warn"
	Where string // "question 3" / "row 5" / "pack"
	Msg   string
}

var codeRe = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)

// lintSpec validates one Spec. syllabus is the body's topic set
// (nil when no tree is shipped): when present, every non-empty topic
// must be a node of that tree, the same join cbtdata enforces at boot.
func lintSpec(s *Spec, syllabus map[string]struct{}) []Issue {
	var iss []Issue
	err := func(where, format string, a ...any) {
		iss = append(iss, Issue{Level: "error", Where: where, Msg: fmt.Sprintf(format, a...)})
	}
	warn := func(where, format string, a ...any) {
		iss = append(iss, Issue{Level: "warn", Where: where, Msg: fmt.Sprintf(format, a...)})
	}

	if !codeRe.MatchString(s.Code) {
		err("pack", "code %q must be lowercase kebab-case (letters/digits/hyphens)", s.Code)
	}
	if s.Title == "" {
		err("pack", "title is required")
	}
	if s.DurationMinutes != nil && (*s.DurationMinutes < 1 || *s.DurationMinutes > 360) {
		err("pack", "durationMinutes %d outside 1..360", *s.DurationMinutes)
	}
	if len(s.Questions) == 0 {
		err("pack", "no questions found")
		return iss
	}

	seenStems := map[string]int{}
	for i, q := range s.Questions {
		where := fmt.Sprintf("question %d", i+1)

		if q.Stem == "" {
			err(where, "stem is empty")
		} else if len(q.Stem) > 300 {
			warn(where, "stem is %d chars (readability: keep under 300)", len(q.Stem))
		}
		if prev, dup := seenStems[strings.ToLower(q.Stem)]; dup {
			warn(where, "duplicate stem (same as question %d)", prev+1)
		}
		seenStems[strings.ToLower(q.Stem)] = i

		// Options: ladder A,B,C.. with no gaps, at least 2, each non-empty.
		letters := make([]string, 0, len(q.Options))
		for l, t := range q.Options {
			if t == "" {
				err(where, "option %s is empty (drop the key or fill the text)", l)
			}
			letters = append(letters, l)
		}
		sort.Strings(letters)
		if len(letters) < 2 {
			err(where, "needs at least 2 options, has %d", len(letters))
		}
		for j, l := range letters {
			if want := string(rune('A' + j)); l != want {
				err(where, "option letters must form an unbroken ladder A,B,C...; found %q at position %d", l, j+1)
				break
			}
		}
		if len(letters) > 8 {
			err(where, "at most 8 options (A-H), has %d", len(letters))
		}

		if len(q.Answer) != 1 || q.Answer < "A" || q.Answer > "H" {
			err(where, "answer %q is not a single option letter", q.Answer)
		} else if _, ok := q.Options[q.Answer]; !ok {
			err(where, "answer %q is not one of the provided options", q.Answer)
		}

		if q.Marks < 1 {
			err(where, "marks %d must be >= 1", q.Marks)
		}
		switch q.Difficulty {
		case "", "easy", "medium", "hard":
		default:
			err(where, "difficulty %q must be easy|medium|hard (or empty)", q.Difficulty)
		}
		if q.Topic == "" {
			warn(where, "no topic — results screens group weak topics by it")
		} else if syllabus != nil {
			if _, ok := syllabus[q.Topic]; !ok {
				err(where, "topic %q is not in the %s syllabus tree (data/syllabus/%s.json)", q.Topic, s.Body, cbtdata.Slug(s.Body))
			}
		}
		if q.Explanation == "" {
			warn(where, "no explanation in the key — review mode is thinner without it")
		}
	}
	return iss
}
