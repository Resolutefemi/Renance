// engine.go - the just-in-time lesson pipeline (Supreme engine.ts
// ported): cache hit → serve; miss → one strict-JSON AI generation
// (two attempts, repair retry), validated, decorated with the curated
// drawing library and REAL past questions from the Renance bank, then
// persisted as a read-through cache. The next two topics of the course
// are prefetched in the background.
package learn

import (
        "context"
        "encoding/json"
        "fmt"
        "regexp"
        "sort"
        "strconv"
        "strings"
        "sync"
        "time"

        "renance.dev/study-api/internal/cbtdata"
        "renance.dev/study-api/internal/tutor"
)

type LessonNote struct {
        Heading  string `json:"heading"`
        Body     string `json:"body"`
        Image    string `json:"image,omitempty"`
        ImageAlt string `json:"imageAlt,omitempty"`
}

type LessonQuizQ struct {
        ID          string            `json:"id"`
        Type        string            `json:"type"` // mcq | true_false | fill_blank | word_bank
        Stem        string            `json:"stem"`
        Options     map[string]string `json:"options,omitempty"`
        Answer      string            `json:"answer"`
        Explanation string            `json:"explanation,omitempty"`
        Year        int               `json:"year,omitempty"`
        FromBank    bool              `json:"fromBank,omitempty"` // a real past question
}

type LessonDoc struct {
        TopicID   string       `json:"topicId"`
        CourseID  string       `json:"courseId"`
        Course    string       `json:"course"`
        Title     string       `json:"title"`
        Summary   string       `json:"summary"`
        Notes     []LessonNote `json:"notes"`
        KeyPoints []string     `json:"keyPoints"`
        Quiz      []LessonQuizQ `json:"quiz"`
        Drawings  []DrawingRef `json:"drawings"`
        Source    string       `json:"source"`
        Cached    bool         `json:"cached"`
}

// LessonSource is the lesson FORMAT stamp: the generation recipe it
// follows. A cached row carrying a different stamp was written by an
// older recipe and regenerates at the current depth on its next open
// (founder 2026-10-15: "the notes generated in each part are too small
// and short, not that explainable" - the old recipe allowed 60-140-word
// bodies; the current one demands 150-260 words and worked examples).
// If regeneration fails (AI down), the stale doc still serves - its
// quiz is sanitized on the way out either way.
const LessonSource = "zai-glm-2"

type Engine struct {
        AI  tutor.Provider
        Lib *cbtdata.Library
        Log interface {
                Error(string, ...any)
                Info(string, ...any)
        }
        sem  chan struct{}
        mu   sync.Mutex
        live map[string]*inflight
}

type inflight struct {
        done chan struct{}
        doc  *LessonDoc
        err  error
}

func NewEngine(ai tutor.Provider, lib *cbtdata.Library) *Engine {
        return &Engine{
                AI:  ai,
                Lib: lib,
                sem: make(chan struct{}, 3), // MAX_PARALLEL parity
                live: map[string]*inflight{},
        }
}

// ─── Prompting ────────────────────────────────────────────────────────────

const lessonSystem = `You are Renance's AI tutor: an expert Nigerian teacher writing full lesson notes for students preparing for their exams.

Rules:
- Write for the topic's exam body. JAMB/WAEC/NECO topics follow the Nigerian senior-secondary syllabus; university topics follow the NUC CCMAS / NBTE / NCCE curricula.
- Output STRICT JSON only. No markdown fences, no commentary.
- Shape: {"title": string, "summary": string, "notes": [{"heading": string, "body": string}], "key_points": [string], "quiz": [{"type": "mcq", "stem": string, "options": {"A": string, "B": string, "C": string}, "answer": "A"|"B"|"C", "explanation": string}]}
- notes: 5 to 7 sections that TEACH, not tease. Each body: 150-260 words of plain-text paragraphs (no HTML, no markdown syntax). Define every term in full, walk through at least one worked example step by step (numbered steps), point out the exam trap students actually fail on, and use Nigerian examples (naira, kana, Lagos/Kano/Akure contexts) where natural. A student who reads ONLY these notes must be able to answer every quiz item.
- MATHS NOTATION (strict): every formula, equation, exponent or symbol is LaTeX wrapped in dollar signs. Write $x^2$, $H_2O$, $\\frac{dy}{dx}$, $\\lim_{x \\to \\infty} f(x)$, $\\int_0^1 x^2\\,dx$, $\\sum_{i=1}^{n} i$. NEVER write bare caret or underscore notation (x^2, H_2O, 10^5) outside $...$ - the renderer typesets $...$ only and prints everything else raw.
- key_points: 4 to 6 exam-focused takeaways.
- quiz: 6 to 8 items. EVERY item has "type": "mcq" and EXACTLY 3 options keyed "A", "B", "C" - never 2, never 4, never a fill-in-the-blank or true/false item. Each stem tests THIS lesson's notes (same terms, same worked examples); anything the notes did not teach is forbidden. "answer" is the LETTER ("A", "B" or "C") of the correct option. Distractors must be plausible; never reveal the answer inside the stem. Ramping difficulty. Every item carries a short explanation.`

func lessonUserPrompt(topic, course, body, subject string, seq, total int) string {
        band := "Nigerian university level (NUC CCMAS)"
        if body == "jamb" || body == "waec" || body == "neco" || body == "post-utme" {
                band = fmt.Sprintf("Nigerian senior-secondary %s standard", strings.ToUpper(body))
        }
        subjectLine := ""
        if subject != "" {
                subjectLine = fmt.Sprintf("\nSubject: %s", subject)
        }
        return fmt.Sprintf(`Write the lesson for:
Topic: %s
Course: %s%s
Standard: %s
Position: topic %d of %d in the course roadmap.

Return the JSON object now.`, topic, course, subjectLine, band, seq, total)
}

// ─── JSON validation ──────────────────────────────────────────────────────

type aiLesson struct {
        Title     string `json:"title"`
        Summary   string `json:"summary"`
        Notes     []struct {
                Heading string `json:"heading"`
                Body    string `json:"body"`
        } `json:"notes"`
        KeyPoints []string       `json:"key_points"`
        Quiz      []aiQuizQ      `json:"quiz"`
}

type aiQuizQ struct {
        Type        string            `json:"type"`
        Stem        string            `json:"stem"`
        Options     map[string]string `json:"options"`
        Answer      string            `json:"answer"`
        Explanation string            `json:"explanation"`
}

var jsonFences = regexp.MustCompile("(?s)```(?:json)?(.*?)```")

func extractJSON(raw string) string {
        trimmed := strings.TrimSpace(raw)
        if m := jsonFences.FindStringSubmatch(trimmed); m != nil {
                trimmed = strings.TrimSpace(m[1])
        }
        // Trim anything around the outermost braces.
        start := strings.Index(trimmed, "{")
        end := strings.LastIndex(trimmed, "}")
        if start >= 0 && end > start {
                trimmed = trimmed[start : end+1]
        }
        return trimmed
}

// validateAI gates the AI output before it is ever served. The quiz
// contract (founder directive 2026-10-15): every item an exactly-3-option
// mcq whose answer resolves to one of ITS OWN option letters - anything
// else is sent back for the one repair retry, and normalizeQuiz still
// sweeps whatever slips through.
func validateAI(raw []byte) (*aiLesson, error) {
        var l aiLesson
        if err := json.Unmarshal(raw, &l); err != nil {
                return nil, err
        }
        if len(l.Notes) < 3 || len(l.Notes) > 8 {
                return nil, fmt.Errorf("want 3-8 notes, got %d", len(l.Notes))
        }
        if len(l.Quiz) < 5 {
                return nil, fmt.Errorf("want >=5 quiz items, got %d", len(l.Quiz))
        }
        for i, n := range l.Notes {
                if strings.TrimSpace(n.Body) == "" {
                        return nil, fmt.Errorf("note %d has empty body", i)
                }
                if strings.Contains(n.Body, "<") && strings.Contains(n.Body, ">") {
                        return nil, fmt.Errorf("note %d contains HTML", i)
                }
                // The founder's "notes are too small and short, not that
                // explainable" (2026-10-15): thin bodies are a validation
                // failure now - the repair retry regenerates them at full depth.
                if words := len(strings.Fields(n.Body)); words < 90 {
                        return nil, fmt.Errorf("note %d is too thin (%d words, want >=90)", i, words)
                }
        }
        mcqs := 0
        for i, q := range l.Quiz {
                if strings.TrimSpace(q.Stem) == "" || strings.TrimSpace(q.Answer) == "" {
                        return nil, fmt.Errorf("quiz %d missing stem/answer", i)
                }
                t := strings.ToLower(strings.TrimSpace(q.Type))
                if t != "mcq" && t != "multiple_choice" && t != "multiplechoice" {
                        return nil, fmt.Errorf("quiz %d: type %q is not mcq - every item must be a 3-option mcq", i, q.Type)
                }
                opts := map[string]bool{}
                for k, v := range q.Options {
                        if strings.TrimSpace(v) != "" {
                                opts[strings.ToUpper(strings.TrimSpace(k))] = true
                        }
                }
                if len(opts) != 3 {
                        return nil, fmt.Errorf("quiz %d: want exactly 3 options, got %d", i, len(opts))
                }
                ans := strings.ToUpper(strings.TrimSpace(q.Answer))
                if len(ans) == 1 && opts[ans] {
                        mcqs++
                        continue
                }
                // Text answers are accepted only when they name one of the options.
                found := false
                for _, v := range q.Options {
                        if strings.EqualFold(strings.TrimSpace(v), strings.TrimSpace(q.Answer)) {
                                found = true
                        }
                }
                if !found {
                        return nil, fmt.Errorf("quiz %d: answer %q matches no option letter or option text", i, q.Answer)
                }
                mcqs++
        }
        if mcqs < 5 {
                return nil, fmt.Errorf("want >=5 solid mcq items, got %d", mcqs)
        }
        return &l, nil
}

// normalizeQuiz converts every AI item into a shape the client can
// RENDER. Doctrine (founder bug report 2026-10-14: quiz questions with
// a blank answer area): an MCQ without options is a dead end - the stem
// shows and nothing below it is tappable. So:
//   - fill_blank            → word_bank (distractors from the lesson corpus)
//   - true_false (+aliases) → true_false (answer folded to true/false)
//   - mcq                   → mcq, letters uppercased, answer resolved to
//                             an option letter and trimmed to EXACTLY 3
//                             options (founder directive 2026-10-15: every
//                             choice question ships three options, never
//                             two, four or zero)
//   - anything else         → true_false when the answer reads boolean,
//                             else word_bank - never an option-less mcq
func (e *Engine) normalizeQuiz(in []aiQuizQ, topicID string, corpus []string) []LessonQuizQ {
        out := make([]LessonQuizQ, 0, len(in))
        for i, q := range in {
                o := LessonQuizQ{
                        ID:          fmt.Sprintf("%s-ai-%d", topicID, i+1),
                        Type:        q.Type,
                        Stem:        strings.TrimSpace(q.Stem),
                        Options:     q.Options, // THE blank-quiz bug (2026-10-14): the old copy loop dropped this field, so every AI mcq reached the client with an empty options map - stem rendered, answer area blank.
                        Answer:      strings.TrimSpace(q.Answer),
                        Explanation: strings.TrimSpace(q.Explanation),
                }
                switch strings.ToLower(strings.TrimSpace(o.Type)) {
                case "mcq", "multiple_choice", "multiplechoice":
                        o.Type = "mcq"
                        // Uppercase option letters and drop empty ones.
                        fixed := map[string]string{}
                        for k, v := range o.Options {
                                if strings.TrimSpace(v) == "" {
                                        continue
                                }
                                fixed[strings.ToUpper(strings.TrimSpace(k))] = strings.TrimSpace(v)
                        }
                        if len(fixed) < 2 {
                                // An MCQ with no real options can never be answered
                                // on screen - ship it as a type-in instead.
                                o.Type = "word_bank"
                                o.Options = buildWordBank(o.Answer, corpus)
                        } else {
                                o.Options, o.Answer, o.ID = trimToThree(fixed, o.Answer, o.ID)
                                if o.Options == nil {
                                        // answer matched no option: degrade to a type-in
                                        // keyed to the answer text, never a dead letter
                                        o.Type = "word_bank"
                                        o.Options = buildWordBank(o.Answer, corpus)
                                }
                        }
                case "true_false", "truefalse", "true/false", "boolean":
                        o.Type = "true_false"
                        o.Options = nil
                        ans := strings.ToLower(o.Answer)
                        if strings.HasPrefix(ans, "t") || strings.HasPrefix(ans, "y") || ans == "1" {
                                o.Answer = "true"
                        } else {
                                o.Answer = "false"
                        }
                case "fill_blank", "short_answer", "input":
                        // → word_bank with distractors harvested from the notes.
                        o.Type = "word_bank"
                        o.Options = buildWordBank(o.Answer, corpus)
                default:
                        // Unknown type the client has no renderer for: never ship
                        // it raw. Boolean-looking answers become true_false; any
                        // other answer becomes a word-bank type-in keyed to the
                        // exact answer text.
                        ans := strings.ToLower(o.Answer)
                        if ans == "true" || ans == "false" || ans == "t" || ans == "f" ||
                                ans == "yes" || ans == "no" {
                                o.Type = "true_false"
                                o.Options = nil
                                if strings.HasPrefix(ans, "t") || strings.HasPrefix(ans, "y") {
                                        o.Answer = "true"
                                } else {
                                        o.Answer = "false"
                                }
                        } else {
                                o.Type = "word_bank"
                                o.Options = buildWordBank(o.Answer, corpus)
                        }
                }
                out = append(out, o)
        }
        return out
}

// ─── The three-option doctrine (founder 2026-10-15) ────────────────────────
//
// "There will be questions in some and the options will not be three, or
// the right answer will be picked and it will mark the user wrong." Both
// halves have one root: questions whose stored answer does not line up
// with the options the student actually sees. trimToThree resolves the
// answer to one of the question's own option letters (letter OR exact
// text), then re-letters the question to EXACTLY three options - the
// answer plus two distractors, answer position deterministic per
// question id. It returns nil options when the answer matches nothing
// (caller degrades to a type-in / drops the question).

// answerLetter finds the option the stored answer points at: a direct
// letter hit first, then an exact (case/space-insensitive) text hit.
func answerLetter(opts map[string]string, answer string) (string, bool) {
        ans := strings.TrimSpace(answer)
        if len(ans) == 1 {
                letter := strings.ToUpper(ans)
                if _, ok := opts[letter]; ok {
                        return letter, true
                }
        }
        for k, v := range opts {
                if strings.EqualFold(strings.TrimSpace(v), ans) {
                        return k, true
                }
        }
        // Common bank quirk: answers recorded as 1..N indices.
        if n, err := strconv.Atoi(ans); err == nil && n >= 1 && n <= len(opts) {
                letters := sortedKeys(opts)
                return letters[n-1], true
        }
        return "", false
}

func sortedKeys(m map[string]string) []string {
        ks := make([]string, 0, len(m))
        for k := range m {
                ks = append(ks, k)
        }
        sort.Strings(ks)
        return ks
}

// trimToThree re-letters an MCQ to exactly three options: the answer plus
// the first two distractors. A question that already carries exactly three
// options and a resolvable letter answer keeps its own letters untouched;
// everything else (4+ options, text answers, dead letters) is re-lettered
// with the answer at a deterministic slot per question (hash of the id) so
// a re-serve never reshuffles it.
func trimToThree(opts map[string]string, answer, id string) (map[string]string, string, string) {
        ansLetter, ok := answerLetter(opts, answer)
        if !ok {
                return nil, answer, id
        }
        if len(opts) == 3 {
                if len(strings.TrimSpace(answer)) == 1 && strings.ToUpper(strings.TrimSpace(answer)) == ansLetter {
                        return opts, ansLetter, id // already doctrine-clean
                }
                // Exactly three options but a text/index answer: fold the
                // answer to its own letter, keep the option letters as they are.
                return opts, ansLetter, id
        }
        distractors := make([]string, 0, 2)
        for _, k := range sortedKeys(opts) {
                if k != ansLetter && len(distractors) < 2 {
                        distractors = append(distractors, k)
                }
        }
        // Position the answer at a deterministic slot (0, 1 or 2).
        slot := int(hashStr(id) % 3)
        if slot > len(distractors) { // fewer distractors than the slot needs
                slot = len(distractors)
        }
        ordered := make([]string, 0, 3)
        ordered = append(ordered, distractors[:slot]...)
        ordered = append(ordered, ansLetter)
        ordered = append(ordered, distractors[slot:]...)

        out := make(map[string]string, len(ordered))
        newAnswer := ""
        for i, k := range ordered {
                letter := string(rune('A' + i))
                out[letter] = opts[k]
                if k == ansLetter {
                        newAnswer = letter
                }
        }
        return out, newAnswer, id
}

// sanitizeQuiz is the SERVE-TIME sweep (founder bug reports 2026-10-15):
// lessons cached before the three-option doctrine carry 4-5-option bank
// questions, text answers, true_false letters and option-less mcqs.
// Every read path (lesson serve, practice set, review set) runs this so
// the whole back catalogue heals without a single regeneration. It
// returns the cleaned slice and whether anything changed (the lesson
// cache persists the healed form once, piggy-backing on a serve that
// already touches the database).
func sanitizeQuiz(in []LessonQuizQ) ([]LessonQuizQ, bool) {
        if len(in) == 0 {
                return in, false
        }
        changed := false
        out := make([]LessonQuizQ, 0, len(in))
        for _, q := range in {
                switch q.Type {
                case "mcq":
                        fixed := map[string]string{}
                        for k, v := range q.Options {
                                if strings.TrimSpace(v) == "" {
                                        continue
                                }
                                fixed[strings.ToUpper(strings.TrimSpace(k))] = strings.TrimSpace(v)
                        }
                        if len(fixed) < 2 {
                                changed = true
                                continue // unanswerable: drop, never ship a blank quiz
                        }
                        if len(fixed) != len(q.Options) {
                                changed = true
                        }
                        trimmed, answer, _ := trimToThree(fixed, q.Answer, q.ID)
                        if trimmed == nil {
                                changed = true
                                continue // answer points nowhere: dead question, drop it
                        }
                        if len(q.Options) != len(trimmed) || answer != q.Answer {
                                changed = true
                        }
                        q.Options = trimmed
                        q.Answer = answer
                case "true_false":
                        ans := strings.ToLower(strings.TrimSpace(q.Answer))
                        folded := "false"
                        if strings.HasPrefix(ans, "t") || strings.HasPrefix(ans, "y") || ans == "1" {
                                folded = "true"
                        }
                        if folded != q.Answer {
                                changed = true
                                q.Answer = folded
                        }
                        q.Options = nil
                default:
                        // word_bank / fill_blank stay as shipped - the client
                        // self-heals their word tiles.
                }
                if strings.TrimSpace(q.Stem) != "" {
                        out = append(out, q)
                } else {
                        changed = true
                }
        }
        return out, changed
}

func buildWordBank(answer string, corpus []string) map[string]string {
        ans := strings.TrimSpace(answer)
        bank := map[string]string{strings.ToLower(ans): ans}
        words := strings.Fields(ans)
        if len(words) > 1 {
                return bank // multi-word answers get no distractors (type-in)
        }
        for _, src := range corpus {
                for _, w := range strings.Fields(src) {
                        w = strings.Trim(w, ".,;:!?()\"'")
                        lw := strings.ToLower(w)
                        if len(w) > 2 && lw != strings.ToLower(ans) && len(bank) < 5 {
                                if isWordish(w) {
                                        bank[lw] = w
                                }
                        }
                }
                if len(bank) >= 5 {
                        break
                }
        }
        return bank
}

func isWordish(w string) bool {
        for _, r := range w {
                if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '\'') {
                        return false
                }
        }
        return true
}

// ─── Bank injection (real past questions) ─────────────────────────────────

var stripRe = regexp.MustCompile(`[^a-z0-9]+`)

// bankQuestions filters a body's bundle for stems matching the topic
// keywords, deterministic order, capped. This is the founder's rule:
// the course quizzes carry the students' ACTUAL past questions - and
// (2026-10-15) they must correspond with the topic being studied: a
// single generic-word hit no longer qualifies, questions RANK by how
// many topic keywords they match, and every survivor is re-lettered to
// exactly three options.
func (e *Engine) bankQuestions(body, subject string, keywords []string, topicID string, cap int) []LessonQuizQ {
        if e.Lib == nil || cap <= 0 || len(keywords) == 0 {
                return nil
        }
        code := fmt.Sprintf("%s-%s-bank", body, subject)
        b, ok := e.Lib.Bundle(code)
        if !ok {
                // Some WAEC subjects split obj/theory: try the object paper name.
                code = fmt.Sprintf("%s-%s-obj-bank", body, subject)
                b, ok = e.Lib.Bundle(code)
                if !ok {
                        return nil
                }
        }
        // The library's resident copy is answer-free (harvest+sanitize,
        // memory doctrine): re-attach the harvested key material on a
        // transient copy so the filter below sees real answers and the
        // quiz ships with its explanations. The LRU copy stays sanitized.
        if keys, hasKeys := e.Lib.KeysFor(code); hasKeys {
                b = b.WithKeyMaterial(keys)
        }
        // Strong keywords (≥6 letters, e.g. "photosynthesis") qualify on
        // their own; short generic ones ("word", "cell", "form") need at
        // least two distinct hits. Founder report 2026-10-15: "the past
        // questions the AI is fetching to the quiz are not corresponding
        // with the notes or subject at all" - the old single-≥4-char-match
        // let generic words drag whole off-topic sections in.
        type scored struct {
                q     cbtdata.Question
                score int
        }
        strong := map[string]bool{}
        weak := map[string]bool{}
        for _, k := range keywords {
                if kk := stripRe.ReplaceAllString(strings.ToLower(k), ""); len(kk) >= 6 {
                        strong[kk] = true
                } else if len(kk) >= 4 {
                        weak[kk] = true
                }
        }
        if len(strong)+len(weak) == 0 {
                return nil
        }
        var hits []scored
        for _, q := range b.Questions {
                if q.Type != "mcq" || q.Answer == "" || len(q.Options) < 2 {
                        continue
                }
                stem := stripRe.ReplaceAllString(strings.ToLower(q.Stem+" "+q.Topic), "")
                score, strongHit := 0, false
                for k := range strong {
                        if strings.Contains(stem, k) {
                                score += 2
                                strongHit = true
                        }
                }
                weakHits := 0
                for k := range weak {
                        if strings.Contains(stem, k) {
                                weakHits++
                                if weakHits >= 2 {
                                        break
                                }
                        }
                }
                score += weakHits
                // Qualify: one strong keyword, or two weak ones together.
                if !strongHit && weakHits < 2 {
                        continue
                }
                hits = append(hits, scored{q: q, score: score})
        }
        // Rank: topic relevance first, then the founder's recency bias.
        sort.SliceStable(hits, func(i, j int) bool {
                if hits[i].score != hits[j].score {
                        return hits[i].score > hits[j].score
                }
                return hits[i].q.Year > hits[j].q.Year
        })
        // Deterministic shuffle within the same score band, then cap.
        seed := uint32(len(hits)) ^ hashStr(topicID)
        rng := mulberry32(seed)
        for i := len(hits) - 1; i > 0; i-- {
                j := int(rng() % uint32(i+1))
                hits[i], hits[j] = hits[j], hits[i]
        }
        // Keep the score order across the shuffle: re-stable-sort by score
        // (shuffle only broke ties inside equal bands).
        sort.SliceStable(hits, func(i, j int) bool { return hits[i].score > hits[j].score })
        if len(hits) > cap {
                hits = hits[:cap]
        }
        out := make([]LessonQuizQ, 0, len(hits))
        for _, h := range hits {
                q := h.q
                o := LessonQuizQ{
                        ID:          q.ID,
                        Type:        "mcq",
                        Stem:        q.Stem,
                        Options:     q.Options,
                        Answer:      q.Answer,
                        Explanation: q.Explanation,
                        Year:        q.Year,
                        FromBank:    true,
                }
                if o.Explanation == "" {
                        o.Explanation = "A real past question from the Renance bank."
                }
                // Three-option doctrine: keep the answer + two distractors,
                // re-lettered A/B/C with the answer deterministically placed.
                // A survivor whose answer cannot be resolved is dropped rather
                // than shipped as a misgrade waiting to happen.
                fixed := map[string]string{}
                for k, v := range o.Options {
                        if strings.TrimSpace(v) == "" {
                                continue
                        }
                        fixed[strings.ToUpper(strings.TrimSpace(k))] = strings.TrimSpace(v)
                }
                if trimmed, answer, _ := trimToThree(fixed, o.Answer, o.ID); trimmed != nil {
                        o.Options, o.Answer = trimmed, answer
                } else {
                        continue
                }
                out = append(out, o)
        }
        return out
}

// ─── Lesson serve (read-through) ──────────────────────────────────────────

type topicCtx struct {
        ID       string
        Title    string
        Category string
        Seq      int
        CourseID string
        Course   string
        Body     string
        Subject  string
        Keywords []string
        Figures  []string
        Total    int
}

func (s *Service) loadTopicCtx(ctx context.Context, topicID string) (*topicCtx, error) {
        t := &topicCtx{ID: topicID}
        err := s.Pool.QueryRow(ctx, `
                SELECT t.title, t.category, t.seq, t.course_id, c.title, c.body, c.subject,
                       t.keywords, t.figures,
                       (SELECT COUNT(*) FROM learn.topics tc WHERE tc.course_id = t.course_id)
                FROM learn.topics t JOIN learn.courses c ON c.course_id = t.course_id
                WHERE t.topic_id = $1`, topicID).
                Scan(&t.Title, &t.Category, &t.Seq, &t.CourseID, &t.Course, &t.Body, &t.Subject,
                        &t.Keywords, &t.Figures, &t.Total)
        if err != nil {
                return nil, err
        }
        return t, nil
}

// lessonGenBudget bounds one background generation (AI 2 attempts +
// bank parse + persist). Detached from any request.
const lessonGenBudget = 150 * time.Second

// lessonWaitBudget caps how long a wait=1 request blocks IN the handler.
// The api server's WriteTimeout is 30s: a response that takes longer is
// killed mid-flight and the client sees a dead connection (the founder's
// "notes not loading" spin, 2026-10-14). 22s leaves the server room to
// write the 200 before that deadline; anything slower answers 202 and
// the client polls.
const lessonWaitBudget = 22 * time.Second

// Lesson returns the cached lesson or generates one (single-flight per
// topic, concurrency-capped). Generation runs on a DETACHED context -
// a polling client's disconnects and the server's WriteTimeout can
// never abort it - and wait=1 callers block for at most lessonWaitBudget
// before receiving ErrGenerating (the 202 the client polls on).
// A stale-format cached doc (old recipe) regenerates on open, falling
// back to the stale doc when generation fails.
func (s *Service) Lesson(ctx context.Context, topicID string, wait bool) (*LessonDoc, error) {
        t, err := s.loadTopicCtx(ctx, topicID)
        if err != nil {
                return nil, err
        }

        // Cache hit (or a stale-format doc kept as the fallback).
        staleDoc, cacheErr := s.cachedLesson(ctx, t)
        if cacheErr != nil {
                return nil, cacheErr
        }
        if staleDoc != nil && staleDoc.Source == LessonSource {
                return staleDoc, nil
        }

        // Miss (or stale format) → single-flight; first caller spawns the
        // background generator, everyone else rides its done channel.
        fl := s.kickOff(t)
        // Generation failed: the stale doc (quiz already sanitized on
        // the way out) beats a hard error - a lesson the student can
        // still study, never a dead screen.
        resolve := func(doc *LessonDoc, genErr error) (*LessonDoc, error) {
                if doc != nil {
                        return doc, nil
                }
                if genErr != nil && staleDoc != nil {
                        return staleDoc, nil
                }
                return doc, genErr
        }

        if !wait {
                select {
                case <-fl.done:
                        return resolve(fl.doc, fl.err)
                default:
                        return nil, ErrGenerating
                }
        }
        timer := time.NewTimer(lessonWaitBudget)
        defer timer.Stop()
        select {
        case <-fl.done:
                return resolve(fl.doc, fl.err)
        case <-ctx.Done():
                return nil, ctx.Err()
        case <-timer.C:
                return nil, ErrGenerating // client polls; generation continues
        }
}

// kickOff returns the live inflight for the topic, spawning the
// generator on a detached context when none is running. The detached
// context is the load-bearing wall: under the old design the generation
// rode the first requester's request context, so the 30s WriteTimeout
// cancelled it mid-flight and every poll restarted it from scratch -
// a cold topic could literally never finish generating.
func (s *Service) kickOff(t *topicCtx) *inflight {
        s.Engine.mu.Lock()
        if fl, ok := s.Engine.live[t.ID]; ok {
                s.Engine.mu.Unlock()
                return fl
        }
        fl := &inflight{done: make(chan struct{})}
        s.Engine.live[t.ID] = fl
        s.Engine.mu.Unlock()

        go func() {
                defer func() {
                        s.Engine.mu.Lock()
                        delete(s.Engine.live, t.ID)
                        s.Engine.mu.Unlock()
                        close(fl.done)
                }()
                ctx, cancel := context.WithTimeout(context.Background(), lessonGenBudget)
                defer cancel()
                fl.doc, fl.err = s.generateLesson(ctx, t)
                if fl.err == nil {
                        // Prefetch the next two topics in the background
                        // (Supreme look-ahead), deduped by the cache.
                        go s.prefetchNext(t)
                }
        }()
        return fl
}

// ErrGenerating tells the handler to answer 202 (the client polls).
var ErrGenerating = fmt.Errorf("learn: lesson is generating, retry shortly")

func (s *Service) cachedLesson(ctx context.Context, t *topicCtx) (*LessonDoc, error) {
        row := s.Pool.QueryRow(ctx, `
                SELECT title, summary, notes, key_points, quiz, drawings, source
                FROM learn.lessons WHERE topic_id=$1`, t.ID)
        var doc LessonDoc
        var notesRaw, kpRaw, quizRaw, drawRaw []byte
        err := row.Scan(&doc.Title, &doc.Summary, &notesRaw, &kpRaw, &quizRaw, &drawRaw, &doc.Source)
        if err != nil {
                return nil, nil // cache miss (incl. not-found) → generate
        }
        if err := json.Unmarshal(notesRaw, &doc.Notes); err != nil {
                doc.Notes = nil
        }
        if err := json.Unmarshal(kpRaw, &doc.KeyPoints); err != nil {
                doc.KeyPoints = nil
        }
        if err := json.Unmarshal(quizRaw, &doc.Quiz); err != nil {
                doc.Quiz = nil
        }
        // Serve-time sweep (founder 2026-10-15): lessons cached before the
        // three-option doctrine carry 4-5-option questions, letter/text
        // answer mismatches and option-less mcqs. Sanitize before ANY
        // student sees them; when the sweep changed something, persist the
        // healed form once (piggy-backing on this serve, which already
        // touches the row for hit_count) so practice and review sets read
        // clean rows too. No regeneration, no extra AI, no extra wake.
        if healed, changed := sanitizeQuiz(doc.Quiz); changed {
                doc.Quiz = healed
                if fixed, err := json.Marshal(doc.Quiz); err == nil {
                        _, _ = s.Pool.Exec(ctx,
                                `UPDATE learn.lessons SET quiz=$2 WHERE topic_id=$1`, t.ID, string(fixed))
                }
        } else {
                doc.Quiz = healed
        }
        if err := json.Unmarshal(drawRaw, &doc.Drawings); err != nil {
                doc.Drawings = nil
        }
        doc.TopicID, doc.CourseID, doc.Course, doc.Cached = t.ID, t.CourseID, t.Course, true
        doc.Drawings = decorateDrawings(t, doc.Drawings)
        _, _ = s.Pool.Exec(ctx, `UPDATE learn.lessons SET hit_count = hit_count + 1 WHERE topic_id=$1`, t.ID)
        return &doc, nil
}

func (s *Service) generateLesson(ctx context.Context, t *topicCtx) (*LessonDoc, error) {
        if s.Engine.AI == nil {
                return nil, fmt.Errorf("learn: AI disabled - lesson generation unavailable")
        }
        s.Engine.sem <- struct{}{}
        defer func() { <-s.Engine.sem }()

        user := lessonUserPrompt(t.Title, t.Course, t.Body, t.Subject, t.Seq, t.Total)
        var lastErr error
        for attempt := 0; attempt < 2; attempt++ { // founder doctrine: one repair retry
                prompt := user
                if attempt > 0 && lastErr != nil {
                        prompt += fmt.Sprintf("\n\nYour previous attempt failed validation: %v\nFix exactly those problems and return the corrected JSON object.", lastErr)
                }
                out, err := s.Engine.AI.Complete(ctx, lessonSystem, []tutor.Message{{Role: "user", Content: prompt}}, 6000)
                if err != nil {
                        lastErr = err
                        continue
                }
                parsed, err := validateAI([]byte(extractJSON(out)))
                if err != nil {
                        lastErr = err
                        continue
                }

                // Assemble the doc.
                corpus := make([]string, 0, len(parsed.Notes))
                for _, n := range parsed.Notes {
                        corpus = append(corpus, n.Heading, n.Body)
                }
                doc := &LessonDoc{
                        TopicID: t.ID, CourseID: t.CourseID, Course: t.Course,
                        Title: firstNonEmpty(parsed.Title, t.Title),
                        Summary: parsed.Summary,
                        Source: LessonSource,
                }
                for _, n := range parsed.Notes {
                        doc.Notes = append(doc.Notes, LessonNote{Heading: n.Heading, Body: n.Body})
                }
                doc.KeyPoints = parsed.KeyPoints
                doc.Quiz = s.Engine.normalizeQuiz(parsed.Quiz, t.ID, corpus)

                // Real past questions from the bank (secondary desks; founder:
                // the roadmap quizzes carry actual past questions).
                if t.Body != "tertiary" {
                        want := LessonQuizTarget - len(doc.Quiz)
                        if want > 14 {
                                want = 14
                        }
                        if bank := s.Engine.bankQuestions(t.Body, t.Subject, t.Keywords, t.ID, want); len(bank) > 0 {
                                doc.Quiz = append(doc.Quiz, bank...)
                        }
                }
                if len(doc.Quiz) > LessonQuizTarget {
                        doc.Quiz = doc.Quiz[:LessonQuizTarget]
                }
                doc.Drawings = decorateDrawings(t, nil)

                if err := s.persistLesson(ctx, doc); err != nil {
                        return nil, err
                }
                return doc, nil
        }
        if s.Engine.Log != nil {
                s.Engine.Log.Error("learn: lesson generation failed twice", "topic", t.ID, "err", lastErr)
        }
        return nil, fmt.Errorf("learn: lesson generation failed, try again shortly")
}

func firstNonEmpty(vals ...string) string {
        for _, v := range vals {
                if strings.TrimSpace(v) != "" {
                        return v
                }
        }
        return ""
}

func (s *Service) persistLesson(ctx context.Context, doc *LessonDoc) error {
        // NOTE: the marshalled docs go in as STRING, not []byte. pgx sends
        // a []byte param as bytea (simple protocol: a \x hex literal) and
        // Postgres refuses to cast that into the jsonb columns - "invalid
        // input syntax for type json" - so every lesson generated but
        // never cached and every poll restarted generation forever
        // (founder's "notes and questions not loading", 2026-10-14).
        notes, _ := json.Marshal(doc.Notes)
        kp, _ := json.Marshal(doc.KeyPoints)
        quiz, _ := json.Marshal(doc.Quiz)
        draw, _ := json.Marshal(doc.Drawings)
        _, err := s.Pool.Exec(ctx, `
                INSERT INTO learn.lessons (topic_id, title, summary, notes, key_points, quiz, drawings, source)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
                ON CONFLICT (topic_id) DO UPDATE SET title=$2, summary=$3, notes=$4, key_points=$5,
                  quiz=$6, drawings=$7, source=$8, generated_at=now()`,
                doc.TopicID, doc.Title, doc.Summary, string(notes), string(kp), string(quiz), string(draw), doc.Source)
        return err
}

func (s *Service) prefetchNext(t *topicCtx) {
        ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
        defer cancel()
        rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.topics
                WHERE course_id=$1 AND seq > $2
                  AND NOT EXISTS (SELECT 1 FROM learn.lessons l WHERE l.topic_id = learn.topics.topic_id)
                ORDER BY seq LIMIT 2`, t.CourseID, t.Seq)
        if err != nil {
                return
        }
        var ids []string
        for rows.Next() {
                var id string
                if err := rows.Scan(&id); err == nil {
                        ids = append(ids, id)
                }
        }
        rows.Close()
        for _, id := range ids {
                nt, err := s.loadTopicCtx(ctx, id)
                if err != nil {
                        return // stop prefetching on first failure (budget guard)
                }
                fl := s.kickOff(nt) // detached generation keeps running after we return
                select {
                case <-fl.done:
                        if fl.err != nil {
                                return // stop prefetching on first failure (budget guard)
                        }
                case <-ctx.Done():
                        return
                }
        }
}

// decorateDrawings attaches the curated SVG figures: explicit ids from
// the topic row first, then keyword/title triggers so the flagship
// topics (organic chemistry, waves) always carry their real drawings.
func decorateDrawings(t *topicCtx, existing []DrawingRef) []DrawingRef {
        out := existing
        seen := map[string]bool{}
        for _, d := range out {
                seen[d.ID] = true
        }
        for _, id := range t.Figures {
                if d, ok := DrawingLibrary[id]; ok && !seen[id] {
                        out = append(out, d)
                        seen[id] = true
                }
        }
        if len(out) == 0 {
                title := strings.ToLower(t.Title)
                for _, kw := range t.Keywords {
                        title += " " + strings.ToLower(kw)
                }
                for trigger, ids := range drawingTriggers {
                        if strings.Contains(title, trigger) {
                                for _, id := range ids {
                                        if d, ok := DrawingLibrary[id]; ok && !seen[id] {
                                                out = append(out, d)
                                                seen[id] = true
                                        }
                                }
                        }
                }
        }
        if out == nil {
                out = []DrawingRef{}
        }
        return out
}
