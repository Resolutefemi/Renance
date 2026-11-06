// prompts.go - THE STANDARDIZED PROMPT SET of the Renance Autonomous
// Course Orchestrator (founder architecture, 2026-11-07).
//
// Six dedicated GLM 4.5 keys, one responsibility each:
//
//	Key 1 -> Part 1 lecture note   (Foundations)
//	Key 2 -> Part 2 lecture note   (Core Principles I)
//	Key 3 -> Part 3 lecture note   (Core Principles II)
//	Key 4 -> Part 4 lecture note   (Applications & Worked Examples)
//	Key 5 -> Part 5 lecture note   (Synthesis & Revision)
//	Key 6 -> The 20-question unit assessment
//
// The five note prompts are ONE template with a per-part mandate; the
// assessment prompt is its own contract. Every prompt enforces the same
// doctrine: NUC CCMAS-aligned Nigerian university standard, KaTeX for
// every mathematical expression, STRICT JSON output, and a part scope
// that never drifts outside its mandate (the founder's rule after the
// HTML/CSS-inside-Java incident: "Computer Programming II should be
// focused only on Java and C++").
package orch

import (
	"fmt"
	"strings"
)

// PartMandate is the one-paragraph scope contract of one note part.
// The five mandates partition the unit: together they cover it fully,
// separately they never overlap.
var PartMandate = [5]string{
	// Part 1
	"FOUNDATIONS: open the unit from zero. Give the precise definition of every key term the unit title implies, its nature and scope, its classification or typology, the vocabulary and notation a student needs before anything else, and close with one simple worked example or concrete illustration that anchors the definitions.",
	// Part 2
	"CORE PRINCIPLES I: teach the first half of the unit's substantive machinery - its laws, mechanisms, rules, structures, models or procedures - each derived from first principles, each illustrated with one worked example or applied case. Define every new term in full the moment it appears.",
	// Part 3
	"CORE PRINCIPLES II: teach the second half of the substantive machinery and its interconnections - the harder subtopics, relationships, comparisons and contrast tables where they aid memory, edge cases and exceptions - each with one worked example or applied case.",
	// Part 4
	"APPLICATIONS AND PROBLEM SOLVING: work through 2 to 3 fully worked, non-trivial examples, exercises or case studies - each with a problem statement, numbered step-by-step working, and a clearly stated final answer (with units where they apply). Then name the common errors and exam traps students actually fall into on this unit.",
	// Part 5
	"SYNTHESIS AND REVISION: pull the whole unit together - a compact summary of what was built across Parts 1-4, how it connects to the wider course, real Nigerian context where it naturally applies, and exam-focused revision takeaways. End by pointing to what the next unit builds on.",
}

// notesSystemPrompt is the system prompt handed to Key N for Part N.
// The output contract is exactly the R2 lesson schema: one
// {"heading","body"} object per part, headings prefixed "Part N:" in
// the style of the curated archive ("Part 1: WHAT PYTHON IS AND WHY IT
// IS POPULAR").
func notesSystemPrompt(part int, calc bool) string {
	courseType := "NON-CALCULATION course (reading, reasoning, description, law, theory or practice)"
	depth := `Depth: textbook-quality structured prose, STRICTLY MORE THAN 200 words. Write clear paragraphs; number the steps of any procedure; name the cases, statutes, thinkers, works or examples the discipline expects.`
	if calc {
		courseType = "CALCULATION course (MTS 201 standard: mathematics, computation, quantitative science or engineering)"
		depth = `Depth: rigorous academic depth, STRICTLY MORE THAN 300 words. EVERY formula, variable and expression MUST use KaTeX/LaTeX: inline $...$ or display $$...$$ - for example $x^2$, $H_2O$, $\frac{dy}{dx}$, $\lim_{x \to \infty} f(x)$, $\int_0^1 x^2\,dx$, $\sum_{i=1}^{n} i$. NEVER write bare caret or underscore notation (x^2, H_2O, 10^5) outside $...$. Include 2 to 3 fully worked, non-trivial examples: complete problem statement, numbered step-by-step mathematical working, and the final answer with its units.`
	}
	var b strings.Builder
	fmt.Fprintf(&b, "You are Key %d of the Renance Autonomous Course Orchestrator: an expert Nigerian university lecturer writing Part %d of a 5-part lecture note for ONE course unit. ", part, part)
	b.WriteString("All six orchestration keys run GLM 4.5; your key owns Part ")
	fmt.Fprintf(&b, "%d only - never write any other part.\n\n", part)
	b.WriteString("STANDARD: NUC CCMAS-aligned Nigerian university curriculum.\n")
	fmt.Fprintf(&b, "COURSE TYPE: %s.\n\n", courseType)
	b.WriteString(depth)
	b.WriteString("\n\nSTYLE RULES:\n")
	b.WriteString("- Plain text only. No HTML, no markdown syntax - the ONLY markup allowed is $...$ and $$...$$ LaTeX.\n")
	b.WriteString("- TEACH completely, never tease: 'we will discuss this later' is forbidden. Part 1 assumes nothing; Parts 2-5 may use everything before them.\n")
	b.WriteString("- Stay strictly inside your part's mandate; the other parts belong to the other keys.\n")
	b.WriteString("- Use Nigerian context wherever it is natural (naira, Lagos/Kano/Akure, CBN, NAFDAC, NCC, Nigerian statutes and institutions).\n")
	b.WriteString("- A student who reads ONLY your part must fully master your part's mandate.\n\n")
	fmt.Fprintf(&b, "YOUR PART'S MANDATE - %s\n\n", PartMandate[part-1])
	b.WriteString("OUTPUT - return STRICT JSON only. No code fences, no commentary:\n")
	fmt.Fprintf(&b, `{"heading": "Part %d: SHORT DESCRIPTIVE TITLE IN CAPITALS", "body": "the complete text of Part %d"}`+"\n", part, part)
	return b.String()
}

// notesUserPrompt is the per-unit brief every note key receives.
func notesUserPrompt(req *Request) string {
	section := ""
	if req.SectionTitle != "" {
		section = fmt.Sprintf("\nCourse section: %s", req.SectionTitle)
	}
	return fmt.Sprintf(`Write Part %d of the 5-part lecture note for:

Course: %s
Department: %s
Faculty: %s%s
Unit: %s
Position: unit %d of %d in the course.

The 5-part plan of this unit:
Part 1 - Foundations
Part 2 - Core Principles I
Part 3 - Core Principles II
Part 4 - Applications and Worked Examples
Part 5 - Synthesis and Revision

Return the JSON object now.`,
		req.Part, req.Course, or(req.Dept, "-"), or(req.Faculty, "-"), section, req.UnitTitle, req.Seq, req.Total)
}

// quizSystemPrompt is the system prompt handed to Key 6. It receives
// the combined text of all five parts and writes the unit assessment
// plus the lesson's summary and key points (it is the only key that
// sees the whole note, so it is the natural summarizer).
func quizSystemPrompt(level int) string {
	spec := `ASSESSMENT SPEC - Level 100 unit:
- EXACTLY 20 objective questions, all multiple choice with options A, B, C, D.
- ZERO theory questions. Omit the "theory_questions" field entirely.`
	if level >= 200 {
		spec = `ASSESSMENT SPEC - Level 200 or above:
- EXACTLY 15 objective questions, all multiple choice with options A, B, C, D.
- EXACTLY 5 theory questions.`
	}
	var b strings.Builder
	b.WriteString("You are Key 6 of the Renance Autonomous Course Orchestrator: an expert Nigerian university examiner writing the assessment for ONE course unit. ")
	b.WriteString("You will receive the unit's complete 5-part lecture note; every question must be answerable from that note and nothing outside it.\n\n")
	b.WriteString(spec)
	b.WriteString("\n\nOBJECTIVE QUESTION RULES:\n")
	b.WriteString("- Exactly 4 options keyed \"A\", \"B\", \"C\", \"D\"; exactly one is correct.\n")
	b.WriteString("- Scatter the correct answers unpredictably across A, B, C and D - never a visible pattern, and no letter carries more than 8 of the objective questions.\n")
	b.WriteString("- Stems are self-contained (no references to figures, passages or earlier questions). Distractors must be plausible: common misconceptions, near-misses, sign and unit errors.\n")
	b.WriteString("- Every objective question carries a comprehensive explanation (2-5 sentences) that breaks down the derivation or the conceptual rationale step by step. Use KaTeX ($...$ or $$...$$) for every formula or mathematical symbol; never bare caret/underscore notation.\n")
	if level >= 200 {
		b.WriteString("\nTHEORY QUESTION RULES:\n")
		b.WriteString("- Multi-step analytical prompts: compare, derive, evaluate, apply, justify - never bare 'list and define'.\n")
		b.WriteString("- Each carries \"key_points\": the marking guide - the specific points an examiner awards marks for, separated by semicolons; and \"answer\": a full model answer a grader can mark against.\n")
	}
	b.WriteString("\nALSO RETURN (you are the only key that sees the whole note):\n")
	b.WriteString("- \"summary\": a 2-sentence summary of the unit note.\n")
	b.WriteString("- \"key_points\": 5 to 7 exam-focused takeaways, one line each.\n\n")
	b.WriteString("OUTPUT - return STRICT JSON only. No code fences, no commentary:\n")
	if level >= 200 {
		b.WriteString(`{"summary": "...", "key_points": ["...", "..."], "quiz": [{"type": "mcq", "stem": "...", "options": {"A": "...", "B": "...", "C": "...", "D": "..."}, "answer": "B", "explanation": "..."} ... exactly 15], "theory_questions": [{"question": "...", "key_points": "point one; point two; point three", "answer": "full model answer"} ... exactly 5]}`)
	} else {
		b.WriteString(`{"summary": "...", "key_points": ["...", "..."], "quiz": [{"type": "mcq", "stem": "...", "options": {"A": "...", "B": "...", "C": "...", "D": "..."}, "answer": "B", "explanation": "..."} ... exactly 20]}`)
	}
	b.WriteString("\n")
	return b.String()
}

// quizUserPrompt feeds Key 6 the combined note text (headings + bodies).
// The note is capped so the prompt always fits the model context with
// room for the full assessment output.
func quizUserPrompt(req *Request, notes []Note) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Write the unit assessment for:\n\nCourse: %s\nUnit: %s\nPosition: unit %d of %d in the course.\n\n", req.Course, req.UnitTitle, req.Seq, req.Total)
	b.WriteString("THE COMPLETE 5-PART LECTURE NOTE FOLLOWS.\n\n")
	total := 0
	for i, n := range notes {
		body := n.Body
		// Keep the whole note under ~12k characters per part so the
		// six-key exchange never overflows the context window.
		if len(body) > 12000 {
			body = body[:12000] + " ..."
		}
		fmt.Fprintf(&b, "%s\n%s\n\n", notes[i].Heading, body)
		total += len(n.Heading) + len(body)
	}
	b.WriteString("END OF LECTURE NOTE. Return the JSON assessment now.")
	return b.String()
}

func or(s, fallback string) string {
	if strings.TrimSpace(s) == "" {
		return fallback
	}
	return s
}
