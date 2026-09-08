package cbtdata

// Composite paper composition (mock, custom, pick).
//
// A paper is a pure function of its CODE: the client builds a canonical
// code, the server composes the same paper for that code every time —
// on any host, after any restart. That determinism keeps grading,
// review and resume honest without persisting composite bundles.
//
// The 2026 grammar (papercode.go) adds per-subject year pinning, an
// English comprehension split and the custom/pick families. Doctrine
// stays intact: composed papers never live in the manifest, never carry
// answer material, and their sealed keys are assembled from the banks'
// own keys at composition time (httpapi layer).

import (
        "crypto/sha256"
        "encoding/binary"
        "fmt"
        "strings"
)

// MockPaperPrefix marks every composite UTME paper code (v1 codes and
// the extended ~params form alike).
const MockPaperPrefix = "jamb-mock-"

// PaperSection groups one paper's questions under a subject so the
// client can render subject tabs exactly like the real CBT player.
type PaperSection struct {
        Subject     string   `json:"subject"`
        QuestionIDs []string `json:"questionIds"`
}

// mockCap mirrors the real UTME shape: 60 Use of English questions,
// 40 for every other subject (180 total when the banks are full).
func mockCap(slug string) int {
        if slug == "english" {
                return defaultMockEnglish
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
        "english":                 "Use of English",
        "mathematics":             "Mathematics",
        "further-mathematics":     "Further Mathematics",
        "physics":                 "Physics",
        "chemistry":               "Chemistry",
        "biology":                 "Biology",
        "economics":               "Economics",
        "government":              "Government",
        "geography":               "Geography",
        "literature":              "Literature in English",
        "crs":                     "Christian Religious Studies",
        "irs":                     "Islamic Religious Studies",
        "agricultural-science":    "Agricultural Science",
        "animal-husbandry":        "Animal Husbandry",
        "commerce":                "Commerce",
        "accounting":              "Principles of Accounts",
        "book-keeping":            "Book Keeping",
        "computer-studies":        "Computer Studies",
        "data-processing":         "Data Processing",
        "civic-education":         "Civic Education",
        "insurance":               "Insurance",
        "history":                 "History",
        "french":                  "French",
        "arabic":                  "Arabic",
        "hausa":                   "Hausa",
        "igbo":                    "Igbo",
        "yoruba":                  "Yoruba",
        "music":                   "Music",
        "fine-arts":               "Fine Arts",
        "home-economics":          "Home Economics",
        "food-and-nutrition":      "Food and Nutrition",
        "home-management":         "Home Management",
        "catering-craft-practice": "Catering Craft Practice",
        "physical-education":      "Physical Education",
        "health-education":        "Health Education",
        "office-practice":         "Office Practice",
        "technical-drawing":       "Technical Drawing",
        "marketing":               "Marketing",
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
        sortStrings(slugs)
        return slugs
}

// MockPaperSubjects segments a mock paper code into its subject slugs.
// The result is canonical: Use of English first, the rest sorted, no
// duplicates, at least two subjects.
func (l *Library) MockPaperSubjects(code string) ([]string, bool) {
        if !IsMockPaperCode(code) {
                return nil, false
        }
        dict := map[string]struct{}{}
        for _, s := range l.bankSlugs() {
                dict[s] = struct{}{}
        }
        spec, err := ParsePaperCode(code, dict)
        if err != nil {
                return nil, false
        }
        return spec.Subjects, true
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

// mcqOnly filters a bank pool down to auto-gradable objective questions:
// theory items ride their own packs and never enter a CBT paper.
func mcqOnly(qs []Question) []Question {
        out := make([]Question, 0, len(qs))
        for _, q := range qs {
                if q.Type == "theory" {
                        continue
                }
                out = append(out, q)
        }
        return out
}

// yearPool filters a pool to one exam year (0 = no filter).
func yearPool(qs []Question, year int) []Question {
        if year == 0 {
                return qs
        }
        out := make([]Question, 0, len(qs))
        for _, q := range qs {
                if q.Year == year {
                        out = append(out, q)
                }
        }
        return out
}

// paperRNG seeds the deterministic walk from the full code.
func paperRNG(code string) uint64 {
        seed := sha256.Sum256([]byte("jamb-mock|" + code))
        return binary.BigEndian.Uint64(seed[:8])
}

// shuffledIndex returns a seeded Fisher-Yates permutation of [0..n).
func shuffledIndex(n int, rng *uint64) []int {
        idx := make([]int, n)
        for i := range idx {
                idx[i] = i
        }
        for i := n - 1; i > 0; i-- {
                *rng = splitMix64(*rng)
                j := int(*rng % uint64(i+1))
                idx[i], idx[j] = idx[j], idx[i]
        }
        return idx
}

// takeShuffled draws up to `take` questions from pool deterministically.
func takeShuffled(pool []Question, take int, rng *uint64) []Question {
        if take > len(pool) {
                take = len(pool)
        }
        idx := shuffledIndex(len(pool), rng)
        out := make([]Question, 0, take)
        for _, i := range idx[:take] {
                out = append(out, pool[i])
        }
        return out
}

// englishSplit divides an English pool into the comprehension, novel
// and rest groups, honouring the comp/compN/nov options. It returns the
// questions the English section should walk (already capped) or an
// error when the section would come out empty. Novel questions (when
// opted in) are seated first, then comprehension, then the rest — the
// backfill logic still guarantees the section never comes up short.
func englishSplit(pool []Question, rng *uint64, total int, comp bool, compN int, novel bool) ([]Question, error) {
        var compQ, novelQ, restQ []Question
        for _, q := range pool {
                switch q.Group {
                case "comprehension":
                        compQ = append(compQ, q)
                case "novel":
                        novelQ = append(novelQ, q)
                default:
                        restQ = append(restQ, q)
                }
        }
        if comp && compN > len(compQ) {
                compN = len(compQ) // clamp: never invent passages
        }
        if !comp {
                compN = 0
        }
        novelN := defaultNovelN
        if novelN > len(novelQ) {
                novelN = len(novelQ) // clamp: never invent novel questions
        }
        if !novel {
                novelN = 0
        }
        if total > len(compQ)+len(novelQ)+len(restQ) {
                total = len(compQ) + len(novelQ) + len(restQ)
        }
        if total <= 0 {
                return nil, fmt.Errorf("english section has no questions")
        }
        // comp=0 with a comprehension-only pool is still answerable from the
        // rest pool only — surface the shortfall loudly instead.
        if !comp && !novel && len(restQ) == 0 {
                return nil, fmt.Errorf("comprehension excluded but the bank has no other English questions")
        }
        // Seat the opted-in special groups first (novel, then
        // comprehension), top up from the rest pool; if the rest pool
        // runs dry, backfill from whatever special-group questions the
        // section has not used yet.
        novelN = minInt(novelN, total)
        compN = minInt(compN, total-novelN)
        var out []Question
        used := map[string]struct{}{}
        seat := func(src []Question, n int) {
                for _, q := range takeShuffled(src, n, rng) {
                        out = append(out, q)
                        used[q.ID] = struct{}{}
                }
        }
        seat(novelQ, novelN)
        seat(compQ, compN)
        if need := total - len(out); need > 0 {
                seat(restQ, need)
        }
        if len(out) < total {
                // rest pool exhausted: backfill from the special groups
                extra := takeShuffled(append(append([]Question{}, novelQ...), compQ...), len(novelQ)+len(compQ), rng)
                for _, q := range extra {
                        if len(out) >= total {
                                break
                        }
                        if _, dup := used[q.ID]; dup {
                                continue
                        }
                        out = append(out, q)
                        used[q.ID] = struct{}{}
                }
        }
        return out, nil
}

func minInt(a, b int) int {
        if a < b {
                return a
        }
        return b
}

// ComposePaper builds the composite bundle for a parsed mock/custom
// spec from the subject banks. Deterministic per code + bank data.
func ComposePaper(spec *PaperSpec, banks map[string]*Bundle) (*Bundle, error) {
        if spec.Family != PaperFamilyMock && spec.Family != PaperFamilyCustom {
                return nil, fmt.Errorf("cbtdata: ComposePaper handles mock/custom only, got %q", spec.Family)
        }
        subjects := spec.Subjects
        rng := paperRNG(spec.Encode())

        // Custom distribution: n spread evenly, remainder to the earlier
        // subjects in canonical order.
        share := map[string]int{}
        if spec.Family == PaperFamilyCustom {
                n := spec.N
                if n <= 0 {
                        n = 40
                }
                base := n / len(subjects)
                rem := n % len(subjects)
                for i, s := range subjects {
                        share[s] = base
                        if i < rem {
                                share[s]++
                        }
                }
        }

        paper := &Bundle{
                Code:      spec.Encode(),
                Version:   1,
                Category:  "secondary",
                Body:      "JAMB",
                Sections:  make([]PaperSection, 0, len(subjects)),
                Questions: []Question{},
        }
        titles := make([]string, 0, len(subjects))
        for i, slug := range subjects {
                bank, ok := banks[slug]
                if !ok || bank == nil {
                        return nil, fmt.Errorf("cbtdata: paper %q needs bank jamb-%s-bank, which is not loaded", paper.Code, slug)
                }
                titles = append(titles, SubjectTitle(slug))
                year := 0
                if spec.Years != nil && i < len(spec.Years) {
                        year = spec.Years[i]
                }
                pool := yearPool(mcqOnly(bank.Questions), year)

                var take int
                if spec.Family == PaperFamilyMock {
                        take = mockCap(slug)
                        if slug == "english" && spec.EnN > 0 {
                                take = spec.EnN
                        }
                } else {
                        take = share[slug]
                }

                var section []Question
                var err error
                if slug == "english" {
                        section, err = englishSplit(pool, &rng, take, spec.Comp, spec.CompN, spec.Novel)
                        if err != nil {
                                return nil, fmt.Errorf("cbtdata: paper %q english section: %w", paper.Code, err)
                        }
                } else {
                        if take > len(pool) {
                                take = len(pool)
                        }
                        section = takeShuffled(pool, take, &rng)
                }
                sec := PaperSection{Subject: SubjectTitle(slug), QuestionIDs: make([]string, 0, len(section))}
                for _, q := range section {
                        paper.Questions = append(paper.Questions, q)
                        sec.QuestionIDs = append(sec.QuestionIDs, q.ID)
                }
                paper.Sections = append(paper.Sections, sec)
        }
        for _, q := range paper.Questions {
                paper.TotalMarks += q.Marks
        }
        if spec.Family == PaperFamilyMock {
                dur := spec.Timer
                if dur == 0 {
                        dur = defaultMockTimer
                }
                paper.DurationMinutes = &dur
        } else if spec.Timer > 0 {
                dur := spec.Timer
                paper.DurationMinutes = &dur
        } // custom without t: nil = untimed (count-up clock)
        paper.QuestionCount = len(paper.Questions)
        label := "UTME Mock"
        if spec.Family == PaperFamilyCustom {
                label = "Custom Practice"
        }
        paper.Title = label + " · " + strings.Join(titles, " + ")
        if paper.QuestionCount == 0 {
                return nil, fmt.Errorf("cbtdata: paper %q composed to zero questions", paper.Code)
        }
        return paper, nil
}

// ComposePickPaper carves a practice subset from one static pack.
// Deterministic per code + pack data; theory items never enter.
func ComposePickPaper(spec *PaperSpec, base *Bundle) (*Bundle, error) {
        if spec.Family != PaperFamilyPick {
                return nil, fmt.Errorf("cbtdata: ComposePickPaper handles pick only, got %q", spec.Family)
        }
        year := 0
        if len(spec.Years) == 1 {
                year = spec.Years[0]
        }
        pool := yearPool(mcqOnly(base.Questions), year)
        if len(pool) == 0 {
                if year != 0 {
                        return nil, fmt.Errorf("cbtdata: %s has no objective questions for %d", base.Code, year)
                }
                return nil, fmt.Errorf("cbtdata: %s has no objective questions", base.Code)
        }
        n := spec.N
        if n <= 0 {
                n = 40
        }
        rng := paperRNG(spec.Encode())
        picked := takeShuffled(pool, n, &rng)

        paper := &Bundle{
                Code:      spec.Encode(),
                Title:     base.Title,
                Version:   1,
                Category:  base.Category,
                Body:      base.Body,
                Questions: append([]Question{}, picked...),
        }
        if year != 0 {
                paper.Title = fmt.Sprintf("%s · %d Practice", strings.TrimSuffix(base.Title, " Bank"), year)
        } else {
                paper.Title = base.Title + " · Practice Set"
        }
        if base.DurationMinutes != nil && spec.Timer == 0 {
                // the base pack's own timing carries over when no override given
                dur := *base.DurationMinutes
                paper.DurationMinutes = &dur
        }
        if spec.Timer > 0 {
                dur := spec.Timer
                paper.DurationMinutes = &dur
        }
        for _, q := range paper.Questions {
                paper.TotalMarks += q.Marks
        }
        paper.QuestionCount = len(paper.Questions)
        return paper, nil
}
