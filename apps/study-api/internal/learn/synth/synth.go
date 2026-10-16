package synth

// synth.go: the orchestrator. PackFor routes a course to its
// discipline pack, UnitPlan grows the 15 x 10 ladder, and Lesson
// assembles the complete lesson for one topic. Everything is a pure
// function of the ids and titles, so the API, the bulk generator and
// future rebuilds all produce byte identical content.

import (
        "fmt"
        "sort"
        "strings"
)

/* --------------------------- pack routing ------------------------- */

// PackFor picks the best matching discipline pack for a course.
func PackFor(title, dept, faculty string) *pack {
        best := genericPack
        bestScore := 0
        for _, p := range packs {
                s := p.match(title, dept, faculty)
                if s > bestScore {
                        bestScore = s
                        best = p
                }
        }
        return best
}

/* ------------------------- topic title engine --------------------- */

// topicShapes: the phrasing pool for topic titles. {u} is the unit
// anchor, {n}/{n2} pack nouns, {p} a process, {tool} a tool, {law} a
// law, {ctx} a context.
var topicShapes = []string{
        "Overview of {u}",
        "{n} and its place in {u}",
        "Key principles of {u}",
        "Working methods in {u}",
        "{u} in practice: {ctx}",
        "{n} and {n2} compared",
        "Tools and techniques for {u}",
        "{law} applied to {u}",
        "Common errors in {u} and their fixes",
        "{p} step by step",
        "{n} in the Nigerian setting",
        "Case study on {u}",
        "Measuring results in {u}",
        "Data and evidence in {u}",
        "Planning work in {u}",
        "Standards and quality in {u}",
        "Connections between {n} and {n2}",
        "Problems and prospects of {u}",
        "Revision focus on {u}",
        "Applications of {n}",
        "Classification and types in {u}",
        "{u} and the wider field",
        "Evaluating evidence in {u}",
        "Improving practice in {u}",
}

// shortAnchor trims a unit title to its core phrase so topic titles
// stay under a reasonable length.
func shortAnchor(unit string) string {
        s := unit
        s = strings.TrimPrefix(s, "Introduction to ")
        s = strings.TrimPrefix(s, "Foundations of ")
        if i := strings.Index(s, ":"); i > 0 {
                s = s[:i]
        }
        return strings.TrimSpace(s)
}

// UnitPlan returns the title and 10 topics for one unit of a course.
func UnitPlan(courseID, courseTitle, dept, faculty string, unit int) (string, []TopicPlan) {
        p := PackFor(courseTitle, dept, faculty)
        if unit < 1 {
                unit = 1
        }
        if unit > len(p.units) {
                unit = len(p.units)
        }
        g := NewRNG(courseID + "|unit|" + fmt.Sprint(unit))
        anchor := shortAnchor(p.units[unit-1])
        title := p.units[unit-1]

        nouns := g.Shuffle(p.nouns)
        ctx := g.Pick(p.contexts)
        law := g.Pick(p.laws)
        tool := g.Pick(p.tools)

        vals := map[string]string{
                "u": anchor, "n": nouns[0], "n2": nouns[1%len(nouns)],
                "p": g.Pick(p.processes), "ctx": ctx, "law": law, "tool": tool,
        }

        shapeOrder := g.Shuffle(topicShapes)
        seen := map[string]bool{}
        topics := make([]TopicPlan, 0, 10)
        for _, sh := range shapeOrder {
                if len(topics) >= 10 {
                        break
                }
                t := Cap(Clean(Fill(sh, vals)))
                if len(t) < 10 || len(t) > 72 || seen[strings.ToLower(t)] {
                        continue
                }
                seen[strings.ToLower(t)] = true
                topics = append(topics, TopicPlan{
                        Title:    t,
                        Category: categoriesFor(unit)[len(topics)%len(categoriesFor(unit))],
                })
        }
        // top up if the shapes starved (very short pools)
        for len(topics) < 10 {
                nn := nouns[len(topics)%len(nouns)]
                t := Cap(Clean(nn + " within " + anchor))
                if seen[strings.ToLower(t)] {
                        t = Cap(Clean(fmt.Sprintf("Further studies in %s, part %d", anchor, len(topics)+1)))
                }
                seen[strings.ToLower(t)] = true
                topics = append(topics, TopicPlan{
                        Title:    t,
                        Category: categoriesFor(unit)[len(topics)%len(categoriesFor(unit))],
                })
        }
        return title, topics
}

func categoriesFor(unit int) []string {
        return []string{"Concepts & Foundations", "Core Principles", "Methods & Practice", "Applications", "Exam Focus"}
}

// TopicPlan is one generated topic inside a unit plan.
type TopicPlan struct {
        ID       string
        Title    string
        Category string
}

/* ------------------------- lesson assembly ------------------------ */

// Note is one reading section.
type Note struct {
        Heading string `json:"heading"`
        Body    string `json:"body"`
}

// LessonOut is the synthesized lesson, shape compatible with the API's
// LessonDoc notes and quiz fields.
type LessonOut struct {
        Title     string      `json:"title"`
        Summary   string      `json:"summary"`
        Notes     []Note      `json:"notes"`
        KeyPoints []string    `json:"keyPoints"`
        Quiz      []QuizItem  `json:"quiz"`
}

func lowerFirst(s string) string {
        if s == "" {
                return s
        }
        r := []rune(s)
        if r[0] >= 'A' && r[0] <= 'Z' {
                r[0] = r[0] + 32
        }
        return string(r)
}

// BuildLesson synthesizes the full lesson for one topic. Deterministic
// on topicID: the same topic always yields the same content.
func BuildLesson(topicID, courseTitle, dept, faculty, topicTitle string, unit int) *LessonOut {
        p := PackFor(courseTitle, dept, faculty)
        if unit < 1 {
                unit = 1
        }
        if unit > len(p.units) {
                unit = len(p.units)
        }
        g := NewRNG(topicID)

        nouns := g.Shuffle(p.nouns)
        sibs := g.PickN(p.siblings, 4)
        procs := g.Shuffle(p.processes)
        laws := g.Shuffle(p.laws)

        units := p.units
        uPrev := units[(unit-2+len(units))%len(units)]
        if unit == 1 {
                uPrev = units[len(units)-1]
        }
        uNext := units[unit%len(units)]
        if unit == len(units) {
                uNext = units[0]
        }

        vals := map[string]string{
                "t":    lowerFirst(topicTitle),
                "T":    topicTitle,
                "c":    courseTitle,
                "n":    nouns[0],
                "n2":   nouns[1%len(nouns)],
                "p":    procs[0],
                "tool": g.Pick(p.tools),
                "law":  laws[0],
                "law2": laws[1%len(laws)],
                "ctx":  g.Pick(p.contexts),
                "car":  g.Pick(p.careers),
                "u":    shortAnchor(units[unit-1]),
                "uPrev": shortAnchor(uPrev),
                "uNext": shortAnchor(uNext),
                "sib":  sibs[0],
                "sib2": sibs[1],
                "sib3": sibs[2],
                "sib4": sibs[3],
                "iss":  g.Pick(p.issues),
                "pack": p.key,
                "calc": p.calc,
        }

        notes := buildNotesStable(g, vals)
        easy := easyQuestions(g, vals, topicID)
        hard := hardQuestions(g, vals, topicID)
        quiz := append(append([]QuizItem{}, easy...), hard...)

        ns := make([]Note, 0, len(notes.Bodies))
        for i := range notes.Bodies {
                h := ""
                if i < len(notes.Headings) {
                        h = notes.Headings[i]
                }
                ns = append(ns, Note{Heading: h, Body: notes.Bodies[i]})
        }

        return &LessonOut{
                Title:     Clean(topicTitle),
                Summary:   notes.Summary,
                Notes:     ns,
                KeyPoints: notes.KeyPts,
                Quiz:      quiz,
        }
}

/* --------------------- stable reading contract -------------------- */

// buildNotesStable assembles the ten sections while GUARANTEEING that
// every sentence a quiz item depends on is always present: the stage
// definitions, the named law, the vocabulary roles, the rounding
// warning, the verification principle and the exam strategy. A single
// seen set is shared across all sections, so no sentence repeats
// anywhere in the lesson.
func buildNotesStable(g *RNG, v map[string]string) NotesResult {
        seen := map[string]bool{}
        b := func() *sectBuilder { return &sectBuilder{g: g, vals: v, seen: seen} }

        build := func(open string, mids []string, close string, floor int) string {
                sb := b()
                sb.addOrdered([]string{open})
                sb.add(mids, len(mids))
                if close != "" {
                        sb.addOrdered([]string{close})
                }
                return sb.render(floor)
        }
        // ordered variant: fixed pedagogical sequences keep their order
        buildOrdered := func(open string, ordered []string, close string, floor int) string {
                sb := b()
                sb.addOrdered([]string{open})
                sb.addOrdered(ordered)
                if close != "" {
                        sb.addOrdered([]string{close})
                }
                return sb.render(floor)
        }

        // S1: meaning and why it matters
        sb := b()
        sb.addOrdered([]string{g.Pick(pOpener)})
        sb.add(pDefine, 2)
        sb.add(pWhy, 3)
        b1 := sb.render(165)

        // S2: vocabulary; the role sentences ALWAYS present, in order
        vocab := []string{pTerms[0], pTerms[1], pTerms[2], pTerms[3]}
        extraVocab := g.PickN(pTerms[4:], 1)
        vocab = append(vocab, extraVocab...)
        b2 := buildOrdered("Definitions come first in every serious study, so this section fixes the vocabulary of {t}.", vocab, g.Pick(pTermsCloser), 150)

        // S3: the method; the five stage definitions plus the strong
        // students warning are ALWAYS present, in stage order
        steps := []string{pHowSteps[0], pHowSteps[1], pHowSteps[2], pHowSteps[3], pHowSteps[4], pHowSteps[6]}
        steps = append(steps, g.PickN(pHowSteps[5:6], 1)...)
        b3 := buildOrdered(g.Pick(pHowOpen), steps, g.Pick(pHowCloser), 170)

        // S4: principles; the named law, the conditions rule and the
        // verification principle are ALWAYS present
        lawSet := []string{pLawBody[0], pLawBody[3], pLawBody[4]}
        lawSet = append(lawSet, g.PickN(pLawBody[1:3], 1)...)
        b4 := buildOrdered(g.Pick(pLawOpen), lawSet, g.Pick(pLawCloser), 155)

        // S5: worked example; narration in stage order, rounding warning included
        exSet := []string{pExBody[0], pExBody[1], pExBody[2], pExBody[3], pExBody[4], pExBody[5], pExBody[7]}
        exSet = append(exSet, g.PickN([]string{pExBody[6], pExBody[8], pExBody[9]}, 1)...)
        b5 := buildOrdered(g.Pick(pExOpen), exSet, g.Pick(pExCloser), 160)
        if k, ok := v["calc"]; ok && k != "" {
                b5 = b5 + " " + calcParagraph(k, g)
        }

        // S6: real world
        b6 := build("{T} does not live only in textbooks; it works for a living, and this section shows where.", pickN(g, pReal, 4), "", 150)

        // S7: traps; first three traps in order
        trapSet := []string{pTrap[0], pTrap[1], pTrap[2], pTrap[3]}
        trapSet = append(trapSet, g.PickN(pTrap[4:8], 2)...)
        trapSet = append(trapSet, pTrap[9])
        b7 := buildOrdered("Before the quiz, read this list of classic errors; it is the cheapest marks you will ever save.", trapSet, "", 160)

        // S8: connections
        b8 := build("A topic understood in isolation is a topic half understood, so this section wires {t} into the rest of {c}.", pickN(g, pConnect, 4), "", 150)

        // S9: exam focus
        b9 := build("Here is how examiners actually test {t}, based on the patterns of past questions in {c}.", pickN(g, pExam, 5), "", 155)

        // S10: summary; the arc and the strategy line ALWAYS present
        sumSet := []string{pSummary[0], pSummary[1], pSummary[3], pSummary[6], pSummary[7]}
        sumSet = append(sumSet, g.PickN([]string{pSummary[2], pSummary[4], pSummary[5]}, 1)...)
        b10 := buildOrdered("Let us gather the whole lesson into one closing section you can revise in three minutes.", sumSet, pSummary[8], 165)

        return NotesResult{
                Headings: headingsFor(g, v),
                Bodies:   []string{b1, b2, b3, b4, b5, b6, b7, b8, b9, b10},
                Summary:  Clean(Fill(g.Pick(sumPool), v)),
                KeyPts:   keyPoints(g, v),
        }
}

// SortTopics orders topic plans by unit then position (helper for the
// bulk runner).
func SortTopics(ts []TopicPlan) {
        sort.Slice(ts, func(i, j int) bool { return ts[i].Title < ts[j].Title })
}
