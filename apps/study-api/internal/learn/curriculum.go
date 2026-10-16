// curriculum.go seeds the learn curriculum tree. Two sources, both
// embedded in the binary:
//
//  1. The tertiary CSVs (289 departments / 10,684 courses / 128,208
//     topics) carried over from the supreme repo - gzipped in
//     seed/*.csv.gz, parsed with an RFC4180-tolerant reader, seeded
//     once in a background goroutine at boot when learn.courses is
//     empty.
//  2. The secondary subject roadmaps (JAMB / WAEC / NECO desks): one
//     JSON per subject in seed/secondary/*.json, up to 60 sequenced
//     topics per subject built on the Renance question-bank subjects,
//     with keyword sets that map each topic to the REAL past questions
//     in data/questions.
package learn

import (
        "compress/gzip"
        "context"
        "embed"
        "encoding/csv"
        "encoding/json"
        "fmt"
        "io"
        "log/slog"
        "strings"
        "time"
)

//go:embed seed/*.csv.gz
var tertiaryFS embed.FS

//go:embed seed/secondary/*.json
var secondaryFS embed.FS

// SecondarySubject is one JAMB/WAEC/NECO subject roadmap. The topics
// are the study order; keywords map the topic to the Renance bank so
// lesson quizzes serve REAL past questions (founder directive).
type SecondarySubject struct {
        Body       string   `json:"body"`                 // jamb | waec | neco
        Subject    string   `json:"subject"`              // bank slug, e.g. "chemistry"
        Title      string   `json:"title"`                // display, e.g. "Chemistry"
        UnitTitles []string `json:"unitTitles,omitempty"` // one display title per unit (JAMB 30x10)
        Topics     []struct {
                Title    string   `json:"title"`
                Category string   `json:"category"`
                Keywords []string `json:"keywords"`
                Drawings []string `json:"drawings,omitempty"` // ids in the drawing library
        } `json:"topics"`
}

type seedCourse struct {
        id, dept, code, title, level, category, body, subject string
}

type seedDept struct {
        id, itype, faculty, name, focus string
}

type seedTopic struct {
        id, courseID string
        seq, unit    int
        title        string
        category     string
        keywords     []string
        figures      []string
}

// parseCSVAt reads one gzipped CSV and yields its rows (skipping the
// banner row 0 and using row 1 as the header).
func parseCSVAt(path string) ([][]string, error) {
        f, err := tertiaryFS.Open(path)
        if err != nil {
                return nil, fmt.Errorf("learn: open %s: %w", path, err)
        }
        defer f.Close()
        gz, err := gzip.NewReader(f)
        if err != nil {
                return nil, fmt.Errorf("learn: gzip %s: %w", path, err)
        }
        defer gz.Close()
        r := csv.NewReader(gz)
        r.FieldsPerRecord = -1 // the master sheet carries footer junk
        r.LazyQuotes = true
        rows, err := r.ReadAll()
        if err != nil {
                return nil, fmt.Errorf("learn: csv %s: %w", path, err)
        }
        return rows, nil
}

var csvCRx = strings.NewReplacer(" ", "", "-", "", "_", "")

func isCRS(id string) bool { return strings.HasPrefix(id, "CRS-") || strings.HasPrefix(id, "GST ") }

// collectTertiary parses the six supreme CSVs into seed rows. The
// safety nets from prisma/seed.ts carry over: a course or department
// the department sheet misses is reconstructed so the FKs always hold.
func collectTertiary() ([]seedDept, []seedCourse, []seedTopic, error) {
        depts := map[string]seedDept{}
        courses := map[string]seedCourse{}
        var topics []seedTopic

        addDept := func(id, itype, faculty, name, focus string) {
                if id == "" || name == "" {
                        return
                }
                if _, ok := depts[id]; !ok {
                        depts[id] = seedDept{id: id, itype: itype, faculty: faculty, name: name, focus: focus}
                }
        }

        for _, spec := range []struct{ file, itype string }{
                {"seed/02_Universities.csv.gz", "University"},
                {"seed/03_Polytechnics.csv.gz", "Polytechnic"},
                {"seed/04_Colleges_of_Education.csv.gz", "College of Education"},
        } {
                rows, err := parseCSVAt(spec.file)
                if err != nil {
                        return nil, nil, nil, err
                }
                for i, row := range rows {
                        if i < 2 || len(row) < 5 {
                                continue
                        }
                        addDept(row[1], row[2], row[3], row[4], func() string {
                                if len(row) > 5 {
                                        return row[5]
                                }
                                return ""
                        }())
                }
        }

        // GST virtual department (supreme seed.ts L100-108).
        addDept("GST-ALL", "General Studies", "General Studies", "General Studies (all institutions)", "")

        // Courses master (10,604 CRS rows).
        rows, err := parseCSVAt("seed/05_Courses_Master.csv.gz")
        if err != nil {
                return nil, nil, nil, err
        }
        for i, row := range rows {
                if i < 2 || len(row) < 8 || !strings.HasPrefix(row[1], "CRS-") {
                        continue
                }
                id, code := row[1], row[2]
                dept := row[3]
                itype, faculty := row[4], row[5]
                deptName := ""
                if len(row) > 6 {
                        deptName = row[6]
                }
                title := row[7]
                level, category := "", "Core"
                if len(row) > 8 {
                        level = row[8]
                }
                if len(row) > 9 && row[9] != "" {
                        category = row[9]
                }
                if _, ok := courses[id]; ok {
                        continue
                }
                // Safety net: department missing from the sheets.
                addDept(dept, itype, faculty, func() string {
                        if deptName != "" {
                                return deptName
                        }
                        return faculty + " " + itype
                }(), "")
                courses[id] = seedCourse{id: id, dept: dept, code: code, title: title, level: level, category: category, body: "tertiary"}
        }

        // General Studies suite (seed 07): the national GST/GNS shelf.
        // Its column layout differs from the master - [1] is the code
        // AND the id ("GST 101"), [2] the category, [3] the title. The
        // first parse treated it as a master sheet and seeded the whole
        // shelf with empty titles under bogus departments; the columns
        // now map correctly (the real topics ride in the master topic
        // sheet).
        gstRows, err := parseCSVAt("seed/07_General_Studies_GST.csv.gz")
        if err != nil {
                return nil, nil, nil, err
        }
        for i, row := range gstRows {
                if i < 2 || len(row) < 4 {
                        continue
                }
                code := strings.TrimSpace(row[1])
                title := strings.TrimSpace(row[3])
                category := strings.TrimSpace(row[2])
                if code == "" || title == "" || !strings.HasPrefix(code, "GST") {
                        continue // footer junk ('80', blank separators)
                }
                if _, ok := courses[code]; ok {
                        continue
                }
                courses[code] = seedCourse{
                        id: code, dept: "GST-ALL", code: code, title: title,
                        level: "100 Level", category: category, body: "tertiary",
                }
                // Topics: the master topic sheet (06) already covers every
                // GST course with real sequenced topics, so nothing is
                // synthesised here.
        }

        // Topics (128,208).
        rows, err = parseCSVAt("seed/06_Course_Topics.csv.gz")
        if err != nil {
                return nil, nil, nil, err
        }
        for i, row := range rows {
                if i < 2 || len(row) < 8 || !strings.HasPrefix(row[1], "TOP-") {
                        continue
                }
                tid, cid := row[1], row[2]
                if _, ok := courses[cid]; !ok {
                        continue
                }
                seq := 0
                fmt.Sscanf(row[6], "%d", &seq)
                if _, ok := courses[cid]; ok {
                        unit := (seq-1)/12 + 1
                        if seq <= 0 {
                                seq = 1
                        }
                        topics = append(topics, seedTopic{id: tid, courseID: cid, seq: seq, unit: unit, title: row[7], category: row[8]})
                }
        }

        out := make([]seedDept, 0, len(depts))
        for _, d := range depts {
                out = append(out, d)
        }
        courseList := make([]seedCourse, 0, len(courses))
        for _, c := range courses {
                courseList = append(courseList, c)
        }
        return out, courseList, topics, nil
}

// loadSecondary parses the embedded subject roadmaps.
func loadSecondary() ([]SecondarySubject, error) {
        entries, err := secondaryFS.ReadDir("seed/secondary")
        if err != nil {
                return nil, err
        }
        var out []SecondarySubject
        for _, e := range entries {
                if !strings.HasSuffix(e.Name(), ".json") {
                        continue
                }
                f, err := secondaryFS.Open("seed/secondary/" + e.Name())
                if err != nil {
                        return nil, err
                }
                raw, err := io.ReadAll(f)
                f.Close()
                if err != nil {
                        return nil, err
                }
                var s SecondarySubject
                if err := json.Unmarshal(raw, &s); err != nil {
                        return nil, fmt.Errorf("learn: %s: %w", e.Name(), err)
                }
                out = append(out, s)
        }
        return out, nil
}

// collectSecondary converts subject roadmaps into seed rows: one
// department per body, one course per subject, topics in study order.
// JAMB subjects carry the founder's 2026-10-17 ladder: 30 units of 10
// topics each (unitTitles named per unit); WAEC/NECO keep the classic
// units of 4 (Supreme's TOPICS_PER_UNIT). The returned map carries
// courseID -> unit titles for the ladder captions.
func collectSecondary(subs []SecondarySubject) ([]seedDept, []seedCourse, []seedTopic, map[string][]string) {
        var depts []seedDept
        var courses []seedCourse
        var topics []seedTopic
        unitTitles := map[string][]string{}
        seen := map[string]bool{}
        for _, s := range subs {
                body := strings.ToLower(s.Body)
                deptID := "SEC-" + strings.ToUpper(body)
                if !seen[deptID] {
                        seen[deptID] = true
                        depts = append(depts, seedDept{
                                id: deptID, itype: "Secondary",
                                faculty: "Senior Secondary", name: strings.ToUpper(body)+" subjects", focus: "",
                        })
                }
                courseID := "SEC-" + strings.ToUpper(body) + "-" + strings.ToUpper(s.Subject)
                courses = append(courses, seedCourse{
                        id: courseID, dept: deptID, code: strings.ToUpper(s.Subject[:3]), title: s.Title,
                        level: "", category: "Core", body: body, subject: s.Subject,
                })
                unitSize := 4 // the classic secondary ladder
                if body == "jamb" {
                        unitSize = 10 // founder directive: 30 units x 10 topics
                        if len(s.UnitTitles) > 0 {
                                unitTitles[courseID] = s.UnitTitles
                        }
                }
                for i, t := range s.Topics {
                        seq := i + 1
                        unit := (seq-1)/unitSize + 1
                        topics = append(topics, seedTopic{
                                id:       fmt.Sprintf("%s-T%03d", courseID, seq),
                                courseID: courseID,
                                seq:      seq, unit: unit,
                                title: t.Title, category: t.Category, keywords: t.Keywords,
                                figures: t.Drawings,
                        })
                }
        }
        return depts, courses, topics, unitTitles
}

// SeedIfEmpty loads the whole curriculum when learn.courses is empty.
// Called from a background goroutine at boot: first boot pays the
// insert cost (~140k rows, chunked), later boots return instantly.
// Self-repair (2026-10-14): the first GST parse seeded the general
// studies shelf with empty titles under bogus departments; when those
// rows are detected they are purged (the department delete cascades
// the courses and any list entries) and the curriculum re-seeds once.
func SeedIfEmpty(ctx context.Context, q querier, log *slog.Logger) error {
        var n int
        if err := q.QueryRow(ctx, "SELECT COUNT(*) FROM learn.courses").Scan(&n); err != nil {
                return err
        }
        if n > 0 {
                var broken int
                if err := q.QueryRow(ctx,
                        "SELECT COUNT(*) FROM learn.departments WHERE itype LIKE 'Core for all programmes%'").Scan(&broken); err != nil {
                        return err
                }
                if broken == 0 {
                        return nil
                }
                log.Warn("learn: repairing the broken general-studies seed", "bogus_departments", broken)
                for _, stmt := range []string{
                        `DELETE FROM learn.departments WHERE itype LIKE 'Core for all programmes%'`,
                        `DELETE FROM learn.courses WHERE course_id LIKE 'GST %'`,
                        `DELETE FROM learn.departments WHERE dept_id = 'GST-ALL'`,
                } {
                        if _, err := q.Exec(ctx, stmt); err != nil {
                                return fmt.Errorf("learn: gst repair: %w", err)
                        }
                }
        }
        start := time.Now()
        td, tc, tt, err := collectTertiary()
        if err != nil {
                return err
        }
        subs, err := loadSecondary()
        if err != nil {
                return err
        }
        sd, sc, st, _ := collectSecondary(subs)
        depts := append(td, sd...)
        courses := append(tc, sc...)
        topics := append(tt, st...)

        if err := insertCurriculum(ctx, q, depts, courses, topics); err != nil {
                return err
        }
        log.Info("learn: curriculum seeded",
                "departments", len(depts), "courses", len(courses), "topics", len(topics),
                "took", time.Since(start).Round(time.Millisecond).String())
        return nil
}
