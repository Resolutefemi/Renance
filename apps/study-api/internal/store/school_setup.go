// School setup + people + attendance SQL: school profile (logo),
// subject departments, per-student subject offering, attendance rows
// and the bulk topic import the web scraper pours through. Doctrine
// mirrors school.go: everything through this file, simple protocol
// safe, no hand-ALTERs.
package store

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
)

// ------------------------------------------------------------ profile

// UpdateSchoolProfile edits the school row itself: display name,
// address and the logo (a data URL or an https URL). Empty strings
// leave the column untouched.
func (s *Store) UpdateSchoolProfile(ctx context.Context, schoolID, name, address, logoURL string) error {
	sets := []string{}
	args := []any{}
	arg := func(v, col string) {
		args = append(args, v)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	if name != "" {
		arg(name, "name")
	}
	if address != "" {
		arg(address, "address")
	}
	if logoURL != "" {
		arg(logoURL, "logo_url")
	}
	if len(sets) == 0 {
		return nil
	}
	args = append(args, schoolID)
	_, err := s.Pool.Exec(ctx,
		"UPDATE school.schools SET "+strings.Join(sets, ", ")+" WHERE id = $"+fmt.Sprint(len(args)),
		args...)
	return err
}

// ----------------------------------------------------------- subjects

// CreateSubject adds a school-owned subject (NERDC name or a custom
// one), with its senior-band department and core flag.
func (s *Store) CreateSubject(ctx context.Context, schoolID, name, code, level, department string, isCore bool) (*SchoolSubject, error) {
	row := s.Pool.QueryRow(ctx, `
                INSERT INTO school.subjects (school_id, name, code, level, department, is_core)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (school_id, name) DO UPDATE SET
                  code = EXCLUDED.code, level = EXCLUDED.level,
                  department = EXCLUDED.department, is_core = EXCLUDED.is_core
                RETURNING id, name, code, level, seq, department, is_core`,
		schoolID, name, code, level, department, isCore)
	return scanSubject(row)
}

// UpdateSubject edits department / core / name / code on a subject.
func (s *Store) UpdateSubject(ctx context.Context, subjectID, name, code, department string, isCore *bool) error {
	sets := []string{}
	args := []any{}
	arg := func(v any, col string) {
		args = append(args, v)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	if name != "" {
		arg(name, "name")
	}
	if code != "" {
		arg(code, "code")
	}
	if department != "" {
		arg(department, "department")
	}
	if isCore != nil {
		arg(*isCore, "is_core")
	}
	if len(sets) == 0 {
		return nil
	}
	args = append(args, subjectID)
	_, err := s.Pool.Exec(ctx,
		"UPDATE school.subjects SET "+strings.Join(sets, ", ")+" WHERE id = $"+fmt.Sprint(len(args)),
		args...)
	return err
}

// AddClassSubject wires a subject into a class (after checking both
// belong to the school). RemoveClassSubject unwires it.
func (s *Store) AddClassSubject(ctx context.Context, schoolID, classID, subjectID string) error {
	tag, err := s.Pool.Exec(ctx, `
                INSERT INTO school.class_subjects (class_id, subject_id)
                SELECT $2, $3
                WHERE EXISTS (SELECT 1 FROM school.classes  WHERE id = $2 AND school_id = $1)
                  AND EXISTS (SELECT 1 FROM school.subjects WHERE id = $3 AND school_id = $1)
                ON CONFLICT DO NOTHING`,
		schoolID, classID, subjectID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("class or subject not in this school")
	}
	return nil
}

func (s *Store) RemoveClassSubject(ctx context.Context, schoolID, classID, subjectID string) error {
	_, err := s.Pool.Exec(ctx, `
                DELETE FROM school.class_subjects cs
                USING school.classes c
                WHERE cs.class_id = c.id AND c.school_id = $1
                  AND cs.class_id = $2 AND cs.subject_id = $3`,
		schoolID, classID, subjectID)
	return err
}

// ClearSchoolLogo resets the logo to empty.
func (s *Store) ClearSchoolLogo(ctx context.Context, schoolID string) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE school.schools SET logo_url = '' WHERE id = $1`, schoolID)
	return err
}

// TeacherAssignedClass reports whether a member holds any assignment in
// a class (any subject) - the attendance-editing gate for teachers.
func (s *Store) TeacherAssignedClass(ctx context.Context, memberID, classID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx, `
                SELECT EXISTS (SELECT 1 FROM school.assignments
                               WHERE member_id = $1 AND class_id = $2)`,
		memberID, classID).Scan(&ok)
	return ok, err
}

// ----------------------------------------------------------- students

// StudentDetail is the full enrollment record: everything the portal
// form collects, beyond the roster's short row.
type StudentDetail struct {
	SchoolStudent
	DOB           string   `json:"dob"`
	GuardianName  string   `json:"guardianName"`
	GuardianPhone string   `json:"guardianPhone"`
	Address       string   `json:"address"`
	PhotoURL      string   `json:"photoUrl"`
	Status        string   `json:"status"`
	Subjects      []string `json:"subjects,omitempty"`
}

const studentDetailCols = `
        s.id, s.school_id, s.class_id, s.full_name, s.admission_no, s.sex, s.session,
        s.dob, s.guardian_name, s.guardian_phone, s.address, s.photo_url, s.status`

func scanStudentDetail(row pgx.Row) (*StudentDetail, error) {
	var d StudentDetail
	err := row.Scan(&d.ID, &d.SchoolID, &d.ClassID, &d.FullName, &d.AdmissionNo, &d.Sex, &d.Session,
		&d.DOB, &d.GuardianName, &d.GuardianPhone, &d.Address, &d.PhotoURL, &d.Status)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// StudentByID loads one student's full detail (school-scoped).
func (s *Store) StudentByID(ctx context.Context, schoolID, studentID string) (*StudentDetail, error) {
	d, err := scanStudentDetail(s.Pool.QueryRow(ctx, `
                SELECT `+studentDetailCols+` FROM school.students s
                WHERE s.id = $1 AND s.school_id = $2`, studentID, schoolID))
	if err != nil {
		return nil, err
	}
	d.Subjects, err = s.StudentSubjectIDs(ctx, studentID)
	return d, err
}

// UpdateStudent edits the enrollment record. classID empty keeps the
// current class.
func (s *Store) UpdateStudent(ctx context.Context, schoolID, studentID string, d StudentDetail) error {
	sets := []string{}
	args := []any{}
	arg := func(v, col string) {
		args = append(args, v)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	arg(d.FullName, "full_name")
	arg(d.AdmissionNo, "admission_no")
	arg(d.Sex, "sex")
	arg(d.Session, "session")
	arg(d.DOB, "dob")
	arg(d.GuardianName, "guardian_name")
	arg(d.GuardianPhone, "guardian_phone")
	arg(d.Address, "address")
	if d.ClassID != "" {
		arg(d.ClassID, "class_id")
	}
	args = append(args, studentID, schoolID)
	tag, err := s.Pool.Exec(ctx, `
                UPDATE school.students SET `+strings.Join(sets, ", ")+`
                WHERE id = $`+fmt.Sprint(len(args)-1)+` AND school_id = $`+fmt.Sprint(len(args)),
		args...)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("student not found in this school")
	}
	return nil
}

// StudentSubjectIDs returns the student's explicit offering (empty
// slice = follow the class subjects).
func (s *Store) StudentSubjectIDs(ctx context.Context, studentID string) ([]string, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT subject_id FROM school.student_subjects
                WHERE student_id = $1 ORDER BY subject_id`, studentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	ids := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// SetStudentSubjects replaces the offering. An empty list clears back
// to "follow the class".
func (s *Store) SetStudentSubjects(ctx context.Context, schoolID, studentID string, subjectIDs []string) error {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	var exists bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM school.students WHERE id = $1 AND school_id = $2)`,
		studentID, schoolID).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return errors.New("student not found in this school")
	}
	if _, err := tx.Exec(ctx, `DELETE FROM school.student_subjects WHERE student_id = $1`, studentID); err != nil {
		return err
	}
	for _, sid := range subjectIDs {
		if _, err := tx.Exec(ctx, `
                        INSERT INTO school.student_subjects (student_id, subject_id)
                        SELECT $1, $2
                        WHERE EXISTS (SELECT 1 FROM school.subjects WHERE id = $2 AND school_id = $3)
                        ON CONFLICT DO NOTHING`,
			studentID, sid, schoolID); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// --------------------------------------------------------- attendance

// AttendanceEntry is one student's mark for a day.
type AttendanceEntry struct {
	StudentID string `json:"studentId"`
	Status    string `json:"status"`
	Note      string `json:"note"`
}

// SaveAttendance upserts a batch of marks for one class + day. Unknown
// statuses are coerced to present.
func (s *Store) SaveAttendance(ctx context.Context, schoolID, classID, day, markedBy string, entries []AttendanceEntry) (int, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)
	n := 0
	for _, e := range entries {
		status := e.Status
		if status != "present" && status != "absent" && status != "late" && status != "excused" {
			status = "present"
		}
		tag, err := tx.Exec(ctx, `
                        INSERT INTO school.attendance (school_id, class_id, student_id, day, status, note, marked_by)
                        SELECT $1, $2, $3, $4::date, $5, $6, $7
                        WHERE EXISTS (SELECT 1 FROM school.students WHERE id = $3 AND school_id = $1
                                      AND (class_id = $2 OR $2 = ''))
                        ON CONFLICT (student_id, day) DO UPDATE SET
                          status = EXCLUDED.status, note = EXCLUDED.note,
                          marked_by = EXCLUDED.marked_by, updated_at = now()`,
			schoolID, classID, e.StudentID, day, status, e.Note, markedBy)
		if err != nil {
			return n, err
		}
		n += int(tag.RowsAffected())
	}
	return n, tx.Commit(ctx)
}

// AttendanceDay loads the saved marks for one class + day.
func (s *Store) AttendanceDay(ctx context.Context, schoolID, classID, day string) ([]AttendanceEntry, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT student_id, status, note FROM school.attendance
                WHERE school_id = $1 AND class_id = $2 AND day = $3::date`,
		schoolID, classID, day)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AttendanceEntry{}
	for rows.Next() {
		var e AttendanceEntry
		if err := rows.Scan(&e.StudentID, &e.Status, &e.Note); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// AttendanceSummaryRow rolls a date range up per student.
type AttendanceSummaryRow struct {
	StudentID string `json:"studentId"`
	Present   int    `json:"present"`
	Absent    int    `json:"absent"`
	Late      int    `json:"late"`
	Excused   int    `json:"excused"`
	Total     int    `json:"total"`
	Rate      int    `json:"rate"` // percent
}

// AttendanceSummary aggregates a class's marks over a date range.
func (s *Store) AttendanceSummary(ctx context.Context, schoolID, classID, from, to string) ([]AttendanceSummaryRow, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT student_id,
                       COUNT(*) FILTER (WHERE status = 'present')  AS present,
                       COUNT(*) FILTER (WHERE status = 'absent')   AS absent,
                       COUNT(*) FILTER (WHERE status = 'late')     AS late,
                       COUNT(*) FILTER (WHERE status = 'excused')  AS excused,
                       COUNT(*)                                    AS total
                FROM school.attendance
                WHERE school_id = $1 AND class_id = $2 AND day BETWEEN $3::date AND $4::date
                GROUP BY student_id ORDER BY student_id`,
		schoolID, classID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AttendanceSummaryRow{}
	for rows.Next() {
		var r AttendanceSummaryRow
		if err := rows.Scan(&r.StudentID, &r.Present, &r.Absent, &r.Late, &r.Excused, &r.Total); err != nil {
			return nil, err
		}
		if r.Total > 0 {
			r.Rate = int(float64(r.Present+r.Late+r.Excused) / float64(r.Total) * 100)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// -------------------------------------------------------- bulk import

// BulkTopic is one imported topic (scraper output shape).
type BulkTopic struct {
	Title   string `json:"title"`
	Week    int    `json:"week"`
	Content string `json:"content"`
	Source  string `json:"source"`
	// Provenance URL the corpora carry per topic; accepted so a pour
	// can post its rows verbatim. Stored provenance stays in source.
	SourceURL string `json:"sourceUrl"`
}

// BulkUpsertTopics imports a whole topic list into one class+subject+
// term syllabus, creating the syllabus if needed and upserting topics
// by title. overwrite=false only fills topics whose content is still
// empty (safe to re-pour a growing corpus); overwrite=true replaces.
// Returns the number of topics written.
func (s *Store) BulkUpsertTopics(ctx context.Context, schoolID, classID, subjectID string, term int, session string, overwrite bool, topics []BulkTopic) (int, error) {
	if len(topics) == 0 {
		return 0, nil
	}
	syll, err := s.EnsureSyllabus(ctx, schoolID, classID, subjectID, term, session)
	if err != nil {
		return 0, err
	}
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	// Load existing titles once so seq keeps a sane order on merge.
	existing := map[string]string{}
	rows, err := tx.Query(ctx,
		`SELECT title, content FROM school.topics WHERE syllabus_id = $1`, syll.ID)
	if err != nil {
		return 0, err
	}
	for rows.Next() {
		t, c := "", ""
		if err := rows.Scan(&t, &c); err != nil {
			rows.Close()
			return 0, err
		}
		existing[strings.ToLower(strings.TrimSpace(t))] = c
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}

	nextSeq := len(existing) + 1
	written := 0
	for _, tp := range topics {
		title := strings.TrimSpace(tp.Title)
		if title == "" || strings.TrimSpace(tp.Content) == "" {
			continue
		}
		key := strings.ToLower(title)
		src := tp.Source
		if src == "" {
			src = "import"
		}
		old, seen := existing[key]
		if seen {
			if !overwrite && strings.TrimSpace(old) != "" {
				continue
			}
			if _, err := tx.Exec(ctx, `
                                UPDATE school.topics SET content = $1, source = $2, week = $3, updated_at = now()
                                WHERE syllabus_id = $4 AND lower(trim(title)) = $5`,
				tp.Content, src, tp.Week, syll.ID, key); err != nil {
				return written, err
			}
		} else {
			if _, err := tx.Exec(ctx, `
                                INSERT INTO school.topics (syllabus_id, title, seq, week, content, source)
                                VALUES ($1, $2, $3, $4, $5, $6)`,
				syll.ID, title, nextSeq, tp.Week, tp.Content, src); err != nil {
				return written, err
			}
			nextSeq++
			existing[key] = tp.Content
		}
		written++
	}
	return written, tx.Commit(ctx)
}
