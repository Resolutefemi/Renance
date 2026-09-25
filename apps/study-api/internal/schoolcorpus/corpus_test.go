package schoolcorpus

import (
	"encoding/json"
	"strings"
	"testing"
)

// The corpus must read the repo's own data folder: classes in school
// order, subjects with honest term availability, and term files that
// parse as the shapes the corpus README promises.
func TestLoadFromRepoData(t *testing.T) {
	c := Load("../../../../data")
	classes := c.Classes()
	if len(classes) == 0 {
		t.Fatal("no classes loaded from the repo data dir")
	}
	if classes[0].Stage != "pre-primary" {
		t.Fatalf("first class should be nursery, got %s", classes[0].ID)
	}
	var jss3 *Class
	for i := range classes {
		if classes[i].ID == "jss-3" {
			jss3 = &classes[i]
		}
	}
	if jss3 == nil {
		t.Fatal("jss-3 missing from the corpus")
	}
	var maths *Subject
	for i := range jss3.Subjects {
		if jss3.Subjects[i].ID == "mathematics" {
			maths = &jss3.Subjects[i]
		}
	}
	if maths == nil {
		t.Fatal("jss-3 mathematics missing from the corpus")
	}
	if len(maths.SchemeTerms) != 3 {
		t.Fatalf("jss-3 mathematics should carry 3 scheme terms, got %v", maths.SchemeTerms)
	}

	terms := c.Terms("school-schemes", "jss-3", "mathematics")
	if len(terms) != 3 {
		t.Fatalf("expected 3 scheme term payloads, got %d", len(terms))
	}
	var weeks []struct {
		Week  int    `json:"week"`
		Topic string `json:"topic"`
	}
	if err := json.Unmarshal(terms[0].Data, &struct {
		Weeks *[]struct {
			Week  int    `json:"week"`
			Topic string `json:"topic"`
		}
	}{Weeks: &weeks}); err != nil {
		t.Fatalf("scheme term payload does not parse: %v", err)
	}
	if len(weeks) == 0 || strings.TrimSpace(weeks[0].Topic) == "" {
		t.Fatal("first term scheme has no week topics")
	}

	if !c.Has("jss-3", "mathematics") {
		t.Fatal("Has should accept jss-3 mathematics")
	}
	if c.Has("jss-9", "mathematics") || c.Has("nursery-1", "quantum-mechanics") {
		t.Fatal("Has should reject unknown slugs")
	}
	if got := c.Terms("school-schemes", "jss-9", "mathematics"); got != nil {
		t.Fatal("unknown class must return nil terms")
	}
	if got := titleSubject("english-studies"); got != "English Studies" {
		t.Fatalf("titleSubject broken: %q", got)
	}
}
