package lessonmd

import (
	"strings"
	"testing"
)

const fullSource = `---
slug: photosynthesis
title: Photosynthesis — How Plants Make Food
subject: Biology
body: JAMB
tags: [plants, energy]
minutes: 6
summary: The light and dark reactions, in exam-ready language.
---

## What photosynthesis does

Green plants build glucose from carbon dioxide and
water using light energy trapped by chlorophyll.

- Raw materials: carbon dioxide and water
- Products: glucose and oxygen

## The two stages

### Light reaction

Happens in the grana; light splits water.

> Key point: without light there is no split, so no oxygen.

### Dark reaction

1. Carbon dioxide is fixed
2. Glucose is assembled
`

func TestParseFullLesson(t *testing.T) {
	les, err := Parse([]byte(fullSource))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if les.Slug != "photosynthesis" || les.Title == "" || les.Minutes != 6 {
		t.Fatalf("meta = %+v", les)
	}
	if len(les.Tags) != 2 || les.Tags[0] != "plants" {
		t.Fatalf("tags = %v", les.Tags)
	}
	if len(les.Sections) != 2 {
		t.Fatalf("sections = %d", len(les.Sections))
	}
	s0 := les.Sections[0]
	if s0.Heading != "What photosynthesis does" || len(s0.Blocks) != 2 {
		t.Fatalf("section0 = %+v", s0)
	}
	// soft-wrapped paragraph merges into one line
	if s0.Blocks[0].Type != "p" || strings.Contains(s0.Blocks[0].Text, "\n") {
		t.Fatalf("paragraph = %+v", s0.Blocks[0])
	}
	if s0.Blocks[1].Type != "ul" || len(s0.Blocks[1].Items) != 2 {
		t.Fatalf("bullets = %+v", s0.Blocks[1])
	}
	s1 := les.Sections[1]
	if s1.Blocks[0].Type != "h3" || s1.Blocks[0].Text != "Light reaction" {
		t.Fatalf("h3 = %+v", s1.Blocks[0])
	}
	if s1.Blocks[2].Type != "callout" || !strings.HasPrefix(s1.Blocks[2].Text, "Key point") {
		t.Fatalf("callout = %+v", s1.Blocks[2])
	}
	// last section ends with an ordered list
	last := s1.Blocks[len(s1.Blocks)-1]
	if last.Type != "ol" || len(last.Items) != 2 {
		t.Fatalf("ol = %+v", last)
	}
}

func TestParseRejectsRawHTML(t *testing.T) {
	src := strings.Replace(fullSource, "chlorophyll.", "<script>alert(1)</script> chlorophyll.", 1)
	if _, err := Parse([]byte(src)); err == nil || !strings.Contains(err.Error(), "HTML") {
		t.Fatalf("expected HTML refusal, got %v", err)
	}
}

func TestParseRejectsCodeFences(t *testing.T) {
	src := strings.Replace(fullSource, "Happens in the grana;", "```\ndrop table\n```", 1)
	if _, err := Parse([]byte(src)); err == nil {
		t.Fatal("code fences must be refused")
	}
}

func TestParseRejectsUnknownFrontMatter(t *testing.T) {
	src := strings.Replace(fullSource, "minutes: 6", "minutes: 6\nmonkey: patch", 1)
	if _, err := Parse([]byte(src)); err == nil {
		t.Fatal("unknown front-matter keys must be refused")
	}
}

func TestParseRequiresSections(t *testing.T) {
	noHeadings := strings.Replace(fullSource, "## What photosynthesis does", "Just prose, no heading", 1)
	noHeadings = strings.Replace(noHeadings, "## The two stages", "More prose, still no heading", 1)
	if _, err := Parse([]byte(noHeadings)); err == nil || !strings.Contains(err.Error(), "##") {
		t.Fatalf("expected section-required error, got %v", err)
	}
}

func TestParseRejectsBadSlugs(t *testing.T) {
	src := strings.Replace(fullSource, "slug: photosynthesis", "slug: Photosynthesis Rulez", 1)
	if _, err := Parse([]byte(src)); err == nil {
		t.Fatal("bad slug must be refused")
	}
}

func TestEncodeJSONDoesNotEscape(t *testing.T) {
	les, err := Parse([]byte(fullSource))
	if err != nil {
		t.Fatal(err)
	}
	les.Summary = "The light & dark reactions — exam ready <3"
	raw, err := EncodeJSON(les)
	if err != nil {
		t.Fatal(err)
	}
	s := string(raw)
	if strings.Contains(s, "&amp;") || strings.Contains(s, "\\u003c") || strings.Contains(s, "\\u2014") {
		t.Fatalf("HTML escaping crept in: %s", s)
	}
	if !strings.Contains(s, "The light & dark reactions — exam ready <3") {
		t.Fatalf("summary mangled: %s", s)
	}
}
