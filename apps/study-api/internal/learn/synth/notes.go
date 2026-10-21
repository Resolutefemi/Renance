package synth

// notes.go builds the 10 reading sections of a topic lesson. Each body
// is 150 to 260 words of plain teaching prose (the founder: at least
// 10 distinct long parts the student reads sequentially before the
// quiz unlocks). Slots: {t}=topic, {c}=course, {n}=pack noun,
// {n2}=second noun, {p}=process, {tool}=tool, {law}=law,
// {ctx}=context, {car}=career, {u}=unit, {iss}=field issue.

import (
        "fmt"
        "strings"
)

/* ------------------------------ pools ----------------------------- */

var pOpener = []string{
        "Every serious course touches {t} at some point, and this section sets the foundation you will build on for the rest of {c}.",
        "When examiners set questions on {c}, {t} is one of the areas they return to again and again, so treat this as core material.",
        "Before you can solve problems in this part of {c}, you must be clear about what {t} actually involves.",
        "Students often jump straight into questions on {t} and get stuck, because they skipped the groundwork this section provides.",
        "{t} sits at the heart of {c}, and mastering it early makes every later topic easier to absorb.",
        "There is a reason your curriculum places {t} inside {u}: it supplies the language and ideas the following units depend on.",
        "Think of {t} as one of the load bearing walls of {c}: weaken it and everything after it shakes.",
        "You will meet {t} again in later units, in tougher forms, which is why the basics deserve careful attention now.",
}

var pDefine = []string{
        "In simple terms, {t} deals with how {n} is understood, organised and applied in {c}.",
        "At its core, {t} describes the ideas, relationships and procedures that connect {n} with {n2}.",
        "A working definition: {t} is the organised study of {n} and the principles that govern it.",
        "Put plainly, anyone who understands {t} can explain {n} to another person without hiding behind jargon.",
        "The subject matter of {t} covers {n}, the methods used for {p}, and the standards used to judge results.",
        "{t} answers three questions: what {n} is, how it behaves, and what can be done with it.",
        "To define {t} properly, we look at {n}, the tools such as {tool}, and the laws such as {law} that keep the field orderly.",
        "In this course, {t} is treated as both a body of knowledge and a set of skills you must practise.",
}

var pWhy = []string{
        "The reason this topic matters is practical: {ctx} depends on people who understand it well.",
        "Without a firm grip on {t}, tasks like {p} turn into guesswork, and guesswork is expensive.",
        "A student who masters {t} can walk into a workplace and handle {ctx} with confidence.",
        "Careers such as {car} ask interview questions built directly on material like this, so the effort pays twice.",
        "Beyond examinations, {t} shapes how professionals in {c} make decisions under real constraints.",
        "National priorities, from {ctx} to everyday services, rely on the ideas gathered under this topic.",
        "Examiners like this topic because it separates students who memorised from students who understood.",
        "Many later problems in {c} simply cannot be solved without the ideas introduced here.",
}

var pTerms = []string{
        "Several key terms carry the weight of this topic, and you should be able to define each one in a sentence.",
        "First among them is {sib}, which refers to the basic unit of study here and appears in almost every question on {t}.",
        "Next comes {sib2}: it describes a related but distinct idea, and confusing the two is a classic examination error.",
        "You should also note {sib3}, a term that describes how the parts of {t} interact in practice.",
        "Where {sib} concerns what something is, {sib2} concerns how it behaves, and that difference matters in the exam.",
        "Terms such as {sib} and {sib2} often appear as options in multiple choice questions, so learn their exact meanings.",
        "Keep a vocabulary list for {t}; write each term, its definition, and one fresh example beside it.",
        "Do not rely on vague impressions: a definition is either correct or wrong, and examiners mark it that way.",
}

var pTermsCloser = []string{
        "When you can define these terms without looking them up, you are ready to move to the next section.",
        "Test yourself: cover the definitions, rewrite each term in your own words, then check.",
        "These terms are the keys that unlock the worked examples later in this lesson.",
        "Say the definitions aloud; your ears catch errors your eyes forgive.",
}

var pHowOpen = []string{
        "This section walks through {t} as a sequence of steps, so follow each stage before moving on.",
        "Understanding {t} becomes easier when you see it as a process rather than a block of facts.",
        "Here is the working procedure, broken into stages you can reproduce in an examination answer.",
        "To use {t} correctly, professionals follow a recognisable sequence, which is exactly what examiners want you to describe.",
        "Read the steps below slowly; each one depends on the one before it.",
}

var pHowSteps = []string{
        "Stage one is observation: gather the facts of the situation, whether it is data, a specimen, a diagram or a set of figures.",
        "Stage two is identification: state clearly what is given and what is required, because half of all wrong answers come from answering the wrong question.",
        "Stage three is selection: choose the principle, formula or method that fits the situation, for instance {law} where it applies.",
        "Stage four is execution: carry out the method carefully, showing every step, since method marks are real marks.",
        "Stage five is checking: look back over the result and ask whether it is sensible in size, sign and units.",
        "In practice, skipping the checking stage is the most common reason strong students lose easy marks.",
        "When the situation is more complex, the same five stages repeat at a higher level, so the habit you build here scales up.",
        "Write the stages on a card and keep it beside you while you practise questions on {t}.",
}

var pHowCloser = []string{
        "The sequence above turns a confusing topic into a routine you can repeat under examination pressure.",
        "With rehearsal, the stages become automatic, and that is the goal: calm, ordered work in the exam hall.",
        "Do not rush this section; the rest of the lesson assumes you can reproduce these steps.",
}

var pLawOpen = []string{
        "Every topic in {c} is held together by rules, and {t} is governed by principles you must be able to state and apply.",
        "Examiners reward answers that name the governing principle before applying it, so learn these statements precisely.",
        "The following principles appear again and again in questions from this unit of {c}.",
}

var pLawBody = []string{
        "The first is {law}. In the context of {t}, it says that outcomes follow fixed patterns, not chance, and you can rely on that regularity when solving problems.",
        "A second guiding idea is the principle of careful definition: state what each symbol, term or component stands for before you use it, because ambiguity quietly corrupts answers.",
        "There is also the principle of consistency: the same rules apply at every scale of {n}, so a method that works in a small example works in a large one, provided its conditions hold.",
        "Related to this is the rule of conditions: every principle such as {law} carries conditions, and applying it outside those conditions produces the wrong answer even when the arithmetic is perfect.",
        "Finally, the principle of verification underpins honest work in {c}: a result that cannot be checked, at least roughly, should not be trusted.",
}

var pLawCloser = []string{
        "State each principle, note its conditions, and attach one solved example to it in your notes.",
        "These principles are the shortest part of the topic to memorise and the most valuable in the examination.",
        "When you revise, begin with these rules; they are the skeleton on which every example hangs.",
}

var pExOpen = []string{
        "The fastest way to make {t} stick is to work examples, so study the one below line by line.",
        "Examiners choose questions that follow familiar patterns, and the example here shows the standard route.",
        "Read the example twice: once for the story, once for the method.",
}

var pExBody = []string{
        "Consider a straightforward case connected with {ctx}: a learner meets a task that falls squarely inside {t} and must produce a defensible answer.",
        "Stage one, observation: the given facts are written out plainly, whether they are figures, a specimen, a passage or a set of conditions.",
        "Stage two, identification: the requirement is restated in one sentence, so that nobody solves the wrong problem by accident.",
        "Stage three, selection: the fitting principle is named, here {law}, and its conditions are checked against the facts before anything else happens.",
        "Stage four, execution: the chosen method is applied one step per line, with every term and symbol kept consistent from start to finish.",
        "Stage five, checking: the result is read back against the requirement, confirming size, sign and units before the answer is declared.",
        "Notice how the five stages appear here in person: observe, identify, select, execute, check, in that order, exactly as the method section promised.",
        "Carry full precision through every line and round only at the end; premature rounding is a quiet marks killer in {c}.",
        "Now change one detail of the case and work it again yourself; varied practice beats re reading every time.",
        "If your second attempt disagrees with your first, find the exact line where they separated; that line is your learning point.",
}

var pExCloser = []string{
        "Attempt at least three more examples of this kind before you unlock the quiz; fluency, not familiarity, is the target.",
        "The quiz questions were written with exactly this style of working in mind.",
        "One well digested example is worth five half read ones.",
}

var pReal = []string{
        "This topic is not just examination material; it lives inside {ctx}, where decisions depend on it daily.",
        "In Nigeria, you can see {t} at work in places like {ctx}, and connecting the theory to such places makes recall easier.",
        "A professional such as a {car} uses the ideas of {t} when {p} is part of the working day, under real constraints of time and money.",
        "Look at {ctx}: the same five stage method you learned above is what practitioners there follow, only faster and with more data.",
        "When theory feels dry, tie each concept to one concrete place or industry; memory loves pictures and places.",
        "Ask yourself what would go wrong at {ctx} if nobody understood {t}; the answer explains why the topic earns its place in {c}.",
        "Global practice runs on the same principles, from {ctx} to facilities abroad, which means the skill you build here travels with you.",
        "Guest lecturers and industrial training supervisors consistently say the same thing: students who connect topics to real settings stand out.",
}

var pTrap = []string{
        "Every year, examiners report the same avoidable errors on {t}, so read this section as a list of warnings from past scripts.",
        "The first trap is mixing up {sib} with {sib2}; they sound related, but they answer different questions, and options in multiple choice tests exploit that confusion.",
        "The second trap is applying {law} without checking its conditions, which produces confident, well written, completely wrong answers.",
        "The third trap is stopping halfway: many students state a principle and never apply it, losing the application marks entirely.",
        "Another recurring error is ignoring units, signs or labels, so that a correct method lands on a wrong answer.",
        "Some students memorise the steps of {p} in the wrong order; the five stage sequence protects you from that.",
        "Closely related is the habit of copying a worked example without varying the numbers, which creates the feeling of mastery without the fact of it.",
        "A final trap is relying on memory alone the night before; spaced practice across several short sessions beats one long cram.",
        "Print this section and tick each trap as you deliberately avoid it during practice.",
        "The quiz that follows includes items built directly on these traps, so treat them as your revision list.",
}

var pConnect = []string{
        "No topic in {c} stands alone, and {t} draws meaning from its neighbours.",
        "Looking back, the ideas of {uPrev} prepared the ground for what you have just read.",
        "Looking forward, {uNext} will assume you can handle {t} without renegotiating the basics.",
        "Within this unit, the connection is tighter still: the same nouns, {n} and {n2}, reappear with new procedures attached.",
        "Make a small concept map: place {t} at the centre, draw arrows to {sib}, {sib2} and {law}, and label each arrow with one sentence.",
        "Students who build such maps before quizzes answer application questions faster, because retrieval has paths to follow.",
        "When you revise for examinations, revise the connections as well as the topics; questions often join two areas deliberately.",
        "A question that links {t} with another part of {c} is not being cruel; it is testing the maturity that universities prize.",
}

var pExam = []string{
        "Knowing how a topic is examined is half of preparation, so study this section with past papers beside you.",
        "Questions on {t} typically begin with a definition or a request to state a principle such as {law}, and those are your free marks.",
        "Application items follow: a short scenario set at {ctx}, asking you to choose the correct method or result.",
        "Calculation items, where they appear, follow the worked example pattern closely, and method marks reward the staged working you practised above.",
        "The harder items compare near neighbours, {sib} against {sib2} for instance, and punish vague revision.",
        "Multiple choice options are written from the common errors listed in the traps section, which is why that section deserves a second read.",
        "Time discipline matters: definitions take thirty seconds, applications a minute, calculations two or three; practise with a clock.",
        "When stuck, return to the five stages and ask which stage is actually blocking you; naming the block usually breaks it.",
        "Write your own question on {t}, swap with a coursemate, and mark each other; constructing options teaches you how distractors are made.",
}

var pSummary = []string{
        "You have reached the final section, and it is worth pausing to consolidate what this lesson has built.",
        "You began with the meaning of {t}, learned the essential terms {sib}, {sib2} and {sib3}, and then walked the five stage method.",
        "You met the governing principles, led by {law}, and saw them applied in a worked example tied to {ctx}.",
        "You studied the traps that cost other students marks and mapped the connections to {uPrev} and {uNext}.",
        "Your action list is short: rewrite the definitions from memory, redo the worked example with fresh numbers, and list the traps beside your desk.",
        "Read any section again that felt rushed; the quiz will unlock only after the reading, but understanding, not clicking, is the goal.",
        "When you start the quiz, answer the easy items quickly and save time for the hard half, where options are deliberately close.",
        "Review every explanation the quiz shows you, including for correct answers; the explanations often carry one more teaching point.",
        "Well done: a student who completes this reading honestly is prepared for anything the examination board sets on {t}.",
}

/* --------------------------- assembly ----------------------------- */

// sectBuilder assembles one section body. `seen` is shared across the
// WHOLE lesson, so a sentence can never appear twice in one lesson:
// repetition across sections was the worst failure of the first draft
// and the founder reads every section.
type sectBuilder struct {
        g     *RNG
        vals  map[string]string
        seen  map[string]bool
        body  []string
        words int
}

func (b *sectBuilder) fresh(s string) (string, bool) {
        s = Fill(s, b.vals)
        if s == "" || b.seen[s] {
                return "", false
        }
        b.seen[s] = true
        return s, true
}

// add draws n fresh sentences from pool in seeded random order.
func (b *sectBuilder) add(pool []string, n int) {
        for _, s := range b.g.Shuffle(pool) {
                if n <= 0 {
                        return
                }
                if f, ok := b.fresh(s); ok {
                        b.body = append(b.body, f)
                        b.words += len(strings.Fields(f))
                        n--
                }
        }
}

// addOrdered appends pool in its natural pedagogical order, skipping
// already used sentences. Ordered pools carry the fixed teaching
// sequence (stages one to five, vocabulary roles, example narration).
func (b *sectBuilder) addOrdered(pool []string) {
        for _, s := range pool {
                if f, ok := b.fresh(s); ok {
                        b.body = append(b.body, f)
                        b.words += len(strings.Fields(f))
                }
        }
}

// spillPool backs the word floor: fresh sentences that appear nowhere
// else, so the filler never repeats earlier sections.
var spillPool = []string{
        "One more study habit worth adopting is to explain the section aloud to an imaginary classmate, because speaking exposes gaps that silent reading hides.",
        "Keep your notes for this topic on a single spread of paper so that revision before the examination is fast and complete.",
        "Set a small target for each sitting, for example two sections, and reward yourself when the target is met.",
        "Past questions from your institution are the best guide to the depth expected here, so collect a few before the quiz.",
        "If a sentence above feels unclear, reread it slowly rather than moving on; every later sentence assumes the earlier ones.",
        "Formulas and definitions from this topic should enter your revision card today, not during the examination week.",
        "Study groups help most when each member prepares one section and teaches it to the others in turn.",
        "A short daily contact with this topic, even fifteen minutes, builds more lasting mastery than a single long weekend session.",
        "When you meet a new example in class, label its parts with the vocabulary of this lesson and the topic comes alive.",
        "Write the date beside your practice attempts so that your progress across the semester stays visible to you.",
        "Comparing your working with a coursemate's often reveals a simpler route to the same answer.",
        "Remember that the goal is understanding you can transfer to unfamiliar questions, not memorising one solution.",
}

func (b *sectBuilder) render(floor int) string {
        for b.words < floor && len(b.body) < 18 {
                before := len(b.body)
                b.add(spillPool, 1)
                if len(b.body) == before {
                        break // filler exhausted: never spin
                }
        }
        for i := range b.body {
                b.body[i] = Clean(b.body[i])
        }
        return strings.Join(b.body, " ")
}

// NotesResult is the full notes half of a lesson.
type NotesResult struct {
        Headings []string
        Bodies   []string
        Summary  string
        KeyPts   []string
}

// buildNotesStable, the single assembly path used by the engine,
// lives in synth.go: it guarantees that every sentence a quiz item
// depends on is always present in the reading.

func pickN(g *RNG, pool []string, n int) []string {
        return g.PickN(pool, n)
}

var sumPool = []string{
        "The topic of {t} within {c} rewards orderly study: definitions, the five stage method, the principles led by {law}, the real settings such as {ctx}, and the traps that cost marks. Revise in that order and the topic holds together.",
        "This lesson defined {t}, fixed the vocabulary of {sib} and {sib2}, walked the method stage by stage, applied {law} to a worked example, and flagged the classic errors. The quiz that follows tests exactly these moves.",
        "{T} rewards orderly study: learn the terms, learn the steps, learn the conditions of each principle, then practise until the stages run themselves. That is the whole strategy of {c} in miniature.",
}

func keyPoints(g *RNG, v map[string]string) []string {
        kp := []string{
                Clean(Fill("{T} is examined through definitions, applications and comparisons between near neighbours such as {sib} and {sib2}.", v)),
                Clean("The five stage method: observe, identify, select, execute, check. Name it and use it in every answer."),
                Clean(Fill("Name {law} before applying it: stating the governing principle earns method marks.", v)),
                Clean(Fill("Real settings like {ctx} run on this topic; tie each concept to one concrete place for easier recall.", v)),
                Clean(Fill("The classic traps: confusing {sib} with {sib2}, ignoring conditions, stopping halfway, and sloppy units.", v)),
                Clean(Fill("Connect {T} to {uPrev} and {uNext}; examiners often join topics deliberately.", v)),
        }
        return g.PickN(kp, 5)
}

func headingsFor(g *RNG, v map[string]string) []string {
        t := Cap(v["t"])
        return []string{
                Clean("What " + t + " really means"),
                Clean("The vocabulary you need first"),
                Clean("How " + t + " works, step by step"),
                Clean("The rules and principles behind " + t),
                Clean("Worked example you can copy in the exam"),
                Clean(t + " in the real world"),
                Clean("Traps students fall into with " + t),
                Clean("How " + t + " connects to the rest of " + v["c"]),
                Clean("Exam focus: how " + t + " is tested"),
                Clean("Summary and your next moves"),
        }
}

// calcSection is a hook used by the worked example section for
// calculation subjects: it returns one extra body paragraph holding a
// generated, arithmetic checked example in LaTeX.
func calcParagraph(kind string, g *RNG) string {
        if kind == "" {
                return ""
        }
        ex := workedExample(kind, g)
        if ex == nil {
                return ""
        }
        var b strings.Builder
        b.WriteString("Study this fully worked calculation; the same pattern appears in the harder quiz items. ")
        for i, st := range ex.steps {
                b.WriteString(fmt.Sprintf("Step %d: %s ", i+1, st))
        }
        b.WriteString("Check that the final answer is sensible in size and units before you write it down; examiners award the checking sentence its own mark. ")
        return Clean(b.String())
}
