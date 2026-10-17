// service.go - the learn module's economy core: learner profile,
// catalog, course paths, the completion ledger (XP / gems / hearts /
// streak / quests / league / chests), mistakes practice and the shop.
// Every row is keyed by the real study.users id - the founder's rule
// that all gamification lives on the Renance account, nothing mock.
package learn

import (
        "context"
        "fmt"
        "log/slog"
        "math"
        "time"

        "github.com/jackc/pgx/v5"
        "github.com/jackc/pgx/v5/pgconn"

        "renance.dev/study-api/internal/store"
)

type Service struct {
        // Pool is the store's database surface - the split-horizon
        // router (user / content / cache domains), the dual-write Mirror
        // or the raw primary pool. Every accepted write the ledger lands
        // replays to the mirrors.
        Pool store.Pool
        // CachePool is the dedicated lesson-cache database (InsForge).
        // Set by the server wiring; when nil the storage-cap probe reads
        // Pool instead (single-database boots).
        CachePool       store.Pool
        // Blobs is the object-storage home of whole lesson documents
        // (Cloudflare R2, founder 2026-10-17): R2-first reads, dual
        // writes (bucket + cache database), three read tiers with clean
        // falls. nil keeps the cache database as the only home - every
        // path degrades to today's posture.
        Blobs           LessonBlobs
        Log             *slog.Logger
        Engine          *Engine
        UnlimitedHearts bool
        // expGuard single-flights per-course unit expansion (expand.go):
        // two students opening the same growing course never double-generate.
        expGuard *expGuard
}

// WireExpGuard arms the per-course expansion single-flight. Nil-safe
// (tests construct Service structs directly without it).
func (s *Service) WireExpGuard() {
        if s.expGuard == nil {
                s.expGuard = newExpGuard()
        }
}

// querier is the narrow surface shared by store.Pool and pgx.Tx so
// ledger writes can run inside one transaction.
type querier interface {
        QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
        Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
        Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

// ─── Learner ──────────────────────────────────────────────────────────────

type Learner struct {
        UserID          string
        Hearts          int
        Gems            int
        XP              int
        FreezeCount     int
        DailyGoal       int
        SuperActive     bool
        BoostActive     bool
        Streak          int
        LastActive      string
        StreakForgiven  int    // lifetime forgiveness uses (cap: MaxStreakForgiveness)
        InstitutionType string // University | Polytechnic | College of Education
        Department      string // learn.departments.dept_id
}

// ensureLearner materializes the learn.learners row for a Renance user
// on first touch (signup-time lazy init - no registration changes).
func (s *Service) ensureLearner(ctx context.Context, q querier, userID string) error {
        _, err := q.Exec(ctx, `
                INSERT INTO learn.learners (user_id) VALUES ($1)
                ON CONFLICT (user_id) DO NOTHING`, userID)
        return err
}

func (s *Service) loadLearner(ctx context.Context, q querier, userID string) (*Learner, error) {
        l := &Learner{UserID: userID}
        var superUntil, boostUntil *time.Time
        var heartsUpdatedAt time.Time
        err := q.QueryRow(ctx, `
                SELECT hearts, gems, xp, freeze_count, daily_goal, streak_count,
                       COALESCE(last_active_on,''), streak_forgiven_count, super_until, boost_until, hearts_updated_at,
                       institution_type, department
                FROM learn.learners WHERE user_id = $1`, userID).
                Scan(&l.Hearts, &l.Gems, &l.XP, &l.FreezeCount, &l.DailyGoal, &l.Streak,
                        &l.LastActive, &l.StreakForgiven, &superUntil, &boostUntil, &heartsUpdatedAt,
                        &l.InstitutionType, &l.Department)
        if err != nil {
                return nil, err
        }
        now := time.Now()
        l.SuperActive = superUntil != nil && superUntil.After(now)
        l.BoostActive = boostUntil != nil && boostUntil.After(now)

        // Lazy heart regen (Supreme parity): applied on read, written back.
        hs := RegenHearts(l.Hearts, heartsUpdatedAt, l.SuperActive, s.UnlimitedHearts)
        if hs.Hearts != l.Hearts {
                l.Hearts = hs.Hearts
                _, _ = q.Exec(ctx, `UPDATE learn.learners SET hearts=$2, hearts_updated_at=now() WHERE user_id=$1`,
                        userID, hs.Hearts)
        }
        if s.UnlimitedHearts {
                l.Hearts = MaxHearts
        }
        return l, nil
}

// displayStreak is the streak the learner should SEE (economy.go
// DisplayStreak): the stored streak_count only moves on activity, so
// the read path decays it once the quiet days outrun every freeze /
// forgiveness bridge. Presentation only - nothing is written back
// here; the stored value self-corrects on the learner's next action.
func (l *Learner) displayStreak() int {
        return DisplayStreak(l.Streak, l.LastActive, l.FreezeCount, l.StreakForgiven, time.Now())
}

// TouchStreakForQuiz advances the Supreme streak for a GRADED quiz/mock
// attempt (founder directive 2026-10-17: "a streak should only be
// updated when a user attempts any quiz or lesson - simply opening the
// app does not count"). Lesson completions already touch the streak in
// ledger Complete; this is the quiz bridge, called by the grading
// engine after the paper lands. Best-effort by contract: a streak
// hiccup must never re-grade or fail an attempt, so every error is
// swallowed into the log.
func (s *Service) TouchStreakForQuiz(ctx context.Context, userID string) {
        defer func() {
                if r := recover(); r != nil && s.Log != nil {
                        s.Log.Error("learn: quiz streak touch panic", "err", r, "user", userID)
                }
        }()
        if s.Pool == nil || userID == "" {
                return
        }
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                if s.Log != nil {
                        s.Log.Error("learn: quiz streak touch learner", "err", err, "user", userID)
                }
                return
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                if s.Log != nil {
                        s.Log.Error("learn: quiz streak touch load", "err", err, "user", userID)
                }
                return
        }
        today := LagosToday()
        if l.LastActive == today {
                return // already active today - the lesson path owns this touch
        }
        sr := ComputeStreak(l.Streak, l.LastActive, l.FreezeCount, l.StreakForgiven, time.Now())
        forgiven := l.StreakForgiven
        if sr.Forgiven {
                forgiven++
        }
        if _, err := s.Pool.Exec(ctx, `
                UPDATE learn.learners SET streak_count=$2, last_active_on=$3,
                       freeze_count=$4, streak_forgiven_count=$5
                WHERE user_id=$1`,
                userID, sr.Count, today, l.FreezeCount-sr.FreezesUsed, forgiven); err != nil {
                if s.Log != nil {
                        s.Log.Error("learn: quiz streak touch write", "err", err, "user", userID)
                }
        }
}

// ─── Profile (top-bar counters + settings page payload) ───────────────────

type Profile struct {
        Hearts          int    `json:"hearts"`
        UnlimitedHearts bool   `json:"unlimitedHearts"`
        NextHeartInMs   *int64 `json:"nextHeartInMs"`
        Gems            int    `json:"gems"`
        XP              int    `json:"xp"`
        Streak          int    `json:"streak"`
        DailyGoal       int    `json:"dailyGoal"`
        TodayXP         int    `json:"todayXp"`
        SuperActive     bool   `json:"superActive"`
        BoostActive     bool   `json:"boostActive"`
        FreezeCount     int    `json:"freezeCount"`
        League          string `json:"league"`
        Courses         int    `json:"courseCount"`
        TopicsDone      int    `json:"topicsDone"`
        PerfectCount    int    `json:"perfectCount"`
        InstitutionType string `json:"institutionType"`
        Department      string `json:"department"`
        DepartmentName  string `json:"departmentName"`
}

func (s *Service) Profile(ctx context.Context, userID string) (*Profile, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                return nil, err
        }
        p := &Profile{
                Hearts: l.Hearts, UnlimitedHearts: s.UnlimitedHearts || l.SuperActive,
                Gems: l.Gems, XP: l.XP, Streak: l.displayStreak(), DailyGoal: l.DailyGoal,
                SuperActive: l.SuperActive, BoostActive: l.BoostActive, FreezeCount: l.FreezeCount,
        }
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(xp),0) FROM learn.daily_stats WHERE user_id=$1 AND day_key=$2`,
                userID, LagosToday()).Scan(&p.TodayXP)
        leagueIdx := s.leagueIndex(ctx, userID)
        p.League = Leagues[clamp(leagueIdx, 0, len(Leagues)-1)]
        _ = s.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM learn.user_courses WHERE user_id=$1`, userID).Scan(&p.Courses)
        _ = s.Pool.QueryRow(ctx, `SELECT COUNT(*), COUNT(*) FILTER (WHERE best_score >= 100) FROM learn.progress WHERE user_id=$1`,
                userID).Scan(&p.TopicsDone, &p.PerfectCount)
        p.InstitutionType, p.Department = l.InstitutionType, l.Department
        if p.Department != "" {
                _ = s.Pool.QueryRow(ctx, `SELECT name FROM learn.departments WHERE dept_id=$1`, p.Department).Scan(&p.DepartmentName)
        }
        return p, nil
}

// SetDailyGoal whitelists the Supreme goals grid (20/50/100/200).
func (s *Service) SetDailyGoal(ctx context.Context, userID string, goal int) error {
        switch goal {
        case 20, 50, 100, 200:
        default:
                return fmt.Errorf("learn: invalid daily goal %d", goal)
        }
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return err
        }
        _, err := s.Pool.Exec(ctx, `UPDATE learn.learners SET daily_goal=$2 WHERE user_id=$1`, userID, goal)
        return err
}

// ResetProgress wipes every learn row for the account (settings page,
// Supreme's "reset all progress").
func (s *Service) ResetProgress(ctx context.Context, userID string) error {
        for _, stmt := range []string{
                `DELETE FROM learn.progress WHERE user_id=$1`,
                `DELETE FROM learn.xp_events WHERE user_id=$1`,
                `DELETE FROM learn.daily_stats WHERE user_id=$1`,
                `DELETE FROM learn.mistakes WHERE user_id=$1`,
                `DELETE FROM learn.quest_claims WHERE user_id=$1`,
                `DELETE FROM learn.league_members WHERE user_id=$1`,
                `DELETE FROM learn.chest_opens WHERE user_id=$1`,
                `DELETE FROM learn.user_courses WHERE user_id=$1`,
                `DELETE FROM learn.active_course WHERE user_id=$1`,
                `DELETE FROM learn.learners WHERE user_id=$1`,
        } {
                if _, err := s.Pool.Exec(ctx, stmt, userID); err != nil {
                        return err
                }
        }
        return nil
}

// ─── Catalog + course selection (multi-select, add/remove later) ──────────

type CatalogItem struct {
        ID          string `json:"id"`
        Title       string `json:"title"`
        Faculty     string `json:"faculty"`
        Institution string `json:"institutionType"`
        Body        string `json:"body"`
        TopicCount  int    `json:"topicCount"`
        InList      bool   `json:"inList"`
        Learners    int    `json:"learnerCount"`
}

// Catalog lists courses the student can pick from. body selects the
// desk: jamb | waec | neco | post-utme → that body's subject courses;
// tertiary (university focus) → the full curriculum tree with the
// institution-type + faculty filters. The level tag is NEVER returned
// (founder directive: removed from the courses list).
func (s *Service) Catalog(ctx context.Context, userID, body, q, faculty, itype string, page, pageSize int) ([]CatalogItem, int, error) {
        if pageSize <= 0 || pageSize > 50 {
                pageSize = 24
        }
        if page <= 0 {
                page = 1
        }
        offset := (page - 1) * pageSize
        where := "WHERE TRUE"
        args := []any{}
        arg := func(v any) string { args = append(args, v); return fmt.Sprintf("$%d", len(args)) }

        switch body {
        case "jamb", "waec", "neco", "post-utme":
                where += " AND c.body = " + arg(body)
        default: // tertiary tree
                where += " AND c.body = 'tertiary'"
                if itype != "" && itype != "All" {
                        where += " AND d.itype = " + arg(itype)
                }
                if faculty != "" && faculty != "All" {
                        where += " AND d.faculty = " + arg(faculty)
                }
        }
        if q != "" {
                where += " AND c.title ILIKE " + arg("%"+q+"%")
        }

        base := `FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id ` + where
        var total int
        if err := s.Pool.QueryRow(ctx, "SELECT COUNT(*) "+base, args...).Scan(&total); err != nil {
                return nil, 0, err
        }
        // The user-scoped + paging arguments are appended after the filter
        // args so their positional placeholders stay stable.
        out, _, err := s.catalogQuery(ctx, userID, base, args, pageSize, offset)
        return out, total, err
}

func (s *Service) catalogQuery(ctx context.Context, userID, base string, args []any, pageSize, offset int) ([]CatalogItem, int, error) {
        // Two-step pool-safe rewrite (the catalog lives on the content
        // database, user_courses/progress on the user database): the page
        // is content-only, the InList + Learners columns fill from the
        // user pool over the page's course ids.
        pageSizePh := fmt.Sprintf("$%d", len(args)+1)
        offsetPh := fmt.Sprintf("$%d", len(args)+2)
        args = append(args, pageSize, offset)
        sql := `
                SELECT c.course_id, c.title, d.faculty, d.itype, c.body,
                       (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id)
                ` + base + `
                ORDER BY c.title LIMIT ` + pageSizePh + ` OFFSET ` + offsetPh
        rows, err := s.Pool.Query(ctx, sql, args...)
        if err != nil {
                return nil, 0, err
        }
        defer rows.Close()
        var out []CatalogItem
        for rows.Next() {
                var it CatalogItem
                if err := rows.Scan(&it.ID, &it.Title, &it.Faculty, &it.Institution, &it.Body,
                        &it.TopicCount); err != nil {
                        return nil, 0, err
                }
                out = append(out, it)
        }
        if err := rows.Err(); err != nil {
                return nil, 0, err
        }
        ids := make([]string, len(out))
        for i := range out {
                ids[i] = out[i].ID
        }
        if enrolled, err := s.enrolledSet(ctx, userID, ids); err == nil {
                for i := range out {
                        out[i].InList = enrolled[out[i].ID]
                }
        }
        if counts, err := s.enrolledLearnerCounts(ctx, ids); err == nil {
                for i := range out {
                        out[i].Learners = counts[out[i].ID]
                }
        }
        return out, len(out), nil
}

// Faculties returns the distinct faculty list of the tertiary tree.
func (s *Service) Faculties(ctx context.Context) ([]string, error) {
        rows, err := s.Pool.Query(ctx,
                `SELECT DISTINCT d.faculty FROM learn.departments d
                 JOIN learn.courses c ON c.dept_id = d.dept_id
                 WHERE c.body = 'tertiary' ORDER BY faculty`)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        var out []string
        for rows.Next() {
                var f string
                if err := rows.Scan(&f); err != nil {
                        return nil, err
                }
                out = append(out, f)
        }
        return out, rows.Err()
}

// MyCourses is the student's own course list with per-course progress.
type MyCourse struct {
        ID         string `json:"id"`
        Title      string `json:"title"`
        Body       string `json:"body"`
        TopicCount int    `json:"topicCount"`
        DoneCount  int    `json:"completedTopics"`
        BestSum    int    `json:"bestScoreSum"`
        Active     bool   `json:"active"`
}

func (s *Service) MyCourses(ctx context.Context, userID string) ([]MyCourse, error) {
        // Two-step pool-safe rewrite (the list + active flag + progress
        // on the user database, titles + topic counts on the content
        // database): the ordered list comes from user_courses, the
        // catalog columns fill over the course ids, the per-course
        // progress aggregates ride the user pool over the topic ids.
        listRows, err := s.Pool.Query(ctx, `
                SELECT uc.course_id,
                       EXISTS (SELECT 1 FROM learn.active_course ac
                                WHERE ac.user_id = uc.user_id AND ac.course_id = uc.course_id)
                FROM learn.user_courses uc
                WHERE uc.user_id = $1 ORDER BY uc.added_at DESC`, userID)
        if err != nil {
                return nil, err
        }
        defer listRows.Close()
        type entry struct {
                active bool
                item   MyCourse
        }
        ordered := []entry{}
        var ids []string
        for listRows.Next() {
                var id string
                var active bool
                if err := listRows.Scan(&id, &active); err != nil {
                        return nil, err
                }
                ordered = append(ordered, entry{active: active, item: MyCourse{ID: id}})
                ids = append(ids, id)
        }
        if err := listRows.Err(); err != nil {
                return nil, err
        }
        if len(ids) == 0 {
                return []MyCourse{}, nil
        }
        crows, err := s.Pool.Query(ctx, `
                SELECT c.course_id, c.title, c.body,
                       (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id)
                FROM learn.courses c WHERE c.course_id = ANY($1)`, ids)
        if err != nil {
                return nil, err
        }
        defer crows.Close()
        byCourse := map[string]MyCourse{}
        for crows.Next() {
                var c MyCourse
                if err := crows.Scan(&c.ID, &c.Title, &c.Body, &c.TopicCount); err != nil {
                        return nil, err
                }
                byCourse[c.ID] = c
        }
        if err := crows.Err(); err != nil {
                return nil, err
        }
        tmap, err := s.topicIDsForCourses(ctx, ids)
        if err != nil {
                return nil, err
        }
        var flat []string
        for _, list := range tmap {
                flat = append(flat, list...)
        }
        progress := map[string]struct {
                done int
                sum  int
        }{}
        if len(flat) > 0 {
                prows, err := s.Pool.Query(ctx, `
                SELECT topic_id, COALESCE(best_score, 0) FROM learn.progress
                WHERE user_id = $1 AND topic_id = ANY($2)`, userID, flat)
                if err == nil {
                        for prows.Next() {
                                var tid string
                                var best int
                                if prows.Scan(&tid, &best) == nil {
                                        p := progress[tid]
                                        p.done++
                                        p.sum += best
                                        progress[tid] = p
                                }
                        }
                        prows.Close()
                }
        }
        out := make([]MyCourse, 0, len(ordered))
        for _, e := range ordered {
                c := byCourse[e.item.ID]
                c.Active = e.active
                for _, tid := range tmap[e.item.ID] {
                        if p, ok := progress[tid]; ok {
                                c.DoneCount += p.done
                                c.BestSum += p.sum
                        }
                }
                out = append(out, c)
        }
        return out, nil
}

// SetMyCourses replaces the student's course list (the multi-select
// "mark all the ones you want" flow; can add more or remove later).
func (s *Service) SetMyCourses(ctx context.Context, userID string, courseIDs []string) error {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return err
        }
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return err
        }
        defer tx.Rollback(ctx)
        if _, err := tx.Exec(ctx, `DELETE FROM learn.user_courses WHERE user_id=$1`, userID); err != nil {
                return err
        }
        for _, id := range courseIDs {
                if _, err := tx.Exec(ctx, `
                        INSERT INTO learn.user_courses (user_id, course_id) VALUES ($1,$2)
                        ON CONFLICT DO NOTHING`, userID, id); err != nil {
                        return err
                }
        }
        // Keep an active course that is still in the list; else pick the first.
        if _, err := tx.Exec(ctx, `
                DELETE FROM learn.active_course WHERE user_id=$1
                  AND course_id NOT IN (SELECT course_id FROM learn.user_courses WHERE user_id=$1)`, userID); err != nil {
                return err
        }
        if _, err := tx.Exec(ctx, `
                INSERT INTO learn.active_course (user_id, course_id)
                SELECT $1, uc.course_id FROM learn.user_courses uc
                WHERE uc.user_id = $1 AND NOT EXISTS (SELECT 1 FROM learn.active_course ac WHERE ac.user_id=$1)
                ORDER BY uc.added_at DESC LIMIT 1
                ON CONFLICT (user_id) DO NOTHING`, userID); err != nil {
                return err
        }
        return tx.Commit(ctx)
}

// SetActiveCourse pins which course the Learn path opens with.
func (s *Service) SetActiveCourse(ctx context.Context, userID, courseID string) error {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return err
        }
        _, err := s.Pool.Exec(ctx, `
                INSERT INTO learn.active_course (user_id, course_id) VALUES ($1,$2)
                ON CONFLICT (user_id) DO UPDATE SET course_id = EXCLUDED.course_id`, userID, courseID)
        return err
}

// ─── Course path (units + zig-zag ladder) ─────────────────────────────────

type TopicNode struct {
        ID       string `json:"id"`
        Title    string `json:"title"`
        Category string `json:"category"`
        Seq      int    `json:"orderIndex"`
        Unit     int    `json:"unit"`
        Status   string `json:"status"` // completed | current | locked
        Best     int    `json:"bestScore"`
}

type UnitNode struct {
        Index       int    `json:"index"`
        Name        string `json:"name"`
        From        int    `json:"from"`
        To          int    `json:"to"`
        HasChest    bool   `json:"hasChest"`
        ChestOpened bool   `json:"chestOpened"`
        ReviewReady bool   `json:"reviewReady"`
}

type CoursePath struct {
        ID           string      `json:"id"`
        Title        string      `json:"title"`
        Body         string      `json:"body"`
        Institution  string      `json:"institutionType"`
        Faculty      string      `json:"faculty"`
        Department   string      `json:"department"`
        Topics       []TopicNode `json:"topics"`
        Units        []UnitNode  `json:"units"`
        CompletedPct int         `json:"completedPercent"`
        // Generating: the course tree is still growing (the background
        // loop is adding the next unit of 10 topics). The ladder renders
        // a quiet "being prepared" node instead of a fake locked one.
        Generating bool `json:"generating"`
}

// CoursePath renders the Supreme LearnPath ladder: completed behind,
// one current node, everything after locked (sequential unlock).
func (s *Service) CoursePath(ctx context.Context, userID, courseID string) (*CoursePath, error) {
        var cp CoursePath
        err := s.Pool.QueryRow(ctx, `
                SELECT c.course_id, c.title, c.body, d.itype, d.faculty, d.name
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.course_id = $1`, courseID).
                Scan(&cp.ID, &cp.Title, &cp.Body, &cp.Institution, &cp.Faculty, &cp.Department)
        if err != nil {
                return nil, err
        }
        // Two-step pool-safe rewrite (topics on the content database,
        // progress on the user database): the ordered ladder comes from
        // the content pool, the best scores fill over the topic ids.
        rows, err := s.Pool.Query(ctx, `
                SELECT t.topic_id, t.title, t.category, t.seq, t.unit
                FROM learn.topics t
                WHERE t.course_id = $1 ORDER BY t.seq`, courseID)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        var ids []string
        nodeOf := map[string]*TopicNode{}
        var order []*TopicNode
        for rows.Next() {
                var n TopicNode
                if err := rows.Scan(&n.ID, &n.Title, &n.Category, &n.Seq, &n.Unit); err != nil {
                        return nil, err
                }
                ids = append(ids, n.ID)
                nodeOf[n.ID] = &n
                order = append(order, &n)
        }
        if err := rows.Err(); err != nil {
                return nil, err
        }
        bestByTopic, err := s.progressBestByTopic(ctx, userID, ids)
        if err != nil {
                return nil, err
        }
        currentSet := false
        done := 0
        for _, np := range order {
                n := *np
                best, has := bestByTopic[np.ID]
                if !has {
                        best = -1
                }
                switch {
                case best >= 0:
                        n.Status, n.Best = "completed", best
                        done++
                case !currentSet:
                        n.Status = "current"
                        currentSet = true
                default:
                        n.Status = "locked"
                }
                cp.Topics = append(cp.Topics, n)
        }
        if err := rows.Err(); err != nil {
                return nil, err
        }
        if len(cp.Topics) == 0 {
                return &cp, nil
        }
        // Units (4 topics per unit; unit 1 ends in a chest, later units in
        // the trophy review - Supreme's LearnPath shape).
        byUnit := map[int][]TopicNode{}
        for _, t := range cp.Topics {
                byUnit[t.Unit] = append(byUnit[t.Unit], t)
        }
        names := []string{"Foundations", "Core Principles", "Applications in Practice", "Advanced Topics", "Mastery & Project"}
        maxUnit := cp.Topics[len(cp.Topics)-1].Unit
        // Real unit captions win when the roadmap carries them
        // (learn.course_units rows from the secondary refresh and the
        // expansion loop); the cycle names remain the fallback.
        titledUnits := map[int]string{}
        if tRows, err := s.Pool.Query(ctx, `SELECT unit, title FROM learn.course_units WHERE course_id=$1 AND title <> ''`, courseID); err == nil {
                for tRows.Next() {
                        var u int
                        var t string
                        if tRows.Scan(&u, &t) == nil {
                                titledUnits[u] = t
                        }
                }
                tRows.Close()
        }
        for u := 1; u <= maxUnit; u++ {
                ts := byUnit[u]
                if len(ts) == 0 {
                        continue
                }
                name := titledUnits[u]
                if name == "" {
                        name = names[(u-1)%len(names)]
                }
                role := u
                un := UnitNode{Index: u, Name: fmt.Sprintf("Unit %d · %s", u, name), From: ts[0].Seq, To: ts[len(ts)-1].Seq}
                // Chest/review readiness: every topic but the last complete.
                un.ReviewReady = true
                for _, t := range ts {
                        if t.Status != "completed" {
                                un.ReviewReady = false
                        }
                }
                _ = role
                un.HasChest = u == 1
                if un.HasChest {
                        _ = s.Pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM learn.chest_opens WHERE user_id=$1 AND chest_key=$2)`,
                                userID, fmt.Sprintf("%s#%d", courseID, u)).Scan(&un.ChestOpened)
                }
                cp.Units = append(cp.Units, un)
        }
        cp.CompletedPct = int(math.Round(float64(done) * 100 / float64(len(cp.Topics))))

        // The deep tree (founder directive 2026-10-16): when the student
        // is studying inside the LAST generated unit, the background
        // loop silently grows the next unit (10 AI topics) and pre-warms
        // its first lessons. The ladder flags it so the client can show
        // a "being prepared" node instead of pretending the course ends.
        currentUnit := 1
        for _, t := range cp.Topics {
                if t.Status != "completed" {
                        currentUnit = t.Unit
                        break
                }
        }
        cp.Generating = maxUnit < maxUnitsFor(cp.Body) && currentUnit >= maxUnit
        if cp.Generating {
                go s.EnsureUnitsAhead(userID, courseID)
        }
        return &cp, nil
}
