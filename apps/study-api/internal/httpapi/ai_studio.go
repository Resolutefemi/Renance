// Renance AI Studio generation (founder directive, 2026-09-30): four
// document generators behind one pattern, all grounded on the
// past-question bridge so everything reads like the real exams, and all
// persisted as artifacts the student can re-open, export to PDF or
// share:
//
//      POST /ai/quiz        {title?, topics[], difficulty, count, body?}
//                           → quiz artifact + share link
//      POST /ai/notes       {title?, topic, subject?, classLevel?, template?}
//                           → study note artifact
//      POST /ai/notes/from-text {title, content}
//                           → note artifact saved straight from a chat reply
//      POST /ai/lesson-note {subject, classLevel, topic, term?, duration?, weeks?}
//                           → Nigerian-format lesson note for schools
//      POST /ai/notebook    {title?, subject, classLevel?, topics[]}
//                           → NotebookLM-style notebook with the house
//                             arrangement (overview → topic notes →
//                             glossary → exam focus → study plan)
//      GET    /ai/artifacts?type=  list  (quiz | note | notebook | lesson_note | "")
//      GET    /ai/artifacts/{id}   one
//      DELETE /ai/artifacts/{id}   remove
//      POST   /ai/artifacts/{id}/share  (re)issue a quiz's public slug
//      GET    /quiz/shared/{slug}  PUBLIC: play a shared quiz
//
// The studio UI replays the returned phases ("Thinking", "Researching
// past questions", "Composing") and shows the bridge count, the way the
// big AI products surface their reasoning.
package httpapi

import (
        "context"
        "crypto/rand"
        "encoding/json"
        "fmt"
        "net/http"
        "regexp"
        "strings"
        "time"
        "unicode"

        "renance.dev/study-api/internal/store"
        "renance.dev/study-api/internal/tutor"
)

const (
        studioMaxTopics  = 6
        studioMaxTitle   = 90
        studioMaxTopicCh = 90
        // Token budgets per generator. Generation is ASYNC (the background
        // job owns a 90s budget), so the budgets are sized for COMPLETE
        // documents - a truncated JSON is a failed document - not for a
        // latency wall.
        studioQuizTokens     = 3000
        studioNoteTokens     = 2600
        studioLessonTokens   = 3000
        studioNotebookTokens = 4000
        // studioQuizChunk is the per-call question budget for large quizzes:
        // 10 questions per provider call keeps every reply well inside the
        // token and latency walls; a 40-question quiz is four calls.
        studioQuizChunk = 10
)

// studioPhases is the thinking trace the clients replay while waiting.
func studioPhases(bridged int) []string {
        phases := []string{"Thinking", "Analysing the topic"}
        if bridged > 0 {
                phases = append(phases, "Researching past questions")
        }
        return append(phases, "Composing")
}

// ---------------------------------------------------------------------------
// The async generation engine
// ---------------------------------------------------------------------------

// studioPendingData is the placeholder payload a generator's POST
// returns immediately: the artifact row exists, the document is being
// written in the background. Clients poll GET /ai/artifacts/{id} until
// pending clears (or error lands).
type studioPendingData struct {
        Pending bool   `json:"pending"`
        Title   string `json:"title"`
}

// studioGenError is the failure payload a background job writes onto
// the artifact row; the polling client surfaces it as a retry card.
type studioGenError struct {
        Pending bool   `json:"pending"`
        Error   string `json:"error"`
}

// runStudioGen executes one generation OFF the request (Render's proxy
// cuts responses at ~30s and the GLM free tier can take longer on big
// documents), then lands the finished payload - or the error - on the
// pending artifact row. The handler returns 202 the moment the row is
// created, so no request ever hangs on the provider.
func (s *Server) runStudioGen(uid, artID, system, user string, maxTokens int, parse func(string) (json.RawMessage, error)) {
        go func() {
                ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
                defer cancel()
                var payload json.RawMessage
                // One retry on a provider hiccup: the free GLM tier throws the
                // occasional 429/timeout, and a fresh attempt usually lands.
                out, err := s.tutor.Provider.Complete(ctx, system, []tutorMessage{{Role: "user", Content: user}}, maxTokens)
                if err != nil {
                        s.log.Error("studio generation first attempt failed, retrying", "artifact", artID, "err", err)
                        select {
                        case <-ctx.Done():
                        case <-time.After(4 * time.Second):
                                out, err = s.tutor.Provider.Complete(ctx, system, []tutorMessage{{Role: "user", Content: user}}, maxTokens)
                        }
                }
                if err == nil {
                        payload, err = parse(out)
                }
                if err != nil {
                        s.log.Error("studio generation failed", "artifact", artID, "err", err)
                        payload, _ = json.Marshal(studioGenError{
                                Pending: false,
                                Error:   "Renance AI could not finish this document, try regenerating.",
                        })
                }
                if err := s.store.UpdateAIArtifactData(ctx, uid, artID, payload); err != nil {
                        s.log.Error("studio generation save failed", "artifact", artID, "err", err)
                }
        }()
}

// ---------------------------------------------------------------------------
// Quiz generation
// ---------------------------------------------------------------------------

type studioQuizRequest struct {
        Title      string   `json:"title"`
        Topics     []string `json:"topics"`
        Difficulty string   `json:"difficulty"`
        Count      int      `json:"count"`
        Body       string   `json:"body"` // JAMB | WAEC | NECO | POST-UTME | University Modules
}

type studioQuizData struct {
        Title      string                `json:"title"`
        Subject    string                `json:"subject,omitempty"`
        Difficulty string                `json:"difficulty"`
        Body       string                `json:"body,omitempty"`
        Questions  []aiGeneratedQuestion `json:"questions"`
}

// handleAIGenerateQuiz writes a quiz, saves it as an artifact and hands
// back the public share link straight away.
func (s *Server) handleAIGenerateQuiz(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if !s.limiter.allow("ai:user:" + uid) {
                w.Header().Set("Retry-After", "15")
                fail(w, http.StatusTooManyRequests, "rate_limited", "AI cooling down, retry in a few seconds")
                return
        }
        if !requireStandard(w, s.tierRank(r, uid)) {
                return
        }
        if s.tutor == nil || s.tutor.Provider == nil {
                fail(w, http.StatusServiceUnavailable, "ai_disabled", "AI generation is not configured on this deployment")
                return
        }
        var req studioQuizRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        topics := cleanTopics(req.Topics, studioMaxTopics)
        if len(topics) == 0 {
                fail(w, http.StatusBadRequest, "invalid_topic", "pick at least one topic")
                return
        }
        difficulty := normalizeDifficulty(req.Difficulty)
        if req.Count <= 0 {
                req.Count = 5
        }
        if req.Count > studioMaxQuizQuestions {
                req.Count = studioMaxQuizQuestions
        }
        body := normalizeExamBody(req.Body)

        // Ground the writer on real past questions for these topics:
        // every topic is its own keyword group, so a multi-topic quiz
        // grounds on EACH topic, not on stems naming all of them at once.
        bridging := ""
        bridged := 0
        if s.lib != nil {
                bridging, bridged = s.bridgeGrounding(topics, body)
        }

        title := strings.TrimSpace(req.Title)
        if title == "" {
                title = defaultArtifactTitle(topics) + " Quiz"
        }
        if len(title) > studioMaxTitle {
                title = title[:studioMaxTitle]
        }
        subject := topics[0]

        pending, _ := json.Marshal(studioPendingData{Pending: true, Title: title})
        art := &store.AIArtifact{
                UserID:     uid,
                Kind:       "quiz",
                Title:      title,
                Subject:    subject,
                ClassLevel: body,
                Data:       pending,
        }
        if err := s.store.SaveAIArtifact(r.Context(), art); err != nil {
                s.log.Error("studio quiz save", "err", err)
                fail(w, http.StatusInternalServerError, "save_failed", "could not save the quiz")
                return
        }
        // Every generated quiz is public-shareable from birth: stamp the
        // name-bearing slug right away (jamb-biology-cells-quiz-x7q2). The
        // link works the moment the questions land on the row.
        art.ShareSlug = quizShareSlug(title)
        if err := s.store.SetAIArtifactShareSlug(r.Context(), uid, art.ID, art.ShareSlug); err != nil {
                s.log.Error("studio quiz share slug", "err", err)
        }

        s.runStudioQuizGen(quizGenSpec{
                uid: uid, artID: art.ID, title: title, subject: subject,
                topics: topics, difficulty: difficulty, body: body,
                count: req.Count, bridging: bridging,
        })

        writeJSON(w, http.StatusAccepted, studioArtifactResponse{
                Artifact: artifactJSON(*art),
                Phases:   studioPhases(bridged),
                Bridged:  bridged,
        })
}

// quizGenSpec carries everything the chunked quiz writer needs.
type quizGenSpec struct {
        uid, artID, title, subject string
        topics                     []string
        difficulty, body           string
        count                      int
        bridging                   string
}

// runStudioQuizGen generates the quiz in sequential chunks of
// studioQuizChunk questions (a 40-question paper is four 10-question
// calls). Sequential on purpose: the free provider tier throttles
// parallel calls hard. Every chunk gets the same one-retry policy as
// every other studio generation; duplicate stems across chunks are
// dropped. If a chunk ultimately fails, the set still lands with the
// questions that made it - a 37-question quiz beats an error card -
// and only a fully empty set writes the error payload.
func (s *Server) runStudioQuizGen(spec quizGenSpec) {
        go func() {
                // Overall budget: 90s base + 45s per extra chunk, capped.
                budget := 90*time.Second + time.Duration((spec.count-1)/studioQuizChunk)*45*time.Second
                if budget > 6*time.Minute {
                        budget = 6 * time.Minute
                }
                deadline := time.Now().Add(budget)

                all := make([]aiGeneratedQuestion, 0, spec.count)
                seen := map[string]bool{}
                for made := 0; made < spec.count; {
                        want := studioQuizChunk
                        if rem := spec.count - made; rem < want {
                                want = rem
                        }
                        // Per-chunk prompt asks for exactly this chunk's size.
                        system := quizSystemPrompt(spec.topics, spec.difficulty, want, spec.body, spec.bridging)
                        user := fmt.Sprintf("Generate %d %s practice questions on: %s. Vary the angles; do not repeat earlier questions.",
                                want, strings.ToLower(spec.difficulty), strings.Join(spec.topics, ", "))

                        chunkCtx, cancel := context.WithTimeout(context.Background(), 75*time.Second)
                        out, err := s.completeWithRetry(chunkCtx, system, user, studioQuizTokens)
                        if err == nil {
                                var qs []aiGeneratedQuestion
                                qs, err = parseAIBatchMax(out, spec.topics, spec.difficulty, want)
                                if err == nil {
                                        for _, q := range qs {
                                                key := strings.ToLower(strings.TrimSpace(q.Stem))
                                                if key == "" || seen[key] {
                                                        continue
                                                }
                                                seen[key] = true
                                                all = append(all, q)
                                                made++
                                        }
                                }
                        }
                        cancel()
                        if err != nil {
                                s.log.Error("studio quiz chunk failed", "artifact", spec.artID, "made", len(all), "err", err)
                        }
                        // Stop early when the wall clock is spent, keeping
                        // every question that already landed.
                        if time.Now().After(deadline) {
                                break
                        }
                }

                var payload json.RawMessage
                if len(all) == 0 {
                        payload, _ = json.Marshal(studioGenError{
                                Pending: false,
                                Error:   "Renance AI could not finish this quiz, try regenerating.",
                        })
                } else {
                        payload, _ = json.Marshal(studioQuizData{
                                Title: spec.title, Subject: spec.subject, Difficulty: spec.difficulty,
                                Body: spec.body, Questions: all,
                        })
                }
                if err := s.store.UpdateAIArtifactData(context.Background(), spec.uid, spec.artID, payload); err != nil {
                        s.log.Error("studio quiz save failed", "artifact", spec.artID, "err", err)
                }
        }()
}

// completeWithRetry is the one-retry provider call every studio
// generator shares (the free tier throws the occasional 429/timeout,
// and a fresh attempt usually lands).
func (s *Server) completeWithRetry(ctx context.Context, system, user string, maxTokens int) (string, error) {
        msgs := []tutorMessage{{Role: "user", Content: user}}
        out, err := s.tutor.Provider.Complete(ctx, system, msgs, maxTokens)
        if err != nil {
                select {
                case <-ctx.Done():
                case <-time.After(4 * time.Second):
                        out, err = s.tutor.Provider.Complete(ctx, system, msgs, maxTokens)
                }
        }
        return out, err
}

// quizShareSlug builds "<slugified title>-<4 random chars>".
func quizShareSlug(title string) string {
        return slugify(title) + "-" + randomSuffix(4)
}

var slugStrip = regexp.MustCompile(`[^a-z0-9]+`)

func slugify(s string) string {
        s = strings.ToLower(strings.TrimSpace(s))
        s = slugStrip.ReplaceAllString(s, "-")
        s = strings.Trim(s, "-")
        if s == "" {
                s = "quiz"
        }
        if len(s) > 60 {
                s = s[:60]
        }
        // never end on a partial word boundary
        s = strings.Trim(s, "-")
        return s
}

func randomSuffix(n int) string {
        const alphabet = "abcdefghjkmnpqrstuvwxyz23456789"
        buf := make([]byte, n)
        rand.Read(buf)
        for i, b := range buf {
                buf[i] = alphabet[int(b)%len(alphabet)]
        }
        return string(buf)
}

// tutorMessage is tutor.Message under the studio's local name.
type tutorMessage = tutor.Message

// ---------------------------------------------------------------------------
// Study note generation
// ---------------------------------------------------------------------------

type studioNoteRequest struct {
        Title      string `json:"title"`
        Topic      string `json:"topic"`
        Subject    string `json:"subject"`
        ClassLevel string `json:"classLevel"`
        Template   string `json:"template"` // simple | detailed | revision
}

type studioNoteSection struct {
        Heading string `json:"heading"`
        Body    string `json:"body"`
}

type studioNoteData struct {
        Title      string                `json:"title"`
        Subject    string                `json:"subject,omitempty"`
        ClassLevel string                `json:"classLevel,omitempty"`
        Template   string                `json:"template,omitempty"`
        Summary    string                `json:"summary"`
        Sections   []studioNoteSection   `json:"sections"`
        KeyPoints  []string              `json:"keyPoints"`
        ExamTips   []string              `json:"examTips"`
        PracticeQs []aiGeneratedQuestion `json:"practiceQuestions"`
}

// handleAIGenerateNote writes a structured study note. The template is
// the house arrangement (summary, sections, key points, exam tips,
// practice questions) so every note renders and exports identically.
func (s *Server) handleAIGenerateNote(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if !s.limiter.allow("ai:user:" + uid) {
                w.Header().Set("Retry-After", "15")
                fail(w, http.StatusTooManyRequests, "rate_limited", "AI cooling down, retry in a few seconds")
                return
        }
        if !requireStandard(w, s.tierRank(r, uid)) {
                return
        }
        if s.tutor == nil || s.tutor.Provider == nil {
                fail(w, http.StatusServiceUnavailable, "ai_disabled", "AI generation is not configured on this deployment")
                return
        }
        var req studioNoteRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        topic := strings.TrimSpace(req.Topic)
        if topic == "" || len(topic) > studioMaxTopicCh {
                fail(w, http.StatusBadRequest, "invalid_topic", "topic is required (max 90 chars)")
                return
        }
        template := normalizeNoteTemplate(req.Template)

        bridging := ""
        bridged := 0
        if s.lib != nil {
                bridging, bridged = s.bridgeGrounding([]string{topic}, "")
        }

        title := firstNonEmpty(req.Title, defaultArtifactTitle([]string{topic}))
        if len(title) > studioMaxTitle {
                title = title[:studioMaxTitle]
        }
        subject := strings.TrimSpace(req.Subject)
        classLevel := strings.TrimSpace(req.ClassLevel)

        pending, _ := json.Marshal(studioPendingData{Pending: true, Title: title})
        art := &store.AIArtifact{
                UserID:     uid,
                Kind:       "note",
                Title:      title,
                Subject:    subject,
                ClassLevel: classLevel,
                Data:       pending,
        }
        if err := s.store.SaveAIArtifact(r.Context(), art); err != nil {
                s.log.Error("studio note save", "err", err)
                fail(w, http.StatusInternalServerError, "save_failed", "could not save the note")
                return
        }

        system := noteSystemPrompt(topic, subject, classLevel, template, bridging)
        s.runStudioGen(uid, art.ID, system, "Write the note on: "+topic+".", studioNoteTokens, func(out string) (json.RawMessage, error) {
                var data studioNoteData
                if err := extractJSONObject(out, &data); err != nil {
                        return nil, err
                }
                data.Title = firstNonEmpty(title, data.Title)
                if len(data.Title) > studioMaxTitle {
                        data.Title = data.Title[:studioMaxTitle]
                }
                data.Subject = subject
                data.ClassLevel = classLevel
                data.Template = template
                if len(data.Sections) == 0 {
                        data.Sections = []studioNoteSection{{Heading: topic, Body: data.Summary}}
                }
                if data.Summary == "" && len(data.Sections) > 0 {
                        data.Summary = data.Sections[0].Body
                }
                return json.Marshal(data)
        })

        writeJSON(w, http.StatusAccepted, studioArtifactResponse{
                Artifact: artifactJSON(*art),
                Phases:   studioPhases(bridged),
                Bridged:  bridged,
        })
}

// handleAINoteFromText saves a chat reply (or any text) as a note
// artifact so anything the AI writes can live on the Notes page.
func (s *Server) handleAINoteFromText(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        var req struct {
                Title   string `json:"title"`
                Content string `json:"content"`
                Subject string `json:"subject"`
        }
        if !decodeJSON(w, r, &req) {
                return
        }
        title := strings.TrimSpace(req.Title)
        content := strings.TrimSpace(req.Content)
        if title == "" {
                title = "Saved from Renance AI"
        }
        if len(title) > studioMaxTitle {
                title = title[:studioMaxTitle]
        }
        if content == "" {
                fail(w, http.StatusBadRequest, "invalid_content", "content is required")
                return
        }
        if len(content) > 24000 {
                content = content[:24000]
        }
        data := studioNoteData{
                Title:    title,
                Template: "saved",
                Summary:  firstLine(content),
                Sections: []studioNoteSection{{Heading: title, Body: content}},
        }
        raw, err := json.Marshal(data)
        if err != nil {
                fail(w, http.StatusInternalServerError, "encode_failed", "could not encode the note")
                return
        }
        art := &store.AIArtifact{
                UserID:  uid,
                Kind:    "note",
                Title:   title,
                Subject: strings.TrimSpace(req.Subject),
                Data:    raw,
        }
        if err := s.store.SaveAIArtifact(r.Context(), art); err != nil {
                s.log.Error("note from text save", "err", err)
                fail(w, http.StatusInternalServerError, "save_failed", "could not save the note")
                return
        }
        writeJSON(w, http.StatusOK, studioArtifactResponse{Artifact: artifactJSON(*art)})
}

// ---------------------------------------------------------------------------
// Lesson note generation (schools)
// ---------------------------------------------------------------------------

type studioLessonRequest struct {
        Subject    string `json:"subject"`
        ClassLevel string `json:"classLevel"`
        Topic      string `json:"topic"`
        Term       string `json:"term"`
        Duration   int    `json:"duration"`
        Body       string `json:"body"`
}

type studioLessonData struct {
        Subject           string              `json:"subject"`
        ClassLevel        string              `json:"classLevel"`
        Topic             string              `json:"topic"`
        Term              string              `json:"term,omitempty"`
        Duration          int                 `json:"duration,omitempty"`
        AgeGroup          string              `json:"ageGroup,omitempty"`
        Objectives        []string            `json:"objectives"`
        Materials         []string            `json:"materials"`
        EntryBehaviour    string              `json:"entryBehaviour"`
        PreviousKnowledge string              `json:"previousKnowledge"`
        Content           []studioNoteSection `json:"content"`
        Evaluation        []string            `json:"evaluation"`
        Summary           string              `json:"summary"`
        Assignment        string              `json:"assignment"`
}

// handleAIGenerateLessonNote writes a Nigerian school lesson note in
// the standard format (objectives, materials, entry behaviour, content
// steps, evaluation, summary, assignment).
func (s *Server) handleAIGenerateLessonNote(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if !s.limiter.allow("ai:user:" + uid) {
                w.Header().Set("Retry-After", "15")
                fail(w, http.StatusTooManyRequests, "rate_limited", "AI cooling down, retry in a few seconds")
                return
        }
        if !requireStandard(w, s.tierRank(r, uid)) {
                return
        }
        if s.tutor == nil || s.tutor.Provider == nil {
                fail(w, http.StatusServiceUnavailable, "ai_disabled", "AI generation is not configured on this deployment")
                return
        }
        var req studioLessonRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        subject := strings.TrimSpace(req.Subject)
        classLevel := strings.TrimSpace(req.ClassLevel)
        topic := strings.TrimSpace(req.Topic)
        if subject == "" || classLevel == "" || topic == "" {
                fail(w, http.StatusBadRequest, "invalid_request", "subject, classLevel and topic are required")
                return
        }
        if len(topic) > studioMaxTopicCh {
                fail(w, http.StatusBadRequest, "invalid_topic", "topic too long (max 90 chars)")
                return
        }
        term := strings.TrimSpace(req.Term)
        if term == "" {
                term = "First Term"
        }
        duration := req.Duration
        if duration <= 0 || duration > 240 {
                duration = 40
        }

        title := topic + " - " + subject + " " + classLevel
        if len(title) > studioMaxTitle {
                title = title[:studioMaxTitle]
        }
        pending, _ := json.Marshal(studioPendingData{Pending: true, Title: title})
        art := &store.AIArtifact{
                UserID:     uid,
                Kind:       "lesson_note",
                Title:      title,
                Subject:    subject,
                ClassLevel: classLevel,
                Data:       pending,
        }
        if err := s.store.SaveAIArtifact(r.Context(), art); err != nil {
                s.log.Error("studio lesson save", "err", err)
                fail(w, http.StatusInternalServerError, "save_failed", "could not save the lesson note")
                return
        }

        system := lessonSystemPrompt(subject, classLevel, topic, term, duration)
        s.runStudioGen(uid, art.ID, system, "Write the lesson note.", studioLessonTokens, func(out string) (json.RawMessage, error) {
                var data studioLessonData
                if err := extractJSONObject(out, &data); err != nil {
                        return nil, err
                }
                data.Subject, data.ClassLevel, data.Topic, data.Term, data.Duration = subject, classLevel, topic, term, duration
                if len(data.Objectives) == 0 {
                        return nil, fmt.Errorf("lesson note came back without objectives")
                }
                return json.Marshal(data)
        })

        writeJSON(w, http.StatusAccepted, studioArtifactResponse{
                Artifact: artifactJSON(*art),
                Phases:   []string{"Thinking", "Structuring the lesson plan", "Composing"},
                Bridged:  0,
        })
}

// ---------------------------------------------------------------------------
// Notebook generation (NotebookLM-style)
// ---------------------------------------------------------------------------

type studioNotebookRequest struct {
        Title      string   `json:"title"`
        Subject    string   `json:"subject"`
        ClassLevel string   `json:"classLevel"`
        Topics     []string `json:"topics"`
}

type studioKeyTerm struct {
        Term    string `json:"term"`
        Meaning string `json:"meaning"`
}

type studioTopicNote struct {
        Topic    string          `json:"topic"`
        Summary  string          `json:"summary"`
        DeepDive string          `json:"deepDive"`
        KeyTerms []studioKeyTerm `json:"keyTerms"`
        Examples []string        `json:"examples"`
}

type studioNotebookData struct {
        Title      string            `json:"title"`
        Subject    string            `json:"subject,omitempty"`
        ClassLevel string            `json:"classLevel,omitempty"`
        Overview   string            `json:"overview"`
        TopicNotes []studioTopicNote `json:"topicNotes"`
        Glossary   []studioKeyTerm   `json:"glossary"`
        ExamFocus  []string          `json:"examFocus"`
        StudyPlan  []string          `json:"studyPlan"`
}

// handleAIGenerateNotebook writes the NotebookLM-style study notebook
// with the pre-built house arrangement: overview, one deep note per
// topic, glossary, exam focus and a day-by-day study plan.
func (s *Server) handleAIGenerateNotebook(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if !s.limiter.allow("ai:user:" + uid) {
                w.Header().Set("Retry-After", "15")
                fail(w, http.StatusTooManyRequests, "rate_limited", "AI cooling down, retry in a few seconds")
                return
        }
        if !requireStandard(w, s.tierRank(r, uid)) {
                return
        }
        if s.tutor == nil || s.tutor.Provider == nil {
                fail(w, http.StatusServiceUnavailable, "ai_disabled", "AI generation is not configured on this deployment")
                return
        }
        var req studioNotebookRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        subject := strings.TrimSpace(req.Subject)
        if subject == "" {
                fail(w, http.StatusBadRequest, "invalid_subject", "subject is required")
                return
        }
        topics := cleanTopics(req.Topics, studioMaxTopics)
        if len(topics) == 0 {
                fail(w, http.StatusBadRequest, "invalid_topics", "add at least one topic")
                return
        }
        bridging := ""
        bridged := 0
        if s.lib != nil {
                bridging, bridged = s.bridgeGrounding(append([]string{subject}, topics...), "")
        }

        title := firstNonEmpty(req.Title, subject+" Notebook")
        if len(title) > studioMaxTitle {
                title = title[:studioMaxTitle]
        }
        classLevel := strings.TrimSpace(req.ClassLevel)

        pending, _ := json.Marshal(studioPendingData{Pending: true, Title: title})
        art := &store.AIArtifact{
                UserID:     uid,
                Kind:       "notebook",
                Title:      title,
                Subject:    subject,
                ClassLevel: classLevel,
                Data:       pending,
        }
        if err := s.store.SaveAIArtifact(r.Context(), art); err != nil {
                s.log.Error("studio notebook save", "err", err)
                fail(w, http.StatusInternalServerError, "save_failed", "could not save the notebook")
                return
        }

        system := notebookSystemPrompt(subject, classLevel, topics, bridging)
        s.runStudioGen(uid, art.ID, system, "Build the notebook.", studioNotebookTokens, func(out string) (json.RawMessage, error) {
                var data studioNotebookData
                if err := extractJSONObject(out, &data); err != nil {
                        return nil, err
                }
                data.Title = firstNonEmpty(title, data.Title)
                if len(data.Title) > studioMaxTitle {
                        data.Title = data.Title[:studioMaxTitle]
                }
                data.Subject = subject
                data.ClassLevel = classLevel
                if len(data.TopicNotes) == 0 {
                        return nil, fmt.Errorf("notebook came back without topic notes")
                }
                return json.Marshal(data)
        })

        writeJSON(w, http.StatusAccepted, studioArtifactResponse{
                Artifact: artifactJSON(*art),
                Phases:   studioPhases(bridged),
                Bridged:  bridged,
        })
}

// ---------------------------------------------------------------------------
// Artifact CRUD + share
// ---------------------------------------------------------------------------

type studioArtifactJSON struct {
        ID         string          `json:"id"`
        Kind       string          `json:"kind"`
        Title      string          `json:"title"`
        Subject    string          `json:"subject,omitempty"`
        ClassLevel string          `json:"classLevel,omitempty"`
        Data       json.RawMessage `json:"data"`
        ShareSlug  string          `json:"shareSlug,omitempty"`
        CreatedAt  string          `json:"createdAt"`
}

type studioArtifactResponse struct {
        Artifact studioArtifactJSON `json:"artifact"`
        Phases   []string           `json:"phases,omitempty"`
        Bridged  int                `json:"bridged,omitempty"`
}

func artifactJSON(a store.AIArtifact) studioArtifactJSON {
        return studioArtifactJSON{
                ID:         a.ID,
                Kind:       a.Kind,
                Title:      a.Title,
                Subject:    a.Subject,
                ClassLevel: a.ClassLevel,
                Data:       a.Data,
                ShareSlug:  a.ShareSlug,
                CreatedAt:  a.CreatedAt.UTC().Format("2006-01-02T15:04:05Z"),
        }
}

func (s *Server) handleListArtifacts(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        kind := r.URL.Query().Get("type")
        switch kind {
        case "", "quiz", "note", "notebook", "lesson_note":
        default:
                fail(w, http.StatusBadRequest, "invalid_type", "unknown artifact type")
                return
        }
        arts, err := s.store.ListAIArtifacts(r.Context(), uid, kind)
        if err != nil {
                s.log.Error("list artifacts", "err", err)
                fail(w, http.StatusInternalServerError, "list_failed", "could not load your documents")
                return
        }
        out := make([]studioArtifactJSON, 0, len(arts))
        for _, a := range arts {
                out = append(out, artifactJSON(a))
        }
        writeJSON(w, http.StatusOK, map[string]any{"artifacts": out})
}

func (s *Server) handleGetArtifact(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        art, err := s.store.GetAIArtifact(r.Context(), uid, r.PathValue("id"))
        if err != nil {
                fail(w, http.StatusNotFound, "not_found", "that document does not exist")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{"artifact": artifactJSON(art)})
}

func (s *Server) handleDeleteArtifact(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if err := s.store.DeleteAIArtifact(r.Context(), uid, r.PathValue("id")); err != nil {
                fail(w, http.StatusNotFound, "not_found", "that document does not exist")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// handleShareArtifact (re)issues a public share slug for a quiz. Quizes
// only: notes and notebooks stay private to the account.
func (s *Server) handleShareArtifact(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        id := r.PathValue("id")
        art, err := s.store.GetAIArtifact(r.Context(), uid, id)
        if err != nil {
                fail(w, http.StatusNotFound, "not_found", "that document does not exist")
                return
        }
        if art.Kind != "quiz" {
                fail(w, http.StatusBadRequest, "not_shareable", "only quizzes can be shared publicly")
                return
        }
        art.ShareSlug = quizShareSlug(art.Title)
        if err := s.store.SetAIArtifactShareSlug(r.Context(), uid, art.ID, art.ShareSlug); err != nil {
                s.log.Error("share artifact", "err", err)
                fail(w, http.StatusInternalServerError, "share_failed", "could not create the share link")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{"shareSlug": art.ShareSlug})
}

// handleSharedQuiz serves GET /quiz/shared/{slug} - PUBLIC, no auth.
// The link tag carries the quiz's own name; scoring happens on the
// player's device so the friend plays instantly, no account needed.
func (s *Server) handleSharedQuiz(w http.ResponseWriter, r *http.Request) {
        slug := strings.TrimSpace(r.PathValue("slug"))
        if slug == "" || len(slug) > 90 {
                fail(w, http.StatusNotFound, "not_found", "that quiz does not exist")
                return
        }
        art, err := s.store.GetAIArtifactBySlug(r.Context(), slug)
        if err != nil {
                fail(w, http.StatusNotFound, "not_found", "that quiz does not exist")
                return
        }
        if art.Kind != "quiz" {
                fail(w, http.StatusNotFound, "not_found", "that quiz does not exist")
                return
        }
        var data studioQuizData
        if err := json.Unmarshal(art.Data, &data); err != nil {
                fail(w, http.StatusInternalServerError, "encode_failed", "that quiz is corrupted")
                return
        }
        // A quiz still being generated (or one whose generation failed) has
        // no questions to play: the share link starts working the moment
        // the document lands on the row.
        var probe struct {
                Pending bool   `json:"pending"`
                Error   string `json:"error"`
        }
        _ = json.Unmarshal(art.Data, &probe)
        if probe.Pending || probe.Error != "" || len(data.Questions) == 0 {
                fail(w, http.StatusNotFound, "not_ready", "that quiz is not ready yet, try the link again in a few seconds")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "title":      data.Title,
                "subject":    data.Subject,
                "difficulty": data.Difficulty,
                "body":       data.Body,
                "questions":  data.Questions,
        })
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

func cleanTopics(in []string, max int) []string {
        var out []string
        seen := map[string]bool{}
        for _, t := range in {
                t = strings.TrimSpace(t)
                if t == "" || len(t) > studioMaxTopicCh || seen[strings.ToLower(t)] {
                        continue
                }
                seen[strings.ToLower(t)] = true
                out = append(out, t)
                if len(out) == max {
                        break
                }
        }
        return out
}

func normalizeDifficulty(d string) string {
        switch strings.TrimSpace(d) {
        case "Easy", "Medium", "Hard":
                return strings.TrimSpace(d)
        default:
                return "Medium"
        }
}

func normalizeExamBody(b string) string {
        switch strings.ToUpper(strings.TrimSpace(b)) {
        case "JAMB":
                return "JAMB"
        case "WAEC":
                return "WAEC"
        case "NECO":
                return "NECO"
        case "POST-UTME", "POST UTME":
                return "POST-UTME"
        case "UNIVERSITY MODULES", "University Modules":
                return "University Modules"
        default:
                return ""
        }
}

func normalizeNoteTemplate(t string) string {
        switch strings.TrimSpace(t) {
        case "simple", "detailed", "revision":
                return strings.TrimSpace(t)
        default:
                return "detailed"
        }
}

func defaultArtifactTitle(topics []string) string {
        if len(topics) == 0 {
                return "Renance AI"
        }
        t := strings.TrimSpace(topics[0])
        if t != "" {
                t = strings.ToUpper(t[:1]) + t[1:]
        }
        t = strings.Map(func(r rune) rune {
                if unicode.IsLetter(r) || unicode.IsDigit(r) || r == ' ' || r == '-' || r == ',' || r == '&' || r == '\'' {
                        return r
                }
                return -1
        }, t)
        if len(t) > studioMaxTitle {
                t = t[:studioMaxTitle]
        }
        return t
}

func firstNonEmpty(vals ...string) string {
        for _, v := range vals {
                if strings.TrimSpace(v) != "" {
                        return strings.TrimSpace(v)
                }
        }
        return ""
}

func firstLine(s string) string {
        if i := strings.IndexByte(s, '\n'); i > 0 {
                s = s[:i]
        }
        s = strings.TrimSpace(s)
        if len(s) > 160 {
                s = s[:160] + "..."
        }
        return s
}

// extractJSONObject pulls the first balanced {...} out of a model reply
// and decodes it into dst.
func extractJSONObject(raw string, dst any) error {
        cut := strings.Index(raw, "{")
        if cut < 0 {
                return fmt.Errorf("no JSON object in reply")
        }
        depth := 0
        inStr := false
        esc := false
        for i := cut; i < len(raw); i++ {
                c := raw[i]
                if inStr {
                        if esc {
                                esc = false
                        } else if c == '\\' {
                                esc = true
                        } else if c == '"' {
                                inStr = false
                        }
                        continue
                }
                switch c {
                case '"':
                        inStr = true
                case '{':
                        depth++
                case '}':
                        depth--
                        if depth == 0 {
                                return json.Unmarshal([]byte(raw[cut:i+1]), dst)
                        }
                }
        }
        return fmt.Errorf("unbalanced JSON object in reply")
}
