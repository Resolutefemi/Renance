package synth

// synth_test.go: quality gates for the engine. The founder's rules:
// no hyphen anywhere, notes long enough, quiz shapes valid, options
// related, determinism, and the answer key consistent.

import (
        "encoding/json"
        "fmt"
        "strings"
        "testing"
)

var sampleCourses = []struct{ id, course, dept, faculty string }{
        {"TOP-000002", "General Biology", "Zoology", "Science"},
        {"CRS-07800-EU0501", "Polymer Chemistry", "Chemistry", "Science"},
        {"CRS-04811-EU0203", "Criminal Law", "Law", "Law"},
        {"CRS-01234-EU0307", "General Mathematics I", "Mathematics", "Science"},
        {"CRS-09999-EU0402", "Principles of Economics", "Economics", "Social Sciences"},
        {"CRS-05575-EU0204", "Pharmaceutics I", "Pharmaceutics", "Pharmacy"},
        {"CRS-03000-EU0205", "Introduction to Computer Science", "Computer Science", "Science"},
        {"CRS-04000-EU0601", "Principles of Accountancy", "Accounting", "Management Sciences"},
        {"CRS-05000-EU0802", "Nigerian Government and Politics", "Political Science", "Social Sciences"},
        {"CRS-06000-EU0903", "Introduction to Mass Communication", "Mass Communication", "Social Sciences"},
        {"CRS-07000-EU0405", "Soil Science", "Soil Science", "Agriculture"},
        {"CRS-08000-EU0206", "Educational Psychology", "Education", "Education"},
        {"CRS-09000-EU0701", "Human Anatomy", "Anatomy", "Basic Medical Sciences"},
        {"CRS-10000-EU0302", "Principles of Marketing", "Business Administration", "Management Sciences"},
        {"CRS-11000-EU0504", "Engineering Mechanics", "Mechanical Engineering", "Engineering"},
        {"CRS-12000-EU0207", "Introduction to Statistics", "Statistics", "Science"},
        {"CRS-13000-EU0606", "Urban and Regional Planning", "Urban and Regional Planning", "Environmental Studies"},
        {"CRS-14000-EU0108", "Introduction to Hospitality and Tourism", "Hospitality", "Management Sciences"},
        {"CRS-15000-EU0210", "International Trade", "Economics", "Social Sciences"},
        {"CRS-16000-EU0311", "African Literature", "English", "Arts"},
}

func allTopics() []struct{ id, course, dept, faculty, topic string; unit int } {
        out := []struct{ id, course, dept, faculty, topic string; unit int }{}
        for _, c := range sampleCourses {
                for u := 1; u <= 15; u += 7 { // sample three units per course
                        _, tops := UnitPlan(c.id, c.course, c.dept, c.faculty, u)
                        for i, tp := range tops {
                                out = append(out, struct {
                                        id, course, dept, faculty, topic string
                                        unit                             int
                                }{fmt.Sprintf("%s-EU%02d%02d", c.id, u, i+1), c.course, c.dept, c.faculty, tp.Title, u})
                        }
                }
        }
        return out
}

func TestHyphenFreeAndShapes(t *testing.T) {
        for _, tc := range allTopics() {
                l := BuildLesson(tc.id, tc.course, tc.dept, tc.faculty, tc.topic, tc.unit)
                if len(l.Notes) < 10 {
                        t.Fatalf("%s: only %d note sections", tc.id, len(l.Notes))
                }
                if len(l.Quiz) != 20 {
                        t.Fatalf("%s: quiz has %d items, want 20", tc.id, len(l.Quiz))
                }
                // hyphen scan across every CONTENT string (ids carry hyphens
                // by design; the founder's rule covers reading text)
                scan := []string{l.Summary}
                scan = append(scan, l.KeyPoints...)
                for _, n := range l.Notes {
                        scan = append(scan, n.Heading, n.Body)
                }
                for _, q := range l.Quiz {
                        scan = append(scan, q.Stem, q.Explanation)
                        for _, o := range q.Options {
                                scan = append(scan, o)
                        }
                }
                for _, s := range scan {
                        if strings.Contains(s, "-") {
                                i := strings.Index(s, "-")
                                lo := maxInt(0, i-70)
                                hi := minInt(len(s), i+70)
                                t.Fatalf("%s: hyphen in content: ...%s...", tc.id, s[lo:hi])
                        }
                }
                // word floors
                for i, n := range l.Notes {
                        w := len(strings.Fields(n.Body))
                        if w < 130 {
                                t.Fatalf("%s section %d too short: %d words", tc.id, i, w)
                        }
                }
                // quiz shape parity with the API validator
                for i, q := range l.Quiz {
                        if q.Stem == "" || q.Answer == "" {
                                t.Fatalf("%s quiz %d missing stem or answer", tc.id, i)
                        }
                        if q.ID == "" {
                                t.Fatalf("%s quiz %d missing id", tc.id, i)
                        }
                        switch q.Type {
                        case "mcq":
                                if len(q.Options) != 4 {
                                        t.Fatalf("%s quiz %d: %d options", tc.id, i, len(q.Options))
                                }
                                if _, ok := q.Options[q.Answer]; !ok {
                                        t.Fatalf("%s quiz %d: answer %q not an option key", tc.id, i, q.Answer)
                                }
                        case "true_false":
                                if q.Answer != "true" && q.Answer != "false" {
                                        t.Fatalf("%s quiz %d: bad tf answer %q", tc.id, i, q.Answer)
                                }
                        case "fill_blank":
                                if len(strings.Fields(q.Answer)) != 1 {
                                        t.Fatalf("%s quiz %d: blank answer must be one word, got %q", tc.id, i, q.Answer)
                                }
                        default:
                                t.Fatalf("%s quiz %d: unknown type %q", tc.id, i, q.Type)
                        }
                }
                // easy/hard split: first 10 easy ids, last 10 hard
                for i := 0; i < 10; i++ {
                        if !strings.Contains(l.Quiz[i].ID, "E") {
                                t.Fatalf("%s quiz %d id %q not easy band", tc.id, i, l.Quiz[i].ID)
                        }
                }
                for i := 10; i < 20; i++ {
                        if !strings.Contains(l.Quiz[i].ID, "H") {
                                t.Fatalf("%s quiz %d id %q not hard band", tc.id, i, l.Quiz[i].ID)
                        }
                }
        }
}

func TestDeterminism(t *testing.T) {
        a := BuildLesson("CRS-04811-EU0203", "Criminal Law", "Law", "Law", "Elements of a valid contract", 7)
        b := BuildLesson("CRS-04811-EU0203", "Criminal Law", "Law", "Law", "Elements of a valid contract", 7)
        ja, _ := json.Marshal(a)
        jb, _ := json.Marshal(b)
        if string(ja) != string(jb) {
                t.Fatal("synthesis is not deterministic for the same topic id")
        }
}

func TestUnitPlanShape(t *testing.T) {
        for u := 1; u <= 15; u++ {
                title, tops := UnitPlan("CRS-00001", "General Biology", "Zoology", "Science", u)
                if title == "" {
                        t.Fatalf("unit %d has empty title", u)
                }
                if len(tops) != 10 {
                        t.Fatalf("unit %d has %d topics", u, len(tops))
                }
                seen := map[string]bool{}
                for _, tp := range tops {
                        if seen[strings.ToLower(tp.Title)] {
                                t.Fatalf("unit %d duplicates topic %q", u, tp.Title)
                        }
                        seen[strings.ToLower(tp.Title)] = true
                        if len(tp.Title) > 72 {
                                t.Fatalf("unit %d topic too long: %q", u, tp.Title)
                        }
                        if strings.Contains(tp.Title, "-") {
                                t.Fatalf("unit %d topic has hyphen: %q", u, tp.Title)
                        }
                }
        }
}

func TestNumericCorrectness(t *testing.T) {
        // run each generator many times; answers must never equal a wrong
        // option, and all four options must be distinct
        for kind, pool := range generators {
                for _, gen := range pool {
                        for i := 0; i < 300; i++ {
                                g := NewRNG(fmt.Sprintf("%s|%d", kind, i))
                                e := dedupeEx(gen(g))
                                if e == nil {
                                        continue
                                }
                                set := map[string]bool{e.answer: true}
                                for _, w := range e.wrongs {
                                        if set[w] {
                                                t.Fatalf("%s %s: duplicate option %q", kind, e.topic, w)
                                        }
                                        set[w] = true
                                }
                                if len(set) != 4 {
                                        t.Fatalf("%s %s: options collapsed: %v %v", kind, e.topic, e.answer, e.wrongs)
                                }
                        }
                }
        }
}

func maxInt(a, b int) int {
        if a > b {
                return a
        }
        return b
}

func minInt(a, b int) int {
        if a < b {
                return a
        }
        return b
}
