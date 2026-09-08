package cbtdata

import (
	"strings"
	"testing"
)

// loadRealLibrary boots the committed data dir (banks included).
func loadRealLibrary(t *testing.T) *Library {
	t.Helper()
	lib, err := Load("../../../../data")
	if err != nil {
		t.Fatalf("Load(real data): %v", err)
	}
	return lib
}

func TestMockPaperCodeClassification(t *testing.T) {
	if !IsMockPaperCode("jamb-mock-english-mathematics-physics-biology") {
		t.Fatal("canonical code must classify as a mock paper")
	}
	// the params-aware grammar classifies extended codes too
	if !IsMockPaperCode("jamb-mock-english-mathematics-physics-biology~y=2024;r;2019;r") {
		t.Fatal("extended mock code must classify as a mock paper")
	}
	for _, code := range []string{"jamb-english-bank", "jamb-mock-", "jamb-mockish-english", ""} {
		if IsMockPaperCode(code) {
			t.Fatalf("%q must not classify as a mock paper", code)
		}
	}
	if !IsCustomPaperCode("jamb-custom-english-mathematics~n=40") {
		t.Fatal("custom code must classify")
	}
	if !IsPickPaperCode("jamb-pick-waec-biology-bank~n=40,y=2019") {
		t.Fatal("pick code must classify")
	}
	if !IsComposedPaperCode("jamb-custom-music~n=10") || IsComposedPaperCode("jamb-biology-bank") {
		t.Fatal("composed-family classification broken")
	}
}

func TestMockPaperSubjectsCanonical(t *testing.T) {
	lib := loadRealLibrary(t)
	cases := []struct {
		code string
		want []string
		ok   bool
	}{
		{"jamb-mock-english-biology-mathematics-physics", []string{"english", "biology", "mathematics", "physics"}, true},
		{"jamb-mock-english-chemistry-economics-geography", []string{"english", "chemistry", "economics", "geography"}, true},
		{"jamb-mock-english-biology-chemistry-mathematics", []string{"english", "biology", "chemistry", "mathematics"}, true},
		// multi-word slugs segment like single-word ones
		{"jamb-mock-english-agricultural-science-chemistry-physics", []string{"english", "agricultural-science", "chemistry", "physics"}, true},
		// non-canonical order (subjects unsorted): rejected
		{"jamb-mock-english-mathematics-physics-biology", nil, false},
		// english missing: rejected
		{"jamb-mock-biology-chemistry-physics", nil, false},
		// duplicate subject: rejected
		{"jamb-mock-english-biology-biology-physics", nil, false},
		// single subject: rejected
		{"jamb-mock-english", nil, false},
		// unknown subject: rejected
		{"jamb-mock-english-french-physics-biology", nil, false},
	}
	for _, c := range cases {
		got, ok := lib.MockPaperSubjects(c.code)
		if ok != c.ok {
			t.Errorf("%s: ok=%v, want %v", c.code, ok, c.ok)
			continue
		}
		if ok && len(got) != len(c.want) {
			t.Errorf("%s: subjects %v, want %v", c.code, got, c.want)
			continue
		}
		for i := range got {
			if got[i] != c.want[i] {
				t.Errorf("%s: subjects[%d]=%s, want %s", c.code, i, got[i], c.want[i])
			}
		}
	}
}

func TestParsePaperCodeGrammar(t *testing.T) {
	lib := loadRealLibrary(t)
	cases := []struct {
		code    string
		wantErr bool
		check   func(*PaperSpec) bool
	}{
		// plain v1 mock still parses
		{"jamb-mock-english-biology-mathematics-physics", false, func(s *PaperSpec) bool {
			return s.Family == PaperFamilyMock && len(s.Years) == 0 && s.Comp && s.CompN == 0 && s.Timer == 0
		}},
		// per-subject years, canonical all-random omitted
		{"jamb-mock-english-biology-mathematics-physics~y=2024;r;2019;r", false, func(s *PaperSpec) bool {
			return len(s.Years) == 4 && s.Years[0] == 2024 && s.Years[1] == 0 && s.Years[2] == 2019
		}},
		// single year applies to every subject
		{"jamb-mock-english-biology-mathematics-physics~y=2024", false, func(s *PaperSpec) bool {
			return s.Years[0] == 2024 && s.Years[3] == 2024
		}},
		// all-random y list is NOT canonical (must be omitted)
		{"jamb-mock-english-biology-mathematics-physics~y=r;r;r;r", true, nil},
		// y list length must match subject count
		{"jamb-mock-english-biology-mathematics-physics~y=r", true, nil},
		// English options
		{"jamb-mock-english-biology-mathematics-physics~comp=0", false, func(s *PaperSpec) bool {
			return !s.Comp
		}},
		{"jamb-mock-english-biology-mathematics-physics~compN=15", false, func(s *PaperSpec) bool {
			return s.CompN == 15
		}},
		{"jamb-mock-english-biology-mathematics-physics~enN=40", false, func(s *PaperSpec) bool {
			return s.EnN == 40
		}},
		// timer
		{"jamb-mock-english-biology-mathematics-physics~t=60", false, func(s *PaperSpec) bool {
			return s.Timer == 60
		}},
		// t=120 is the mock default: not canonical
		{"jamb-mock-english-biology-mathematics-physics~t=120", true, nil},
		// out of range
		{"jamb-mock-english-biology-mathematics-physics~y=1800;r;r;r", true, nil},
		{"jamb-mock-english-biology-mathematics-physics~enN=200", true, nil},
		// unknown param
		{"jamb-mock-english-biology-mathematics-physics~z=3", true, nil},
		// custom family
		{"jamb-custom-music~n=10", false, func(s *PaperSpec) bool {
			return s.Family == PaperFamilyCustom && s.N == 10 && s.Subjects[0] == "music"
		}},
		{"jamb-custom-agricultural-science-english-music~n=30.t=25", false, func(s *PaperSpec) bool {
			return s.N == 30 && s.Timer == 25 && len(s.Subjects) == 3
		}},
		// custom must be fully sorted
		{"jamb-custom-music-english~n=10", true, nil},
		// pick family
		{"jamb-pick-jamb-biology-bank~y=2019.n=40", false, func(s *PaperSpec) bool {
			return s.Family == PaperFamilyPick && s.Base == "jamb-biology-bank" && s.Years[0] == 2019 && s.N == 40
		}},
		{"jamb-pick-jamb-biology-bank", false, func(s *PaperSpec) bool {
			return s.Base == "jamb-biology-bank" && len(s.Years) == 0
		}},
		// pick of a composed paper: refused
		{"jamb-pick-jamb-mock-english-biology", true, nil},
		// composed y on pick is single-valued
		{"jamb-pick-jamb-biology-bank~y=2019.2020", true, nil},
	}
	for _, c := range cases {
		spec, err := lib.ParsePaper(c.code)
		if c.wantErr {
			if err == nil {
				t.Errorf("%s: expected error, got spec %+v", c.code, spec)
			}
			continue
		}
		if err != nil {
			t.Errorf("%s: unexpected error %v", c.code, err)
			continue
		}
		if spec.Encode() != c.code {
			t.Errorf("%s: re-encodes to %s", c.code, spec.Encode())
		}
		if c.check != nil && !c.check(spec) {
			t.Errorf("%s: spec check failed: %+v", c.code, spec)
		}
	}
}

func TestComposeMockPaperShape(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-mathematics-physics"
	spec, ok := lib.MockPaperSubjects(code)
	if !ok {
		t.Fatalf("canonical code rejected: %s", code)
	}
	parsed, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	_ = spec
	banks := map[string]*Bundle{}
	for _, slug := range parsed.Subjects {
		banks[slug] = mustBank(t, lib, slug)
	}
	paper, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper: %v", err)
	}
	if paper.Body != "JAMB" || paper.Category != "secondary" {
		t.Fatalf("paper body/category wrong: %+v", paper)
	}
	if paper.DurationMinutes == nil || *paper.DurationMinutes != 120 {
		t.Fatalf("mock paper must run the official 120 minutes")
	}
	if len(paper.Sections) != len(parsed.Subjects) {
		t.Fatalf("sections=%d, subjects=%d", len(paper.Sections), len(parsed.Subjects))
	}
	wantCounts := map[string]int{}
	for _, sec := range paper.Sections {
		wantCounts[sec.Subject] = len(sec.QuestionIDs)
	}
	if wantCounts["Use of English"] > 60 {
		t.Fatalf("english cap breached: %d", wantCounts["Use of English"])
	}
	if paper.QuestionCount != len(paper.Questions) {
		t.Fatalf("questionCount=%d, len=%d", paper.QuestionCount, len(paper.Questions))
	}
	ids := map[string]bool{}
	for _, q := range paper.Questions {
		if ids[q.ID] {
			t.Fatalf("duplicate question %s", q.ID)
		}
		ids[q.ID] = true
		if q.Type == "theory" {
			t.Fatal("theory question leaked into a CBT paper")
		}
	}
	covered := 0
	for _, sec := range paper.Sections {
		for _, id := range sec.QuestionIDs {
			if !ids[id] {
				t.Fatalf("section %s lists %s which is not in the walk", sec.Subject, id)
			}
			covered++
		}
	}
	if covered != paper.QuestionCount {
		t.Fatalf("sections cover %d, paper has %d", covered, paper.QuestionCount)
	}
	marks := 0
	for _, q := range paper.Questions {
		marks += q.Marks
	}
	if paper.TotalMarks != marks {
		t.Fatalf("totalMarks=%d, summed=%d", paper.TotalMarks, marks)
	}
}

func TestComposeMockPaperDeterministic(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-chemistry-economics-geography"
	parsed, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	banks := map[string]*Bundle{}
	for _, slug := range parsed.Subjects {
		banks[slug] = mustBank(t, lib, slug)
	}
	a, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("compose a: %v", err)
	}
	b, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("compose b: %v", err)
	}
	for i := range a.Questions {
		if a.Questions[i].ID != b.Questions[i].ID {
			t.Fatalf("walk diverges at %d: %s vs %s", i, a.Questions[i].ID, b.Questions[i].ID)
		}
	}
	// a different subject mix must produce a different paper
	code2 := "jamb-mock-english-chemistry-economics-government"
	parsed2, err := lib.ParsePaper(code2)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	for _, slug := range parsed2.Subjects {
		if _, ok := banks[slug]; !ok {
			banks[slug] = mustBank(t, lib, slug)
		}
	}
	c, err := ComposePaper(parsed2, banks)
	if err != nil {
		t.Fatalf("compose c: %v", err)
	}
	if c.Questions[0].ID == a.Questions[0].ID && c.Questions[len(c.Questions)-1].ID == a.Questions[len(a.Questions)-1].ID {
		t.Fatal("distinct codes should seed distinct walks (first and last ids equal: suspicious)")
	}
}

func TestComposePaperYearPinning(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-mathematics-physics~y=2024;r;2019;r"
	parsed, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	banks := map[string]*Bundle{}
	for _, slug := range parsed.Subjects {
		banks[slug] = mustBank(t, lib, slug)
	}
	paper, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper: %v", err)
	}
	// sections align with subjects: english (2024), biology (random),
	// mathematics (2019), physics (random)
	secBySubject := map[string]PaperSection{}
	for _, sec := range paper.Sections {
		secBySubject[sec.Subject] = sec
	}
	for _, q := range paper.Questions {
		switch {
		case containsID(secBySubject["Use of English"].QuestionIDs, q.ID):
			if q.Year != 2024 {
				t.Fatalf("english question %s year=%d, want 2024", q.ID, q.Year)
			}
		case containsID(secBySubject["Mathematics"].QuestionIDs, q.ID):
			if q.Year != 2019 {
				t.Fatalf("mathematics question %s year=%d, want 2019", q.ID, q.Year)
			}
		}
	}
	// year-pinned composition stays deterministic
	again, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("recompose: %v", err)
	}
	for i := range paper.Questions {
		if paper.Questions[i].ID != again.Questions[i].ID {
			t.Fatalf("year-pinned walk diverges at %d", i)
		}
	}
}

func TestComposePaperEnglishComprehension(t *testing.T) {
	lib := loadRealLibrary(t)
	banks := map[string]*Bundle{"english": mustBank(t, lib, "english")}

	// comp=0: no comprehension-group question survives
	code := "jamb-mock-english-mathematics-physics~comp=0"
	parsed, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	banks["mathematics"] = mustBank(t, lib, "mathematics")
	banks["physics"] = mustBank(t, lib, "physics")
	paper, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper comp=0: %v", err)
	}
	for _, q := range paper.Questions {
		if q.Group == "comprehension" {
			t.Fatal("comprehension question present with comp=0")
		}
	}

	// compN=5: exactly 5 comprehension questions in the English section
	code = "jamb-mock-english-mathematics-physics~compN=5"
	parsed, err = lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	paper, err = ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper compN=5: %v", err)
	}
	var englishStart int
	for i, sec := range paper.Sections {
		if sec.Subject == "Use of English" {
			englishStart = i
			break
		}
	}
	count := 0
	for _, q := range paper.Questions {
		if q.Group == "comprehension" {
			count++
		}
	}
	if count != 5 {
		t.Fatalf("compN=5 yielded %d comprehension questions (englishStart=%d)", count, englishStart)
	}
}

func TestComposeCustomPaper(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-custom-music~n=10"
	parsed, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	banks := map[string]*Bundle{"music": mustBank(t, lib, "music")}
	paper, err := ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper custom: %v", err)
	}
	if paper.QuestionCount != 10 {
		t.Fatalf("custom n=10 produced %d questions", paper.QuestionCount)
	}
	if paper.DurationMinutes != nil {
		t.Fatalf("untimed custom must carry no duration, got %d", *paper.DurationMinutes)
	}
	if !strings.HasPrefix(paper.Title, "Custom Practice") {
		t.Fatalf("custom title wrong: %s", paper.Title)
	}
	// timed custom
	parsed, _ = lib.ParsePaper("jamb-custom-music~n=10.t=25")
	paper, err = ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper timed custom: %v", err)
	}
	if paper.DurationMinutes == nil || *paper.DurationMinutes != 25 {
		t.Fatalf("timed custom must carry 25 minutes")
	}
	// multi-subject distribution: n=30 across 3 subjects -> 10 each
	parsed, _ = lib.ParsePaper("jamb-custom-agricultural-science-music-physics~n=30")
	banks["agricultural-science"] = mustBank(t, lib, "agricultural-science")
	banks["physics"] = mustBank(t, lib, "physics")
	paper, err = ComposePaper(parsed, banks)
	if err != nil {
		t.Fatalf("ComposePaper 3-subject custom: %v", err)
	}
	if paper.QuestionCount != 30 {
		t.Fatalf("3-subject custom n=30 produced %d", paper.QuestionCount)
	}
	for _, sec := range paper.Sections {
		if len(sec.QuestionIDs) != 10 {
			t.Fatalf("section %s has %d, want 10", sec.Subject, len(sec.QuestionIDs))
		}
	}
}

func TestComposePickPaper(t *testing.T) {
	lib := loadRealLibrary(t)
	base, ok := lib.Bundle("jamb-biology-bank")
	if !ok {
		t.Fatal("biology bank missing")
	}
	code := "jamb-pick-jamb-biology-bank~n=25"
	parsed, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	paper, err := ComposePickPaper(parsed, base)
	if err != nil {
		t.Fatalf("ComposePickPaper: %v", err)
	}
	if paper.QuestionCount != 25 || len(paper.Questions) != 25 {
		t.Fatalf("pick n=25 produced %d", paper.QuestionCount)
	}
	if len(paper.Sections) != 0 {
		t.Fatal("pick papers carry no sections")
	}
	// deterministic
	again, _ := ComposePickPaper(parsed, base)
	for i := range paper.Questions {
		if paper.Questions[i].ID != again.Questions[i].ID {
			t.Fatalf("pick walk diverges at %d", i)
		}
	}
	// year-pinned pick draws only that year
	years := map[int]int{}
	for _, q := range base.Questions {
		years[q.Year]++
	}
	code = "jamb-pick-jamb-biology-bank~y=2023.n=40"
	parsed, _ = lib.ParsePaper(code)
	paper, err = ComposePickPaper(parsed, base)
	if err != nil {
		t.Fatalf("ComposePickPaper year: %v", err)
	}
	for _, q := range paper.Questions {
		if q.Year != 2023 {
			t.Fatalf("pick y=2023 returned question %s year=%d", q.ID, q.Year)
		}
	}
	if years[2023] == 0 {
		t.Fatal("test data lacks 2023 biology questions")
	}
	// a year the bank lacks: loud error at compose time
	code = "jamb-pick-jamb-biology-bank~y=1996.n=40"
	parsed, err = lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper 1996: %v", err)
	}
	if _, err := ComposePickPaper(parsed, base); err == nil {
		t.Fatal("pick with a year the bank lacks must fail")
	}
}

func TestComposeMockPaperUnknownBank(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-mathematics-physics"
	parsed, _ := lib.ParsePaper(code)
	if _, err := ComposePaper(parsed, map[string]*Bundle{}); err == nil {
		t.Fatal("compose without banks must fail")
	}
}

func TestRegisterPaperVisible(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-economics-physics"
	parsed, ok := lib.MockPaperSubjects(code)
	if !ok {
		t.Fatalf("canonical code rejected: %s", code)
	}
	pSpec, err := lib.ParsePaper(code)
	if err != nil {
		t.Fatalf("ParsePaper: %v", err)
	}
	_ = parsed
	banks := map[string]*Bundle{}
	for _, slug := range pSpec.Subjects {
		banks[slug] = mustBank(t, lib, slug)
	}
	paper, err := ComposePaper(pSpec, banks)
	if err != nil {
		t.Fatalf("compose: %v", err)
	}
	if _, ok := lib.Bundle(code); ok {
		t.Fatal("paper must not be visible before registration")
	}
	lib.RegisterPaper(paper)
	got, ok := lib.Bundle(code)
	if !ok || got.Code != code {
		t.Fatal("registered paper must resolve via Bundle()")
	}
	// registered composites must never join a body rotation pool
	for _, b := range lib.BundlesByBody("JAMB") {
		if IsMockPaperCode(b.Code) || IsCustomPaperCode(b.Code) || IsPickPaperCode(b.Code) {
			t.Fatalf("composite %s leaked into the daily rotation pool", b.Code)
		}
	}
}

func containsID(ids []string, id string) bool {
	for _, i := range ids {
		if i == id {
			return true
		}
	}
	return false
}

func mustBank(t *testing.T, lib *Library, slug string) *Bundle {
	t.Helper()
	b, ok := lib.Bundle("jamb-" + slug + "-bank")
	if !ok {
		t.Fatalf("bank missing: %s", slug)
	}
	return b
}
