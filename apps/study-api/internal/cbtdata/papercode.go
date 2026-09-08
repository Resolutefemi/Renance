package cbtdata

// Paper code grammar v2 — deterministic composition, extended.
//
// Every composed paper is a pure function of its CODE, so grading,
// review and resume always rebuild the exact sitting. The 2026 grammar
// adds per-subject year pinning, English comprehension controls and a
// custom/practice family while keeping the original codes valid:
//
//      jamb-mock-<slug>-<slug>...[~params]   official UTME mock
//                                            (Use of English first, >=2 subjects)
//      jamb-custom-<slug>-<slug>...~params   custom practice paper
//                                            (>=1 subject, English optional)
//      jamb-pick-<base-code>[~params]        practice subset carved from one
//                                            static manifest pack
//
// params are dot-joined key=value pairs in canonical order y,n,enN,comp,compN,nov,t:
//
//      y     per-subject years, semicolon list aligned with the subjects
//            ("r" = random); a single value pins every subject; pick codes
//            carry a single value. Omitted when every entry is random.
//      n     total question count (custom: spread across subjects; pick:
//            subset size)
//      enN   mock Use-of-English section size (default 60)
//      comp  0|1 — include comprehension-passage questions in the English
//            section (default 1)
//      compN how many comprehension questions the English section carries
//            (default 10, only meaningful when comp=1)
//      nov   0|1 — include the JAMB novel questions ("The Lekki
//            Headmaster") in the English section (default 0; the
//            candidate opts in, like the hall's novel ask)
//      t     timer minutes (mock default 120; custom/pick default 0 = untimed)
//
// Codes are canonical: re-encoding a parsed spec MUST reproduce the
// input byte-for-byte, otherwise the server refuses the paper.

import (
        "fmt"
        "strconv"
        "strings"
)

// Composed paper families.
const (
        PaperFamilyMock   = "mock"
        PaperFamilyCustom = "custom"
        PaperFamilyPick   = "pick"
)

const (
        mockPaperFamilyPrefix   = "jamb-mock-"
        customPaperFamilyPrefix = "jamb-custom-"
        pickPaperFamilyPrefix   = "jamb-pick-"

        defaultMockEnglish = 60
        defaultMockTimer   = 120
        defaultCompN       = 10
        defaultNovelN      = 10
        maxEnglishSection  = 60
        maxCompN           = 30
        maxTimerMinutes    = 600
        maxPaperQuestions  = 500
        minYear, maxYear   = 1975, 2030
)

// PaperSpec is a parsed composed-paper code.
type PaperSpec struct {
        Family   string   // mock | custom | pick
        Subjects []string // mock/custom: bank slugs (mock: English first)
        Base     string   // pick: the static pack the subset is carved from
        Years    []int    // aligned with Subjects (pick: length 1); 0 = random
        N        int      // custom/pick question total; 0 = family default
        EnN      int      // mock English section size; 0 = default 60
        Comp     bool     // English comprehension included (default true)
        CompN    int      // comprehension count; 0 = default 10
        Novel    bool     // JAMB novel questions included (default false)
        Timer    int      // minutes; 0 = family default
}

// IsMockPaperCode reports whether code names a composite UTME mock paper
// (with or without params).
func IsMockPaperCode(code string) bool {
        return strings.HasPrefix(code, mockPaperFamilyPrefix) && len(code) > len(mockPaperFamilyPrefix)
}

// IsCustomPaperCode reports whether code names a custom practice paper.
func IsCustomPaperCode(code string) bool {
        return strings.HasPrefix(code, customPaperFamilyPrefix) && len(code) > len(customPaperFamilyPrefix)
}

// IsPickPaperCode reports whether code names a carved practice subset.
func IsPickPaperCode(code string) bool {
        return strings.HasPrefix(code, pickPaperFamilyPrefix) && len(code) > len(pickPaperFamilyPrefix)
}

// IsComposedPaperCode reports whether code names ANY composed paper —
// papers that never appear in the manifest and resolve by code alone.
func IsComposedPaperCode(code string) bool {
        return IsMockPaperCode(code) || IsCustomPaperCode(code) || IsPickPaperCode(code)
}

// ParsePaperCode parses a composed paper code into its spec against the
// bank-slug dictionary (multi-word slugs like "agricultural-science"
// segment exactly like single-word ones). Returns an error for anything
// malformed, out of range or non-canonical.
func ParsePaperCode(code string, dict map[string]struct{}) (*PaperSpec, error) {
        body, params := splitParams(code)
        switch {
        case IsMockPaperCode(code):
                subjects, err := segmentSubjects(strings.TrimPrefix(body, mockPaperFamilyPrefix), dict, true)
                if err != nil {
                        return nil, err
                }
                spec := &PaperSpec{Family: PaperFamilyMock, Comp: true, Subjects: subjects}
                if err := spec.applyParams(params, false); err != nil {
                        return nil, err
                }
                if err := spec.canonicalCheck(code); err != nil {
                        return nil, err
                }
                return spec, nil
        case IsCustomPaperCode(code):
                subjects, err := segmentSubjects(strings.TrimPrefix(body, customPaperFamilyPrefix), dict, false)
                if err != nil {
                        return nil, err
                }
                spec := &PaperSpec{Family: PaperFamilyCustom, Comp: true, Subjects: subjects}
                if err := spec.applyParams(params, false); err != nil {
                        return nil, err
                }
                if err := spec.canonicalCheck(code); err != nil {
                        return nil, err
                }
                return spec, nil
        case IsPickPaperCode(code):
                base := strings.TrimPrefix(body, pickPaperFamilyPrefix)
                if !validPackCode(base) || IsComposedPaperCode(base) {
                        return nil, fmt.Errorf("cbtdata: pick base %q is not a static pack", base)
                }
                spec := &PaperSpec{Family: PaperFamilyPick, Base: base, Comp: true}
                if err := spec.applyParams(params, true); err != nil {
                        return nil, err
                }
                if err := spec.canonicalCheck(code); err != nil {
                        return nil, err
                }
                return spec, nil
        }
        return nil, fmt.Errorf("cbtdata: %q is not a composed paper code", code)
}

// ParsePaper is the Library convenience wrapper: parse against this
// library's bank-slug dictionary.
func (l *Library) ParsePaper(code string) (*PaperSpec, error) {
        dict := map[string]struct{}{}
        for _, s := range l.bankSlugs() {
                dict[s] = struct{}{}
        }
        return ParsePaperCode(code, dict)
}

// splitParams cuts the code at the "~" separator (at most one).
func splitParams(code string) (string, string) {
        if i := strings.Index(code, "~"); i >= 0 {
                return code[:i], code[i+1:]
        }
        return code, ""
}

// segmentSubjects word-breaks the dash-joined tail into dictionary
// slugs, then enforces the family's canonical order: mock = Use of
// English first with the rest sorted; custom = fully sorted. Re-encoding
// the parsed spec must reproduce the code, so unsorted input is refused.
func segmentSubjects(tail string, dict map[string]struct{}, englishFirst bool) ([]string, error) {
        if tail == "" {
                return nil, fmt.Errorf("cbtdata: empty subject list")
        }
        subs, ok := segmentSlugs(tail, dict)
        if !ok {
                return nil, fmt.Errorf("cbtdata: subject list %q does not segment into bank slugs", tail)
        }
        seen := map[string]struct{}{}
        for _, s := range subs {
                if _, dup := seen[s]; dup {
                        return nil, fmt.Errorf("cbtdata: duplicate subject %q", s)
                }
                seen[s] = struct{}{}
        }
        if englishFirst {
                if len(subs) < 2 || subs[0] != "english" {
                        return nil, fmt.Errorf("cbtdata: mock papers start with Use of English plus at least one subject")
                }
                rest := append([]string(nil), subs[1:]...)
                sortStrings(rest)
                if strings.Join(append([]string{"english"}, rest...), "-") != tail {
                        return nil, fmt.Errorf("cbtdata: non-canonical subject order %q", tail)
                }
        } else {
                sorted := append([]string(nil), subs...)
                sortStrings(sorted)
                if strings.Join(sorted, "-") != tail {
                        return nil, fmt.Errorf("cbtdata: non-canonical subject order %q", tail)
                }
        }
        return subs, nil
}

func sortStrings(s []string) {
        for i := 1; i < len(s); i++ {
                for j := i; j > 0 && s[j] < s[j-1]; j-- {
                        s[j], s[j-1] = s[j-1], s[j]
                }
        }
}

func validPackCode(s string) bool {
        if s == "" || len(s) > 80 {
                return false
        }
        for _, r := range s {
                if (r < 'a' || r > 'z') && (r < '0' || r > '9') && r != '-' {
                        return false
                }
        }
        return true
}

// applyParams parses the dot-joined param string onto the spec.
func (p *PaperSpec) applyParams(params string, pick bool) error {
        if params == "" {
                return nil
        }
        for _, pair := range strings.Split(params, ".") {
                k, v, found := strings.Cut(pair, "=")
                if !found {
                        return fmt.Errorf("cbtdata: bad param %q", pair)
                }
                switch k {
                case "y":
                        if pick {
                                year, err := parseYearToken(v)
                                if err != nil {
                                        return err
                                }
                                p.Years = []int{year}
                                continue
                        }
                        // a single year without the ";" list pins every subject
                        if !strings.Contains(v, ";") {
                                year, err := parseYearToken(v)
                                if err != nil {
                                        return err
                                }
                                if year == 0 {
                                        return fmt.Errorf("cbtdata: all-random y must be omitted")
                                }
                                p.Years = make([]int, len(p.Subjects))
                                for i := range p.Years {
                                        p.Years[i] = year
                                }
                                continue
                        }
                        parts := strings.Split(v, ";")
                        if len(parts) != len(p.Subjects) {
                                return fmt.Errorf("cbtdata: y list must have one entry per subject (%d != %d)", len(parts), len(p.Subjects))
                        }
                        p.Years = make([]int, len(parts))
                        for i, tok := range parts {
                                year, err := parseYearToken(tok)
                                if err != nil {
                                        return err
                                }
                                p.Years[i] = year
                        }
                case "n":
                        n, err := positiveInt(v)
                        if err != nil || n > maxPaperQuestions {
                                return fmt.Errorf("cbtdata: bad n %q", v)
                        }
                        p.N = n
                case "enN":
                        n, err := positiveInt(v)
                        if err != nil || n < 5 || n > maxEnglishSection {
                                return fmt.Errorf("cbtdata: bad enN %q", v)
                        }
                        p.EnN = n
                case "comp":
                        if v != "0" && v != "1" {
                                return fmt.Errorf("cbtdata: bad comp %q", v)
                        }
                        p.Comp = v == "1"
                case "compN":
                        n, err := positiveInt(v)
                        if err != nil || n > maxCompN {
                                return fmt.Errorf("cbtdata: bad compN %q", v)
                        }
                        p.CompN = n
                case "nov":
                        if v != "0" && v != "1" {
                                return fmt.Errorf("cbtdata: bad nov %q", v)
                        }
                        p.Novel = v == "1"
                case "t":
                        n, err := positiveInt(v)
                        if err != nil || n > maxTimerMinutes {
                                return fmt.Errorf("cbtdata: bad t %q", v)
                        }
                        p.Timer = n
                default:
                        return fmt.Errorf("cbtdata: unknown param %q", k)
                }
        }
        return nil
}

func parseYearToken(tok string) (int, error) {
        if tok == "r" || tok == "" {
                return 0, nil
        }
        y, err := strconv.Atoi(tok)
        if err != nil || y < minYear || y > maxYear {
                return 0, fmt.Errorf("cbtdata: bad year %q", tok)
        }
        return y, nil
}

func positiveInt(s string) (int, error) {
        if s == "" {
                return 0, fmt.Errorf("empty int")
        }
        n, err := strconv.Atoi(s)
        if err != nil || n <= 0 {
                return 0, fmt.Errorf("bad int %q", s)
        }
        return n, nil
}

// Encode rebuilds the canonical code from the spec.
func (p *PaperSpec) Encode() string {
        var body string
        switch p.Family {
        case PaperFamilyMock:
                body = mockPaperFamilyPrefix + strings.Join(p.Subjects, "-")
        case PaperFamilyCustom:
                body = customPaperFamilyPrefix + strings.Join(p.Subjects, "-")
        case PaperFamilyPick:
                body = pickPaperFamilyPrefix + p.Base
        }
        params := p.paramsString()
        if params == "" {
                return body
        }
        return body + "~" + params
}

// paramsString renders the non-default params in canonical order.
func (p *PaperSpec) paramsString() string {
        var parts []string
        if p.Years != nil {
                if pick := p.Family == PaperFamilyPick; pick {
                        if p.Years[0] != 0 {
                                parts = append(parts, "y="+strconv.Itoa(p.Years[0]))
                        }
                } else {
                        allRandom := true
                        allSame := p.Years[0] != 0
                        for _, y := range p.Years {
                                if y != 0 {
                                        allRandom = false
                                }
                                if y != p.Years[0] {
                                        allSame = false
                                }
                        }
                        if !allRandom {
                                if allSame {
                                        parts = append(parts, "y="+strconv.Itoa(p.Years[0]))
                                } else {
                                        toks := make([]string, len(p.Years))
                                        for i, y := range p.Years {
                                                if y == 0 {
                                                        toks[i] = "r"
                                                } else {
                                                        toks[i] = strconv.Itoa(y)
                                                }
                                        }
                                        parts = append(parts, "y="+strings.Join(toks, ";"))
                                }
                        }
                }
        }
        if p.Family == PaperFamilyCustom && p.N > 0 {
                parts = append(parts, "n="+strconv.Itoa(p.N))
        }
        if p.Family == PaperFamilyPick && p.N > 0 {
                parts = append(parts, "n="+strconv.Itoa(p.N))
        }
        if p.Family == PaperFamilyMock && p.EnN > 0 && p.EnN != defaultMockEnglish {
                parts = append(parts, "enN="+strconv.Itoa(p.EnN))
        }
        if !p.Comp {
                parts = append(parts, "comp=0")
        } else if p.CompN > 0 && p.CompN != defaultCompN {
                parts = append(parts, "compN="+strconv.Itoa(p.CompN))
        }
        if p.Novel {
                parts = append(parts, "nov=1")
        }
        if p.Timer > 0 && !(p.Family == PaperFamilyMock && p.Timer == defaultMockTimer) {
                parts = append(parts, "t="+strconv.Itoa(p.Timer))
        }
        return strings.Join(parts, ".")
}

// canonicalCheck re-encodes and compares — the server refuses
// non-canonical codes so every surface builds them through one grammar.
func (p *PaperSpec) canonicalCheck(code string) error {
        if got := p.Encode(); got != code {
                return fmt.Errorf("cbtdata: non-canonical paper code %q (canonical %q)", code, got)
        }
        return nil
}
