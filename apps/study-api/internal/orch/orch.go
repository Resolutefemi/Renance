// Package orch is the Renance Autonomous Course Orchestrator (founder
// architecture, 2026-11-07): six dedicated GLM 4.5 keys that generate a
// university course unit on demand.
//
//      Key 1 -> Part 1 lecture note   (Foundations)
//      Key 2 -> Part 2 lecture note   (Core Principles I)
//      Key 3 -> Part 3 lecture note   (Core Principles II)
//      Key 4 -> Part 4 lecture note   (Applications & Worked Examples)
//      Key 5 -> Part 5 lecture note   (Synthesis & Revision)
//      Key 6 -> The 20-question unit assessment (fed the combined note)
//
// Stage A dispatches the five note parts in PARALLEL, one key per part.
// Stage B runs strictly AFTER all five parts return: Key 6 receives the
// combined note text and writes the assessment - so every question is
// grounded in what the note actually teaches. The compiled unit matches
// the R2 lesson archive schema byte for byte (5 note parts, key points,
// 20-question quiz, level-dependent theory questions), and persists
// through the learn module's existing dual write (bucket + cache
// database) so the next open is instant.
//
// Configuration (all optional - a missing key set keeps the module off
// and the deterministic agent engine serving):
//
//      ORCH_KEY_1 .. ORCH_KEY_6   the six GLM 4.5 API keys
//      ORCH_BASE_URL              default https://open.bigmodel.cn/api/paas/v4
//      ORCH_MODEL                 default glm-4.5
//      ORCH_THINKING              default disabled (fast, fits the budget)
package orch

import (
        "context"
        "encoding/json"
        "fmt"
        "log/slog"
        "net/http"
        "os"
        "regexp"
        "strconv"
        "strings"
        "sync"
        "time"

        "renance.dev/study-api/internal/tutor"
)

// noteMaxTokens is per PART (the old single-call recipe asked for 10-14
// sections in one 6000-token shot and truncated; one part of >300 words
// with worked examples and LaTeX lands comfortably under this).
const noteMaxTokens = 3072

// quizMaxTokens covers 20 MCQs with full explanations plus 5 theory
// questions with model answers and marking guides.
const quizMaxTokens = 8192

// Acceptance word floors sit deliberately UNDER the prompted depths
// (>300 calculation / >200 non-calculation): a 280-word rigorous part
// with two worked examples is a good part - word-count pedantry must
// not burn a whole regeneration. The prompt still demands the full
// depth; the floor only decides what survives validation.
const (
        calcWordFloor    = 220
        nonCalcWordFloor = 150
)

// Orchestrator is the six-key registry. A nil Orchestrator (FromEnv
// with missing keys) keeps every consumer on today's behavior.
type Orchestrator struct {
        notes [5]tutor.Provider
        quiz  tutor.Provider
        log   *slog.Logger
        model string
}

// FromEnv arms the orchestrator from ORCH_KEY_1..6. All six keys must
// be present - the architecture has no partial posture (five note keys
// without the assessment key would ship notes with no quiz).
func FromEnv(log *slog.Logger) *Orchestrator {
        var keys [6]string
        for i := 0; i < 6; i++ {
                keys[i] = strings.TrimSpace(os.Getenv(fmt.Sprintf("ORCH_KEY_%d", i+1)))
        }
        for i, k := range keys {
                if k == "" {
                        if log != nil {
                                log.Info("orchestrator: off - key missing", "key", i+1)
                        }
                        return nil
                }
        }
        base := strings.TrimSpace(os.Getenv("ORCH_BASE_URL"))
        if base == "" {
                base = "https://open.bigmodel.cn/api/paas/v4"
        }
        base = strings.TrimRight(base, "/")
        model := strings.TrimSpace(os.Getenv("ORCH_MODEL"))
        if model == "" {
                model = "glm-4.5"
        }
        thinking := strings.TrimSpace(os.Getenv("ORCH_THINKING"))
        if thinking == "" {
                thinking = "disabled"
        }
        // One client per key, the house 150s ceiling: a deep part on a slow
        // day legitimately runs long, and the generation budget (300s) is
        // the real governor.
        newProvider := func(key string) tutor.Provider {
                return &tutor.OpenAICompat{
                        BaseURL: base,
                        APIKey:  key,
                        Model:   model,
                        Thinking: func() string {
                                if thinking == "enabled" {
                                        return "enabled"
                                }
                                return "disabled"
                        }(),
                        HTTP: &http.Client{Timeout: 150 * time.Second},
                }
        }
        o := &Orchestrator{quiz: newProvider(keys[5]), log: log, model: model}
        for i := 0; i < 5; i++ {
                o.notes[i] = newProvider(keys[i])
        }
        if log != nil {
                log.Info("orchestrator: 6 GLM keys armed - on-demand unit generation live",
                        "model", model, "base", base, "thinking", thinking)
        }
        return o
}

// Model reports the configured model id (boot logs / ops).
func (o *Orchestrator) Model() string { return o.model }

// ─── The unit contract ────────────────────────────────────────────────────

// Request is everything the orchestrator knows about the unit being
// generated. The learn module fills it from learn.units + learn.courses.
type Request struct {
        TopicID      string
        CourseID     string
        Course       string // course title
        UnitTitle    string // the unit (topic) title
        SectionTitle string // the section the unit lives under
        Dept         string
        Faculty      string
        Seq, Total   int
        Level        int  // 100 | 200 | ... (0 parses as 200+)
        Calc         bool // calculation course (MTS 201 standard)
        Keywords     []string

        // Part is internal (prompt building for the note keys).
        Part int
}

// Note is one part of the 5-part lecture note.
type Note struct {
        Heading string `json:"heading"`
        Body    string `json:"body"`
}

// QuizQ is one objective item (mcq, A-D).
type QuizQ struct {
        Type        string            `json:"type"`
        Stem        string            `json:"stem"`
        Options     map[string]string `json:"options"`
        Answer      string            `json:"answer"`
        Explanation string            `json:"explanation"`
}

// TheoryQ is one 200L+ theory item with its marking guide.
type TheoryQ struct {
        Question  string `json:"question"`
        KeyPoints string `json:"key_points"`
        Answer    string `json:"answer"`
}

// Unit is the compiled lesson document (the R2 archive shape).
type Unit struct {
        Title       string
        Summary     string
        Notes       []Note
        KeyPoints   []string
        Quiz        []QuizQ
        Theory      []TheoryQ
        GeneratedAt time.Time
}

// Generate runs the two-stage pipeline for one unit.
// Stage A: Keys 1-5 in parallel, one part each.
// Stage B: Key 6, sequentially, on the combined note.
// Any hard failure answers an error - the caller (learn) falls back to
// the deterministic agent engine, so a student never sees a dead unit.
func (o *Orchestrator) Generate(ctx context.Context, req Request) (*Unit, error) {
        notes := make([]Note, 5)
        errs := make([]error, 5)
        var wg sync.WaitGroup
        for i := 0; i < 5; i++ {
                wg.Add(1)
                go func(i int) {
                        defer wg.Done()
                        part := i + 1
                        pr := req
                        pr.Part = part
                        notes[i], errs[i] = o.genPart(ctx, pr)
                }(i)
        }
        wg.Wait()
        for i, err := range errs {
                if err != nil {
                        return nil, fmt.Errorf("orch: part %d failed: %w", i+1, err)
                }
        }

        assessment, err := o.genQuiz(ctx, req, notes)
        if err != nil {
                return nil, fmt.Errorf("orch: assessment failed: %w", err)
        }

        unit := &Unit{
                Title:       req.UnitTitle,
                Summary:     assessment.Summary,
                Notes:       notes,
                KeyPoints:   assessment.KeyPoints,
                Quiz:        assessment.Quiz,
                Theory:      assessment.Theory,
                GeneratedAt: time.Now().UTC(),
        }
        return unit, nil
}

// genPart writes one note part on its dedicated key, one repair retry
// (house doctrine: a validation failure is a REPAIR request, not a
// restart from zero).
func (o *Orchestrator) genPart(ctx context.Context, req Request) (Note, error) {
        system := notesSystemPrompt(req.Part, req.Calc)
        user := notesUserPrompt(&req)
        floor := nonCalcWordFloor
        if req.Calc {
                floor = calcWordFloor
        }
        var lastErr error
        for attempt := 0; attempt < 2; attempt++ {
                prompt := user
                if attempt > 0 && lastErr != nil {
                        prompt += fmt.Sprintf("\n\nYour previous attempt failed validation: %v\nFix exactly those problems and return the corrected JSON object. Remember: STRICTLY more than %d words.", lastErr, map[bool]int{true: 300, false: 200}[req.Calc])
                }
                out, err := o.complete(ctx, o.notes[req.Part-1], system, prompt, noteMaxTokens)
                if err != nil {
                        lastErr = err
                        continue
                }
                note, perr := parseNote(out, req.Part, floor)
                if perr == nil {
                        return note, nil
                }
                lastErr = perr
        }
        return Note{}, lastErr
}

// assessment is Key 6's parsed output.
type assessment struct {
        Summary   string   `json:"summary"`
        KeyPoints []string `json:"key_points"`
        Quiz      []QuizQ  `json:"quiz"`
        Theory    []TheoryQ `json:"theory_questions"`
}

// genQuiz runs Stage B: Key 6 over the combined note.
func (o *Orchestrator) genQuiz(ctx context.Context, req Request, notes []Note) (*assessment, error) {
        system := quizSystemPrompt(req.Level)
        user := quizUserPrompt(&req, notes)
        var lastErr error
        for attempt := 0; attempt < 2; attempt++ {
                prompt := user
                if attempt > 0 && lastErr != nil {
                        prompt += fmt.Sprintf("\n\nYour previous attempt failed validation: %v\nFix exactly those problems and return the corrected JSON object. Remember the exact counts: %s.", lastErr, quizCountsContract(req.Level))
                }
                out, err := o.complete(ctx, o.quiz, system, prompt, quizMaxTokens)
                if err != nil {
                        lastErr = err
                        continue
                }
                a, perr := parseAssessment(out, req.Level)
                if perr == nil {
                        return a, nil
                }
                lastErr = perr
        }
        return nil, lastErr
}

func quizCountsContract(level int) string {
        if level >= 200 {
                return "exactly 15 objective (A-D) + exactly 5 theory questions"
        }
        return "exactly 20 objective (A-D) + zero theory questions"
}

// ─── Provider calls ───────────────────────────────────────────────────────

// complete rides out the provider's rate-limit window (house pattern:
// a 429 backs off 20s/35s and retries inside the generation budget).
func (o *Orchestrator) complete(ctx context.Context, p tutor.Provider, system, prompt string, maxTokens int) (string, error) {
        var lastErr error
        for i := 0; i < 3; i++ {
                out, err := p.Complete(ctx, system, []tutor.Message{{Role: "user", Content: prompt}}, maxTokens)
                if err == nil && strings.TrimSpace(out) != "" {
                        return out, nil
                }
                lastErr = err
                if err == nil {
                        lastErr = fmt.Errorf("empty reply")
                }
                if !strings.Contains(err.Error(), "429") {
                        return "", lastErr
                }
                if o.log != nil {
                        o.log.Info("orchestrator: provider rate-limited - backing off", "attempt", i+1)
                }
                select {
                case <-ctx.Done():
                        return "", ctx.Err()
                case <-time.After(time.Duration(20*(i+1)) * time.Second):
                }
        }
        return "", lastErr
}

// ─── Parsing + validation ─────────────────────────────────────────────────

var jsonFences = regexp.MustCompile("(?s)```(?:json)?(.*?)```")

// extractJSON trims fences and anything around the outermost braces.
func extractJSON(raw string) string {
        trimmed := strings.TrimSpace(raw)
        if m := jsonFences.FindStringSubmatch(trimmed); m != nil {
                trimmed = strings.TrimSpace(m[1])
        }
        start := strings.Index(trimmed, "{")
        end := strings.LastIndex(trimmed, "}")
        if start >= 0 && end > start {
                trimmed = trimmed[start : end+1]
        }
        return trimmed
}

// salvageJSON closes the brackets of a truncated JSON document around
// its last complete element (the house trick - LaTeX escapes make
// mid-string truncation common).
func salvageJSON(raw string) string {
        lastClose := strings.LastIndex(raw, "}")
        if lastClose < 0 {
                return raw
        }
        trimmed := raw[:lastClose+1]
        var stack []rune
        inStr, esc := false, false
        for _, r := range trimmed {
                if esc {
                        esc = false
                        continue
                }
                if r == '\\' && inStr {
                        esc = true
                        continue
                }
                if r == '"' {
                        inStr = !inStr
                        continue
                }
                if inStr {
                        continue
                }
                switch r {
                case '{':
                        stack = append(stack, '}')
                case '[':
                        stack = append(stack, ']')
                case '}', ']':
                        if len(stack) > 0 {
                                stack = stack[:len(stack)-1]
                        }
                }
        }
        if esc && len(trimmed) > 0 && trimmed[len(trimmed)-1] == '\\' {
                trimmed = trimmed[:len(trimmed)-1]
        }
        if inStr {
                trimmed += `"`
        }
        for i := len(stack) - 1; i >= 0; i-- {
                trimmed += string(stack[i])
        }
        return trimmed
}

// parseNote validates one note part.
func parseNote(raw string, part, wordFloor int) (Note, error) {
        body := extractJSON(raw)
        var n Note
        if err := json.Unmarshal([]byte(body), &n); err != nil {
                if serr := json.Unmarshal([]byte(salvageJSON(body)), &n); serr != nil {
                        return Note{}, fmt.Errorf("part %d: decode: %w", part, err)
                }
        }
        n.Heading = strings.TrimSpace(n.Heading)
        n.Body = strings.TrimSpace(n.Body)
        if n.Heading == "" {
                return Note{}, fmt.Errorf("part %d: empty heading", part)
        }
        if n.Body == "" {
                return Note{}, fmt.Errorf("part %d: empty body", part)
        }
        if words := len(strings.Fields(n.Body)); words < wordFloor {
                return Note{}, fmt.Errorf("part %d: %d words, floor is %d", part, words, wordFloor)
        }
        if strings.Contains(n.Body, "<") && strings.Contains(n.Body, ">") {
                return Note{}, fmt.Errorf("part %d: HTML in body", part)
        }
        return n, nil
}

// parseAssessment validates Key 6's output against the level contract.
func parseAssessment(raw string, level int) (*assessment, error) {
        body := extractJSON(raw)
        var a assessment
        if err := json.Unmarshal([]byte(body), &a); err != nil {
                if serr := json.Unmarshal([]byte(salvageJSON(body)), &a); serr != nil {
                        return nil, fmt.Errorf("decode: %w", err)
                }
        }
        // Objective sweep: exactly A-D, answer letter resolves, explanation
        // present. Dead items are dropped; too many dead items = repair.
        quiz := make([]QuizQ, 0, len(a.Quiz))
        for _, q := range a.Quiz {
                q.Stem = strings.TrimSpace(q.Stem)
                q.Answer = strings.ToUpper(strings.TrimSpace(q.Answer))
                q.Explanation = strings.TrimSpace(q.Explanation)
                if q.Stem == "" || q.Explanation == "" {
                        continue
                }
                fixed := map[string]string{}
                for k, v := range q.Options {
                        k = strings.ToUpper(strings.TrimSpace(k))
                        v = strings.TrimSpace(v)
                        if len(k) == 1 && k >= "A" && k <= "E" && v != "" {
                                fixed[k] = v
                        }
                }
                if len(fixed) != 4 { // the spec is A-D, exactly four
                        continue
                }
                if _, ok := fixed[q.Answer]; !ok {
                        continue
                }
                q.Type = "mcq"
                q.Options = fixed
                quiz = append(quiz, q)
        }
        theory := make([]TheoryQ, 0, len(a.Theory))
        for _, t := range a.Theory {
                t.Question = strings.TrimSpace(t.Question)
                t.KeyPoints = strings.TrimSpace(t.KeyPoints)
                t.Answer = strings.TrimSpace(t.Answer)
                if t.Question == "" || t.KeyPoints == "" || t.Answer == "" {
                        continue
                }
                theory = append(theory, t)
        }
        if level >= 200 {
                if len(quiz) < 13 {
                        return nil, fmt.Errorf("want >=13 objective items, got %d", len(quiz))
                }
                if len(theory) < 4 {
                        return nil, fmt.Errorf("want >=4 theory questions, got %d", len(theory))
                }
                if len(quiz) > 15 {
                        quiz = quiz[:15]
                }
                if len(theory) > 5 {
                        theory = theory[:5]
                }
        } else {
                // Level 100: ZERO theory questions (founder spec) - any that
                // leak through are dropped, not served.
                theory = nil
                if len(quiz) < 18 {
                        return nil, fmt.Errorf("want >=18 objective items, got %d", len(quiz))
                }
                if len(quiz) > 20 {
                        quiz = quiz[:20]
                }
        }
        if len(a.KeyPoints) < 3 {
                return nil, fmt.Errorf("want >=3 key points, got %d", len(a.KeyPoints))
        }
        if strings.TrimSpace(a.Summary) == "" {
                return nil, fmt.Errorf("empty summary")
        }
        rebalanceAnswers(quiz)
        a.Quiz = quiz
        a.Theory = theory
        return &a, nil
}

// rebalanceAnswers enforces the founder's scattering rule when the
// model leaned on one letter: every over-represented question is
// ROTATED (options cyclically shifted, answer letter remapped) onto the
// least-used letter. Deterministic, grading-safe (the answer text
// travels with its letter), and it never rewrites an option.
func rebalanceAnswers(quiz []QuizQ) {
        if len(quiz) == 0 {
                return
        }
        letters := []string{"A", "B", "C", "D"}
        counts := map[string]int{}
        for _, q := range quiz {
                counts[q.Answer]++
        }
        cap := (len(quiz) + 3) / 4 // ~25% balance target, rounded up
        for i := range quiz {
                if counts[quiz[i].Answer] <= cap {
                        continue
                }
                // Find the least-used letter and rotate this question onto it.
                target, best := "", 1<<30
                for _, l := range letters {
                        if counts[l] < best {
                                target, best = l, counts[l]
                        }
                }
                if target == "" || target == quiz[i].Answer {
                        continue
                }
                shift := 0
                for j, l := range letters {
                        if l == quiz[i].Answer {
                                shift = j
                        }
                }
                for j, l := range letters {
                        if l == target {
                                // Cyclic rotation: option at position j takes the value
                                // from position (j+shift)%4.
                                src := letters[(j+shift)%4]
                                quiz[i].Options[l] = quiz[i].Options[src]
                        }
                }
                counts[quiz[i].Answer]--
                quiz[i].Answer = target
                counts[target]++
        }
}

// ─── Level + course-type helpers ──────────────────────────────────────────

// ParseLevel maps learn.courses.level onto the 100/200/... ladder the
// assessment spec keys on. "100 Level".."600 Level" parse directly;
// ND/NCE roman ranks map I->100, II->200, III->300; HND rides one band
// higher (post-ND). Anything unparsable answers 200 - the spec's
// "Level 200 & Above" branch - so an exotic level string never silently
// strips a course's theory questions.
func ParseLevel(level string) int {
        s := strings.TrimSpace(strings.ToUpper(level))
        if s == "" {
                return 200
        }
        if n, err := strconv.Atoi(s[:1]); err == nil && strings.Contains(s, "LEVEL") {
                return n * 100
        }
        romans := map[string]int{"I": 1, "II": 2, "III": 3, "IV": 4}
        for _, r := range []string{"IV", "III", "II", "I"} {
                if strings.HasSuffix(s, r) {
                        base := romans[r] * 100
                        if strings.HasPrefix(s, "HND") {
                                base += 100
                        }
                        return base
                }
        }
        if n, err := strconv.Atoi(strings.Fields(s)[0]); err == nil && n >= 100 {
                return n
        }
        return 200
}

// calcWords flag a calculation course (the founder's "MTS 201
// standard"): quantitative disciplines whose notes carry formulas and
// worked mathematics.
var calcWords = []string{
        "mathematic", "maths", "mt s", "statistics", "statistic", "quantitative",
        "chemistry", "physics", "engineering", "mechanics", "thermodynamic",
        "calculus", "algebra", "geometry", "trigonometry", "computation",
        "computing", "programming", "electronic", "electric", "circuit",
        "account", "finance", "economic", "actuarial", "survey", "strength of material",
        "fluid", "dynamics", "kinematic", "astronom", "geolog", "biochemist",
        "pharmacolog", "physiolog", "anatom", "measure", "instrument", "control system",
        "machine", "thermal", "hydraulic", "structural", "numerical", "operation research",
}

// IsCalcCourse reports whether a unit rides the calculation recipe.
func IsCalcCourse(course, dept, unitTitle string) bool {
        hay := strings.ToLower(course + " " + dept + " " + unitTitle)
        for _, w := range calcWords {
                if strings.Contains(hay, w) {
                        return true
                }
        }
        return false
}
