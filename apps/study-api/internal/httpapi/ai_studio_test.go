package httpapi

import (
        "strings"
        "testing"
)

func TestSlugifyAndShareSlug(t *testing.T) {
        cases := map[string]string{
                "JAMB Biology: Cells & Respiration": "jamb-biology-cells-respiration",
                "  Photosynthesis  Quiz!! ":         "photosynthesis-quiz",
                "???":                              "quiz",
        }
        for in, want := range cases {
                if got := slugify(in); got != want {
                        t.Fatalf("slugify(%q) = %q, want %q", in, got, want)
                }
        }
        slug := quizShareSlug("JAMB Biology Cells")
        if !strings.HasPrefix(slug, "jamb-biology-cells-") || len(slug) != len("jamb-biology-cells-")+4 {
                t.Fatalf("share slug malformed: %q", slug)
        }
        if quizShareSlug("same title") == quizShareSlug("same title") {
                t.Fatal("two quizzes with the same title must never share a slug")
        }
}

func TestSplitKeywordsAndContainsAll(t *testing.T) {
        kw := splitKeywords("Please give me past questions on Photosynthesis in jamb")
        // filler + exam names drop, the subject word survives
        if len(kw) != 1 || kw[0] != "photosynthesis" {
                t.Fatalf("keywords = %v", kw)
        }
        if !containsAll("the process of photosynthesis in leaves", kw) {
                t.Fatal("containsAll should match")
        }
        if containsAll("respiration and breathing", kw) {
                t.Fatal("containsAll should not match")
        }
        if got := splitKeywords(""); len(got) != 0 {
                t.Fatalf("empty query should give no keywords, got %v", got)
        }
}

func bridgeIDs(qs []BridgeQuestion) []string {
        out := make([]string, len(qs))
        for i, q := range qs {
                out[i] = q.ID
        }
        return out
}

// TestMergeGroupMatches pins the grounding merge rules: round-robin
// across topics, loose top-up only when the strict harvest is thin, and
// a clean nil when nothing matched at all (founder directive
// 2026-10-02: the AI must reach every topic's past questions).
func TestMergeGroupMatches(t *testing.T) {
        mk := func(id string) BridgeQuestion { return BridgeQuestion{ID: id, Stem: "s " + id} }

        // Two topics with plenty of strict matches: round-robin spreads them.
        strict := [][]BridgeQuestion{
                {mk("a1"), mk("a2"), mk("a3"), mk("a4")},
                {mk("b1"), mk("b2")},
        }
        got := mergeGroupMatches(strict, nil, 6)
        want := []string{"a1", "b1", "a2", "b2", "a3", "a4"}
        if len(got) != len(want) {
                t.Fatalf("want %d merged, got %v", len(want), bridgeIDs(got))
        }
        for i := range want {
                if got[i].ID != want[i] {
                        t.Fatalf("merge order = %v, want %v", bridgeIDs(got), want)
                }
        }

        // Thin strict harvest tops up from loose candidates, best hits first.
        strict = [][]BridgeQuestion{{mk("a1")}}
        loose := []looseMatch{
                {q: mk("l1"), hits: 1},
                {q: mk("l2"), hits: 3},
                {q: mk("l3"), hits: 2},
        }
        got = mergeGroupMatches(strict, loose, 4)
        if ids := bridgeIDs(got); len(ids) != 4 || ids[0] != "a1" || ids[1] != "l2" || ids[2] != "l3" || ids[3] != "l1" {
                t.Fatalf("thin merge = %v", ids)
        }

        // A healthy strict harvest ignores loose noise entirely.
        strict = [][]BridgeQuestion{{mk("a1"), mk("a2"), mk("a3")}}
        got = mergeGroupMatches(strict, []looseMatch{{q: mk("l1"), hits: 9}}, 6)
        if ids := bridgeIDs(got); len(ids) != 3 {
                t.Fatalf("strict-only merge should stay at 3, got %v", ids)
        }

        // Nothing at all -> nil.
        if got := mergeGroupMatches(nil, nil, 6); got != nil {
                t.Fatalf("empty merge should be nil, got %v", bridgeIDs(got))
        }
}

func TestExtractJSONObject(t *testing.T) {
        raw := "Sure, here it is:\n```json\n" + `{"title":"Cell note","summary":"ok","sections":[{"heading":"H","body":"B"}]}` + "\n```"
        var dst struct {
                Title    string `json:"title"`
                Summary  string `json:"summary"`
                Sections []struct {
                        Heading string `json:"heading"`
                        Body    string `json:"body"`
                } `json:"sections"`
        }
        if err := extractJSONObject(raw, &dst); err != nil {
                t.Fatalf("extractJSONObject: %v", err)
        }
        if dst.Title != "Cell note" || len(dst.Sections) != 1 {
                t.Fatalf("decoded wrong: %+v", dst)
        }
        if err := extractJSONObject("no object here", &dst); err == nil {
                t.Fatal("want error for reply without object")
        }
        // nested braces inside strings must not break the scan
        nested := `{"title":"a {b} c","summary":"x"}`
        if err := extractJSONObject(nested, &dst); err != nil {
                t.Fatalf("nested braces in strings broke the scan: %v", err)
        }
        if dst.Title != "a {b} c" {
                t.Fatalf("string with braces decoded wrong: %+v", dst)
        }
}

func TestStudioHelpers(t *testing.T) {
        topics := cleanTopics([]string{" Cells ", "", "cells", "Respiration", "a topic name that is far too long to be real and definitely goes past the ninety character limit we enforce"}, 6)
        if len(topics) != 2 || topics[0] != "Cells" || topics[1] != "Respiration" {
                t.Fatalf("cleanTopics = %v", topics)
        }
        if cleanTopics(nil, 6) != nil && len(cleanTopics(nil, 6)) != 0 {
                t.Fatal("empty input should give empty output")
        }
        if normalizeDifficulty("easy") != "Medium" || normalizeDifficulty("Hard") != "Hard" {
                t.Fatal("difficulty normalization broken")
        }
        if normalizeExamBody("jamb") != "JAMB" || normalizeExamBody("POST UTME") != "POST-UTME" || normalizeExamBody("random") != "" {
                t.Fatal("exam body normalization broken")
        }
        if normalizeNoteTemplate("") != "detailed" || normalizeNoteTemplate("revision") != "revision" {
                t.Fatal("template normalization broken")
        }
        if got := titleFromContent("Please teach me photosynthesis and respiration today"); got != "Please teach me photosynthesis and respiration" {
                t.Fatalf("titleFromContent = %q", got)
        }
        if got := firstLine("First line\nsecond line"); got != "First line" {
                t.Fatalf("firstLine = %q", got)
        }
        if got := firstNonEmpty("", "  ", "third"); got != "third" {
                t.Fatalf("firstNonEmpty = %q", got)
        }
}

func TestChatThinkingTrace(t *testing.T) {
        if got := chatThinkingTrace(0); got != "Thought through the topic before answering." {
                t.Fatalf("trace(0) = %q", got)
        }
        if got := chatThinkingTrace(5); !strings.Contains(got, "5 past questions") {
                t.Fatalf("trace(5) = %q", got)
        }
}

func TestStudioPhases(t *testing.T) {
        p := studioPhases(0)
        if len(p) != 3 || p[0] != "Thinking" || p[2] != "Composing" {
                t.Fatalf("phases(0) = %v", p)
        }
        p = studioPhases(4)
        found := false
        for _, x := range p {
                if x == "Researching past questions" {
                        found = true
                }
        }
        if !found || len(p) != 4 {
                t.Fatalf("phases(4) = %v", p)
        }
}

func TestNoteSystemPromptCarriesGrounding(t *testing.T) {
        p := noteSystemPrompt("Photosynthesis", "Biology", "SSS 1", "detailed", "REAL past question text")
        for _, want := range []string{"Photosynthesis", "Biology", "SSS 1", "REAL past question text", "summary"} {
                if !strings.Contains(p, want) {
                        t.Fatalf("note prompt missing %q", want)
                }
        }
        lp := lessonSystemPrompt("Biology", "SSS 1", "Cell division", "First Term", 40)
        for _, want := range []string{"Biology", "SSS 1", "Cell division", "First Term", "40 minutes", "objectives"} {
                if !strings.Contains(lp, want) {
                        t.Fatalf("lesson prompt missing %q", want)
                }
        }
        np := notebookSystemPrompt("Biology", "SSS 1", []string{"Cells", "Genetics"}, "")
        for _, want := range []string{"Cells; Genetics", "topicNotes", "glossary", "studyPlan"} {
                if !strings.Contains(np, want) {
                        t.Fatalf("notebook prompt missing %q", want)
                }
        }
}
