// drawings.go — the curated figure library. Real structural-formula
// SVGs for the flagship senior-secondary topics (founder directive:
// organic chemistry and waves must carry actual drawings). All figures
// draw in currentColor so they follow the light/dark tier; strokes are
// 2px, labels 13px, viewBox 0 0 420 240 unless noted.
package learn

type DrawingRef struct {
        ID    string `json:"id"`
        Title string `json:"title"`
        SVG   string `json:"svg"`
}

const svgOpen = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 420 240" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" font-family="inherit">`
const svgOpenWide = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 240" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" font-family="inherit">`

func svg(text string) string {
        return svgOpen + text + `</svg>`
}

func svgWide(text string) string {
        return svgOpenWide + text + `</svg>`
}

// txt is a stroked-none label helper.
func txt(x, y int, s string) string {
        return `<text x="` + itoa(x) + `" y="` + itoa(y) + `" fill="currentColor" stroke="none" font-size="13" text-anchor="middle">` + s + `</text>`
}

func itoa(n int) string {
        if n == 0 {
                return "0"
        }
        neg := n < 0
        if neg {
                n = -n
        }
        var b [8]byte
        i := len(b)
        for n > 0 {
                i--
                b[i] = byte('0' + n%10)
                n /= 10
        }
        if neg {
                i--
                b[i] = '-'
        }
        return string(b[i:])
}

var DrawingLibrary = map[string]DrawingRef{
        // ─── Organic chemistry: displayed structural formulas ────────────────
        "alkane-methane": {
                ID: "alkane-methane", Title: "Methane (CH₄) — displayed structural formula",
                SVG: svg(
                        // central C with four bonds
                        `<path d="M210 110 L160 60"/><path d="M210 110 L260 60"/><path d="M210 110 L160 160"/><path d="M210 110 L260 160"/>` +
                                txt(210, 118, "C") + txt(150, 56, "H") + txt(272, 56, "H") + txt(148, 168, "H") + txt(272, 168, "H") +
                                txt(210, 205, "Four single covalent bonds — a saturated tetrahedral molecule (109.5° bond angle)."),
                ),
        },
        "alkane-ethane": {
                ID: "alkane-ethane", Title: "Ethane (C₂H₆) — displayed structural formula",
                SVG: svg(
                        `<path d="M150 120 L270 120"/><path d="M150 120 L150 70"/><path d="M150 120 L110 145"/><path d="M150 120 L190 145"/>` +
                                `<path d="M270 120 L270 70"/><path d="M270 120 L230 145"/><path d="M270 120 L310 145"/>` +
                                txt(150, 128, "C") + txt(270, 128, "C") +
                                txt(150, 62, "H") + txt(100, 152, "H") + txt(198, 152, "H") +
                                txt(270, 62, "H") + txt(222, 152, "H") + txt(318, 152, "H") +
                                txt(210, 205, "Two carbons joined by a single bond — the second member of the alkane homologous series (CₙH₂ₙ₊₂)."),
                ),
        },
        "alkene-ethene": {
                ID: "alkene-ethene", Title: "Ethene (C₂H₄) — displayed structural formula",
                SVG: svg(
                        `<path d="M170 120 L250 120"/><path d="M175 110 L245 110"/>` +
                                `<path d="M170 120 L170 70"/><path d="M170 120 L130 150"/><path d="M250 120 L250 70"/><path d="M250 120 L290 150"/>` +
                                txt(170, 130, "C") + txt(250, 130, "C") +
                                txt(170, 62, "H") + txt(120, 158, "H") + txt(250, 62, "H") + txt(300, 158, "H") +
                                txt(210, 205, "The C=C double bond makes it UNSATURATED — ethene decolourises bromine water quickly."),
                ),
        },
        "alkanol-ethanol": {
                ID: "alkanol-ethanol", Title: "Ethanol (C₂H₅OH) — displayed structural formula",
                SVG: svg(
                        `<path d="M140 120 L210 120"/><path d="M210 120 L280 120"/><path d="M280 120 L280 75"/>` +
                                `<path d="M140 120 L140 75"/><path d="M140 120 L105 150"/><path d="M140 120 L175 150"/>` +
                                `<path d="M210 120 L210 160"/>` +
                                txt(140, 128, "C") + txt(210, 128, "C") + txt(287, 128, "O") +
                                txt(287, 68, "H") +
                                txt(140, 68, "H") + txt(96, 158, "H") + txt(184, 168, "H") + txt(217, 168, "H") +
                                txt(210, 205, "The –OH (hydroxyl) functional group on the end carbon makes it an alkanol."),
                ),
        },
        "alkanoic-acid-ethanoic": {
                ID: "alkanoic-acid-ethanoic", Title: "Ethanoic acid (CH₃COOH) — displayed structural formula",
                SVG: svg(
                        `<path d="M150 130 L220 130"/><path d="M220 130 L290 130"/><path d="M290 130 L290 82"/><path d="M290 130 L340 158"/>` +
                                `<path d="M150 130 L150 85"/><path d="M150 130 L115 160"/><path d="M150 130 L185 160"/>` +
                                `<path d="M220 130 L220 172"/>` +
                                txt(150, 138, "C") + txt(220, 138, "C") + txt(290, 140, "C") + txt(290, 74, "O") + txt(350, 168, "O–H") +
                                txt(150, 78, "H") + txt(106, 168, "H") + txt(192, 180, "H") + txt(227, 180, "H") +
                                txt(210, 213, "The –COOH (carboxyl) group: C=O double bond plus O–H — the alkanoic acid functional group."),
                ),
        },
        "esterification": {
                ID: "esterification", Title: "Esterification — ethanol + ethanoic acid → ethyl ethanoate + water",
                SVG: svgWide(
                        // ethanol condensed displayed
                        txt(30, 120, "C₂H₅–OH") +
                                txt(110, 124, "+") +
                                txt(190, 120, "CH₃COOH") +
                                // equilibrium arrow + catalyst
                                `<path d="M260 118 L320 118"/><path d="M312 112 L322 118 L312 124"/>` +
                                txt(290, 105, "conc. H₂SO₄") + txt(290, 140, "heat") +
                                txt(375, 120, "CH₃COOC₂H₅") + txt(470, 124, "+") + txt(500, 120, "H₂O") +
                                txt(260, 205, "Sweet-smelling ester + water. The acid's –OH leaves with the alcohol's H — a condensation reaction."),
                ),
        },
        "benzene": {
                ID: "benzene", Title: "Benzene (C₆H₆) — the delocalised ring",
                SVG: svg(
                        `<path d="M210 45 L285 87 L285 173 L210 215 L135 173 L135 87 Z"/>` +
                                `<circle cx="210" cy="130" r="42"/>` +
                                txt(210, 38, "H") + txt(295, 82, "H") + txt(295, 182, "H") + txt(210, 232, "H") + txt(125, 182, "H") + txt(125, 82, "H") +
                                txt(210, 254, "Six carbons in a ring; the circle is the delocalised π electrons (aromatic stability)."),
                ),
        },
        "polyethene": {
                ID: "polyethene", Title: "Addition polymerisation — ethene → polyethene",
                SVG: svgWide(
                        txt(60, 110, "n CH₂=CH₂") +
                                `<path d="M150 108 L210 108"/><path d="M202 102 L212 108 L202 114"/>` +
                                txt(180, 95, "heat, pressure") + txt(180, 128, "catalyst") +
                                // repeat unit brackets
                                `<path d="M260 75 L245 75 L245 150 L260 150"/>` +
                                `<path d="M370 75 L385 75 L385 150 L370 150"/>` +
                                txt(280, 118, "– CH₂ – CH₂ –") + txt(408, 118, "n") +
                                txt(260, 205, "The C=C opens and links into a long saturated chain — an addition polymer."),
                ),
        },

        // ─── Physics: waves ───────────────────────────────────────────────────
        "wave-anatomy": {
                ID: "wave-anatomy", Title: "Anatomy of a transverse wave — amplitude, wavelength, crest, trough",
                SVG: svg(
                        `<path d="M30 120 Q 75 30 120 120 T 210 120 T 300 120 T 390 120"/>` +
                                // axis
                                `<path d="M20 120 L400 120" stroke-dasharray="5 5" stroke-width="1"/>` +
                                // amplitude arrow
                                `<path d="M120 120 L120 34"/><path d="M115 42 L120 32 L125 42"/><path d="M115 112 L120 122 L125 112"/>` +
                                txt(95, 75, "amplitude a") +
                                // wavelength bracket between crest 1 and 2
                                `<path d="M75 22 L75 14 L195 14 L195 22"/>` +
                                txt(135, 10, "wavelength λ") +
                                txt(75, 30, "crest") + txt(165, 190, "trough") +
                                txt(210, 225, "One complete wave = one wavelength λ. Height from the middle = amplitude (carries the energy)."),
                ),
        },
        "wave-types": {
                ID: "wave-types", Title: "Transverse vs longitudinal waves",
                SVG: svg(
                        txt(60, 30, "TRANSVERSE") +
                                `<path d="M30 70 Q 60 35 90 70 T 150 70 T 210 70 T 270 70"/>` +
                                txt(300, 74, "vibration ⊥ travel") +
                                txt(60, 130, "LONGITUDINAL") +
                                // compression zones: dense vertical bars, rarefaction: sparse
                                `<path d="M40 160 L40 200"/><path d="M46 160 L46 200"/><path d="M52 164 L52 196"/>` +
                                `<path d="M90 160 L90 200"/>` +
                                `<path d="M130 160 L130 200"/><path d="M136 156 L136 204"/><path d="M142 160 L142 200"/><path d="M148 164 L148 196"/>` +
                                `<path d="M190 160 L190 200"/>` +
                                `<path d="M230 160 L230 200"/><path d="M236 156 L236 204"/><path d="M242 160 L242 200"/>` +
                                `<path d="M285 160 L285 200"/>` +
                                txt(320, 184, "vibration ∥ travel") +
                                txt(140, 140, "C = compression") + txt(140, 225, "R = rarefaction") +
                                txt(150, 116, "sound is longitudinal; light and water waves are transverse"),
                ),
        },
        "wave-equation": {
                ID: "wave-equation", Title: "The wave equation v = fλ",
                SVG: svg(
                        `<path d="M30 110 Q 75 40 120 110 T 210 110 T 300 110 T 390 110"/>` +
                                `<path d="M75 92 L75 30 L195 30 L195 92"/>` +
                                txt(135, 22, "λ (metres)") +
                                `<path d="M30 190 L180 190"/><path d="M170 184 L182 190 L170 196"/>` +
                                txt(105, 212, "v (m/s)") +
                                txt(255, 195, "f = cycles per second (Hz)") +
                                txt(210, 90, "v = f × λ") +
                                txt(210, 235, "Frequency never changes between media — speed and wavelength do."),
                ),
        },
}

// drawingTriggers map topic-title/keyword fragments → drawing ids, so
// flagship topics get their figures even when the roadmap JSON omits
// explicit ids.
var drawingTriggers = map[string][]string{
        "alkane":        {"alkane-methane", "alkane-ethane"},
        "methane":       {"alkane-methane"},
        "ethane":        {"alkane-ethane"},
        "alkene":        {"alkene-ethene"},
        "ethene":        {"alkene-ethene"},
        "unsaturated":   {"alkene-ethene"},
        "alkanol":       {"alkanol-ethanol"},
        "ethanol":       {"alkanol-ethanol"},
        "alcohol":       {"alkanol-ethanol"},
        "alkanoic":      {"alkanoic-acid-ethanoic"},
        "ethanoic":      {"alkanoic-acid-ethanoic", "esterification"},
        "carboxylic":    {"alkanoic-acid-ethanoic"},
        "ester":         {"esterification"},
        "benzene":       {"benzene"},
        "aromatic":      {"benzene"},
        "polymer":       {"polyethene"},
        "polyethene":    {"polyethene"},
        "wave":          {"wave-anatomy", "wave-types"},
        "wavelength":    {"wave-anatomy"},
        "amplitude":     {"wave-anatomy"},
        "transverse":    {"wave-types"},
        "longitudinal":  {"wave-types"},
        "frequency":     {"wave-equation"},
        "wave motion":   {"wave-anatomy", "wave-equation"},
        "sound":         {"wave-types"},
        "progressive":   {"wave-anatomy", "wave-equation"},
        "stationary":    {"wave-anatomy"},
}
