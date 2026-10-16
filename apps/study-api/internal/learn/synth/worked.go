package synth

// worked.go: arithmetic checked calculation generators. Every numeric
// answer is COMPUTED, never asserted, and every distractor is the
// result of a named common error, so the options are close, related
// and explainable (the founder: options must be related, equations
// must look professional, x2 must be x², fractions must stack).
//
// Compound units are rendered as stacked LaTeX fractions so nothing
// ever looks like slanted phone input.

import (
        "fmt"
        "strconv"
        "strings"
)

// ex is one generated calculation.
type ex struct {
        stem    string    // question text with LaTeX spans
        answer  string    // correct option text
        wrongs  [3]string // distractors, each a named common error result
        reasons [3]string // why each distractor tempts students
        steps   []string  // worked steps for lesson notes (LaTeX ok)
        topic   string    // sub label, e.g. "differentiation"
}

// unitRate renders a compound unit as a stacked LaTeX fraction.
func unitRate(num, den string) string {
        return Math(`\mathrm{\frac{` + num + `}{` + den + `}}`)
}

// unitRateV renders value plus a stacked compound unit.
func unitRateV(v int, num, den string) string {
        return fmt.Sprintf("%d\\,%s", v, unitRate(num, den))
}

/* --------------------------- mathematics -------------------------- */

func exDiffQuad(g *RNG) *ex {
        a := g.Int(2, 6)
        b := g.Int(1, 9)
        c := g.Int(0, 9)
        x := g.Int(1, 5)
        d := 2*a*x + b
        return &ex{
                stem: fmt.Sprintf("If %s, find the value of the derivative at %s.",
                        Math(fmt.Sprintf("f(x) = %dx^{2} + %dx + %d", a, b, c)),
                        Math(fmt.Sprintf("x = %d", x))),
                answer: fmt.Sprintf("%d", d),
                wrongs: [3]string{
                        fmt.Sprintf("%d", d-a),
                        fmt.Sprintf("%d", d+1),
                        fmt.Sprintf("%d", a*x*x + b*x + c),
                },
                reasons: [3]string{
                        "forgetting that the power rule doubles the coefficient of the squared term",
                        "a small arithmetic slip when adding the constant term",
                        "substituting into f instead of the derivative",
                },
                steps: []string{
                        "State the power rule: " + Math(`\frac{d}{dx}\left( ax^{2} \right) = 2ax`) + ", so the derivative of the first term is " + Math(fmt.Sprintf("%dx", 2*a)) + ".",
                        fmt.Sprintf("The derivative of %dx is %d, and the constant %d differentiates to zero.", b, b, c),
                        fmt.Sprintf("So the derivative is %s.", Math(fmt.Sprintf("f'(x) = %dx + %d", 2*a, b))),
                        fmt.Sprintf("Substitute %s: the value is %d \u00d7 %d + %d = %d.", Math(fmt.Sprintf("x = %d", x)), 2*a, x, b, d),
                },
                topic: "differentiation",
        }
}

func exIntegLin(g *RNG) *ex {
        a := g.Int(2, 8)
        if a%2 != 0 {
                a++
        }
        b := g.Int(1, 9)
        k := g.Int(2, 6)
        val := (a*k*k)/2 + b*k
        return &ex{
                stem: fmt.Sprintf("Evaluate %s.",
                        Math(fmt.Sprintf(`\int_{0}^{%d}\left( %dx + %d \right)dx`, k, a, b))),
                answer: fmt.Sprintf("%d", val),
                wrongs: [3]string{
                        fmt.Sprintf("%d", a*k*k + b*k),
                        fmt.Sprintf("%d", (a*k*k)/2),
                        fmt.Sprintf("%d", val+b*k),
                },
                reasons: [3]string{
                        "omitting the factor one half from integrating the linear term",
                        "integrating only the first term and forgetting the constant",
                        "adding one extra contribution of the constant term",
                },
                steps: []string{
                        "Integrate term by term: " + Math(fmt.Sprintf(`\int %dx\,dx = %dx^{2}`, a, a/2)) + " and " + Math(fmt.Sprintf(`\int %d\,dx = %dx`, b, b)) + ".",
                        fmt.Sprintf("The antiderivative is %s.", Math(fmt.Sprintf("F(x) = %dx^{2} + %dx", a/2, b))),
                        fmt.Sprintf("Evaluate F(%d) minus F(0): %d \u00d7 %d^{2} + %d \u00d7 %d = %d.", k, a/2, k, b, k, val),
                        fmt.Sprintf("So the value of the definite integral is %d.", val),
                },
                topic: "integration",
        }
}

func exArithSeries(g *RNG) *ex {
        a := g.Int(2, 9)
        d := g.Int(2, 7)
        n := g.Int(5, 12)
        if n%2 != 0 {
                n++ // keep n(a+l) even for a clean sum
        }
        l := a + (n-1)*d
        sum := n * (a + l) / 2
        return &ex{
                stem: fmt.Sprintf("An arithmetic progression has first term %d and common difference %d. Find the sum of the first %d terms.", a, d, n),
                answer: fmt.Sprintf("%d", sum),
                wrongs: [3]string{
                        fmt.Sprintf("%d", n*l),
                        fmt.Sprintf("%d", sum-d),
                        fmt.Sprintf("%d", sum+d),
                },
                reasons: [3]string{
                        "multiplying the number of terms by the last term without averaging",
                        "a counting slip of one common difference",
                        "a counting slip in the other direction",
                },
                steps: []string{
                        fmt.Sprintf("The last term is l = a + (n \u2212 1)d = %d + %d \u00d7 %d = %d.", a, n-1, d, l),
                        "Apply the sum formula " + Math(`S_n = \frac{n(a + l)}{2}`) + ".",
                        fmt.Sprintf("Substitute: S = %d \u00d7 (%d + %d) \u00f7 2 = %d.", n, a, l, sum),
                },
                topic: "sequences",
        }
}

func exLinearSolve(g *RNG) *ex {
        a := g.Int(2, 9)
        x := g.Int(2, 12)
        b := g.Int(1, 15)
        c := a*x + b
        return &ex{
                stem: fmt.Sprintf("Solve for x: %s.", Math(fmt.Sprintf("%dx + %d = %d", a, b, c))),
                answer: fmt.Sprintf("%d", x),
                wrongs: [3]string{
                        fmt.Sprintf("%d", x+b),
                        fmt.Sprintf("%d", c-a),
                        fmt.Sprintf("%d", c/a),
                },
                reasons: [3]string{
                        "moving the constant to the wrong side",
                        "dividing by the coefficient before isolating the constant term",
                        "ignoring the constant term completely",
                },
                steps: []string{
                        fmt.Sprintf("Move the constant: %s.", Math(fmt.Sprintf("%dx = %d - %d = %d", a, c, b, c-b))),
                        fmt.Sprintf("Divide both sides by %d: x = %d.", a, x),
                        fmt.Sprintf("Check by substitution: %d \u00d7 %d + %d = %d. Correct.", a, x, b, c),
                },
                topic: "linear equations",
        }
}

func exMatrixDet(g *RNG) *ex {
        a := g.Int(1, 9)
        b := g.Int(1, 9)
        c := g.Int(1, 9)
        d := g.Int(1, 9)
        det := a*d - b*c
        return &ex{
                stem: fmt.Sprintf("Find the determinant of the matrix with first row (%d, %d) and second row (%d, %d).", a, b, c, d),
                answer: fmt.Sprintf("%d", det),
                wrongs: [3]string{
                        fmt.Sprintf("%d", a*d + b*c),
                        fmt.Sprintf("%d", a*c - b*d),
                        fmt.Sprintf("%d", a*d),
                },
                reasons: [3]string{
                        "adding the cross products instead of subtracting",
                        "multiplying the wrong pairing of entries",
                        "forgetting the second cross product",
                },
                steps: []string{
                        "For a 2 \u00d7 2 matrix the determinant is ad \u2212 bc.",
                        fmt.Sprintf("Here: (%d \u00d7 %d) \u2212 (%d \u00d7 %d) = %d \u2212 %d = %d.", a, d, b, c, a*d, b*c, det),
                },
                topic: "matrices",
        }
}

func exProbability(g *RNG) *ex {
        red := g.Int(2, 6)
        blue := g.Int(2, 6)
        green := g.Int(2, 6)
        total := red + blue + green
        r := reduce(red, total)
        return &ex{
                stem: fmt.Sprintf("A bag contains %d red, %d blue and %d green balls, identical apart from colour. One ball is drawn at random. What is the probability that it is red?", red, blue, green),
                answer: Math(FracRaw(fmt.Sprintf("%d", r[0]), fmt.Sprintf("%d", r[1]))),
                wrongs: [3]string{
                        Math(FracRaw(fmt.Sprintf("%d", blue), fmt.Sprintf("%d", total))),
                        Math(FracRaw(fmt.Sprintf("%d", red), fmt.Sprintf("%d", total-blue))),
                        Math(FracRaw(fmt.Sprintf("%d", total), fmt.Sprintf("%d", red))),
                },
                reasons: [3]string{
                        "counting the wrong colour",
                        "dividing by a wrong total that forgets the third colour",
                        "inverting the ratio",
                },
                steps: []string{
                        fmt.Sprintf("Total balls: %d + %d + %d = %d.", red, blue, green, total),
                        "Probability " + Math(`P(\text{red}) = \frac{\text{red}}{\text{total}}`) + fmt.Sprintf(" = %s.", Math(FracRaw(fmt.Sprintf("%d", r[0]), fmt.Sprintf("%d", r[1])))),
                },
                topic: "probability",
        }
}

/* ----------------------------- physics ---------------------------- */

func exOhm(g *RNG) *ex {
        i := g.Int(2, 9)
        r := g.Int(3, 12)
        v := i * r
        return &ex{
                stem: fmt.Sprintf("A current of %d A flows through a resistor of %d \u03a9. Find the potential difference across it.", i, r),
                answer: fmt.Sprintf("%d V", v),
                wrongs: [3]string{fmt.Sprintf("%d V", i+r), fmt.Sprintf("%d V", v/2), fmt.Sprintf("%d V", r)},
                reasons: [3]string{
                        "adding current and resistance instead of multiplying",
                        "halving the product for no physical reason",
                        "quoting the resistance value instead of computing the voltage",
                },
                steps: []string{
                        "Ohm law: " + Math(`V = IR`) + ".",
                        fmt.Sprintf("Substitute: V = %d \u00d7 %d = %d V.", i, r, v),
                },
                topic: "current electricity",
        }
}

func exKinematics(g *RNG) *ex {
        u := g.Int(0, 10)
        a := g.Int(2, 6)
        t := g.Int(2, 8)
        if (a*t*t)%2 != 0 {
                t++
        }
        s := u*t + (a*t*t)/2
        return &ex{
                stem: fmt.Sprintf("A body starts with velocity %d %s and accelerates uniformly at %d %s for %d s. What distance does it cover?",
                        u, unitRate("m", "s"), a, unitRate("m", "s^{2}"), t),
                answer: fmt.Sprintf("%d m", s),
                wrongs: [3]string{
                        fmt.Sprintf("%d m", u*t),
                        fmt.Sprintf("%d m", (a*t*t)/2),
                        fmt.Sprintf("%d m", s+u*t),
                },
                reasons: [3]string{
                        "using only the uniform motion term and ignoring acceleration",
                        "using only the acceleration term and ignoring the initial motion",
                        "adding the initial motion contribution twice",
                },
                steps: []string{
                        "Use " + Math(`s = ut + \frac{1}{2}at^{2}`) + ".",
                        fmt.Sprintf("First term: ut = %d \u00d7 %d = %d m.", u, t, u*t),
                        fmt.Sprintf("Second term: \u00bd \u00d7 %d \u00d7 %d\u00b2 = %d m.", a, t, (a*t*t)/2),
                        fmt.Sprintf("Total distance s = %d + %d = %d m.", u*t, (a*t*t)/2, s),
                },
                topic: "kinematics",
        }
}

func exDensity(g *RNG) *ex {
        d := g.Int(2, 12)
        v := g.Int(2, 9)
        m := d * v
        return &ex{
                stem: fmt.Sprintf("A block of mass %d kg occupies %d m%s. Find its density.", m, v, Sup("3")),
                answer: fmt.Sprintf("%d kg per m%s", d, Sup("3")),
                wrongs: [3]string{
                        fmt.Sprintf("%d kg per m%s", v, Sup("3")),
                        fmt.Sprintf("%d kg per m%s", m+v, Sup("3")),
                        fmt.Sprintf("%d kg per m%s", d*2, Sup("3")),
                },
                reasons: [3]string{
                        "quoting the volume instead of the ratio",
                        "adding mass and volume instead of dividing",
                        "doubling the correct quotient",
                },
                steps: []string{
                        "Density " + Math(`\rho = \frac{m}{V}`) + ".",
                        fmt.Sprintf("Substitute: density = %d \u00f7 %d = %d kg per m\u00b3.", m, v, d),
                },
                topic: "density",
        }
}

func exWave(g *RNG) *ex {
        f := g.Int(2, 12) * 5
        wl := g.Int(1, 4)
        v := f * wl
        return &ex{
                stem: fmt.Sprintf("A wave of frequency %d Hz has wavelength %d m. Find its speed.", f, wl),
                answer: fmt.Sprintf("%d %s", v, unitRate("m", "s")),
                wrongs: [3]string{
                        fmt.Sprintf("%d %s", f+wl, unitRate("m", "s")),
                        fmt.Sprintf("%d %s", f-wl, unitRate("m", "s")),
                        fmt.Sprintf("%d %s", v/2, unitRate("m", "s")),
                },
                reasons: [3]string{
                        "adding frequency and wavelength",
                        "subtracting instead of multiplying",
                        "halving the correct product",
                },
                steps: []string{
                        "Wave equation: " + Math(`v = f\lambda`) + ".",
                        fmt.Sprintf("Substitute: v = %d \u00d7 %d = %d m per s.", f, wl, v),
                },
                topic: "waves",
        }
}

/* --------------------------- chemistry ---------------------------- */

func exMoles(g *RNG) *ex {
        mol := g.Int(2, 9)
        var mm int
        switch g.Intn(4) {
        case 0:
                mm = 40
        case 1:
                mm = 44
        case 2:
                mm = 58
        default:
                mm = 32
        }
        mass := mol * mm
        return &ex{
                stem: fmt.Sprintf("How many moles are present in %d g of a compound whose molar mass is %d g per mol?", mass, mm),
                answer: fmt.Sprintf("%d mol", mol),
                wrongs: [3]string{
                        fmt.Sprintf("%d mol", mass+mm),
                        fmt.Sprintf("%d mol", mm),
                        fmt.Sprintf("%d mol", mass/(mm+1)),
                },
                reasons: [3]string{
                        "adding mass and molar mass instead of dividing",
                        "quoting the molar mass itself",
                        "a division slip using a slightly wrong molar mass",
                },
                steps: []string{
                        "Mole relation: " + Math(`n = \frac{m}{M}`) + ".",
                        fmt.Sprintf("Substitute: n = %d \u00f7 %d = %d mol.", mass, mm, mol),
                },
                topic: "the mole concept",
        }
}

func exMolarity(g *RNG) *ex {
        vol := g.Int(2, 5)
        conc := g.Int(1, 6)
        mol := conc * vol
        return &ex{
                stem: fmt.Sprintf("%d mol of solute is dissolved to make %d dm%s of solution. Find the concentration in mol per dm%s.",
                        mol, vol, Sup("3"), Sup("3")),
                answer: fmt.Sprintf("%d mol per dm%s", conc, Sup("3")),
                wrongs: [3]string{
                        fmt.Sprintf("%d mol per dm%s", mol+vol, Sup("3")),
                        fmt.Sprintf("%d mol per dm%s", mol*vol, Sup("3")),
                        fmt.Sprintf("%d mol per dm%s", vol, Sup("3")),
                },
                reasons: [3]string{
                        "adding instead of dividing",
                        "multiplying instead of dividing",
                        "quoting the volume instead of the ratio",
                },
                steps: []string{
                        "Concentration " + Math(`C = \frac{n}{V}`) + ".",
                        fmt.Sprintf("Substitute: C = %d \u00f7 %d = %d mol per dm\u00b3.", mol, vol, conc),
                },
                topic: "solutions",
        }
}

func exYield(g *RNG) *ex {
        y := g.Int(3, 9) * 10
        theo := g.Int(2, 9) * 10
        act := theo * y / 100
        return &ex{
                stem: fmt.Sprintf("A reaction should theoretically produce %d g of product but only %d g is obtained. Find the percentage yield.", theo, act),
                answer: fmt.Sprintf("%d%%", y),
                wrongs: [3]string{
                        fmt.Sprintf("%d%%", theo-act),
                        fmt.Sprintf("%d%%", act+theo),
                        fmt.Sprintf("%d%%", y/2),
                },
                reasons: [3]string{
                        "subtracting masses instead of taking a percentage",
                        "adding the masses for no reason",
                        "halving the correct percentage",
                },
                steps: []string{
                        "Percentage yield " + Math(`= \frac{\text{actual}}{\text{theoretical}} \times 100\%`) + ".",
                        fmt.Sprintf("Substitute: %d \u00f7 %d \u00d7 100 = %d percent.", act, theo, y),
                },
                topic: "percentage yield",
        }
}

/* --------------------------- statistics --------------------------- */

func exMean(g *RNG) *ex {
        n := 5
        vals := make([]int, n)
        sum := 0
        for i := range vals {
                vals[i] = g.Int(3, 40)
                sum += vals[i]
        }
        rem := sum % n
        vals[0] += (n - rem)
        sum += n - rem
        mean := sum / n
        return &ex{
                stem: fmt.Sprintf("Find the mean of the numbers %d, %d, %d, %d and %d.", vals[0], vals[1], vals[2], vals[3], vals[4]),
                answer: fmt.Sprintf("%d", mean),
                wrongs: [3]string{
                        fmt.Sprintf("%d", sum),
                        fmt.Sprintf("%d", mean+2),
                        fmt.Sprintf("%d", vals[2]),
                },
                reasons: [3]string{
                        "giving the total instead of the average",
                        "a division slip when computing the average",
                        "quoting a middle value instead of computing",
                },
                steps: []string{
                        fmt.Sprintf("Add the values: the sum is %d.", sum),
                        fmt.Sprintf("Divide by the count %d: mean = %d \u00f7 %d = %d.", n, sum, n, mean),
                },
                topic: "the mean",
        }
}

/* --------------------------- economics ---------------------------- */

func exElasticity(g *RNG) *ex {
        dq := g.Int(1, 3) * 5
        dp := 5
        e := dq / dp
        return &ex{
                stem: fmt.Sprintf("When price rose by %d percent, quantity demanded fell by %d percent. Find the price elasticity of demand.", dp, dq),
                answer: fmt.Sprintf("%d", e),
                wrongs: [3]string{
                        fmt.Sprintf("%d", dq+dp),
                        fmt.Sprintf("%d", e*2),
                        fmt.Sprintf("%d", e/2),
                },
                reasons: [3]string{
                        "adding the percentages instead of dividing",
                        "doubling the correct ratio",
                        "halving the correct ratio",
                },
                steps: []string{
                        "Elasticity " + Math(`= \frac{\%\Delta Q}{\%\Delta P}`) + ".",
                        fmt.Sprintf("Substitute: %d \u00f7 %d = %d.", dq, dp, e),
                },
                topic: "elasticity",
        }
}

func exMultiplier(g *RNG) *ex {
        // only MPC values whose reciprocal is a whole number keep the
        // arithmetic exact: 50 gives 2, 75 gives 4, 80 gives 5, 90 gives 10
        mpcs := [4]int{50, 75, 80, 90}
        mpc := mpcs[g.Intn(4)]
        k := 100 / (100 - mpc)
        return &ex{
                stem: fmt.Sprintf("In an economy the marginal propensity to consume is %d percent. Find the value of the simple multiplier.", mpc),
                answer: fmt.Sprintf("%d", k),
                wrongs: [3]string{
                        fmt.Sprintf("%d", mpc/10),
                        fmt.Sprintf("%d", k+1),
                        fmt.Sprintf("%d", 100-mpc),
                },
                reasons: [3]string{
                        "using the MPC value directly instead of the formula",
                        "adding one after computing the reciprocal",
                        "quoting the marginal propensity to save",
                },
                steps: []string{
                        "Multiplier " + Math(`k = \frac{1}{1 - MPC}`) + ".",
                        fmt.Sprintf("Substitute: k = 1 \u00f7 (1 \u2212 %d \u00f7 100) = %d.", mpc, k),
                },
                topic: "the multiplier",
        }
}

/* ------------------------- engineering ---------------------------- */

func exStress(g *RNG) *ex {
        a := g.Int(2, 6) * 50
        s := g.Int(2, 9) * 10
        f := a * s
        return &ex{
                stem: fmt.Sprintf("A tensile force of %d N acts on a bar of cross sectional area %d mm%s. Find the direct stress.", f, a, Sup("2")),
                answer: fmt.Sprintf("%d N per mm%s", s, Sup("2")),
                wrongs: [3]string{
                        fmt.Sprintf("%d N per mm%s", s/2, Sup("2")),
                        fmt.Sprintf("%d N per mm%s", s+10, Sup("2")),
                        fmt.Sprintf("%d N per mm%s", f/a+s, Sup("2")),
                },
                reasons: [3]string{
                        "halving the correct quotient",
                        "an arithmetic slip of one step on the area",
                        "adding an extra step after dividing",
                },
                steps: []string{
                        "Stress " + Math(`\sigma = \frac{F}{A}`) + ".",
                        fmt.Sprintf("Substitute: stress = %d \u00f7 %d = %d N per mm\u00b2.", f, a, s),
                },
                topic: "stress",
        }
}

func exPowerElec(g *RNG) *ex {
        v := g.Int(4, 24) * 5
        i := g.Int(2, 9)
        p := v * i
        return &ex{
                stem: fmt.Sprintf("An appliance draws %d A at %d V. Find the power it consumes.", i, v),
                answer: fmt.Sprintf("%d W", p),
                wrongs: [3]string{fmt.Sprintf("%d W", v+i), fmt.Sprintf("%d W", v), fmt.Sprintf("%d W", p/2)},
                reasons: [3]string{
                        "adding voltage and current",
                        "quoting the voltage instead of computing power",
                        "halving the correct product",
                },
                steps: []string{
                        "Power " + Math(`P = VI`) + ".",
                        fmt.Sprintf("Substitute: P = %d \u00d7 %d = %d W.", v, i, p),
                },
                topic: "electrical power",
        }
}

/* ------------------------- computing ------------------------------ */

func exBinary(g *RNG) *ex {
        n := g.Int(5, 63)
        bin := fmt.Sprintf("%b", n)
        w2 := n + 16
        if w2 == n*2 {
                w2 = n + 7
        }
        return &ex{
                stem: fmt.Sprintf("Convert the binary number %s to denary.", bin),
                answer: fmt.Sprintf("%d", n),
                wrongs: [3]string{
                        fmt.Sprintf("%d", n-1),
                        fmt.Sprintf("%d", w2),
                        fmt.Sprintf("%d", n*2),
                },
                reasons: [3]string{
                        "missing the contribution of one place value",
                        "slipping a place value by sixteen",
                        "shifting the value one extra place",
                },
                steps: []string{
                        fmt.Sprintf("Write the place values of %s as powers of two.", bin),
                        fmt.Sprintf("Add the place values where the digit is 1: the total is %d.", n),
                },
                topic: "number systems",
        }
}

/* --------------------------- helpers ------------------------------ */

var generators = map[string][]func(*RNG) *ex{
        "math":    {exDiffQuad, exIntegLin, exArithSeries, exLinearSolve, exMatrixDet, exProbability},
        "physics": {exOhm, exKinematics, exDensity, exWave},
        "chem":    {exMoles, exMolarity, exYield},
        "stats":   {exMean, exProbability, exElasticity},
        "econ":    {exElasticity, exMultiplier, exMean},
        "eng":     {exStress, exPowerElec, exOhm, exKinematics},
        "cs":      {exBinary, exProbability},
}

// workedExample picks one generator for the kind and runs it.
func workedExample(kind string, g *RNG) *ex {
        pool := generators[kind]
        if len(pool) == 0 {
                return nil
        }
        return dedupeEx(pool[g.Intn(len(pool))](g))
}

// reduce reduces a fraction to lowest terms.
func reduce(a, b int) [2]int {
        for i := b; i > 1; i-- {
                if a%i == 0 && b%i == 0 {
                        return [2]int{a / i, b / i}
                }
        }
        return [2]int{a, b}
}

// dedupeEx guarantees the three distractors are distinct from the
// answer and from each other. A colliding distractor is bumped by one
// on its leading number (still a plausible near miss), so no quiz item
// ever shows two identical options.
func dedupeEx(e *ex) *ex {
        seen := map[string]bool{e.answer: true}
        for i := range e.wrongs {
                for seen[e.wrongs[i]] {
                        e.wrongs[i] = bumpNum(e.wrongs[i])
                }
                seen[e.wrongs[i]] = true
        }
        return e
}

// bumpNum increments the first number found in s, preserving the rest
// ("12 V" -> "13 V", "50%" -> "51%"). Non numeric strings pass back
// with a tilde guard.
func bumpNum(s string) string {
        digits := "0123456789"
        start := -1
        for i, ch := range s {
                if strings.ContainsRune(digits, ch) {
                        start = i
                        break
                }
        }
        if start < 0 {
                return s + "b"
        }
        end := start
        for end < len(s) && strings.ContainsRune(digits, rune(s[end])) {
                end++
        }
        n, err := strconv.Atoi(s[start:end])
        if err != nil {
                return s + "b"
        }
        return s[:start] + strconv.Itoa(n+1) + s[end:]
}
