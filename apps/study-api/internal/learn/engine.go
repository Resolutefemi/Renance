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
        "renance.dev/study-api/internal/learn/synth"
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
        TopicID   string        `json:"topicId"`
        CourseID  string        `json:"courseId"`
        Course    string        `json:"course"`
        Title     string        `json:"title"`
        Summary   string        `json:"summary"`
        Notes     []LessonNote  `json:"notes"`
        KeyPoints []string      `json:"keyPoints"`
        Quiz      []LessonQuizQ `json:"quiz"`
        Drawings  []DrawingRef  `json:"drawings"`
        Source    string        `json:"source"`
        Cached    bool          `json:"cached"`
        // GenError carries the generation failure reason when a stale doc
        // serves as the fallback - ops forensics without log access (the
        // founder reads the API, not the Render console).
        GenError string `json:"genError,omitempty"`
}

// LessonSource is the lesson FORMAT stamp: the generation recipe it
// follows. A cached row carrying a different stamp was written by an
// older recipe and regenerates at the current depth on its next open
// (founder 2026-10-15: "the notes generated in each part are too small
// and short, not that explainable" - the old recipe allowed 60-140-word
// bodies; the current one demands 150-260 words and worked examples).
// zai-glm-3 (founder directive 2026-10-16, the deep-content pass): at
// least 10 distinct long note parts per topic and 20 practice
// questions - older caches regenerate at the new depth on open.
// If regeneration fails (AI down), the stale doc still serves - its
// quiz is sanitized on the way out either way.
const LessonSource = "zai-glm-3"

// AgentSource stamps the lessons written by the deterministic agent
// engine (internal/learn/synth). The founder's 2026-10-16 directive:
// the AI API does not have the capacity for 10,000+ courses x 15 units
// x 10 topics of deep notes and quizzes, so the agent generated the
// content engine itself. Both stamps count as CURRENT format.
const AgentSource = "agent-v1"

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
                AI:   ai,
                Lib:  lib,
                sem:  make(chan struct{}, 3), // MAX_PARALLEL parity
                live: map[string]*inflight{},
        }
}

// ─── Prompting ────────────────────────────────────────────────────────────

// The deep-content recipe (founder directive 2026-10-16): the notes
// and the quiz generate in TWO concurrent calls. One giant call that
// wrote 12 sections AND 20 questions regularly blew past the provider
// timeout and the whole lesson was lost; two focused calls each fit
// comfortably, retry independently, and a quiz miss no longer wastes
// the notes. The quiz prompt carries the topic's teaching contract so
// every item stays grounded in what a full lesson on the topic teaches.

const lessonNotesSystem = `You are Renance's AI tutor: an expert Nigerian teacher writing full lesson notes for students preparing for their exams.

Rules:
- Write for the topic's exam body. JAMB/WAEC/NECO topics follow the Nigerian senior-secondary syllabus; university topics follow the NUC CCMAS / NBTE / NCCE curricula.
- Output STRICT JSON only. No markdown fences, no commentary.
- Shape: {"title": string, "summary": string, "notes": [{"heading": string, "body": string}], "key_points": [string]}
- notes: the number of sections the brief asks for (the lesson is built in two passes - write exactly how many the brief says). Every section TEACHES, never teases: each body is 150-260 words of plain-text paragraphs (no HTML, no markdown syntax). Build the topic from first principles: define every term in full, walk through worked examples step by step (numbered steps), point out the exam traps students actually fail on, and use Nigerian examples (naira, kana, Lagos/Kano/Akure contexts) where natural. A student who reads ONLY these notes must be able to answer every quiz item on the topic.
- MATHS NOTATION (strict): every formula, equation, exponent or symbol is LaTeX wrapped in dollar signs. Write $x^2$, $H_2O$, $\\frac{dy}{dx}$, $\\lim_{x \\to \\infty} f(x)$, $\\int_0^1 x^2\\,dx$, $\\sum_{i=1}^{n} i$. NEVER write bare caret or underscore notation (x^2, H_2O, 10^5) outside $...$ - the renderer typesets $...$ only and prints everything else raw.
- key_points: 5 to 7 exam-focused takeaways.`

const lessonQuizSystem = `You are Renance's exam writer: an expert Nigerian examiner writing practice questions that test one specific lesson topic.

Rules:
- Write for the topic's exam body. JAMB/WAEC/NECO topics follow the Nigerian senior-secondary syllabus; university topics follow the NUC CCMAS / NBTE / NCCE curricula.
- Output STRICT JSON only. No markdown fences, no commentary.
- Shape: {"quiz": [{"type": "mcq"|"true_false"|"fill_blank", "stem": string, "options": {"A": string, "B": string, "C": string, "D": string}, "answer": "A"|"B"|"C"|"D"|"true"|"false"|string, "explanation": string}]}
- quiz: the number of items the brief asks for (the exam is built in two passes - write exactly how many the brief says). Multiple-choice questions carry exactly 4 options keyed "A", "B", "C", "D" - the standard Nigerian exam shape (use 5 options "A"-"E" only where the past papers themselves carry five). Mix the types: mostly mcq plus true_false and fill_blank (fill_blank has no options; answer is the exact word/phrase). Each stem must be answerable from a comprehensive lesson on THIS topic; anything a proper lesson on this topic would not teach is forbidden. For mcq the "answer" is the LETTER of the correct option; for true_false it is "true" or "false". Distractors must be plausible; never reveal the answer inside the stem. Every item carries a short explanation.
- MATHS NOTATION (strict): every formula or symbol is LaTeX wrapped in dollar signs ($x^2$, $\\frac{dy}{dx}$). Never bare caret/underscore notation outside $...$.`

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

This is the FIRST pass of the lesson: write EXACTLY 6 sections - the foundational half (definitions, first principles, the first worked example). A second pass will add the deeper 6.

Return the JSON object now.`, topic, course, subjectLine, band, seq, total)
}

func lessonQuizUserPrompt(topic, course, body, subject string, seq, total int) string {
        band := "Nigerian university level (NUC CCMAS)"
        if body == "jamb" || body == "waec" || body == "neco" || body == "post-utme" {
                band = fmt.Sprintf("Nigerian senior-secondary %s standard", strings.ToUpper(body))
        }
        subjectLine := ""
        if subject != "" {
                subjectLine = fmt.Sprintf("\nSubject: %s", subject)
        }
        return fmt.Sprintf(`Write the %d practice questions for:
Topic: %s
Course: %s%s
Standard: %s
Position: topic %d of %d in the course roadmap.

This is the FIRST pass of the exam: write EXACTLY %d items - the easier ramp (definitions, direct recall, one-step applications). A second pass will add the harder half.

Return the JSON object now.`, LessonQuizTarget/2, topic, course, subjectLine, band, seq, total, LessonQuizTarget/2)
}

// ─── JSON validation ──────────────────────────────────────────────────────

type aiLesson struct {
        Title   string `json:"title"`
        Summary string `json:"summary"`
        Notes   []struct {
                Heading string `json:"heading"`
                Body    string `json:"body"`
        } `json:"notes"`
        KeyPoints []string  `json:"key_points"`
        Quiz      []aiQuizQ `json:"quiz"`
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

// validateNotesAI gates the notes half of the deep recipe before it is
// ever served (founder directive 2026-10-16: "at least 10 distinct,
// long parts/sections of comprehensive notes"). Thin bodies are a
// validation failure - the repair retry regenerates them at depth.
func validateNotesAI(raw []byte) (*aiLesson, error) {
        var l aiLesson
        if err := json.Unmarshal(raw, &l); err != nil {
                return nil, err
        }
        if len(l.Notes) < 10 || len(l.Notes) > 14 {
                return nil, fmt.Errorf("want 10-14 notes, got %d", len(l.Notes))
        }
        for i, n := range l.Notes {
                if strings.TrimSpace(n.Body) == "" {
                        return nil, fmt.Errorf("note %d has empty body", i)
                }
                if strings.Contains(n.Body, "<") && strings.Contains(n.Body, ">") {
                        return nil, fmt.Errorf("note %d contains HTML", i)
                }
                if words := len(strings.Fields(n.Body)); words < 110 {
                        return nil, fmt.Errorf("note %d is too thin (%d words, want >=110)", i, words)
                }
        }
        return &l, nil
}

// validateQuizAI gates the quiz half: the founder's "Each individual
// topic must contain 20 practice questions". 18 survives validation
// (sanitize may drop a dead item); below that the repair retry regenerates.
func validateQuizAI(raw []byte) ([]aiQuizQ, error) {
        var l struct {
                Quiz []aiQuizQ `json:"quiz"`
        }
        if err := json.Unmarshal(raw, &l); err != nil {
                return nil, err
        }
        if len(l.Quiz) < 18 {
                return nil, fmt.Errorf("want >=18 quiz items, got %d", len(l.Quiz))
        }
        mcqs := 0
        for i, q := range l.Quiz {
                if strings.TrimSpace(q.Stem) == "" || strings.TrimSpace(q.Answer) == "" {
                        return nil, fmt.Errorf("quiz %d missing stem/answer", i)
                }
                t := strings.ToLower(strings.TrimSpace(q.Type))
                if t == "mcq" || t == "multiple_choice" || t == "multiplechoice" {
                        opts := map[string]bool{}
                        for k, v := range q.Options {
                                if strings.TrimSpace(v) != "" {
                                        opts[strings.ToUpper(strings.TrimSpace(k))] = true
                                }
                        }
                        if len(opts) < 3 {
                                return nil, fmt.Errorf("quiz %d: mcq has %d usable options, want >=3", i, len(opts))
                        }
                        ans := strings.ToUpper(strings.TrimSpace(q.Answer))
                        if len(ans) == 1 && opts[ans] {
                                mcqs++
                                continue
                        }
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
        }
        if mcqs < 10 {
                return nil, fmt.Errorf("want >=10 mcq items, got %d", mcqs)
        }
        return l.Quiz, nil
}

// normalizeQuiz converts every AI item into a shape the client can
// RENDER. Doctrine (founder bug report 2026-10-14: quiz questions with
// a blank answer area): an MCQ without options is a dead end - the stem
// shows and nothing below it is tappable. So:
//   - fill_blank            → word_bank (distractors from the lesson corpus)
//   - true_false (+aliases) → true_false (answer folded to true/false)
//   - mcq                   → mcq, letters uppercased and the answer
//     resolved to one of its own option letters
//     (founder directive 2026-10-15, later the
//     same day: "the options will not be three" -
//     the option COUNT is never rewritten, only
//     the answer alignment is enforced)
//   - anything else         → true_false when the answer reads boolean,
//     else word_bank - never an option-less mcq
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
                        } else if letter, ok := answerLetter(fixed, o.Answer); ok {
                                // The answer resolves to one of the question's own
                                // options: keep EVERY option as generated (4 or 5 wide
                                // is the normal exam shape) and point the graded value
                                // at its letter, so the client's letter comparison can
                                // never misgrade a correct student.
                                o.Options = fixed
                                o.Answer = letter
                        } else {
                                // answer matched no option: degrade to a type-in
                                // keyed to the answer text, never a dead letter
                                o.Type = "word_bank"
                                o.Options = buildWordBank(o.Answer, corpus)
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

// ─── The answer-alignment doctrine (founder 2026-10-15) ───────────────────
//
// "The right answer will be picked and it will mark the user wrong" has
// one root: a stored answer that does not line up with the options the
// student actually sees. answerLetter resolves the stored answer (a
// letter, the option TEXT, or a 1..N index - a common bank quirk) to
// one of the question's own option letters. The REVERSED half of the
// same day's directive ("the options will not be three"): the option
// COUNT is never rewritten - 4- and 5-option questions ship exactly as
// the paper (or the generator) carried them.

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

// sanitizeQuiz is the SERVE-TIME sweep (founder bug reports 2026-10-15):
// lessons cached before the answer-alignment doctrine carry text
// answers, true_false letters and option-less mcqs. Every read path
// (lesson serve, practice set, review set) runs this so the whole back
// catalogue heals without a single regeneration. It NEVER rewrites an
// option count (founder reversal 2026-10-15: "the options will not be
// three") - 4- and 5-option questions ship as they are; only the
// answer's alignment with the options is healed. It returns the cleaned
// slice and whether anything changed (the lesson cache persists the
// healed form once, piggy-backing on a serve that already touches the
// database).
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
                        letter, ok := answerLetter(fixed, q.Answer)
                        if !ok {
                                changed = true
                                continue // answer points nowhere: dead question, drop it
                        }
                        if letter != q.Answer {
                                changed = true
                                q.Answer = letter
                        }
                        q.Options = fixed
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
                // Answer alignment: the stored answer must point at one of
                // the options the student sees (letter, text or 1..N index)
                // - a misgrade waiting to happen is dropped instead. The
                // bank's own option count (4 or 5 wide, exactly as the past
                // paper carried it) is NEVER rewritten (founder reversal
                // 2026-10-15: "the options will not be three").
                fixed := map[string]string{}
                for k, v := range o.Options {
                        if strings.TrimSpace(v) == "" {
                                continue
                        }
                        fixed[strings.ToUpper(strings.TrimSpace(k))] = strings.TrimSpace(v)
                }
                if letter, ok := answerLetter(fixed, o.Answer); ok {
                        o.Options, o.Answer = fixed, letter
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
        Unit     int
        CourseID string
        Course   string
        Body     string
        Subject  string
        Dept     string
        Faculty  string
        Keywords []string
        Figures  []string
        Total    int
}

func (s *Service) loadTopicCtx(ctx context.Context, topicID string) (*topicCtx, error) {
        t := &topicCtx{ID: topicID}
        err := s.Pool.QueryRow(ctx, `
                SELECT t.title, t.category, t.seq, t.course_id, c.title, c.body, c.subject,
                       t.keywords, t.figures, t.unit,
                       COALESCE(d.name,''), COALESCE(d.faculty,''),
                       (SELECT COUNT(*) FROM learn.topics tc WHERE tc.course_id = t.course_id)
                FROM learn.topics t JOIN learn.courses c ON c.course_id = t.course_id
                JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE t.topic_id = $1`, topicID).
                Scan(&t.Title, &t.Category, &t.Seq, &t.CourseID, &t.Course, &t.Body, &t.Subject,
                        &t.Keywords, &t.Figures, &t.Unit, &t.Dept, &t.Faculty, &t.Total)
        if err != nil {
                return nil, err
        }
        return t, nil
}

// lessonGenBudget bounds one background generation (notes + top-up
// rounds + quiz + bank parse + persist). Detached from any request.
const lessonGenBudget = 300 * time.Second

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
        if staleDoc != nil && (staleDoc.Source == LessonSource || staleDoc.Source == AgentSource) {
                // Cache HIT - and the look-ahead still fires: the next two
                // topics of this course pre-generate silently in the
                // background (prefetchNext dedupes via the cache + inflight
                // map), so the student never waits on generation again.
                go s.prefetchNext(t)
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
                        msg := genErr.Error()
                        if len(msg) > 240 {
                                msg = msg[:240]
                        }
                        staleDoc.GenError = msg
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
        // answer-alignment doctrine carry letter/text answer mismatches and
        // option-less mcqs. Sanitize before ANY student sees them; when the
        // sweep changed something, persist the healed form once (piggy-backing
        // on this serve, which already touches the row for hit_count) so
        // practice and review sets read clean rows too. The option count is
        // never rewritten. No regeneration, no extra AI, no extra wake.
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
        // Tertiary courses take the AGENT path (founder directive
        // 2026-10-16: the AI API does not have the capacity for 10,000+
        // courses of deep notes and quizzes, so the agent built the
        // deterministic content engine instead). Synthesis is instant,
        // costs nothing, and every topic in the tree gets the full deep
        // lesson: 10 long reading sections and 20 quiz items.
        if t.Body == "tertiary" {
                return s.generateLessonAgent(ctx, t)
        }
        // Secondary desks (jamb / waec / neco / post utme) keep the AI +
        // past question bank path: their volume is tiny and the banks
        // carry the students' ACTUAL past questions.
        if s.Engine.AI == nil {
                return nil, fmt.Errorf("learn: AI disabled - lesson generation unavailable")
        }
        s.Engine.sem <- struct{}{}
        defer func() { <-s.Engine.sem }()

        // Two concurrent calls (deep-content recipe, founder 2026-10-16):
        // the notes half and the 20-question quiz half. Each retries once
        // with the repair suffix; whichever half fails, the other's work
        // is kept - a quiz miss falls back to bank questions, a notes
        // miss fails the whole generation (a quiz with no notes teaches
        // nothing).
        notesErr := make(chan error, 1)
        quizErr := make(chan error, 1)
        var parsed *aiLesson
        var quizRaw []aiQuizQ
        go func() {
                var err error
                parsed, err = s.genNotes(ctx, t)
                notesErr <- err
        }()
        go func() {
                var err error
                quizRaw, err = s.genQuiz(ctx, t)
                quizErr <- err
        }()
        nErr, qErr := <-notesErr, <-quizErr
        if nErr != nil {
                if s.Engine.Log != nil {
                        s.Engine.Log.Error("learn: lesson generation failed twice", "topic", t.ID, "err", nErr)
                }
                return nil, fmt.Errorf("learn: lesson generation failed: %w", nErr)
        }
        // A quiz miss keeps the lesson alive: quizRaw stays empty and the
        // bank top-up below fills what it can (secondary desks), while
        // tertiary topics retry generation on their next open.
        if qErr != nil && s.Engine.Log != nil {
                s.Engine.Log.Info("learn: quiz half failed - lesson ships without AI quiz", "topic", t.ID, "err", qErr)
        }

        // Assemble the doc.
        corpus := make([]string, 0, len(parsed.Notes))
        for _, n := range parsed.Notes {
                corpus = append(corpus, n.Heading, n.Body)
        }
        doc := &LessonDoc{
                TopicID: t.ID, CourseID: t.CourseID, Course: t.Course,
                Title:   firstNonEmpty(parsed.Title, t.Title),
                Summary: parsed.Summary,
                Source:  LessonSource,
        }
        for _, n := range parsed.Notes {
                doc.Notes = append(doc.Notes, LessonNote{Heading: n.Heading, Body: n.Body})
        }
        doc.KeyPoints = parsed.KeyPoints
        doc.Quiz = s.Engine.normalizeQuiz(quizRaw, t.ID, corpus)

        // Real past questions from the bank (secondary desks; founder:
        // the roadmap quizzes carry actual past questions). The bank
        // tops the AI set up to the 20-question target.
        if t.Body != "tertiary" {
                want := LessonQuizTarget - len(doc.Quiz)
                if want > 14 {
                        want = 14
                }
                if want > 0 {
                        if bank := s.Engine.bankQuestions(t.Body, t.Subject, t.Keywords, t.ID, want); len(bank) > 0 {
                                doc.Quiz = append(doc.Quiz, bank...)
                        }
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

// generateLessonAgent builds the full deep lesson for a tertiary topic
// from the deterministic synthesis engine and persists it under the
// agent stamp. Pure CPU: no AI call, no budget, no 429s.
func (s *Service) generateLessonAgent(ctx context.Context, t *topicCtx) (*LessonDoc, error) {
        unit := t.Unit
        if unit < 1 {
                unit = 1
        }
        out := synth.BuildLesson(t.ID, t.Course, t.Dept, t.Faculty, t.Title, unit)
        doc := &LessonDoc{
                TopicID: t.ID, CourseID: t.CourseID, Course: t.Course,
                Title:   firstNonEmpty(out.Title, t.Title),
                Summary: out.Summary,
                Source:  AgentSource,
        }
        for _, n := range out.Notes {
                doc.Notes = append(doc.Notes, LessonNote{Heading: n.Heading, Body: n.Body})
        }
        doc.KeyPoints = out.KeyPoints
        for _, q := range out.Quiz {
                doc.Quiz = append(doc.Quiz, LessonQuizQ{
                        ID: q.ID, Type: q.Type, Stem: q.Stem,
                        Options: q.Options, Answer: q.Answer, Explanation: q.Explanation,
                })
        }
        // serve-time safety net: run the same sanitizer the cached path
        // uses, so any engine drift can never ship a malformed item
        if healed, changed := sanitizeQuiz(doc.Quiz); changed {
                doc.Quiz = healed
        }
        doc.Drawings = decorateDrawings(t, nil)

        // Cache best effort: when the database is at its storage cap the
        // INSERT fails, but the doc is still valid content - a student
        // must NEVER see a failed lesson just because the cache is full
        // (the founder reads the app, not the disk). Log and serve.
        if err := s.persistLesson(ctx, doc); err != nil {
                if s.Engine.Log != nil {
                        s.Engine.Log.Error("learn: agent lesson persist failed - serving uncached", "topic", t.ID, "err", err)
                }
        }
        return doc, nil
}

// genNotes produces the deep notes half (10-12 long sections). Models
// under-produce (or truncate) very long single outputs, so a short or
// clipped first answer is not a failure: whatever valid sections came
// back are salvaged and the missing ones are requested as CONTINUATION
// (top-up) rounds - the founder's "at least 10 distinct, long parts"
// is guaranteed by construction, never by luck.
func (s *Service) genNotes(ctx context.Context, t *topicCtx) (*aiLesson, error) {
        user := lessonUserPrompt(t.Title, t.Course, t.Body, t.Subject, t.Seq, t.Total)
        var lastErr error
        for attempt := 0; attempt < 2; attempt++ { // founder doctrine: one repair retry
                prompt := user
                if attempt > 0 && lastErr != nil {
                        prompt += fmt.Sprintf("\n\nYour previous attempt failed validation: %v\nFix exactly those problems and return the corrected JSON object.", lastErr)
                }
                // 6000 cap (the provider's proven ceiling - the old
                // recipe ran it for months) with a TWO-PASS ask: each
                // pass requests 6 sections, so the ACTUAL output stays
                // ~1,500-2,500 tokens and never truncates.
                out, err := s.completeRetry429(ctx, lessonNotesSystem, prompt, 6000)
                if err != nil {
                        lastErr = err
                        continue
                }
                partial, perr := notesFromOutput(out)
                if perr == nil && len(partial.Notes) >= 10 {
                        if parsed, verr := validateNotesAI([]byte(extractJSON(out))); verr == nil {
                                return parsed, nil
                        }
                }
                if perr != nil {
                        lastErr = perr
                        continue
                }
                // Under-production or truncation: keep what arrived, ask for more.
                merged, terr := s.topUpNotes(ctx, t, partial)
                if terr == nil {
                        return merged, nil
                }
                lastErr = fmt.Errorf("top-up failed: %v (first pass: %v)", terr, perr)
        }
        return nil, lastErr
}

// notesFromOutput parses a notes half, salvaging a truncated JSON
// output (the provider clamps long generations mid-object) by closing
// the open brackets around the last complete element.
func notesFromOutput(out string) (*aiLesson, error) {
        for _, raw := range []string{extractJSON(out), strings.TrimSpace(out)} {
                if parsed, err := parseNotesLenient([]byte(raw)); err == nil {
                        return parsed, nil
                }
                if salvaged := salvageJSON(raw); salvaged != raw {
                        if parsed, err := parseNotesLenient([]byte(salvaged)); err == nil {
                                return parsed, nil
                        }
                }
        }
        return nil, fmt.Errorf("notes output unusable")
}

// salvageJSON closes the open brackets of a truncated strict-JSON
// document around its last complete element.
func salvageJSON(raw string) string {
        lastClose := strings.LastIndex(raw, "}")
        if lastClose < 0 {
                return raw
        }
        trimmed := raw[:lastClose+1]
        stack := []rune{}
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
        // A truncation mid-string leaves the quote open (and possibly a
        // dangling escape - LaTeX in note bodies makes this common): drop
        // the escape, close the quote, THEN close the brackets.
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

// balancedChunks returns every balanced {...} group in raw, tracking
// strings so LaTeX braces inside note bodies never confuse the scan.
// Corrupted continuation outputs (a snapped quote mid-object) still
// carry complete elements BEFORE the corruption point - this recovers
// them one object at a time.
func balancedChunks(raw string) []string {
        var out []string
        depth, start := 0, -1
        inStr, esc := false, false
        for i, r := range raw {
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
                        if depth == 0 {
                                start = i
                        }
                        depth++
                case '}':
                        depth--
                        if depth == 0 && start >= 0 {
                                out = append(out, raw[start:i+1])
                                start = -1
                        }
                }
        }
        return out
}

// salvageNoteElements recovers individual note objects from a corrupted
// output; every survivor has a real heading and an 80+ word body.
func salvageNoteElements(raw string) []struct {
        Heading string `json:"heading"`
        Body    string `json:"body"`
} {
        var out []struct {
                Heading string `json:"heading"`
                Body    string `json:"body"`
        }
        for _, chunk := range balancedChunks(raw) {
                var el struct {
                        Heading string `json:"heading"`
                        Body    string `json:"body"`
                }
                if err := json.Unmarshal([]byte(chunk), &el); err != nil {
                        continue
                }
                if strings.TrimSpace(el.Body) == "" || len(strings.Fields(el.Body)) < 80 {
                        continue
                }
                out = append(out, el)
        }
        return out
}

// salvageQuizElements recovers individual question objects from a
// corrupted output; every survivor has a stem and an answer.
func salvageQuizElements(raw string) []aiQuizQ {
        var out []aiQuizQ
        for _, chunk := range balancedChunks(raw) {
                var el aiQuizQ
                if err := json.Unmarshal([]byte(chunk), &el); err != nil {
                        continue
                }
                if strings.TrimSpace(el.Stem) == "" || strings.TrimSpace(el.Answer) == "" {
                        continue
                }
                out = append(out, el)
        }
        return out
}

// completeRetry429 rides out the free tier's rate-limit window: a 429
// (Z.ai code 1302) backs off 20s/35s and retries - the generation
// budget is 300s and the student polls, so waiting out the limiter
// beats failing the lesson. Any other error returns immediately.
func (s *Service) completeRetry429(ctx context.Context, system, prompt string, maxTokens int) (string, error) {
        var lastErr error
        for i := 0; i < 3; i++ {
                out, err := s.Engine.AI.Complete(ctx, system, []tutor.Message{{Role: "user", Content: prompt}}, maxTokens)
                if err == nil {
                        return out, nil
                }
                lastErr = err
                if !strings.Contains(err.Error(), "429") {
                        return "", err
                }
                if s.Engine.Log != nil {
                        s.Engine.Log.Info("learn: provider rate-limited - backing off", "attempt", i+1)
                }
                select {
                case <-ctx.Done():
                        return "", ctx.Err()
                case <-time.After(time.Duration(20*(i+1)) * time.Second):
                }
        }
        return "", lastErr
}

// parseNotesLenient accepts a chunk of 1-16 notes with a softer word
// floor (80) - continuation rounds are validated strictly as a whole.
func parseNotesLenient(raw []byte) (*aiLesson, error) {
        var l aiLesson
        if err := json.Unmarshal(raw, &l); err != nil {
                return nil, err
        }
        if len(l.Notes) < 1 || len(l.Notes) > 16 {
                return nil, fmt.Errorf("want 1-16 notes, got %d", len(l.Notes))
        }
        for i, n := range l.Notes {
                if strings.TrimSpace(n.Body) == "" {
                        return nil, fmt.Errorf("note %d has empty body", i)
                }
                if strings.Contains(n.Body, "<") && strings.Contains(n.Body, ">") {
                        return nil, fmt.Errorf("note %d contains HTML", i)
                }
                if words := len(strings.Fields(n.Body)); words < 80 {
                        return nil, fmt.Errorf("note %d is too thin (%d words, want >=80)", i, words)
                }
        }
        return &l, nil
}

// topUpNotes requests the missing sections as continuation rounds
// (two rounds max) until the merged lesson carries 10+ long parts.
func (s *Service) topUpNotes(ctx context.Context, t *topicCtx, partial *aiLesson) (*aiLesson, error) {
        notes := partial.Notes
        for round := 0; round < 3 && len(notes) < 10; round++ {
                need := 12 - len(notes)
                if need > 6 {
                        need = 6 // small continuations never brush the ceiling
                }
                headings := make([]string, len(notes))
                for i, n := range notes {
                        headings[i] = n.Heading
                }
                prompt := fmt.Sprintf(`Continue the lesson you are writing.
Topic: %s
Course: %s
Sections already written (do NOT repeat them): %s

Write the NEXT %d sections of this same lesson, going deeper than the ones before.
Output STRICT JSON only. No markdown fences, no commentary.
Shape: {"notes": [{"heading": string, "body": string}]}
- EXACTLY %d new sections; each body 150-260 words of plain-text paragraphs (no HTML, no markdown syntax).
- MATHS NOTATION (strict): every formula or symbol is LaTeX wrapped in dollar signs ($x^2$, $\\frac{dy}{dx}$). Never bare caret/underscore notation outside $...$.`,
                        t.Title, t.Course, strings.Join(headings, " | "), need, need)
                out, err := s.completeRetry429(ctx, lessonNotesSystem, prompt, 6000)
                if err != nil {
                        return nil, err
                }
                extra, verr := parseNotesLenient([]byte(extractJSON(out)))
                if verr != nil {
                        // Element salvage: a snapped quote mid-object kills the
                        // whole-document parse, but the complete objects before
                        // the corruption are still good notes.
                        els := salvageNoteElements(out)
                        if len(els) == 0 {
                                return nil, verr
                        }
                        extra = &aiLesson{Notes: els}
                }
                notes = append(notes, extra.Notes...)
        }
        partial.Notes = notes
        // The merged lesson must clear the FULL deep bar before it ships.
        merged, _ := json.Marshal(partial)
        final, ferr := validateNotesAI(merged)
        if ferr != nil {
                return nil, ferr
        }
        return final, nil
}

// genQuiz produces the 20-question quiz half. Same doctrine as the
// notes: a short first answer is topped up with continuation rounds
// instead of failing the lesson - the founder's "20 practice questions
// per topic" is assembled to full count.
func (s *Service) genQuiz(ctx context.Context, t *topicCtx) ([]aiQuizQ, error) {
        user := lessonQuizUserPrompt(t.Title, t.Course, t.Body, t.Subject, t.Seq, t.Total)
        var lastErr error
        for attempt := 0; attempt < 2; attempt++ {
                prompt := user
                if attempt > 0 && lastErr != nil {
                        prompt += fmt.Sprintf("\n\nYour previous attempt failed validation: %v\nFix exactly those problems and return the corrected JSON object.", lastErr)
                }
                out, err := s.completeRetry429(ctx, lessonQuizSystem, prompt, 6000)
                if err != nil {
                        lastErr = err
                        continue
                }
                quiz, qerr := quizFromOutput(out)
                if qerr != nil {
                        lastErr = qerr
                        continue
                }
                if len(quiz) >= 18 {
                        if validated, verr := validateQuizAI([]byte(extractJSON(out))); verr == nil {
                                return validated, nil
                        }
                        // A 18+ set that fails strict validation still gets
                        // the top-up chance below (it may just be a thin mcq mix).
                }
                merged, terr := s.topUpQuiz(ctx, t, quiz)
                if terr == nil {
                        return merged, nil
                }
                lastErr = fmt.Errorf("quiz top-up failed: %v", terr)
        }
        if s.Engine.Log != nil {
                s.Engine.Log.Info("learn: quiz generation failed - falling back to bank questions", "topic", t.ID, "err", lastErr)
        }
        return nil, lastErr
}

// quizFromOutput parses a quiz half, salvaging truncated JSON the same
// way the notes half does.
func quizFromOutput(out string) ([]aiQuizQ, error) {
        var partial struct {
                Quiz []aiQuizQ `json:"quiz"`
        }
        for _, raw := range []string{extractJSON(out), strings.TrimSpace(out)} {
                if err := json.Unmarshal([]byte(raw), &partial); err == nil && len(partial.Quiz) > 0 {
                        return partial.Quiz, nil
                }
                if salvaged := salvageJSON(raw); salvaged != raw {
                        if err := json.Unmarshal([]byte(salvaged), &partial); err == nil && len(partial.Quiz) > 0 {
                                return partial.Quiz, nil
                        }
                }
        }
        return nil, fmt.Errorf("quiz output unusable")
}

// topUpQuiz requests the missing questions in continuation rounds
// (two max) until 18+ items exist.
func (s *Service) topUpQuiz(ctx context.Context, t *topicCtx, quiz []aiQuizQ) ([]aiQuizQ, error) {
        if len(quiz) == 0 || len(quiz) > 24 {
                return nil, fmt.Errorf("quiz chunk unusable (%d items)", len(quiz))
        }
        for round := 0; round < 3 && len(quiz) < 18; round++ {
                need := 20 - len(quiz)
                if need > 10 {
                        need = 10 // small continuations never brush the ceiling
                }
                stems := make([]string, 0, len(quiz))
                for i, q := range quiz {
                        if i >= 12 {
                                break
                        }
                        s := q.Stem
                        if len(s) > 70 {
                                s = s[:70]
                        }
                        stems = append(stems, s)
                }
                prompt := fmt.Sprintf(`Continue the exam you are writing.
Topic: %s
Course: %s
Questions already written (do NOT repeat them): %s

Write the NEXT %d questions, ramping harder than the ones before.
Output STRICT JSON only. No markdown fences, no commentary.
Shape: {"quiz": [{"type": "mcq"|"true_false"|"fill_blank", "stem": string, "options": {"A": string, "B": string, "C": string, "D": string}, "answer": "A"|"B"|"C"|"D"|"true"|"false"|string, "explanation": string}]}
- EXACTLY %d new items; mcq carries 4 options keyed A-D; every item carries a short explanation.
- MATHS NOTATION (strict): LaTeX wrapped in dollar signs only.`,
                        t.Title, t.Course, strings.Join(stems, " | "), need, need)
                out, err := s.completeRetry429(ctx, lessonQuizSystem, prompt, 6000)
                if err != nil {
                        return nil, err
                }
                extra, eerr := quizFromOutput(out)
                if eerr != nil {
                        // Element salvage: keep every complete question
                        // before the corruption point.
                        els := salvageQuizElements(out)
                        if len(els) == 0 {
                                return nil, eerr
                        }
                        extra = els
                }
                if len(extra) == 0 {
                        return nil, fmt.Errorf("quiz continuation returned nothing")
                }
                quiz = append(quiz, extra...)
        }
        // The merged set must clear the full 18+ bar (with the same mcq
        // answer-alignment checks) before it ships.
        merged, _ := json.Marshal(map[string]any{"quiz": quiz})
        return validateQuizAI(merged)
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
