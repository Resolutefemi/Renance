package cbtdata

// Composite UTME mock papers (the "Standard UTME Mock" flow).
//
// A mock paper is a pure function of its CODE: the student picks
// English + 3 subjects on the setup screen, the web client builds the
// canonical code (jamb-mock-english-<slug>-<slug>-<slug>) and the
// server composes the same paper for that code every time — on any
// host, after any restart. That determinism is what keeps grading,
// review and resume honest without persisting composite bundles.
//
// Doctrine stays intact: composed papers never live in the manifest,
// never carry answer material, and their sealed keys are assembled
// from the banks' own keys at composition time (httpapi layer).

import (
        "crypto/sha256"
        "encoding/binary"
        "fmt"
        "sort"
        "strings"
)

// MockPaperPrefix marks every composite UTME paper code.
const MockPaperPrefix = "jamb-mock-"

// PaperSection groups one paper's questions under a subject so the
// client can render subject tabs exactly like the real CBT player.
type PaperSection struct {
        Subject     string   `json:"subject"`
        QuestionIDs []string `json:"questionIds"`
}

// IsMockPaperCode reports whether code names a composite mock paper.
func IsMockPaperCode(code string) bool {
        return strings.HasPrefix(code, MockPaperPrefix) && len(code) > len(MockPaperPrefix)
}

// mockCap mirrors the real UTME shape: 60 Use of English questions,
// 40 for every other subject (180 total when the banks are full).
func mockCap(slug string) int {
        if slug == "english" {
                return 60
        }
        return 40
}

// SubjectTitle maps a bank slug to its exam-face name.
func SubjectTitle(slug string) string {
        if t, ok := subjectTitles[slug]; ok {
                return t
        }
        return strings.Title(strings.ReplaceAll(slug, "-", " "))
}

var subjectTitles = map[string]string{
        "english":            "Use of English",
        "mathematics":        "Mathematics",
        "physics":            "Physics",
        "chemistry":          "Chemistry",
        "biology":            "Biology",
        "economics":          "Economics",
        "government":         "Government",
        "geography":          "Geography",
        "literature":         "Literature in English",
        "crs":                "Christian Religious Studies",
        "irs":                "Islamic Religious Studies",
        "agricultural-science": "Agricultural Science",
        "commerce":           "Commerce",
        "accounting":         "Principles of Accounts",
        "computer-studies":   "Computer Studies",
        "civic-education":    "Civic Education",
        "history":            "History",
        "french":             "French",
        "arabic":             "Arabic",
        "hausa":              "Hausa",
        "igbo":               "Igbo",
        "yoruba":             "Yoruba",
        "music":              "Music",
        "fine-arts":          "Fine Arts",
}

// bankSlugs lists every subject that ships a bank pack (jamb-<slug>-bank
// in the manifest), sorted for determinism.
func (l *Library) bankSlugs() []string {
        slugs := []string{}
        for _, ex := range l.manifest.Exams {
                if strings.HasPrefix(ex.Code, "jamb-") && strings.HasSuffix(ex.Code, "-bank") {
                        slugs = append(slugs, strings.TrimSuffix(strings.TrimPrefix(ex.Code, "jamb-"), "-bank"))
                }
        }
        sort.Strings(slugs)
        return slugs
}

// MockPaperSubjects segments a mock paper code into its subject slugs
// (word-break over the bank slug dictionary). The result is canonical:
// Use of English first, the rest sorted, no duplicates, at least two
// subjects — anything else is not a paper the server will seat.
func (l *Library) MockPaperSubjects(code string) ([]string, bool) {
        if !IsMockPaperCode(code) {
                return nil, false
        }
        dict := map[string]struct{}{}
        for _, s := range l.bankSlugs() {
                dict[s] = struct{}{}
        }
        rest := strings.TrimPrefix(code, MockPaperPrefix)
        segs, ok := segmentSlugs(rest, dict)
        if !ok {
                return nil, false
        }
        if len(segs) < 2 || segs[0] != "english" {
                return nil, false
        }
        seen := map[string]struct{}{}
        for _, s := range segs {
                if _, dup := seen[s]; dup {
                        return nil, false
                }
                seen[s] = struct{}{}
        }
        others := append([]string(nil), segs[1:]...)
        sort.Strings(others)
        canonical := append([]string{"english"}, others...)
        if MockPaperPrefix+strings.Join(canonical, "-") != code {
                return nil, false // non-canonical order: the client must not seat it
        }
        return canonical, true
}

// segmentSlugs splits the dash-joined code tail into dictionary slugs.
// It works on dash-separated tokens so multi-word slugs (e.g.
// "financial-accounting") segment exactly like single-word ones.
func segmentSlugs(s string, dict map[string]struct{}) ([]string, bool) {
        tokens := strings.Split(s, "-")
        memo := map[int][]string{}
        var rec func(pos int) ([]string, bool)
        rec = func(pos int) ([]string, bool) {
                if pos == len(tokens) {
                        return []string{}, true
                }
                if v, ok := memo[pos]; ok {
                        return v, v != nil
                }
                for end := pos + 1; end <= len(tokens); end++ {
                        cand := strings.Join(tokens[pos:end], "-")
                        if _, ok := dict[cand]; !ok {
                                continue
                        }
                        rest, ok := rec(end)
                        if ok {
                                out := append([]string{cand}, rest...)
                                memo[pos] = out
                                return out, true
                        }
                }
                memo[pos] = nil
                return nil, false
        }
        out, ok := rec(0)
        return out, ok
}

// ComposeMockPaper builds the composite bundle for a canonical mock
// code from the subject banks. Deterministic: the same code always
// yields the same question walk, so grading, review and resume all see
// exactly the paper the attempt was created with.
func ComposeMockPaper(code string, subjects []string, banks map[string]*Bundle) (*Bundle, error) {
        if !IsMockPaperCode(code) {
                return nil, fmt.Errorf("cbtdata: %q is not a mock paper code", code)
        }
        if len(subjects) < 2 || subjects[0] != "english" {
                return nil, fmt.Errorf("cbtdata: mock paper %q must be Use of English plus at least one subject", code)
        }
        seed := sha256.Sum256([]byte("jamb-mock|" + code))
        rng := uint64(binary.BigEndian.Uint64(seed[:8]))

        paper := &Bundle{
                Code:      code,
                Version:   1,
                Category:  "secondary",
                Body:      "JAMB",
                Sections:  make([]PaperSection, 0, len(subjects)),
                Questions: []Question{},
        }
        titles := make([]string, 0, len(subjects))
        for _, slug := range subjects {
                bank, ok := banks[slug]
                if !ok || bank == nil {
                        return nil, fmt.Errorf("cbtdata: mock paper %q needs bank jamb-%s-bank, which is not loaded", code, slug)
                }
                titles = append(titles, SubjectTitle(slug))
                order := len(bank.Questions)
                idx := make([]int, order)
                for i := range idx {
                        idx[i] = i
                }
                for i := order - 1; i > 0; i-- { // seeded Fisher-Yates over the bank
                        rng = splitMix64(rng)
                        j := int(rng % uint64(i+1))
                        idx[i], idx[j] = idx[j], idx[i]
                }
                take := mockCap(slug)
                if take > order {
                        take = order
                }
                section := PaperSection{Subject: SubjectTitle(slug), QuestionIDs: make([]string, 0, take)}
                for _, i := range idx[:take] {
                        q := bank.Questions[i]
                        paper.Questions = append(paper.Questions, q)
                        section.QuestionIDs = append(section.QuestionIDs, q.ID)
                }
                paper.Sections = append(paper.Sections, section)
        }
        for _, q := range paper.Questions {
                paper.TotalMarks += q.Marks
        }
        dur := 120 // official UTME timing: 2 hours
        paper.DurationMinutes = &dur
        paper.QuestionCount = len(paper.Questions)
        paper.Title = "UTME Mock · " + strings.Join(titles, " + ")
        if paper.QuestionCount == 0 {
                return nil, fmt.Errorf("cbtdata: mock paper %q composed to zero questions", code)
        }
        return paper, nil
}

// splitMix64 is the deterministic PRNG behind the seeded walk. Kept
// local (internal/daily imports this package, so the dependency only
// flows one way); the constants are the standard splitmix64 ones, so
// the sequence matches any independent implementation.
func splitMix64(x uint64) uint64 {
        x += 0x9e3779b97f4a7c15
        z := x
        z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) * 0x94d049bb133111eb
        return z ^ (z >> 31)
}
