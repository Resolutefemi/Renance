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

const lessonSystem = `You are Renance's AI tutor: an expert Nigerian teacher writing lesson notes for students preparing for their exams.

Rules:
- Write for the topic's exam body. JAMB/WAEC/NECO topics follow the Nigerian senior-secondary syllabus; university topics follow the NUC CCMAS / NBTE / NCCE curricula.
- Output STRICT JSON only. No markdown fences, no commentary.
- Shape: {"title": string, "summary": string, "notes": [{"heading": string, "body": string}], "key_points": [string], "quiz": [{"type": "mcq"|"true_false"|"fill_blank", "stem": string, "options": {"A": string, "B": string, "C": string, "D": string}, "answer": "A"|"B"|"C"|"D"|"true"|"false"|string, "explanation": string}]}
- notes: 3 to 5 bite-sized sections. Each body: 60-140 words, plain text paragraphs (no HTML, no markdown syntax). Teach with Nigerian examples (naira, kana, Lagos/Kano/Akure contexts) where natural.
- In bodies you may write simple chemistry/maths notation as plain text (CH3COOH, H2O, v = fλ) and use $...$ for LaTeX the renderer typesets.
- key_points: 3 to 6 exam-focused takeaways.
- quiz: 6 to 8 items. At least 2 mcq, at least 1 true_false, at least 1 fill_blank (fill_blank has no options; answer is the exact word/phrase). Ramping difficulty. Every item carries a short explanation.
- Distractors must be plausible; never reveal the answer inside the stem.`

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

func validateAI(raw []byte) (*aiLesson, error) {
        var l aiLesson
        if err := json.Unmarshal(raw, &l); err != nil {
                return nil, err
        }
        if len(l.Notes) < 2 || len(l.Notes) > 6 {
                return nil, fmt.Errorf("want 2-6 notes, got %d", len(l.Notes))
        }
        if len(l.Quiz) < 3 {
                return nil, fmt.Errorf("want >=3 quiz items, got %d", len(l.Quiz))
        }
        for i, n := range l.Notes {
                if strings.TrimSpace(n.Body) == "" {
                        return nil, fmt.Errorf("note %d has empty body", i)
                }
                if strings.Contains(n.Body, "<") && strings.Contains(n.Body, ">") {
                        return nil, fmt.Errorf("note %d contains HTML", i)
                }
        }
        for i, q := range l.Quiz {
                if strings.TrimSpace(q.Stem) == "" || strings.TrimSpace(q.Answer) == "" {
                        return nil, fmt.Errorf("quiz %d missing stem/answer", i)
                }
                if q.Type == "mcq" && len(q.Options) < 2 {
                        return nil, fmt.Errorf("mcq %d has <2 options", i)
                }
        }
        return &l, nil
}

// normalizeQuiz converts fill_blank → word_bank (distractors from the
// lesson corpus, Supreme parity), normalizes true_false answers and
// stamps ids.
func (e *Engine) normalizeQuiz(in []aiQuizQ, topicID string, corpus []string) []LessonQuizQ {
        out := make([]LessonQuizQ, 0, len(in))
        for i, q := range in {
                o := LessonQuizQ{
                        ID:          fmt.Sprintf("%s-ai-%d", topicID, i+1),
                        Type:        q.Type,
                        Stem:        strings.TrimSpace(q.Stem),
                        Answer:      strings.TrimSpace(q.Answer),
                        Explanation: strings.TrimSpace(q.Explanation),
                }
                switch strings.ToLower(o.Type) {
                case "mcq":
                        o.Type = "mcq"
                        if o.Options == nil {
                                o.Options = map[string]string{}
                        }
                        // Uppercase option letters.
                        fixed := map[string]string{}
                        for k, v := range o.Options {
                                fixed[strings.ToUpper(strings.TrimSpace(k))] = v
                        }
                        o.Options = fixed
                case "true_false", "truefalse", "true/false":
                        o.Type = "true_false"
                        ans := strings.ToLower(o.Answer)
                        if strings.HasPrefix(ans, "t") {
                                o.Answer = "true"
                        } else {
                                o.Answer = "false"
                        }
                case "fill_blank":
                        // → word_bank with distractors harvested from the notes.
                        o.Type = "word_bank"
                        o.Options = buildWordBank(o.Answer, corpus)
                default:
                        o.Type = "mcq"
                }
                out = append(out, o)
        }
        return out
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
// the course quizzes carry the students' ACTUAL past questions.
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
        lk := make([]string, 0, len(keywords))
        for _, k := range keywords {
                if kk := stripRe.ReplaceAllString(strings.ToLower(k), ""); len(kk) >= 4 {
                        lk = append(lk, kk)
                }
        }
        if len(lk) == 0 {
                return nil
        }
        var hits []cbtdata.Question
        for _, q := range b.Questions {
                if q.Type != "mcq" || q.Answer == "" || len(q.Options) < 2 {
                        continue
                }
                stem := stripRe.ReplaceAllString(strings.ToLower(q.Stem+" "+q.Topic), "")
                for _, k := range lk {
                        if strings.Contains(stem, k) {
                                hits = append(hits, q)
                                break
                        }
                }
        }
        // Deterministic shuffle keyed by topic, then cap.
        seed := uint32(len(hits)) ^ hashStr(topicID)
        rng := mulberry32(seed)
        for i := len(hits) - 1; i > 0; i-- {
                j := int(rng() % uint32(i+1))
                hits[i], hits[j] = hits[j], hits[i]
        }
        if len(hits) > cap {
                hits = hits[:cap]
        }
        sort.SliceStable(hits, func(i, j int) bool { return hits[i].Year > hits[j].Year })
        out := make([]LessonQuizQ, 0, len(hits))
        for i, q := range hits {
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
                _ = i
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
func (s *Service) Lesson(ctx context.Context, topicID string, wait bool) (*LessonDoc, error) {
        t, err := s.loadTopicCtx(ctx, topicID)
        if err != nil {
                return nil, err
        }

        // Cache hit.
        if doc, err := s.cachedLesson(ctx, t); err == nil && doc != nil {
                return doc, nil
        } else if err != nil {
                return nil, err
        }

        // Miss → single-flight; first caller spawns the background
        // generator, everyone else rides its done channel.
        fl := s.kickOff(t)

        if !wait {
                select {
                case <-fl.done:
                        return fl.doc, fl.err
                default:
                        return nil, ErrGenerating
                }
        }
        timer := time.NewTimer(lessonWaitBudget)
        defer timer.Stop()
        select {
        case <-fl.done:
                return fl.doc, fl.err
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
                out, err := s.Engine.AI.Complete(ctx, lessonSystem, []tutor.Message{{Role: "user", Content: prompt}}, 3500)
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
                        Source: "zai-glm",
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
