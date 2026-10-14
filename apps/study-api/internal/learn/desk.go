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
	"fmt"
	"sort"
	"strings"
	"unicode"

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

// SetDesk saves the student's institution kind + department on the
// learner row. The department must exist and belong to the institution
// kind, so a stale client can never park a student in a mismatched desk.
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
		return fmt.Errorf("unknown institution kind")
	}
	if department != "" {
		var n int
		if err := s.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM learn.departments WHERE dept_id=$1 AND itype=$2`,
			department, itype).Scan(&n); err != nil {
			return err
		}
		if n == 0 {
			return fmt.Errorf("department does not belong to that institution kind")
		}
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

const deskCourseSelect = `
        c.course_id, c.code, c.title, d.name,
        (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id),
        EXISTS (SELECT 1 FROM learn.user_courses uc WHERE uc.user_id = $1 AND uc.course_id = c.course_id)`

func scanDeskCourse(rows interface {
	Scan(...any) error
}) (DeskCourse, error) {
	var c DeskCourse
	if err := rows.Scan(&c.ID, &c.Code, &c.Title, &c.Department, &c.TopicCount, &c.InList); err != nil {
		return c, err
	}
	c.Code = deskCode(c.Code)
	return c, nil
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
	var itype, dept string
	if err := s.Pool.QueryRow(ctx,
		`SELECT institution_type, department FROM learn.learners WHERE user_id=$1`, userID).
		Scan(&itype, &dept); err != nil {
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
                     OR (c.level = $2 AND c.title ~* $3) )
                ORDER BY c.title,
                         (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id) DESC`,
		userID, firstYearLevel(itype), generalTitleRxSQL)
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

	// Department shelf: the department's own courses, code order.
	if dept != "" {
		drows, err := s.Pool.Query(ctx, `
                        SELECT `+deskCourseSelect+`
                        FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                        WHERE c.dept_id = $2
                        ORDER BY c.code, c.title`, userID, dept)
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
	}
	return shelf, nil
}

// ─── Search ───────────────────────────────────────────────────────────────

// SearchCourses matches the tertiary tree by short code (with street
// aliases), title fragment, or key-topic title / keyword. Real rows
// only, capped for the picker UI.
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
	args = append(args, userID) // $1 - the deskCourseSelect userID

	frag := arg("%" + q + "%")
	conds := []string{
		fmt.Sprintf(`c.title ILIKE %s`, frag),
		fmt.Sprintf(`EXISTS (SELECT 1 FROM learn.topics t WHERE t.course_id = c.course_id
                         AND (t.title ILIKE %s OR EXISTS (SELECT 1 FROM unnest(t.keywords) k WHERE k ILIKE %s)))`, frag, frag),
	}
	codes := append([]string{q}, aliasFor(q)...)
	for _, code := range codes {
		code = strings.ToUpper(strings.TrimSpace(code))
		if len(code) < 1 || len(code) > 4 || !isLetters(code) {
			continue
		}
		conds = append(conds,
			fmt.Sprintf(`(upper(regexp_replace(c.code, '[^A-Za-z].*', '')) = %s)`, arg(code)))
	}
	sql := `
                SELECT DISTINCT ON (c.course_id) ` + deskCourseSelect + `
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary' AND c.title <> '' AND ( ` + strings.Join(conds, " OR ") + ` )
                ORDER BY c.course_id, c.title LIMIT 40`
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
	return out, rows.Err()
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
	out := make([]AIMatchLine, 0, len(lines))
	candidates := map[string]bool{}
	for _, line := range lines {
		matches, err := s.SearchCourses(ctx, userID, line)
		if err != nil {
			return nil, err
		}
		if matches == nil {
			matches = []DeskCourse{}
		}
		for _, m := range matches {
			candidates[m.ID] = true
		}
		out = append(out, AIMatchLine{Input: line, Matches: matches})
	}
	// Deterministic picks first: an exact title hit needs no AI.
	for i := range out {
		for _, m := range out[i].Matches {
			if strings.EqualFold(m.Title, out[i].Input) {
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
					"Each numbered line is a course a Nigerian student must register. Below is the ONLY catalogue allowed (id = title). For every line choose the single best catalogue id, or NONE when no row matches. Reply with one line per input, exactly \"<number>: <id-or-NONE>\".\n\nLINES:\n%s\nCATALOGUE (JSON):\n%s",
					b.String(), shelf)
				if reply, err := s.Engine.AI.Complete(ctx, aiMatchSystem,
					[]tutor.Message{{Role: "user", Content: prompt}}, 1600); err == nil {
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
