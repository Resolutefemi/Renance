// expand.go - the deep course tree (founder directive 2026-10-16):
// "Each course in the tertiary institution desk must be structured to
// have up to 15 units, with 10 topics under each unit."
//
// A seeded tertiary course ships with its CSV topics (12 in unit 1).
// The expansion loop grows it one unit at a time: when a student gets
// close to the end of the generated material, the NEXT unit (10 fresh
// AI topics) is generated silently in the background and cached to
// learn.topics + learn.course_units - the student never waits, never
// sees it happen. Generation is single-flight per course, detached
// from any request, and idempotent (PK conflicts mean "already done").
package learn

import (
        "context"
        "encoding/json"
        "fmt"
        "strings"
        "sync"
        "time"

        "renance.dev/study-api/internal/learn/synth"
        "renance.dev/study-api/internal/tutor"
)

const (
        // MaxCourseUnits is the unit ceiling per course ("up to 15 units").
        MaxCourseUnits = 15
        // UnitTopics is the number of topics the generator writes per unit.
        UnitTopics = 10
        // expandBudget bounds one background expansion loop.
        expandBudget = 180 * time.Second
)

// expansionSystem: the unit-planner persona. Strict JSON, exactly 10
// topics, syllabus-true escalation.
const expansionSystem = `You are Renance's curriculum architect: an expert Nigerian lecturer who designs course unit plans.

Rules:
- Follow the course's standard: JAMB/WAEC/NECO topics follow the Nigerian senior-secondary syllabus; university topics follow the NUC CCMAS / NBTE / NCCE curricula.
- Output STRICT JSON only. No markdown fences, no commentary.
- Titles are plain text (no LaTeX needed here), max 12 words, no unit numbers inside them.`

// unit names cycle exactly like CoursePath's ladder captions, so a
// generated unit's fallback title always matches what the ladder shows.
var unitNameCycle = []string{"Foundations", "Core Principles", "Applications in Practice", "Advanced Topics", "Mastery & Project"}

func unitNamesFor(u int) string {
        return unitNameCycle[(u-1)%len(unitNameCycle)]
}

// expFlight is the per-course single-flight for unit expansion.
type expFlight struct {
        done chan struct{}
}

type expGuard struct {
        mu   sync.Mutex
        live map[string]*expFlight
}

func newExpGuard() *expGuard { return &expGuard{live: map[string]*expFlight{}} }

func (g *expGuard) begin(courseID string) (*expFlight, bool) {
        g.mu.Lock()
        defer g.mu.Unlock()
        if fl, ok := g.live[courseID]; ok {
                return fl, false
        }
        fl := &expFlight{done: make(chan struct{})}
        g.live[courseID] = fl
        return fl, true
}

func (g *expGuard) finish(courseID string, fl *expFlight) {
        g.mu.Lock()
        delete(g.live, courseID)
        g.mu.Unlock()
        close(fl.done)
}

// courseTreeState is what the expander needs to know before growing.
type courseTreeState struct {
        CourseID   string
        Title      string
        Body       string
        Subject    string
        Dept       string
        Faculty    string
        MaxUnit    int
        MaxSeq     int
        UnitCounts map[int]int
        Spine      []string // existing topic titles, in seq order
}

func (s *Service) loadTreeState(ctx context.Context, courseID string) (*courseTreeState, error) {
        st := &courseTreeState{CourseID: courseID, UnitCounts: map[int]int{}}
        err := s.Pool.QueryRow(ctx,
                `SELECT c.title, c.body, COALESCE(c.subject,''), COALESCE(d.name,''), COALESCE(d.faculty,'')
                 FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                 WHERE c.course_id=$1`,
                courseID).Scan(&st.Title, &st.Body, &st.Subject, &st.Dept, &st.Faculty)
        if err != nil {
                return nil, err
        }
        rows, err := s.Pool.Query(ctx,
                `SELECT title, seq, unit FROM learn.topics WHERE course_id=$1 ORDER BY seq`, courseID)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        for rows.Next() {
                var title string
                var seq, unit int
                if err := rows.Scan(&title, &seq, &unit); err != nil {
                        return nil, err
                }
                st.Spine = append(st.Spine, title)
                if seq > st.MaxSeq {
                        st.MaxSeq = seq
                }
                if unit > st.MaxUnit {
                        st.MaxUnit = unit
                }
                st.UnitCounts[unit]++
        }
        return st, rows.Err()
}

// expansionPrompt asks the AI for exactly one unit of topics.
func expansionPrompt(st *courseTreeState, unit int) string {
        spine := st.Spine
        if len(spine) > 14 {
                spine = append([]string{}, spine[len(spine)-10:]...) // the latest 10 keep it anchored
        }
        band := "Nigerian university level (NUC CCMAS)"
        if st.Body == "jamb" || st.Body == "waec" || st.Body == "neco" || st.Body == "post-utme" {
                band = fmt.Sprintf("Nigerian senior-secondary %s standard", strings.ToUpper(st.Body))
        }
        subjectLine := ""
        if strings.TrimSpace(st.Subject) != "" {
                subjectLine = fmt.Sprintf("\nSubject: %s", st.Subject)
        }
        return fmt.Sprintf(`Course: %s%s
Standard: %s
The course already covers these topics (in order): %s.

Design unit %d of the course - the NEXT %d topics that follow naturally from the ones listed. Escalate depth: later units must go further than the earlier ones.

Output STRICT JSON only. No markdown fences, no commentary.
Shape: {"title": string, "topics": [{"title": string, "category": string, "keywords": [string, ...]}]}

Rules:
- "topics" carries EXACTLY %d items.
- Each topic title is a real syllabus-style topic title (max 12 words), no unit numbers inside it.
- "category" is one of: Concept, Principle, Application, Practice, Review.
- "keywords" carries 3 to 5 short study keywords the topic's quiz bank can match on.
- "title" (the unit title) is 2 to 6 words, no unit numbers.

Return the JSON object now.`, st.Title, subjectLine, band, strings.Join(spine, "; "), unit, UnitTopics, UnitTopics)
}

type aiUnitPlan struct {
        Title  string `json:"title"`
        Topics []struct {
                Title    string   `json:"title"`
                Category string   `json:"category"`
                Keywords []string `json:"keywords"`
        } `json:"topics"`
}

func validateUnitPlan(raw []byte) (*aiUnitPlan, error) {
        var p aiUnitPlan
        if err := json.Unmarshal(raw, &p); err != nil {
                return nil, err
        }
        if len(p.Topics) != UnitTopics {
                return nil, fmt.Errorf("want exactly %d topics, got %d", UnitTopics, len(p.Topics))
        }
        seen := map[string]bool{}
        for i, tp := range p.Topics {
                t := strings.TrimSpace(tp.Title)
                if t == "" {
                        return nil, fmt.Errorf("topic %d has an empty title", i)
                }
                if len(strings.Fields(t)) > 14 {
                        return nil, fmt.Errorf("topic %d title is too long", i)
                }
                key := strings.ToLower(t)
                if seen[key] {
                        return nil, fmt.Errorf("topic %d duplicates an earlier title", i)
                }
                seen[key] = true
        }
        return &p, nil
}

// insertUnitTopics writes the plan's topics; skipped = how many topic
// slots already exist for the unit (the refill path only fills gaps).
func (s *Service) insertUnitTopics(ctx context.Context, courseID string, st *courseTreeState, unit int, plan *aiUnitPlan, skip int) (int, error) {
        inserted := 0
        for i, tp := range plan.Topics {
                if i < skip {
                        continue
                }
                tid := fmt.Sprintf("%s-EU%02d%02d", courseID, unit, i+1)
                kw := tp.Keywords
                if len(kw) > 6 {
                        kw = kw[:6]
                }
                cat := firstNonEmpty(strings.TrimSpace(tp.Category), "Concept")
                if _, err := s.Pool.Exec(ctx, `
                        INSERT INTO learn.topics (topic_id, course_id, seq, title, category, unit, keywords)
                        VALUES ($1,$2,$3,$4,$5,$6,$7)
                        ON CONFLICT (topic_id) DO NOTHING`,
                        tid, courseID, st.MaxSeq+i+1, strings.TrimSpace(tp.Title), cat, unit, kw); err != nil {
                        return inserted, err
                }
                inserted++
        }
        return inserted, nil
}

// generateUnitPlan runs the AI pass (2 attempts, repair retry - lesson
// doctrine) for one unit of the course.
// generateUnitPlan produces the 10 topic titles for one unit.
// TERTIARY courses take the agent path (founder 2026-10-16: the AI API
// lacks the capacity for the whole tree, so the deterministic engine
// owns the ladder): instant, reliable, no 429s. Secondary desks never
// expand beyond their seeded roadmap, so the AI branch only ever
// serves exotic bodies.
func (s *Service) generateUnitPlan(ctx context.Context, st *courseTreeState, unit int) (*aiUnitPlan, error) {
        if st.Body == "tertiary" {
                title, tops := synth.UnitPlan(st.CourseID, st.Title, st.Dept, st.Faculty, unit)
                plan := &aiUnitPlan{Title: title}
                for i := range tops {
                        plan.Topics = append(plan.Topics, struct {
                                Title    string   `json:"title"`
                                Category string   `json:"category"`
                                Keywords []string `json:"keywords"`
                        }{Title: tops[i].Title, Category: tops[i].Category})
                }
                if _, verr := validateUnitPlan(mustJSON(plan)); verr != nil {
                        // the validator is the contract the rest of the loop trusts
                        return nil, fmt.Errorf("learn: synth unit plan invalid: %w", verr)
                }
                return plan, nil
        }
        var lastErr error
        for attempt := 0; attempt < 2; attempt++ {
                prompt := expansionPrompt(st, unit)
                if attempt > 0 && lastErr != nil {
                        prompt += fmt.Sprintf("\n\nYour previous attempt failed validation: %v\nFix exactly those problems and return the corrected JSON object.", lastErr)
                }
                out, err := s.Engine.AI.Complete(ctx, expansionSystem, []tutor.Message{{Role: "user", Content: prompt}}, 2200)
                if err != nil {
                        lastErr = err
                        continue
                }
                plan, perr := validateUnitPlan([]byte(extractJSON(out)))
                if perr != nil {
                        lastErr = perr
                        continue
                }
                return plan, nil
        }
        if s.Engine.Log != nil {
                s.Engine.Log.Error("learn: unit plan generation failed twice", "course", st.CourseID, "unit", unit, "err", lastErr)
        }
        return nil, fmt.Errorf("learn: unit plan generation failed, try again shortly")
}

// mustJSON marshals without failing on the plan shapes we just built.
func mustJSON(v any) []byte {
        b, err := json.Marshal(v)
        if err != nil {
                return []byte("{}")
        }
        return b
}

// ExpandNextUnit grows the course by ONE unit (10 AI topics) and
// reports whether it actually grew. Idempotent: a concurrent or replayed
// call loses the insert race and reports false without error.
func (s *Service) ExpandNextUnit(ctx context.Context, courseID string) (bool, error) {
        if s.Engine.AI == nil {
                return false, fmt.Errorf("learn: AI disabled - unit expansion unavailable")
        }
        st, err := s.loadTreeState(ctx, courseID)
        if err != nil {
                return false, err
        }
        if st.MaxUnit >= MaxCourseUnits {
                return false, nil // the tree is fully grown
        }
        next := st.MaxUnit + 1
        plan, err := s.generateUnitPlan(ctx, st, next)
        if err != nil {
                return false, err
        }
        title := strings.TrimSpace(plan.Title)
        if title == "" {
                title = unitNamesFor(next)
        }
        // Unit row first: winning it means this call owns the expansion.
        tag, err := s.Pool.Exec(ctx, `
                INSERT INTO learn.course_units (course_id, unit, title) VALUES ($1,$2,$3)
                ON CONFLICT (course_id, unit) DO NOTHING`, courseID, next, title)
        if err != nil {
                return false, err
        }
        if tag.RowsAffected() == 0 {
                return false, nil // someone expanded first
        }
        // The topics ride AFTER the unit row wins: a crash between the two
        // leaves a titled unit with no topics, which EnsureUnitsAhead's
        // refill pass repairs on the next visit.
        _, err = s.insertUnitTopics(ctx, courseID, st, next, plan, 0)
        if err != nil {
                return true, err
        }
        return true, nil
}

// EnsureUnitsAhead is the background loop the founder asked for: "the
// system must immediately and silently generate the next course/topic
// content in the background... Repeat this seamless background
// generation loop as the user progresses." Called after a CoursePath
// render and after every completion; grows the tree so the student is
// ALWAYS at least one full unit away from the end of the material, and
// repairs any titled-but-unfilled unit the crash window could leave.
func (s *Service) EnsureUnitsAhead(userID, courseID string) {
        if s.expGuard == nil {
                s.WireExpGuard()
        }
        if s.Engine == nil || s.Engine.AI == nil {
                return
        }
        ctx, cancel := context.WithTimeout(context.Background(), expandBudget)
        defer cancel()

        var currentUnit int
        err := s.Pool.QueryRow(ctx, `
                SELECT COALESCE((
                  SELECT t.unit FROM learn.topics t
                  LEFT JOIN learn.progress pr ON pr.topic_id = t.topic_id AND pr.user_id = $1
                  WHERE t.course_id = $2 AND COALESCE(pr.best_score, -1) < 0
                  ORDER BY t.seq LIMIT 1), 1)`,
                userID, courseID).Scan(&currentUnit)
        if err != nil {
                return
        }
        var maxUnit int
        if err := s.Pool.QueryRow(ctx, `SELECT COALESCE(MAX(unit),1) FROM learn.topics WHERE course_id=$1`, courseID).Scan(&maxUnit); err != nil {
                return
        }

        // Repair pass: a course_units row with no topics under it gets
        // refilled before anything else looks at the ladder.
        for u := 1; u <= maxUnit && u <= MaxCourseUnits; u++ {
                var n int
                _ = s.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM learn.topics WHERE course_id=$1 AND unit=$2`, courseID, u).Scan(&n)
                if n == 0 {
                        var titled int
                        _ = s.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM learn.course_units WHERE course_id=$1 AND unit=$2`, courseID, u).Scan(&titled)
                        if titled > 0 {
                                s.refillUnit(ctx, courseID, u)
                        }
                        break
                }
        }

        // Grow while the student is within ONE unit of the edge.
        for maxUnit-currentUnit < 1 && maxUnit < MaxCourseUnits {
                fl, leader := s.expGuard.begin(courseID)
                if !leader {
                        select {
                        case <-fl.done:
                        case <-ctx.Done():
                                return
                        }
                } else {
                        grew, gerr := s.ExpandNextUnit(ctx, courseID)
                        s.expGuard.finish(courseID, fl)
                        if gerr != nil || !grew {
                                return
                        }
                        // Pre-warm the fresh unit's first two lessons so opening
                        // it never shows the generating spinner.
                        s.prefetchUnitLessons(ctx, courseID, maxUnit+1)
                }
                var nextMax int
                if err := s.Pool.QueryRow(ctx, `SELECT COALESCE(MAX(unit),1) FROM learn.topics WHERE course_id=$1`, courseID).Scan(&nextMax); err != nil || nextMax == maxUnit {
                        return
                }
                maxUnit = nextMax
        }
}

// refillUnit re-asks the AI for a titled unit whose topics came up
// short (the crash window) and fills only the missing slots.
func (s *Service) refillUnit(ctx context.Context, courseID string, unit int) {
        st, err := s.loadTreeState(ctx, courseID)
        if err != nil {
                return
        }
        var have int
        _ = s.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM learn.topics WHERE course_id=$1 AND unit=$2`, courseID, unit).Scan(&have)
        if have >= UnitTopics {
                return
        }
        if s.Engine.AI == nil {
                return
        }
        plan, err := s.generateUnitPlan(ctx, st, unit)
        if err != nil {
                return
        }
        _, _ = s.insertUnitTopics(ctx, courseID, st, unit, plan, have)
}

// prefetchUnitLessons quietly generates the first lessons of a fresh
// unit (the same look-ahead doctrine as prefetchNext).
func (s *Service) prefetchUnitLessons(ctx context.Context, courseID string, unit int) {
        rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.topics
                WHERE course_id=$1 AND unit=$2
                  AND NOT EXISTS (SELECT 1 FROM learn.lessons l WHERE l.topic_id = learn.topics.topic_id)
                ORDER BY seq LIMIT 2`, courseID, unit)
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
                        return
                }
                fl := s.kickOff(nt)
                select {
                case <-fl.done:
                        if fl.err != nil {
                                return
                        }
                case <-ctx.Done():
                        return
                }
        }
}
