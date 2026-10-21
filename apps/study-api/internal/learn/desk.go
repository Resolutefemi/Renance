// desk.go - the course desk (founder directive 2026-10-14, third
// pass). The tertiary desk asks the student for their kind of tertiary
// institution first, then their department, and only then shows the
// course shelf: the national 100-level general courses (GST/GNS, the
// general sciences and mathematics) FIRST, then the department's own
// courses. Everything here reads the seeded curriculum tables - no
// mock data anywhere. Search matches a course by its short code (with
// the street aliases students actually type: CSC, COS, MTH, MTS...),
// its title, or one of its key topics.
package learn

import (
        "context"
        "encoding/json"
        "errors"
        "fmt"
        "sort"
        "strings"
        "time"
        "unicode"

        "github.com/jackc/pgx/v5"

        "renance.dev/study-api/internal/tutor"
)

// ─── Department gate ──────────────────────────────────────────────────────

// DeskInstitutions are the kinds of tertiary institution the desk
// serves, in the order the gate shows them. They match the seeded
// learn.departments.itype values exactly.
var DeskInstitutions = []string{"University", "Polytechnic", "College of Education"}

// DeskDepartment is one pick on the department gate.
type DeskDepartment struct {
        ID      string `json:"id"`
        Faculty string `json:"faculty"`
        Name    string `json:"name"`
        Focus   string `json:"focus"`
        Courses int    `json:"courseCount"`
}

// Departments lists the departments of one institution kind, from the
// seeded curriculum (real rows, with a live course count each).
func (s *Service) Departments(ctx context.Context, itype string) ([]DeskDepartment, error) {
        rows, err := s.Pool.Query(ctx, `
                SELECT d.dept_id, d.faculty, d.name, d.focus,
                       (SELECT COUNT(*) FROM learn.courses c WHERE c.dept_id = d.dept_id)
                FROM learn.departments d
                WHERE d.itype = $1 AND EXISTS (SELECT 1 FROM learn.courses c WHERE c.dept_id = d.dept_id)
                ORDER BY d.name`, itype)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        out := []DeskDepartment{}
        for rows.Next() {
                var d DeskDepartment
                if err := rows.Scan(&d.ID, &d.Faculty, &d.Name, &d.Focus, &d.Courses); err != nil {
                        return nil, err
                }
                out = append(out, d)
        }
        return out, rows.Err()
}

// ValidationError is a client-fixable desk save problem (an unknown
// institution kind, or a department that does not belong to it). The
// HTTP layer maps it to 400 with the real message; ANY other error from
// SetDesk is a genuine database fault and answers 500, so the web
// client never blames the student's connection for a server-side
// failure (founder directive 2026-10-15).
type ValidationError struct{ Msg string }

func (e *ValidationError) Error() string { return e.Msg }

// SetDesk saves the student's institution kind + department on the
// learner row. The department must exist and belong to the institution
// kind, so a stale client can never park a student in a mismatched desk.
// The learner row is materialized FIRST: a brand-new account has no
// learn.learners row yet, and an UPDATE against a missing row affects
// 0 rows while still returning success - the student's first desk pick
// was silently thrown away and only a second click ever stuck (founder
// bug report 2026-10-14: tapping an institution did nothing).
func (s *Service) SetDesk(ctx context.Context, userID, itype, department string) error {
        itype = strings.TrimSpace(itype)
        department = strings.TrimSpace(department)
        valid := false
        for _, k := range DeskInstitutions {
                if k == itype {
                        valid = true
                        break
                }
        }
        if !valid {
                return &ValidationError{Msg: "unknown institution kind"}
        }
        if department != "" {
                var n int
                if err := s.Pool.QueryRow(ctx,
                        `SELECT COUNT(*) FROM learn.departments WHERE dept_id=$1 AND itype=$2`,
                        department, itype).Scan(&n); err != nil {
                        return err
                }
                if n == 0 {
                        return &ValidationError{Msg: "department does not belong to that institution kind"}
                }
        }
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return err
        }
        _, err := s.Pool.Exec(ctx,
                `UPDATE learn.learners SET institution_type=$2, department=$3 WHERE user_id=$1`,
                userID, itype, department)
        return err
}

// ─── Catalog rows ─────────────────────────────────────────────────────────

// DeskCourse is one course row on the desk shelf / search results.
type DeskCourse struct {
        ID         string `json:"id"`
        Code       string `json:"code"` // short dept code badge, no numbers
        Title      string `json:"title"`
        Department string `json:"department"`
        TopicCount int    `json:"topicCount"`
        InList     bool   `json:"inList"`
}

// deskCode strips the course code down to its leading letters
// ("CS 101" -> "CS", "BS(Z 101" -> "BSZ") - the badge students search
// with. The founder: the three letters are enough, no numbers.
func deskCode(code string) string {
        var b strings.Builder
        for _, r := range strings.ToUpper(strings.TrimSpace(code)) {
                if unicode.IsLetter(r) {
                        b.WriteRune(r)
                        if b.Len() >= 4 {
                                break
                        }
                } else if b.Len() > 0 {
                        break // stop at the number / separator
                }
        }
        return b.String()
}

// codeAliases maps the street code students type onto the catalogue's
// real department prefixes (the NUC-style codes versus the master
// sheet's per-department prefixes). Founder: "all computer sciences
// course can also be searched with CSC or COS, Mathematics MTS, MTH".
var codeAliases = map[string][]string{
        "CSC": {"CS"}, "COS": {"CS"}, "CMP": {"CS"}, "CS": {"CSC", "COS"},
        "MTH": {"M"}, "MTS": {"M"}, "MAT": {"M"},
        "CHM": {"C"}, "CHE": {"C"},
        "PHY": {"P"},
        "BIO": {"BSZ", "BS", "BCH", "MCB"},
        "GLG": {"G"},
        "STA": {"S"},
}

// aliasFor returns the canonical prefixes an entered code also matches.
func aliasFor(code string) []string { return codeAliases[strings.ToUpper(code)] }

// codeDeptHints are the department-name fragments the typed code is
// LOOKING for. The master sheet codes Computer Science "CS" - the same
// letters Chinese Studies carries - so a student typing CSC must not
// get a wall of Mandarin courses: CS-code rows whose department smells
// of computers outrank the rest. Same idea for MTS/MTH (mathematics),
// CHM (chemistry), PHY (physics), BIO (the bio family).
var codeDeptHints = map[string][]string{
        "CSC": {"computer science", "computer engineering", "informatics", "computer"},
        "COS": {"computer science", "computer engineering", "informatics", "computer"},
        "CMP": {"computer science", "computer engineering", "informatics", "computer"},
        "CS":  {"computer science", "computer engineering", "informatics", "computer"},
        "MTH": {"mathematic"},
        "MTS": {"mathematic"},
        "MAT": {"mathematic"},
        "CHM": {"chem"},
        "CHE": {"chem"},
        "PHY": {"physic"},
        "BIO": {"biolog", "biochem", "microbiol", "plant", "zool"},
        "GLG": {"geolog"},
        "STA": {"statistic"},
}

// generalTitleRxSQL is the national first-year general shelf, as a
// Postgres case-insensitive regex over the course title (the set the
// founder asked us to research: GST/GNS English, Nigerian Peoples &
// Culture, Logic & Philosophy, ICT basics, the general sciences and
// mathematics). The shelf lists ONLY these.
const generalTitleRxSQL = `^(general (biology|chemistry|physics|mathematics)|elementary mathematics|use of english|nigerian peoples & cultures?|introduction to logic & philosophy|information (&|and) communication technology|peace ?(&|and) conflict resolution|entrepreneurship|citizenship education|the good study guide|history (&|and) philosophy of science)`

// firstYearLevel is the first-year level tag per institution kind.
func firstYearLevel(itype string) string {
        switch itype {
        case "Polytechnic":
                return "ND I"
        case "College of Education":
                return "NCE I"
        default:
                return "100 Level"
        }
}

// deskCourseSelect is CONTENT-ONLY (the split-horizon router keeps
// learn.courses/departments/topics on the content database, while
// learn.user_courses lives on the user database) - the InList flag
// fills afterwards through fillDeskInList over the page's course ids.
const deskCourseSelect = `
        c.course_id, c.code, c.title, d.name,
        (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id)`

func scanDeskCourse(rows interface {
        Scan(...any) error
}) (DeskCourse, error) {
        var c DeskCourse
        if err := rows.Scan(&c.ID, &c.Code, &c.Title, &c.Department, &c.TopicCount); err != nil {
                return c, err
        }
        c.Code = deskCode(c.Code)
        return c, nil
}

// fillDeskInList flags the courses already on the student's list
// (the user-side half of the old deskCourseSelect join).
func (s *Service) fillDeskInList(ctx context.Context, userID string, items []DeskCourse) {
        if len(items) == 0 {
                return
        }
        ids := make([]string, len(items))
        for i, c := range items {
                ids[i] = c.ID
        }
        set, err := s.enrolledSet(ctx, userID, ids)
        if err != nil {
                return
        }
        for i := range items {
                items[i].InList = set[items[i].ID]
        }
}

// ─── The desk shelves ─────────────────────────────────────────────────────

// DeskShelves is the tertiary desk payload: the national general
// courses first, then the department's own courses.
type DeskShelves struct {
        InstitutionType string       `json:"institutionType"`
        Department      string       `json:"department"`
        DepartmentName  string       `json:"departmentName"`
        General         []DeskCourse `json:"general"`
        Departmental    []DeskCourse `json:"departmental"`
}

// CourseDesk assembles the two shelves for the student's saved desk.
// The general shelf dedupes the cross-department general courses to one
// row each (the copy with the most topics wins), GST suite first.
func (s *Service) CourseDesk(ctx context.Context, userID string) (*DeskShelves, error) {
        // A brand-new scholar has no learn.learners row yet - materialize
        // it (signup-time lazy init, same as /learn/profile) and treat a
        // still-missing row as an empty desk, never a 500. Founder bug
        // 2026-10-17: the first course-desk visit after signup answered
        // "no rows in result set".
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        var itype, dept string
        if err := s.Pool.QueryRow(ctx,
                `SELECT institution_type, department FROM learn.learners WHERE user_id=$1`, userID).
                Scan(&itype, &dept); err != nil {
                if errors.Is(err, pgx.ErrNoRows) {
                        return &DeskShelves{General: []DeskCourse{}, Departmental: []DeskCourse{}}, nil
                }
                return nil, err
        }
        shelf := &DeskShelves{InstitutionType: itype, Department: dept,
                General: []DeskCourse{}, Departmental: []DeskCourse{}}
        if dept != "" {
                _ = s.Pool.QueryRow(ctx, `SELECT name FROM learn.departments WHERE dept_id=$1`, dept).
                        Scan(&shelf.DepartmentName)
        }

        // General shelf: GST suite first, then the cross-department
        // general titles at the first-year level of the student's
        // institution kind. The query orders the richest copy first and
        // Go dedupes near-identical titles ("...Cultures" vs "...Culture")
        // to one row each - the copy with the most topics wins.
        rows, err := s.Pool.Query(ctx, `
                SELECT `+deskCourseSelect+`
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary' AND c.title <> ''
                  AND ( c.course_id LIKE 'GST %'
                     OR (c.level = $1 AND c.title ~* $2) )
                ORDER BY c.title,
                         (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id) DESC`,
                firstYearLevel(itype), generalTitleRxSQL)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        seenTitle := map[string]bool{}
        for rows.Next() {
                c, err := scanDeskCourse(rows)
                if err != nil {
                        return nil, err
                }
                key := generalKey(c.Title)
                if seenTitle[key] {
                        continue
                }
                seenTitle[key] = true
                shelf.General = append(shelf.General, c)
        }
        if err := rows.Err(); err != nil {
                return nil, err
        }
        sort.SliceStable(shelf.General, func(i, j int) bool {
                pi := strings.HasPrefix(shelf.General[i].ID, "GST ")
                pj := strings.HasPrefix(shelf.General[j].ID, "GST ")
                if pi != pj {
                        return pi // the GST suite leads the shelf
                }
                return shelf.General[i].Title < shelf.General[j].Title
        })
        s.fillDeskInList(ctx, userID, shelf.General)

        // Department shelf: the department's own courses, code order.
        if dept != "" {
                drows, err := s.Pool.Query(ctx, `
                        SELECT `+deskCourseSelect+`
                        FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                        WHERE c.dept_id = $1
                        ORDER BY c.code, c.title`, dept)
                if err != nil {
                        return nil, err
                }
                defer drows.Close()
                for drows.Next() {
                        c, err := scanDeskCourse(drows)
                        if err != nil {
                                return nil, err
                        }
                        shelf.Departmental = append(shelf.Departmental, c)
                }
                if err := drows.Err(); err != nil {
                        return nil, err
                }
                s.fillDeskInList(ctx, userID, shelf.Departmental)
        }
        return shelf, nil
}

// ─── The borrowed-course pages ────────────────────────────────────────────

// OthersCourses serves the REST of the catalogue the two shelves do
// not show: every tertiary course outside the student's department
// that is not on the national general shelf. Founder directive
// 2026-10-15: schools borrow courses across departments, so after the
// department shelf the desk must offer the remaining ~10,000 courses
// too. They ride in pages (LIMIT/OFFSET) so a phone never downloads
// the whole tree at once; the full catalogue stays reachable through
// the Show-more pager and the search bar up top.
func (s *Service) OthersCourses(ctx context.Context, userID string, offset, limit int) ([]DeskCourse, int, error) {
        if limit <= 0 {
                limit = 100
        }
        if limit > 200 {
                limit = 200
        }
        if offset < 0 {
                offset = 0
        }
        // A brand-new scholar has no learn.learners row yet - materialize
        // it (the same lazy init CourseDesk does) so the desk read below
        // never answers "no rows in result set" - a 500 the borrowed-page
        // client swallows into an empty list. Founder bug 2026-10-22.
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, 0, err
        }
        var itype, dept string
        if err := s.Pool.QueryRow(ctx,
                `SELECT institution_type, department FROM learn.learners WHERE user_id=$1`, userID).
                Scan(&itype, &dept); err != nil {
                return nil, 0, err
        }
        // The same exclusion the general shelf applies, so no course
        // ever appears on both: the GST suite plus the general
        // first-year titles at the student's institution level.
        // Everything else outside the student's own department rides
        // the borrowed pages, richest home department first. The count
        // query carries its OWN gapless $1..$3 (dept, level, rx) - the
        // page query numbers $1..$6 (the select embeds $1 = userID) -
        // a placeholder gap makes pgx refuse the statement.
        where := `
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary' AND c.title <> ''
                  AND ($2 = '' OR c.dept_id <> $2)
                  AND NOT ( c.course_id LIKE 'GST %'
                         OR (c.level = $3 AND c.title ~* $4) )`
        countWhere := `
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary' AND c.title <> ''
                  AND ($1 = '' OR c.dept_id <> $1)
                  AND NOT ( c.course_id LIKE 'GST %'
                         OR (c.level = $2 AND c.title ~* $3) )`
        var total int
        if err := s.Pool.QueryRow(ctx,
                `SELECT COUNT(*) `+countWhere,
                dept, firstYearLevel(itype), generalTitleRxSQL).Scan(&total); err != nil {
                return nil, 0, err
        }
        rows, err := s.Pool.Query(ctx, `
                SELECT `+deskCourseSelect+where+`
                ORDER BY d.name, c.code, c.title
                LIMIT $4 OFFSET $5`,
                dept, firstYearLevel(itype), generalTitleRxSQL, limit, offset)
        if err != nil {
                return nil, 0, err
        }
        defer rows.Close()
        items := []DeskCourse{}
        for rows.Next() {
                c, err := scanDeskCourse(rows)
                if err != nil {
                        return nil, 0, err
                }
                items = append(items, c)
        }
        if err := rows.Err(); err != nil {
                return nil, 0, err
        }
        s.fillDeskInList(ctx, userID, items)
        return items, total, nil
}

// ─── Search ───────────────────────────────────────────────────────────────

// SearchCourses matches the tertiary tree by short code (with street
// aliases), title fragment, or key-topic title / keyword. Real rows
// only, capped for the picker UI. Exact-code matches always rank above
// alias matches (typing CSC must surface Computer Science, not every
// "CS" Chinese Studies course the alias sweep drags in), then title
// and topic matches.
func (s *Service) SearchCourses(ctx context.Context, userID, q string) ([]DeskCourse, error) {
        q = strings.TrimSpace(q)
        if q == "" {
                return []DeskCourse{}, nil
        }
        var args []any
        arg := func(v any) string {
                args = append(args, v)
                return fmt.Sprintf("$%d", len(args))
        }
        // The select is content-only now; InList fills via fillDeskInList
        // after the rank pass (the old $1 was the user_courses EXISTS).

        frag := arg("%" + q + "%")
        conds := []string{
                fmt.Sprintf(`c.title ILIKE %s`, frag),
                fmt.Sprintf(`EXISTS (SELECT 1 FROM learn.topics t WHERE t.course_id = c.course_id
                         AND (t.title ILIKE %s OR EXISTS (SELECT 1 FROM unnest(t.keywords) k WHERE k ILIKE %s)))`, frag, frag),
        }
        codes := append([]string{q}, aliasFor(q)...)
        rankCode := strings.ToUpper(q)
        var aliasCodes []string
        for _, code := range codes {
                code = strings.ToUpper(strings.TrimSpace(code))
                if len(code) < 1 || len(code) > 4 || !isLetters(code) {
                        continue
                }
                conds = append(conds,
                        fmt.Sprintf(`(upper(regexp_replace(c.code, '[^A-Za-z].*', '')) = %s)`, arg(code)))
                if code == rankCode {
                        continue // rank 0
                }
                aliasCodes = append(aliasCodes, code)
        }
        sql := `
                SELECT DISTINCT ON (c.course_id) ` + deskCourseSelect + `
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary' AND c.title <> '' AND ( ` + strings.Join(conds, " OR ") + ` )
                ORDER BY c.course_id, c.title LIMIT 160`
        rows, err := s.Pool.Query(ctx, sql, args...)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        out := []DeskCourse{}
        for rows.Next() {
                c, err := scanDeskCourse(rows)
                if err != nil {
                        return nil, err
                }
                out = append(out, c)
        }
        if err := rows.Err(); err != nil {
                return nil, err
        }
        // Rank: the typed code (in its department) beats its aliases
        // beats title/topic hits, title order inside each band, capped
        // for the picker. The department hint is what makes CSC honest:
        // the sheet codes Computer Science "CS" - exactly what Chinese
        // Studies carries - so code matches in departments the code is
        // LOOKING for outrank the strangers sharing the letters.
        hints := codeDeptHints[rankCode]
        hintFor := func(code string) []string {
                if code == rankCode {
                        return hints
                }
                for _, a := range aliasCodes {
                        if code == a {
                                return codeDeptHints[a]
                        }
                }
                return nil
        }
        rank := func(c DeskCourse) int {
                dept := strings.ToLower(c.Department)
                hinted := func() bool {
                        for _, h := range hintFor(c.Code) {
                                if strings.Contains(dept, h) {
                                        return true
                                }
                        }
                        return false
                }
                if c.Code == rankCode {
                        if len(hints) == 0 || hinted() {
                                return 0
                        }
                        return 1
                }
                for _, a := range aliasCodes {
                        if c.Code == a {
                                if len(codeDeptHints[a]) == 0 || hinted() {
                                        return 2
                                }
                                return 3
                        }
                }
                return 4
        }
        sort.SliceStable(out, func(i, j int) bool {
                ri, rj := rank(out[i]), rank(out[j])
                if ri != rj {
                        return ri < rj
                }
                return out[i].Title < out[j].Title
        })
        if len(out) > 40 {
                out = out[:40]
        }
        // Topic-level arms, ONLY when the course-level sweep came back
        // thin: the old single query probed learn.topics with a
        // correlated EXISTS per course (10.7k probes into 1.6M topic
        // rows) - 11-18s per search, and the AI finder ran it once per
        // pasted line. The CTE below hits the trigram indexes ONCE
        // (titles + the flattened keyword array) and costs ~0.7s; a
        // 6s deadline keeps even a cold plan cache from hanging the
        // request, and a timeout just returns the title/code matches.
        if len(out) < 8 {
                tctx, cancel := context.WithTimeout(ctx, 6*time.Second)
                seen := make(map[string]bool, len(out))
                for _, c := range out {
                        seen[c.ID] = true
                }
                rows2, err := s.Pool.Query(tctx, `
                        WITH t_hit AS (
                            SELECT DISTINCT t.course_id FROM learn.topics t
                            WHERE t.title ILIKE $1 OR learn.kw_flat(t.keywords) ILIKE $1
                        )
                        SELECT DISTINCT ON (c.course_id) `+deskCourseSelect+`
                        FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                        JOIN t_hit h ON h.course_id = c.course_id
                        WHERE c.body = 'tertiary' AND c.title <> ''
                        ORDER BY c.course_id, c.title LIMIT 40`, "%"+q+"%", "%"+q+"%")
                if err != nil {
                        cancel()
                        // Deadline/timeout keeps the title matches; a real
                        // DB failure surfaces.
                        if errors.Is(err, context.DeadlineExceeded) || tctx.Err() != nil {
                                s.fillDeskInList(ctx, userID, out)
                                return out, nil
                        }
                        return nil, err
                }
                defer rows2.Close()
                for rows2.Next() {
                        c, err := scanDeskCourse(rows2)
                        if err != nil {
                                cancel()
                                return nil, err
                        }
                        if !seen[c.ID] {
                                seen[c.ID] = true
                                out = append(out, c)
                        }
                }
                if err := rows2.Err(); err != nil {
                        cancel()
                        return nil, err
                }
                cancel()
        }
        s.fillDeskInList(ctx, userID, out)
        return out, nil
}

func isLetters(s string) bool {
        if s == "" {
                return false
        }
        for _, r := range s {
                if !unicode.IsLetter(r) {
                        return false
                }
        }
        return true
}

// generalKey normalises a general-course title for dedupe: lowercased,
// punctuation collapsed, plural trimmed - "Nigerian Peoples & Cultures"
// and "Nigerian Peoples & Culture" share one shelf row.
func generalKey(title string) string {
        var b strings.Builder
        lastSpace := false
        for _, r := range strings.ToLower(title) {
                if unicode.IsLetter(r) || unicode.IsDigit(r) {
                        b.WriteRune(r)
                        lastSpace = false
                } else if !lastSpace {
                        b.WriteRune(' ')
                        lastSpace = true
                }
        }
        return strings.TrimSuffix(strings.TrimSpace(b.String()), "s")
}

// ─── AI course finder ─────────────────────────────────────────────────────

// fuzzyStopWords are the glue words no title match needs.
var fuzzyStopWords = map[string]bool{
        "and": true, "or": true, "of": true, "to": true, "the": true,
        "in": true, "for": true, "with": true, "a": true, "an": true, "on": true,
}

// romanNumerals are the registration-slip section suffixes ("Linear
// Algebra I", "Elementary Differential Equation II") - markers, not
// subject words, so they never drive a match.
var romanNumerals = map[string]bool{
        "i": true, "ii": true, "iii": true, "iv": true, "v": true,
        "vi": true, "vii": true, "viii": true, "ix": true, "x": true,
        "xi": true, "xii": true,
}

// splitTitleWords breaks a lowercased line into its letter/number words.
func splitTitleWords(s string) []string {
        return strings.FieldsFunc(s, func(r rune) bool {
                return !unicode.IsLetter(r) && !unicode.IsDigit(r)
        })
}

// fuzzyTokens reduces a pasted course line to the significant words the
// catalogue sweep should look for: parenthetical qualifiers dropped
// ("General Agriculture (Theory)"), glue words and roman-numeral
// section markers dropped, capped at four words. "Mathematical Methods
// I" -> [mathematical methods]; "Computer Programming I" -> [computer
// programming].
func fuzzyTokens(line string) []string {
        s := strings.ToLower(line)
        if i := strings.IndexByte(s, '('); i >= 0 {
                if j := strings.IndexByte(s[i:], ')'); j > 0 {
                        s = s[:i] + " " + s[i+j+1:]
                }
        }
        var out []string
        for _, f := range splitTitleWords(s) {
                if len(f) < 4 || fuzzyStopWords[f] || romanNumerals[f] {
                        continue
                }
                out = append(out, f)
                if len(out) >= 4 {
                        break
                }
        }
        return out
}

// fuzzyKey canonicalises a title for the deterministic pick: lowercase,
// parentheticals dropped, punctuation to spaces, glue words and roman
// numerals dropped, the trailing plural "s" trimmed per word - so
// "Elementary Differential Equation I" and "Elementary Differential
// Equations" land on the same key, and a pasted line whose title only
// differs by those crumbs still picks without the AI pass.
func fuzzyKey(line string) string {
        s := strings.ToLower(line)
        if i := strings.IndexByte(s, '('); i >= 0 {
                if j := strings.IndexByte(s[i:], ')'); j > 0 {
                        s = s[:i] + " " + s[i+j+1:]
                }
        }
        var b strings.Builder
        for _, f := range splitTitleWords(s) {
                if len(f) < 2 || fuzzyStopWords[f] || romanNumerals[f] {
                        continue
                }
                b.WriteString(strings.TrimSuffix(f, "s"))
                b.WriteByte(' ')
        }
        return strings.TrimSpace(b.String())
}

// fuzzyTitleCourses is the AI finder's safety net: the honest search
// answers nothing when the pasted title is a near-miss ("Mathematical
// Methods I" against the catalogue's "Mathematical Methods") - and the
// AI can only choose among candidates that EXIST. The line's
// significant words sweep the whole tertiary catalogue (schools borrow
// across departments), and SQL ranks the sweep: titles carrying MORE
// of the line's words first, then the LEANEST title (fewest extra
// words - "General Agriculture" outruns "General Chemistry for
// Agriculture"), then the richest copy. Ranking inside the query (not
// after a LIMIT) is what lets the lone real "General Agriculture" row
// surface past hundreds of "General ... for Agriculture" copies.
func (s *Service) fuzzyTitleCourses(ctx context.Context, userID, line string) ([]DeskCourse, error) {
        tokens := fuzzyTokens(line)
        if len(tokens) == 0 {
                return []DeskCourse{}, nil
        }
        var args []any
        arg := func(v any) string {
                args = append(args, v)
                return fmt.Sprintf("$%d", len(args))
        }
        // The select is content-only; InList fills via fillDeskInList.
        likes := make([]string, 0, len(tokens))
        cases := make([]string, 0, len(tokens))
        for _, t := range tokens {
                ph := arg("%" + t + "%")
                likes = append(likes, fmt.Sprintf("c.title ILIKE %s", ph))
                cases = append(cases, fmt.Sprintf("CASE WHEN c.title ILIKE %s THEN 1 ELSE 0 END", ph))
        }
        // Gapless $1..$n: the select embeds $1, the token cases continue it.
        // The coverage score rides as the 7th column; topicCount is the 5th
        // select column, so the tie-break orders by ordinal. Rows dedupe by
        // title in Go (the same course title is seeded per department) and
        // the AI shelf takes the top dozen.
        rows, err := s.Pool.Query(ctx, `
                SELECT `+deskCourseSelect+`, (`+strings.Join(cases, " + ")+`) AS cov
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary' AND c.title <> '' AND (`+strings.Join(likes, " OR ")+`)
                ORDER BY cov DESC, char_length(c.title) ASC, 5 DESC, c.course_id
                LIMIT 30`, args...)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        seen := map[string]bool{}
        out := []DeskCourse{}
        for rows.Next() {
                var c DeskCourse
                var cov int
                if err := rows.Scan(&c.ID, &c.Code, &c.Title, &c.Department, &c.TopicCount, &cov); err != nil {
                        return nil, err
                }
                c.Code = deskCode(c.Code)
                if seen[c.Title] {
                        continue
                }
                seen[c.Title] = true
                out = append(out, c)
                if len(out) >= 12 {
                        break
                }
        }
        if err := rows.Err(); err != nil {
                return nil, err
        }
        s.fillDeskInList(ctx, userID, out)
        return out, nil
}

// AIMatchRequest is the "Find my courses with AI" payload: the student
// pastes every course title on their registration slip.
type AIMatchRequest struct {
        Text string `json:"text"`
}

// AIMatchLine is one pasted line and what the matcher found for it.
type AIMatchLine struct {
        Input   string       `json:"input"`
        Matches []DeskCourse `json:"matches"`
        Picked  string       `json:"picked,omitempty"` // the chosen course id
}

// AIMatchCourses grounds the AI in the real catalogue: every pasted
// line first pulls its top candidates from the DB (code / title /
// topic search), then one AI pass picks the best row per line. Nothing
// the AI invents can enter the result - ids must exist among the
// fetched candidates, so the setup list stays 100% real data.
func (s *Service) AIMatchCourses(ctx context.Context, userID, text string) ([]AIMatchLine, error) {
        lines := splitCourseLines(text)
        if len(lines) == 0 {
                return []AIMatchLine{}, nil
        }
        if len(lines) > 40 {
                lines = lines[:40]
        }
        // Shared sweep budget (founder report 2026-10-17: "find my
        // courses is not working"): seven lines used to cost seven full
        // topic probes (30s+ each) BEFORE the AI pass - the frontend's
        // 45s guard aborted first and the finder read as dead. After
        // the trigram indexes + the gated CTE the sweeps are fast, but
        // the budget is the honest guarantee: 20s of grounding, then
        // remaining lines simply answer from what the AI still gets.
        budget, cancel := context.WithTimeout(ctx, 20*time.Second)
        defer cancel()
        out := make([]AIMatchLine, 0, len(lines))
        candidates := map[string]bool{}
        for _, line := range lines {
                matches, err := s.SearchCourses(budget, userID, line)
                if err != nil {
                        if errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil {
                                matches = []DeskCourse{} // the budget, not the catalogue, is out
                        } else {
                                return nil, err
                        }
                }
                if matches == nil {
                        matches = []DeskCourse{}
                }
                // Near-miss titles (founder 2026-10-15: "if the AI doesn't
                // find the exact course title for some courses make sure
                // the ai find course title that are same as the one
                // entered"): when the honest search came back thin, sweep
                // the catalogue for titles built from the same significant
                // words - "Mathematical Methods I" must reach the
                // catalogue's "Mathematical Methods" - so the AI shelf
                // holds real candidates for every line. The merge is
                // capped so forty lines cannot blow the AI shelf up.
                if len(matches) < 3 {
                        if fuzzy, ferr := s.fuzzyTitleCourses(ctx, userID, line); ferr == nil {
                                seen := make(map[string]bool, len(matches))
                                for _, m := range matches {
                                        seen[m.ID] = true
                                }
                                added := 0
                                for _, f := range fuzzy {
                                        if added >= 12 {
                                                break
                                        }
                                        if !seen[f.ID] {
                                                matches = append(matches, f)
                                                seen[f.ID] = true
                                                added++
                                        }
                                }
                        }
                }
                for _, m := range matches {
                        candidates[m.ID] = true
                }
                out = append(out, AIMatchLine{Input: line, Matches: matches})
        }
        // Deterministic picks first: an exact title hit needs no AI -
        // and neither does a canonical match, both sides normalised
        // through fuzzyKey ("...Equation I" vs "...Equations", "General
        // Agriculture (Theory)" vs "General Agriculture").
        for i := range out {
                key := fuzzyKey(out[i].Input)
                for _, m := range out[i].Matches {
                        if strings.EqualFold(m.Title, out[i].Input) || (key != "" && fuzzyKey(m.Title) == key) {
                                out[i].Picked = m.ID
                                break
                        }
                }
        }

        // One AI pass over the unresolved lines with the candidate shelf.
        if s.Engine != nil && s.Engine.AI != nil {
                var unresolved []int
                for i := range out {
                        if out[i].Picked == "" {
                                unresolved = append(unresolved, i)
                        }
                }
                if len(unresolved) > 0 {
                        ids := make([]string, 0, len(candidates))
                        for id := range candidates {
                                ids = append(ids, id)
                        }
                        sort.Strings(ids)
                        titles, err := s.titlesFor(ctx, ids)
                        if err == nil && len(titles) > 0 {
                                var b strings.Builder
                                for i, idx := range unresolved {
                                        fmt.Fprintf(&b, "%d. %s\n", i+1, out[idx].Input)
                                }
                                shelf, _ := json.Marshal(titles)
                                prompt := fmt.Sprintf(
                                        "Each numbered line is a course a Nigerian student must register. Below is the ONLY catalogue allowed (id = title). For every line choose the single best catalogue id, or NONE when no row matches. A catalogue row counts even when its title differs a little from the line (roman numerals, plurals, extra qualifiers) as long as it covers the SAME subject content. Reply with one line per input, exactly \"<number>: <id-or-NONE>\".\n\nLINES:\n%s\nCATALOGUE (JSON):\n%s",
                                        b.String(), shelf)
                                // The AI pass gets its own 15s ceiling: a slow
                                // provider must never outlive the frontend's
                                // 45s guard (20s sweep budget + 15s here fits).
                                actx, acancel := context.WithTimeout(ctx, 15*time.Second)
                                reply, err := s.Engine.AI.Complete(actx, aiMatchSystem,
                                        []tutor.Message{{Role: "user", Content: prompt}}, 1600)
                                acancel()
                                if err == nil {
                                        applyAIPicks(out, unresolved, reply, candidates)
                                }
                        }
                }
        }
        return out, nil
}

// titlesFor loads id = title rows for the AI shelf (real rows only).
func (s *Service) titlesFor(ctx context.Context, ids []string) ([]map[string]string, error) {
        rows, err := s.Pool.Query(ctx, `
                SELECT c.course_id, c.title || ' (' || d.name || ')'
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.course_id = ANY($1) ORDER BY c.course_id`, ids)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        var out []map[string]string
        for rows.Next() {
                var id, title string
                if err := rows.Scan(&id, &title); err != nil {
                        return nil, err
                }
                out = append(out, map[string]string{"id": id, "title": title})
        }
        return out, rows.Err()
}

const aiMatchSystem = `You map Nigerian university course names to an exact catalogue. You answer ONLY in the requested line format with ids from the catalogue - never invent ids.`

// applyAIPicks parses the "<n>: <id>" reply and fills the picks whose
// ids actually exist among the fetched candidates.
func applyAIPicks(out []AIMatchLine, unresolved []int, reply string, candidates map[string]bool) {
        for _, line := range strings.Split(reply, "\n") {
                line = strings.TrimSpace(line)
                parts := strings.SplitN(line, ":", 2)
                if len(parts) != 2 {
                        continue
                }
                var n int
                if _, err := fmt.Sscanf(strings.TrimSpace(parts[0]), "%d", &n); err != nil || n < 1 || n > len(unresolved) {
                        continue
                }
                id := strings.TrimSpace(parts[1])
                if id == "" || strings.EqualFold(id, "NONE") {
                        continue
                }
                idx := unresolved[n-1]
                if candidates[id] && out[idx].Picked == "" {
                        out[idx].Picked = id
                }
        }
}

// splitCourseLines breaks the pasted block into course lines.
func splitCourseLines(text string) []string {
        fields := strings.FieldsFunc(text, func(r rune) bool {
                return r == '\n' || r == ';' || r == ','
        })
        var out []string
        seen := map[string]bool{}
        for _, f := range fields {
                f = strings.TrimSpace(f)
                f = strings.Trim(f, "•-\t")
                if len(f) < 3 || len(f) > 120 {
                        continue
                }
                lower := strings.ToLower(f)
                if seen[lower] {
                        continue
                }
                seen[lower] = true
                out = append(out, f)
        }
        return out
}
