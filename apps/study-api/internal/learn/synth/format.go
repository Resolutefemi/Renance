package synth

import (
	"regexp"
	"strings"
)

/* ------------------------------------------------------------------ */
/* Output formatting contract (founder directives 2026-10-16)          */
/*                                                                     */
/* 1. NO hyphen character (U+002D) anywhere in notes or quiz text.     */
/*    Math minus is the unicode minus U+2212, never a hyphen.          */
/* 2. Superscripts are real unicode: x2 is x², never x^2.              */
/* 3. Fractions are LaTeX with a vertical bar: \(\frac{dy}{dx}\),      */
/*    never the slant dy/dx. KaTeX is already wired into the web app.  */
/*                                                                     */
/* Clean() is the last gate: every heading, body, stem, option and     */
/* explanation passes through it before it leaves the engine.          */
/* ------------------------------------------------------------------ */

var (
	hyphenMath   = regexp.MustCompile(`(\s|^)-(\s|[0-9])`) // " - 3" or "-3": a math operator
	hyphenWord   = regexp.MustCompile(`([A-Za-z]{2,})-([A-Za-z]{2,})`)
	hyphenNumWord = regexp.MustCompile(`([0-9])-([A-Za-z]{2,})`)
	dashes       = strings.NewReplacer("—", ", ", "–", ", ", "‐", " ", "‑", " ", "‒", " ", "−", "\u2212")
	multiSpace   = regexp.MustCompile(`\s{2,}`)
)

// wordHyphens maps the compound words that could sneak into prose to
// their hyphen free rewrites (the founder's hard rule).
var wordHyphens = map[string]string{
	"well-known": "established", "well known": "established",
	"state-of-the-art": "advanced", "state of the art": "advanced",
	"self-study": "independent study", "self-studying": "independent study",
	"x-axis": "x axis", "y-axis": "y axis", "z-axis": "z axis",
	"x-intercept": "x intercept", "y-intercept": "y intercept",
	"non-linear": "nonlinear", "non-fiction": "nonfiction",
	"real-world": "real world", "real-life": "real life",
	"step-by-step": "stepwise", "step-by": "stepwise",
	"e-mail": "email", "e-commerce": "ecommerce",
	"day-to-day": "daily", "hands-on": "practical",
	"face-to-face": "direct", "one-to-one": "individual",
	"long-term": "long term", "short-term": "short term",
	"in-depth": "detailed", "full-scale": "full scale",
	"real-time": "real time", "end-user": "end user",
	"follow-up": "followup", "follow-up's": "followups",
	"drop-down": "dropdown", "sign-up": "signup",
	"build-up": "buildup", "set-up": "setup",
	"check-up": "checkup", "make-up": "makeup",
	"cover-page": "cover page", "pro-rata": "prorata",
	"per-capita": "per capita", "ex-post": "expost",
	"ex-ante": "exante", "ad-hoc": "adhoc",
	"de-facto": "defacto", "vis-a-vis": "versus",
	"so-called": "so called", "man-made": "artificial",
	"mass-produced": "mass produced", "large-scale": "large scale",
	"small-scale": "small scale", "medium-scale": "medium scale",
	"high-level": "high level", "low-level": "low level",
	"high-order": "higher order", "second-order": "second order",
	"first-order": "first order", "third-order": "third order",
	"cross-section": "cross section", "cross-product": "cross product",
	"dot-product": "dot product", "rate-of-change": "rate of change",
	"chain-rule": "chain rule", "product-rule": "product rule",
	"quotient-rule": "quotient rule", "power-rule": "power rule",
	"left-hand": "left hand", "right-hand": "right hand",
	"right-angled": "right angled", "equi-lateral": "equilateral",
	"co-ordinate": "coordinate", "co-ordinates": "coordinates",
	"co-efficiency": "coefficient", "counter-clockwise": "anticlockwise",
	"clock-wise": "clockwise", "anti-clockwise": "anticlockwise",
	"cost-benefit": "cost benefit", "supply-side": "supply side",
	"demand-side": "demand side", "trade-off": "tradeoff",
	"trade-offs": "tradeoffs", "trade-off's": "tradeoffs",
	"feed-back": "feedback", "feed-forward": "feedforward",
	"by-product": "byproduct", "by-products": "byproducts",
	"under-way": "underway", "over-all": "overall",
	"up-to-date": "current", "out-of-date": "outdated",
	"cutting-edge": "leading", "front-line": "frontline",
	"point-of-view": "viewpoint", "case-by-case": "individual",
	"day-dream": "daydream", "break-down": "breakdown",
	"break-even": "breakeven", "start-up": "startup",
	"start-ups": "startups", "run-away": "runaway",
	"stand-alone": "standalone", "built-in": "built in",
	"cast-off": "discarded", "left-over": "leftover",
	"two-thirds": "two thirds", "three-quarters": "three quarters",
	"one-half": "one half", "two-fifths": "two fifths",
	"semi-conductor": "semiconductor", "semi-final": "semifinal",
	"micro-organism": "microorganism", "micro-organisms": "microorganisms",
	"macro-molecule": "macromolecule", "macro-molecules": "macromolecules",
	"auto-catalytic": "autocatalytic", "bio-chemistry": "biochemistry",
	"bio-chemical": "biochemical", "electro-chemical": "electrochemical",
	"electro-chemistry": "electrochemistry", "electro-magnetic": "electromagnetic",
	"electro-magnetism": "electromagnetism", "thermo-dynamics": "thermodynamics",
	"thermo-dynamic": "thermodynamic", "hydro-carbon": "hydrocarbon",
	"hydro-carbons": "hydrocarbons", "photo-synthesis": "photosynthesis",
	"chloro-phyll": "chlorophyll", ",proto-zoa": "protozoa",
	"counter-example": "counterexample", "counter-examples": "counterexamples",
	"non-zero": "nonzero", "non-negative": "nonnegative",
	"non-trivial": "nontrivial", "non-renewable": "nonrenewable",
	"re-newable": "renewable", "pre-requisite": "prerequisite",
	"pre-requisites": "prerequisites", "post-office": "post office",
	"sub-set": "subset", "sub-sets": "subsets", "sub-script": "subscript",
	"super-script": "superscript", "sub-topic": "subtopic",
	"sub-topics": "subtopics", "sub-unit": "subunit",
}

// Clean enforces the output contract on one text run. Idempotent.
func Clean(s string) string {
	if s == "" {
		return s
	}
	s = dashes.Replace(s)
	// word compounds first (curated rewrites), case preserved on the tail
	low := strings.ToLower(s)
	for hyph, fix := range wordHyphens {
		if strings.Contains(low, hyph) {
			s = strings.ReplaceAll(s, hyph, fix)
			low = strings.ToLower(s)
		}
	}
	// any surviving word hyphen: join the halves ("anti-lock" -> "antilock")
	for hyphenWord.MatchString(s) {
		s = hyphenWord.ReplaceAllString(s, "$1$2")
	}
	// "3-fold", "10-week": number joined to a word -> space
	s = hyphenNumWord.ReplaceAllString(s, "$1 $2")
	// surviving math hyphens: unicode minus
	s = hyphenMath.ReplaceAllString(s, "$1\u2212$2")
	// stray hyphens around parentheses or at line starts
	s = strings.ReplaceAll(s, " - ", ", ")
	s = strings.ReplaceAll(s, "- ", "")
	s = strings.ReplaceAll(s, " -", "")
	s = multiSpace.ReplaceAllString(s, " ")
	return strings.TrimSpace(s)
}

/* ------------------------- unicode maths -------------------------- */

const superDigits = "\u2070\u00b9\u00b2\u00b3\u2074\u2075\u2076\u2077\u2078\u2079"

// Sup renders the digits/exponent signs of s as unicode superscripts:
// Sup("2") = ², Sup("−1") = ⁻¹. Only digits, + and the unicode minus
// map; everything else is dropped.
func Sup(s string) string {
	var b strings.Builder
	for _, ch := range s {
		switch {
		case ch >= '0' && ch <= '9':
			b.WriteByte(superDigits[ch-'0'])
		case ch == '-':
			b.WriteRune('\u207b') // superscript minus
		case ch == '+':
			b.WriteRune('\u207a')
		case ch == 'n':
			b.WriteRune('\u207f')
		}
	}
	return b.String()
}

const subDigits = "\u2080\u2081\u2082\u2083\u2084\u2085\u2086\u2087\u2088\u2089"

// Sub renders digits of s as unicode subscripts: Sub("2") = ₂.
func Sub(s string) string {
	var b strings.Builder
	for _, ch := range s {
		if ch >= '0' && ch <= '9' {
			b.WriteByte(subDigits[ch-'0'])
		} else if ch == 'n' {
			b.WriteRune('\u2099')
		} else if ch == 'm' {
			b.WriteRune('\u2098')
		} else if ch == 'x' {
			b.WriteRune('\u2093')
		}
	}
	return b.String()
}

/* -------------------------- LaTeX helpers ------------------------- */

// Math wraps s as inline LaTeX: \( s \). The web renderer routes it
// through KaTeX, so \frac stacks vertically as the founder demands.
func Math(s string) string { return `\(` + s + `\)` }

// MathD wraps s as display LaTeX: \[ s \].
func MathD(s string) string { return `\[` + s + `\]` }

// Frac builds a stacked fraction: Frac("dy","dx") -> \(\frac{dy}{dx}\).
func Frac(num, den string) string { return Math(`\frac{` + num + `}{` + den + `}`) }

// FracRaw builds a bare \frac for embedding inside another Math span.
func FracRaw(num, den string) string { return `\frac{` + num + `}{` + den + `}` }

// Pow builds x raised to a unicode exponent OUTSIDE latex (plain text
// runs): Pow("x","2") -> x². Inside LaTeX spans use ^ directly.
func Pow(base, exp string) string { return base + Sup(exp) }

// Sqrt builds a LaTeX radical: Sqrt("x") -> \( \sqrt{x} \).
func Sqrt(s string) string { return Math(`\sqrt{` + s + `}`) }

// Times is the unicode multiplication sign.
const Times = "\u00d7"

// PlusMinus is the unicode plus or minus sign.
const PlusMinus = "\u00b1"

// UMinus is the unicode minus sign (never a hyphen).
const UMinus = "\u2212"
