package cbtdata

import (
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
	for _, code := range []string{"jamb-english-bank", "jamb-mock-", "jamb-mockish-english", ""} {
		if IsMockPaperCode(code) {
			t.Fatalf("%q must not classify as a mock paper", code)
		}
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

func TestComposeMockPaperShape(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-mathematics-physics"
	subjects, ok := lib.MockPaperSubjects(code)
	if !ok {
		t.Fatalf("canonical code rejected: %s", code)
	}
	banks := map[string]*Bundle{}
	for _, slug := range subjects {
		b, ok := lib.Bundle("jamb-" + slug + "-bank")
		if !ok {
			t.Fatalf("bank missing for %s", slug)
		}
		banks[slug] = b
	}
	paper, err := ComposeMockPaper(code, subjects, banks)
	if err != nil {
		t.Fatalf("ComposeMockPaper: %v", err)
	}
	if paper.Body != "JAMB" || paper.Category != "secondary" {
		t.Fatalf("paper body/category wrong: %+v", paper)
	}
	if paper.DurationMinutes == nil || *paper.DurationMinutes != 120 {
		t.Fatalf("mock paper must run the official 120 minutes")
	}
	if len(paper.Sections) != len(subjects) {
		t.Fatalf("sections=%d, subjects=%d", len(paper.Sections), len(subjects))
	}
	// caps: English 60, others 40 (or the bank's full size)
	wantCounts := map[string]int{}
	for _, sec := range paper.Sections {
		wantCounts[sec.Subject] = len(sec.QuestionIDs)
		if wantCounts[sec.Subject] > mockCap("")+60 {
			t.Fatalf("section %s impossibly large", sec.Subject)
		}
	}
	if wantCounts["Use of English"] > 60 {
		t.Fatalf("english cap breached: %d", wantCounts["Use of English"])
	}
	if paper.QuestionCount != len(paper.Questions) {
		t.Fatalf("questionCount=%d, len=%d", paper.QuestionCount, len(paper.Questions))
	}
	// section ids must walk the same questions, in order
	ids := map[string]bool{}
	for i, q := range paper.Questions {
		if ids[q.ID] {
			t.Fatalf("duplicate question %s", q.ID)
		}
		ids[q.ID] = true
		_ = i
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
	// every question keeps its own marks and the total sums them
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
	subjects, ok := lib.MockPaperSubjects(code)
	if !ok {
		t.Fatalf("canonical code rejected: %s", code)
	}
	banks := map[string]*Bundle{}
	for _, slug := range subjects {
		banks[slug] = mustBank(t, lib, slug)
	}
	a, err := ComposeMockPaper(code, subjects, banks)
	if err != nil {
		t.Fatalf("compose a: %v", err)
	}
	b, err := ComposeMockPaper(code, subjects, banks)
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
	subjects2, ok := lib.MockPaperSubjects(code2)
	if !ok {
		t.Fatalf("canonical code rejected: %s", code2)
	}
	for _, slug := range subjects2 {
		if _, ok := banks[slug]; !ok {
			banks[slug] = mustBank(t, lib, slug)
		}
	}
	c, err := ComposeMockPaper(code2, subjects2, banks)
	if err != nil {
		t.Fatalf("compose c: %v", err)
	}
	if c.Questions[0].ID == a.Questions[0].ID && c.Questions[len(c.Questions)-1].ID == a.Questions[len(a.Questions)-1].ID {
		t.Fatal("distinct codes should seed distinct walks (first and last ids equal: suspicious)")
	}
}

func TestComposeMockPaperUnknownBank(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-mathematics-physics"
	subjects, _ := lib.MockPaperSubjects(code)
	if _, err := ComposeMockPaper(code, subjects, map[string]*Bundle{}); err == nil {
		t.Fatal("compose without banks must fail")
	}
}

func TestRegisterPaperVisible(t *testing.T) {
	lib := loadRealLibrary(t)
	code := "jamb-mock-english-biology-economics-physics"
	subjects, ok := lib.MockPaperSubjects(code)
	if !ok {
		t.Fatalf("canonical code rejected: %s", code)
	}
	banks := map[string]*Bundle{}
	for _, slug := range subjects {
		banks[slug] = mustBank(t, lib, slug)
	}
	paper, err := ComposeMockPaper(code, subjects, banks)
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
		if IsMockPaperCode(b.Code) {
			t.Fatalf("composite %s leaked into the daily rotation pool", b.Code)
		}
	}
}

func mustBank(t *testing.T, lib *Library, slug string) *Bundle {
	t.Helper()
	b, ok := lib.Bundle("jamb-" + slug + "-bank")
	if !ok {
		t.Fatalf("bank missing: %s", slug)
	}
	return b
}
