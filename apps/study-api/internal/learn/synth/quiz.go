package synth

// quiz.go: 20 questions per topic, the founder's split: 10 easy then
// 10 hard. Every item is answerable from THIS lesson's notes (the
// lesson always teaches the five stage method, one named governing
// principle, the vocabulary trio, the traps and the contexts). All
// four options of every mcq come from the same family of ideas, so
// nothing looks like "bag, monkey, sublimation, banana".

import (
        "fmt"
        "strings"
)

// QuizItem mirrors the API's LessonQuizQ shape.
type QuizItem struct {
        ID          string            `json:"id"`
        Type        string            `json:"type"` // mcq | true_false | fill_blank
        Stem        string            `json:"stem"`
        Options     map[string]string `json:"options,omitempty"`
        Answer      string            `json:"answer"`
        Explanation string            `json:"explanation,omitempty"`
}

var stages = []string{"observation", "identification", "selection", "execution", "checking"}

// mcq builds one multiple choice item: correct + 3 related distractors,
// correct letter placed by the seeded shuffle.
func mcq(g *RNG, id, stem, correct string, wrongs [3]string, expl string) QuizItem {
        opts := []string{correct, wrongs[0], wrongs[1], wrongs[2]}
        order := g.Shuffle(opts)
        letters := []string{"A", "B", "C", "D"}
        om := map[string]string{}
        ans := "A"
        for i, o := range order {
                om[letters[i]] = Clean(o)
                if o == correct {
                        ans = letters[i]
                }
        }
        return QuizItem{ID: id, Type: "mcq", Stem: Clean(stem), Options: om, Answer: ans, Explanation: Clean(expl)}
}

// tf builds a true/false item.
func tf(g *RNG, id, stem string, truth bool, expl string) QuizItem {
        ans := "false"
        if truth {
                ans = "true"
        }
        return QuizItem{ID: id, Type: "true_false", Stem: Clean(stem),
                Options: map[string]string{"A": "True", "B": "False"}, Answer: ans, Explanation: Clean(expl)}
}

// blank builds a fill in the blank item (single word answers only).
func blank(id, stem, word, expl string) QuizItem {
        return QuizItem{ID: id, Type: "fill_blank", Stem: Clean(stem), Answer: strings.ToLower(Clean(word)), Explanation: Clean(expl)}
}

/* ------------------------- easy question bank --------------------- */

func easyQuestions(g *RNG, v map[string]string, topicID string) []QuizItem {
        // sibs order is FIXED: the lesson teaches sib as the basic unit,
        // sib2 as the near neighbour, sib3 as the interaction term
        sibs := []string{v["sib"], v["sib2"], v["sib3"], v["sib4"]}
        t, law := v["t"], v["law"]
        qs := make([]QuizItem, 0, 10)

        // E1: the basic unit of study term (options: sibling terms)
        wr := [3]string{sibs[1], sibs[2], sibs[3]}
        qs = append(qs, mcq(g, QID(topicID, "E", 1),
                fmt.Sprintf("In this lesson on %s, which term is described as the basic unit of study?", t),
                sibs[0], wr,
                fmt.Sprintf("The vocabulary section names %s as the basic unit of study within %s.", sibs[0], t)))
        // E2: the related but distinct idea (options: the other siblings)
        qs = append(qs, mcq(g, QID(topicID, "E", 2),
                fmt.Sprintf("Which term does this lesson describe as a related but distinct idea, so closely tied to %s that mixing the two is a classic error?", sibs[0]),
                sibs[1], [3]string{sibs[0], sibs[2], sibs[3]},
                fmt.Sprintf("The vocabulary section defines %s that way and the traps section repeats the warning.", sibs[1])))

        // E3: the five stage order
        qs = append(qs, mcq(g, QID(topicID, "E", 3),
                "Which option lists the five stage method taught in this lesson in the correct order?",
                "observe, identify, select, execute, check",
                [3]string{
                        "observe, select, identify, check, execute",
                        "identify, observe, execute, select, check",
                        "check, execute, select, identify, observe",
                },
                "The method section gives the order explicitly: observe, identify, select, execute, check."))

        // E4: stage after selection
        qs = append(qs, mcq(g, QID(topicID, "E", 4),
                "In the five stage method, which stage comes immediately after selection?",
                "execution", [3]string{"observation", "identification", "checking"},
                "After selecting the principle or method, you carry it out: that stage is execution."))

        // E5: the governing law (options: laws of the same pack)
        laws := lawsFor(v, 4)
        corr := law
        wrongs := [3]string{}
        j := 0
        for _, l := range laws {
                if l != corr && j < 3 {
                        wrongs[j] = l
                        j++
                }
        }
        for j < 3 {
                wrongs[j] = "the principle of guessing from options"
                j++
        }
        qs = append(qs, mcq(g, QID(topicID, "E", 5),
                fmt.Sprintf("Which principle does this lesson name as a governing principle of %s?", t),
                corr, wrongs,
                fmt.Sprintf("The principles section states it directly: %s governs this topic, with its own conditions.", corr)))

        // E6: true/false on advice
        qs = append(qs, tf(g, QID(topicID, "E", 6),
                fmt.Sprintf("According to this lesson, you should state a principle such as %s before substituting values into it.", law), true,
                "The worked example section says: name the principle first, because naming it earns method marks."))

        // E7: fill blank, final stage
        qs = append(qs, blank(QID(topicID, "E", 7),
                "In the five stage method taught in this lesson, the final stage is called the stage of \u2026",
                "checking",
                "The method ends with checking: looking back over the result for size, sign and units."))

        // E8: numeric easy or context question
        if v["calc"] != "" {
                ex := numericEasy(g, v)
                wrongsN := [3]string{ex.wrongs[0], ex.wrongs[1], ex.wrongs[2]}
                qs = append(qs, mcq(g, QID(topicID, "E", 8), ex.stem, ex.answer, wrongsN,
                        fmt.Sprintf("Working through it: %s The wrong options come from the classic slips named above.", strings.Join(ex.steps[:2], " "))))
        } else {
                // the lesson's real world section features v["ctx"] specifically,
                // so that exact setting must be the correct option
                otherCtxs := g.PickN(vPackOf(v).contexts, 4)
                wr := [3]string{}
                j := 0
                for _, cx := range otherCtxs {
                        if cx != v["ctx"] && j < 3 {
                                wr[j] = cx
                                j++
                        }
                }
                for j < 3 {
                        wr[j] = "a setting from a different course entirely"
                        j++
                }
                qs = append(qs, mcq(g, QID(topicID, "E", 8),
                        fmt.Sprintf("Which setting does this lesson use as a real world example of %s at work?", t),
                        v["ctx"], wr,
                        fmt.Sprintf("The applications section ties the topic to %s.", v["ctx"])))
        }

        // E9: trap awareness
        qs = append(qs, mcq(g, QID(topicID, "E", 9),
                fmt.Sprintf("According to the traps section, what must you confirm before applying %s?", law),
                "its conditions",
                [3]string{
                        "whether it is popular with examiners",
                        "whether other students agree with it",
                        "whether it appears in the summary section",
                },
                "The principles section is explicit: applying a principle outside its conditions produces a wrong answer even when the arithmetic is perfect."))

        // E10: the classic confusion pair
        other := [3]string{sibs[2] + " and " + sibs[3], sibs[1] + " and " + sibs[3], sibs[3] + " and " + sibs[0]}
        qs = append(qs, mcq(g, QID(topicID, "E", 10),
                "Which pair of terms does this lesson warn students never to confuse?",
                sibs[0]+" and "+sibs[1], other,
                fmt.Sprintf("The traps section opens with exactly this confusion: %s with %s.", sibs[0], sibs[1])))

        return qs
}

/* ------------------------- hard question bank --------------------- */

func hardQuestions(g *RNG, v map[string]string, topicID string) []QuizItem {
        sibs := []string{v["sib"], v["sib2"], v["sib3"], v["sib4"]}
        t, law := v["t"], v["law"]
        qs := make([]QuizItem, 0, 10)

        // H1: numeric hard (or for non calc: statement discrimination)
        if v["calc"] != "" {
                ex := numericHard(g, v)
                qs = append(qs, mcq(g, QID(topicID, "H", 1), ex.stem, ex.answer,
                        [3]string{ex.wrongs[0], ex.wrongs[1], ex.wrongs[2]},
                        "Each wrong option is the result of a named slip, such as " + ex.reasons[0] + ". The correct working is: " + strings.Join(ex.steps, " ")))
        } else {
                qs = append(qs, mcq(g, QID(topicID, "H", 1),
                        fmt.Sprintf("Which statement about %s does this lesson support in full?", t),
                        fmt.Sprintf("Its principles carry conditions, and applying them outside those conditions produces wrong answers"),
                        [3]string{
                                fmt.Sprintf("Its principles apply identically in every situation without conditions"),
                                fmt.Sprintf("Its principles remove the need to check final results"),
                                fmt.Sprintf("Its principles matter only in examinations, not in practice"),
                        },
                        "The principles section states that every principle carries conditions; the verification principle says unchecked results should not be trusted."))
        }

        // H2: five stage discrimination (statements, all related)
        qs = append(qs, mcq(g, QID(topicID, "H", 2),
                "Which statement about the five stage method is correct?",
                "Execution follows selection, and checking closes the sequence",
                [3]string{
                        "Checking opens the sequence, and observation closes it",
                        "Identification follows execution, and selection closes it",
                        "Selection precedes observation, and checking closes it",
                },
                "The order taught is observe, identify, select, execute, check; only the first statement preserves it."))

        // H3: conditions of the law
        qs = append(qs, mcq(g, QID(topicID, "H", 3),
                fmt.Sprintf("Which statement about %s matches this lesson?", law),
                "It states a fixed pattern that can be relied on when its conditions hold",
                [3]string{
                        "It states a fixed pattern that holds in every situation without conditions",
                        "It states a preference, not a rule, so it can be ignored when convenient",
                        "It applies only when results are left unchecked",
                },
                fmt.Sprintf("The principles section presents %s as a regularity you can rely on, with conditions stated alongside.", law)))

        // H4: method in a scenario
        qs = append(qs, mcq(g, QID(topicID, "H", 4),
                fmt.Sprintf("A student has observed the facts of a problem on %s and identified exactly what is required. According to the five stage method, what is the next move?", t),
                "Select the principle or formula that fits the situation",
                [3]string{
                        "Execute the solution immediately at full speed",
                        "Check the final answer for size, sign and units",
                        "Observe the situation a second time from the beginning",
                },
                "Selection follows identification in the method; execution and checking come later in the sequence."))

        // H5: the strong students trap
        qs = append(qs, mcq(g, QID(topicID, "H", 5),
                "Which error does this lesson single out as the most common reason strong students lose easy marks?",
                "Skipping the checking stage",
                [3]string{
                        "Stating the governing principle before applying it",
                        "Writing one step per line during calculation",
                        "Listing what is given and what is required",
                },
                "The method section says skipping the checking stage is the most common reason strong students lose easy marks; the other three are all advised behaviours."))

        // H6: verification principle (or numeric for calc)
        if v["calc"] != "" {
                ex2 := numericHard(g, v)
                qs = append(qs, mcq(g, QID(topicID, "H", 6), ex2.stem, ex2.answer,
                        [3]string{ex2.wrongs[0], ex2.wrongs[1], ex2.wrongs[2]},
                        "The correct working is: " + strings.Join(ex2.steps, " ") + " Each distractor comes from a classic slip."))
        } else {
                qs = append(qs, mcq(g, QID(topicID, "H", 6),
                        "According to the verification principle taught in this lesson, a result that cannot be checked, at least roughly, should be",
                        "treated as untrusted until it is checked",
                        [3]string{
                                "submitted quickly before anyone questions it",
                                "rounded so that it becomes easier to defend",
                                "kept out of the final answer entirely",
                        },
                        "The principles section closes with the verification principle: a result that cannot be checked should not be trusted."))
        }

        // H7: subtle inversion true/false
        qs = append(qs, tf(g, QID(topicID, "H", 7),
                "This lesson advises rounding early during calculations so that the arithmetic stays short.", false,
                "The worked example section warns the opposite: premature rounding is a quiet marks killer; carry full precision and round only at the end."))

        // H8: fill blank, stage order hard
        qs = append(qs, blank(QID(topicID, "H", 8),
                "In the five stage method, the stage that immediately follows selection is \u2026",
                "execution",
                "Selection is choosing the method; execution is carrying it out. The lesson lists them in that order."))

        // H9: exam strategy
        qs = append(qs, mcq(g, QID(topicID, "H", 9),
                "How does this lesson advise you to spend time once the quiz opens?",
                "Answer the easy items quickly and save time for the hard half",
                [3]string{
                        "Spend an equal amount of time on every single item",
                        "Answer the hard items first while energy is high",
                        "Wait until the last minutes and then guess in bulk",
                },
                "The summary section gives that exact strategy; it mirrors how examiners distribute difficulty."))

        // H10: third term discrimination
        qs = append(qs, mcq(g, QID(topicID, "H", 10),
                fmt.Sprintf("Which term does this lesson use for the way the parts of %s interact in practice?", t),
                sibs[2], [3]string{sibs[0], sibs[1], sibs[3]},
                fmt.Sprintf("The vocabulary section assigns that role to %s.", sibs[2])))
        return qs
}

/* ------------------------- numeric helpers ------------------------ */

// numericEasy draws an easy one step calculation.
func numericEasy(g *RNG, v map[string]string) *ex {
        pool := generators[v["calc"]]
        if len(pool) == 0 {
                return nil
        }
        return dedupeEx(pool[g.Intn(len(pool))](g))
}

// numericHard draws a calculation with fresh numbers by reseeding.
func numericHard(g *RNG, v map[string]string) *ex {
        pool := generators[v["calc"]]
        if len(pool) == 0 {
                return nil
        }
        // a different seed from the lesson body keeps numbers fresh
        h := NewRNG(v["t"] + "hard" + v["law"])
        return dedupeEx(pool[h.Intn(len(pool))](h))
}

// lawsFor returns k laws of the pack behind v, padded from the generic
// pack when the pack is thin.
func lawsFor(v map[string]string, k int) []string {
        p := vPackOf(v)
        out := append([]string{}, p.laws...)
        for _, l := range genericPack.laws {
                if len(out) >= k+2 {
                        break
                }
                out = append(out, l)
        }
        return out
}

// vPackOf recovers the pack key stored in the values map.
func vPackOf(v map[string]string) *pack {
        if p, ok := packByKey[v["pack"]]; ok {
                return p
        }
        return genericPack
}

var packByKey = map[string]*pack{}

func init() {
        for _, p := range packs {
                packByKey[p.key] = p
        }
}
