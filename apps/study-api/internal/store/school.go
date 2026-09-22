// School-platform SQL. Every table lives in the `school` schema (see
// migrations/0013_school_platform.sql). Doctrine mirrors store.go: all
// access goes through this file, simple-protocol-safe, no hand-ALTERs.
package store

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/jackc/pgx/v5"

	"renance.dev/study-api/internal/school"
)

// ------------------------------------------------------------ data types

type School struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	SchoolType string    `json:"schoolType"`
	Address    string    `json:"address"`
	CreatedAt  time.Time `json:"-"`
}

type SchoolMember struct {
	ID        string    `json:"id"`
	SchoolID  string    `json:"schoolId"`
	UserID    string    `json:"userId"`
	Role      string    `json:"role"` // management | teacher
	FullName  string    `json:"fullName"`
	StaffCode string    `json:"staffCode"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"-"`
}

type SchoolClass struct {
	ID       string `json:"id"`
	SchoolID string `json:"-"`
	Name     string `json:"name"`
	Level    string `json:"level"`
	Seq      int    `json:"seq"`
}

type SchoolSubject struct {
	ID       string `json:"id"`
	SchoolID string `json:"-"`
	Name     string `json:"name"`
	Code     string `json:"code"`
	Level    string `json:"level"`
	Seq      int    `json:"seq"`
}

type SchoolTopic struct {
	ID        string    `json:"id"`
	Syllabus  string    `json:"-"`
	Title     string    `json:"title"`
	Seq       int       `json:"seq"`
	Week      int       `json:"week"`
	Content   string    `json:"content"`
	Source    string    `json:"source"`
	UpdatedAt time.Time `json:"-"`
}

type SchoolSyllabus struct {
	ID           string          `json:"id"`
	SchoolID     string          `json:"-"`
	ClassID      string          `json:"classId"`
	SubjectID    string          `json:"subjectId"`
	Term         int             `json:"term"`
	Session      string          `json:"session"`
	SchemeOfWork json.RawMessage `json:"schemeOfWork"`
	Topics       []SchoolTopic   `json:"topics"`
}

type SchoolStudent struct {
	ID          string `json:"id"`
	SchoolID    string `json:"-"`
	ClassID     string `json:"classId"`
	FullName    string `json:"fullName"`
	AdmissionNo string `json:"admissionNo"`
	Sex         string `json:"sex"`
	Session     string `json:"session"`
}

type SchoolAssignment struct {
	ID        string `json:"id"`
	SchoolID  string `json:"-"`
	MemberID  string `json:"memberId"`
	ClassID   string `json:"classId"`
	SubjectID string `json:"subjectId"`
}

// SchoolResultItem is one subject row of a student's result.
type SchoolResultItem struct {
	SubjectID    string  `json:"subjectId"`
	SubjectName  string  `json:"subjectName"`
	EnteredBy    string  `json:"enteredBy,omitempty"`
	CA1          float64 `json:"ca1"`
	CA2          float64 `json:"ca2"`
	Exam         float64 `json:"exam"`
	Total        float64 `json:"total"`
	Grade        string  `json:"grade"`
	Remark       string  `json:"remark"`
	Position     int     `json:"position,omitempty"`
	ClassAverage float64 `json:"classAverage,omitempty"`
}

// SchoolResult is a student's report card for one term.
type SchoolResult struct {
	ID              string             `json:"id"`
	StudentID       string             `json:"studentId"`
	StudentName     string             `json:"studentName"`
	AdmissionNo     string             `json:"admissionNo"`
	ClassID         string             `json:"classId"`
	ClassName       string             `json:"className"`
	Term            int                `json:"term"`
	Session         string             `json:"session"`
	Status          string             `json:"status"`
	Pin             string             `json:"pin,omitempty"`
	MarksObtainable int                `json:"marksObtainable"`
	TeacherReport   string             `json:"teacherReport"`
	PrincipalReport string             `json:"principalReport"`
	Items           []SchoolResultItem `json:"items"`
}

// SchoolContext is what a signed-in user needs to enter the school world.
type SchoolContext struct {
	Member SchoolMember `json:"member"`
	School School       `json:"school"`
}

// ------------------------------------------------------------- schools

func (s *Store) CreateSchool(ctx context.Context, name, schoolType, ownerUserID, ownerFullName string) (*School, *SchoolMember, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("store: school tx: %w", err)
	}
	defer tx.Rollback(ctx)

	sc := &School{Name: name, SchoolType: schoolType, Address: ""}
	err = tx.QueryRow(ctx, `
                INSERT INTO school.schools (name, school_type, owner_user_id)
                VALUES ($1, $2, $3)
                RETURNING id, created_at`, name, schoolType, ownerUserID,
	).Scan(&sc.ID, &sc.CreatedAt)
	if err != nil {
		return nil, nil, fmt.Errorf("store: create school: %w", err)
	}

	m := &SchoolMember{
		SchoolID: sc.ID, UserID: ownerUserID, Role: "management",
		FullName: ownerFullName, Status: "active",
	}
	err = tx.QueryRow(ctx, `
                INSERT INTO school.members (school_id, user_id, role, full_name)
                VALUES ($1, $2, 'management', $3)
                RETURNING id, created_at`, sc.ID, ownerUserID, ownerFullName,
	).Scan(&m.ID, &m.CreatedAt)
	if err != nil {
		return nil, nil, fmt.Errorf("store: create school owner member: %w", err)
	}

	if err = tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("store: school commit: %w", err)
	}
	return sc, m, nil
}

// SchoolsForUser lists every school membership the user holds.
func (s *Store) SchoolsForUser(ctx context.Context, userID string) ([]SchoolContext, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT m.id, m.school_id, m.user_id, m.role, m.full_name, m.staff_code, m.status, m.created_at,
                       sc.id, sc.name, sc.school_type, sc.address, sc.created_at
                FROM school.members m
                JOIN school.schools sc ON sc.id = m.school_id
                WHERE m.user_id = $1 AND m.status = 'active'
                ORDER BY sc.name`, userID)
	if err != nil {
		return nil, fmt.Errorf("store: schools for user: %w", err)
	}
	defer rows.Close()

	var out []SchoolContext
	for rows.Next() {
		var c SchoolContext
		if err := rows.Scan(
			&c.Member.ID, &c.Member.SchoolID, &c.Member.UserID, &c.Member.Role,
			&c.Member.FullName, &c.Member.StaffCode, &c.Member.Status, &c.Member.CreatedAt,
			&c.School.ID, &c.School.Name, &c.School.SchoolType, &c.School.Address, &c.School.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("store: schools for user scan: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// MemberFor returns the caller's membership of a school (nil if none).
func (s *Store) MemberFor(ctx context.Context, userID, schoolID string) (*SchoolMember, error) {
	m := &SchoolMember{}
	err := s.Pool.QueryRow(ctx, `
                SELECT id, school_id, user_id, role, full_name, staff_code, status, created_at
                FROM school.members WHERE user_id = $1 AND school_id = $2`, userID, schoolID,
	).Scan(&m.ID, &m.SchoolID, &m.UserID, &m.Role, &m.FullName, &m.StaffCode, &m.Status, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("store: member for: %w", err)
	}
	return m, nil
}

func (s *Store) SchoolByID(ctx context.Context, id string) (*School, error) {
	sc := &School{}
	err := s.Pool.QueryRow(ctx, `
                SELECT id, name, school_type, address, created_at
                FROM school.schools WHERE id = $1`, id,
	).Scan(&sc.ID, &sc.Name, &sc.SchoolType, &sc.Address, &sc.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("store: school by id: %w", err)
	}
	return sc, nil
}

// ------------------------------------------------------- curriculum seed

// SeedCurriculum instantiates the Nigerian curriculum for a school:
// classes, subjects and the class-subject map. Idempotent — existing rows
// are left alone so schools that customized keep their edits. It also
// plants the seed syllabuses (JSS 1 + Primary 4, first term) with starter
// notes the very first time a matching class+subject pair appears.
func (s *Store) SeedCurriculum(ctx context.Context, schoolID string) (classes, subjects int, err error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return 0, 0, err
	}
	defer tx.Rollback(ctx)

	for _, c := range school.Classes {
		var id string
		err := tx.QueryRow(ctx, `
                        INSERT INTO school.classes (school_id, name, level, seq)
                        VALUES ($1, $2, $3, $4)
                        ON CONFLICT (school_id, name) DO UPDATE SET seq = EXCLUDED.seq
                        RETURNING id`, schoolID, c.Name, c.Level, c.Seq,
		).Scan(&id)
		if err != nil {
			return 0, 0, fmt.Errorf("store: seed class %s: %w", c.Name, err)
		}
	}
	classes = len(school.Classes)

	subjectIDs := map[string]string{}
	classLevel := map[string]string{}
	for _, c := range school.Classes {
		classLevel[c.Name] = c.Level
	}
	for _, sub := range school.Subjects {
		var id string
		err := tx.QueryRow(ctx, `
                        INSERT INTO school.subjects (school_id, name, code, level, seq)
                        VALUES ($1, $2, $3, $4, $5)
                        ON CONFLICT (school_id, name, level) DO UPDATE SET seq = EXCLUDED.seq
                        RETURNING id`, schoolID, sub.Name, sub.Code, sub.Level, sub.Seq,
		).Scan(&id)
		if err != nil {
			return 0, 0, fmt.Errorf("store: seed subject %s: %w", sub.Name, err)
		}
		subjectIDs[sub.Name+"|"+sub.Level] = id
	}
	subjects = len(school.Subjects)

	// class_subjects: a subject belongs to a class when its level band
	// matches (or is "both"). Senior subjects don't leak into primary.
	if _, err = tx.Exec(ctx, `
                INSERT INTO school.class_subjects (class_id, subject_id)
                SELECT c.id, sub.id
                FROM school.classes c
                JOIN school.subjects sub ON sub.school_id = c.school_id
                WHERE c.school_id = $1 AND (sub.level = c.level OR sub.level = 'both')
                ON CONFLICT DO NOTHING`, schoolID); err != nil {
		return 0, 0, fmt.Errorf("store: seed class_subjects: %w", err)
	}

	if err = tx.Commit(ctx); err != nil {
		return 0, 0, err
	}

	// Seed syllabus + starter notes outside the tx (idempotent upserts,
	// only for the pairs the seed data declares).
	for _, seed := range school.SeedSyllabuses {
		classID, ok := s.seedClassID(ctx, schoolID, seed.Class)
		if !ok {
			continue
		}
		subjectID, ok := seedSubjectID(subjectIDs, classLevel, seed)
		if !ok {
			continue
		}
		if err = s.SeedSyllabusTopics(ctx, schoolID, classID, subjectID, seed); err != nil {
			return classes, subjects, err
		}
	}
	return classes, subjects, nil
}

func (s *Store) seedClassID(ctx context.Context, schoolID, name string) (string, bool) {
	var id string
	err := s.Pool.QueryRow(ctx,
		`SELECT id FROM school.classes WHERE school_id = $1 AND name = $2`, schoolID, name,
	).Scan(&id)
	return id, err == nil
}

// seedSubjectID resolves a seed syllabus's subject for the class's level
// band: "Mathematics" means MTH-J under JSS 1 but MTH-P under Primary 4.
func seedSubjectID(subjectIDs map[string]string, classLevel map[string]string, seed school.SeedSyllabus) (string, bool) {
	level, ok := classLevel[seed.Class]
	if !ok {
		return "", false
	}
	// Prefer the exact band, then "both" (subjects like Civic Education).
	if id, ok := subjectIDs[seed.Subject+"|"+level]; ok {
		return id, true
	}
	if id, ok := subjectIDs[seed.Subject+"|both"]; ok {
		return id, true
	}
	return "", false
}

// SeedSyllabusTopics ensures a syllabus row exists for the term and fills
// ONLY an empty topic list — never overwrites teacher edits.
func (s *Store) SeedSyllabusTopics(ctx context.Context, schoolID, classID, subjectID string, seed school.SeedSyllabus) error {
	var syID string
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.syllabuses (school_id, class_id, subject_id, term, session, scheme_of_work)
                VALUES ($1, $2, $3, $4, '', '[]'::jsonb)
                ON CONFLICT (class_id, subject_id, term, session) DO UPDATE SET term = EXCLUDED.term
                RETURNING id`, schoolID, classID, subjectID, seed.Term,
	).Scan(&syID)
	if err != nil {
		return fmt.Errorf("store: seed syllabus %s/%s: %w", seed.Class, seed.Subject, err)
	}

	var count int
	if err := s.Pool.QueryRow(ctx,
		`SELECT count(*) FROM school.topics WHERE syllabus_id = $1`, syID,
	).Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	for i, t := range seed.Topics {
		if _, err := s.Pool.Exec(ctx, `
                        INSERT INTO school.topics (syllabus_id, title, seq, week, content, source)
                        VALUES ($1, $2, $3, $4, $5, 'nerdc-seed')`,
			syID, t.Title, i+1, t.Week, t.Content,
		); err != nil {
			return fmt.Errorf("store: seed topic %s: %w", t.Title, err)
		}
	}
	return nil
}

// ------------------------------------------------------------ classes

func (s *Store) ListClasses(ctx context.Context, schoolID string) ([]SchoolClass, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, school_id, name, level, seq FROM school.classes
                WHERE school_id = $1 ORDER BY seq`, schoolID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SchoolClass
	for rows.Next() {
		var c SchoolClass
		if err := rows.Scan(&c.ID, &c.SchoolID, &c.Name, &c.Level, &c.Seq); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) ListSubjects(ctx context.Context, schoolID string) ([]SchoolSubject, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, school_id, name, code, level, seq FROM school.subjects
                WHERE school_id = $1 ORDER BY seq`, schoolID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SchoolSubject
	for rows.Next() {
		var sub SchoolSubject
		if err := rows.Scan(&sub.ID, &sub.SchoolID, &sub.Name, &sub.Code, &sub.Level, &sub.Seq); err != nil {
			return nil, err
		}
		out = append(out, sub)
	}
	return out, rows.Err()
}

func (s *Store) ClassSubjects(ctx context.Context, schoolID string) ([]map[string]any, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT cs.class_id, c.name AS class_name, cs.subject_id, s.name AS subject_name
                FROM school.class_subjects cs
                JOIN school.classes c ON c.id = cs.class_id
                JOIN school.subjects s ON s.id = cs.subject_id
                WHERE c.school_id = $1
                ORDER BY c.seq, s.seq`, schoolID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []map[string]any
	for rows.Next() {
		var classID, className, subjectID, subjectName string
		if err := rows.Scan(&classID, &className, &subjectID, &subjectName); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"classId": classID, "className": className,
			"subjectId": subjectID, "subjectName": subjectName,
		})
	}
	return out, rows.Err()
}

// ------------------------------------------------------------ members

// CreateTeacherMember creates a school-owned teacher: a study.users row +
// a school.members row with role=teacher, in one transaction.
func (s *Store) CreateTeacherMember(ctx context.Context, schoolID, userID, fullName, staffCode string) (*SchoolMember, error) {
	m := &SchoolMember{SchoolID: schoolID, UserID: userID, Role: "teacher", FullName: fullName, StaffCode: staffCode, Status: "active"}
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.members (school_id, user_id, role, full_name, staff_code)
                VALUES ($1, $2, 'teacher', $3, $4)
                RETURNING id, created_at`, schoolID, userID, fullName, staffCode,
	).Scan(&m.ID, &m.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("store: create teacher member: %w", err)
	}
	return m, nil
}

// MemberSummary is a member joined with the underlying account.
type MemberSummary struct {
	Member   SchoolMember `json:"member"`
	Username string       `json:"username"`
	Email    string       `json:"email"`
}

func (s *Store) ListMembers(ctx context.Context, schoolID string) ([]MemberSummary, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT m.id, m.school_id, m.user_id, m.role, m.full_name, m.staff_code, m.status, m.created_at,
                       u.username, COALESCE(u.email, '')
                FROM school.members m
                JOIN study.users u ON u.id = m.user_id
                WHERE m.school_id = $1
                ORDER BY m.role, m.full_name`, schoolID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []MemberSummary
	for rows.Next() {
		var ms MemberSummary
		if err := rows.Scan(&ms.Member.ID, &ms.Member.SchoolID, &ms.Member.UserID, &ms.Member.Role,
			&ms.Member.FullName, &ms.Member.StaffCode, &ms.Member.Status, &ms.Member.CreatedAt,
			&ms.Username, &ms.Email); err != nil {
			return nil, err
		}
		out = append(out, ms)
	}
	return out, rows.Err()
}

// ------------------------------------------------------- assignments

func (s *Store) AddAssignment(ctx context.Context, schoolID, memberID, classID, subjectID string) error {
	_, err := s.Pool.Exec(ctx, `
                INSERT INTO school.assignments (school_id, member_id, class_id, subject_id)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (member_id, class_id, subject_id) DO NOTHING`,
		schoolID, memberID, classID, subjectID)
	if err != nil {
		return fmt.Errorf("store: add assignment: %w", err)
	}
	return nil
}

func (s *Store) RemoveAssignment(ctx context.Context, memberID, classID, subjectID string) error {
	_, err := s.Pool.Exec(ctx, `
                DELETE FROM school.assignments
                WHERE member_id = $1 AND class_id = $2 AND subject_id = $3`,
		memberID, classID, subjectID)
	if err != nil {
		return fmt.Errorf("store: remove assignment: %w", err)
	}
	return nil
}

type AssignmentDetail struct {
	SchoolAssignment
	ClassName   string `json:"className"`
	SubjectName string `json:"subjectName"`
	MemberName  string `json:"memberName"`
	MemberRole  string `json:"memberRole"`
}

func (s *Store) ListAssignments(ctx context.Context, schoolID, memberID string) ([]AssignmentDetail, error) {
	base := `
                SELECT a.id, a.school_id, a.member_id, a.class_id, a.subject_id,
                       c.name, s.name, m.full_name, m.role
                FROM school.assignments a
                JOIN school.classes c ON c.id = a.class_id
                JOIN school.subjects s ON s.id = a.subject_id
                JOIN school.members m ON m.id = a.member_id
                WHERE a.school_id = $1`
	args := []any{schoolID}
	if memberID != "" {
		base += ` AND a.member_id = $2`
		args = append(args, memberID)
	}
	base += ` ORDER BY c.seq, s.seq`
	rows, err := s.Pool.Query(ctx, base, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AssignmentDetail
	for rows.Next() {
		var d AssignmentDetail
		if err := rows.Scan(&d.ID, &d.SchoolID, &d.MemberID, &d.ClassID, &d.SubjectID,
			&d.ClassName, &d.SubjectName, &d.MemberName, &d.MemberRole); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// HasAssignment reports whether a member may fill results for a
// class+subject (management may for everything).
func (s *Store) HasAssignment(ctx context.Context, memberID, classID, subjectID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx, `
                SELECT EXISTS (
                        SELECT 1 FROM school.assignments
                        WHERE member_id = $1 AND class_id = $2 AND subject_id = $3)`,
		memberID, classID, subjectID).Scan(&ok)
	return ok, err
}

// ------------------------------------------------------------ students

func (s *Store) CreateStudent(ctx context.Context, schoolID, classID, fullName, admissionNo, sex, session string) (*SchoolStudent, error) {
	st := &SchoolStudent{SchoolID: schoolID, ClassID: classID, FullName: fullName, AdmissionNo: admissionNo, Sex: sex, Session: session}
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.students (school_id, class_id, full_name, admission_no, sex, session)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING id`, schoolID, classID, fullName, admissionNo, sex, session,
	).Scan(&st.ID)
	if err != nil {
		return nil, fmt.Errorf("store: create student: %w", err)
	}
	return st, nil
}

func (s *Store) ListStudents(ctx context.Context, schoolID, classID string) ([]SchoolStudent, error) {
	base := `SELECT id, school_id, COALESCE(class_id::text, ''), full_name, admission_no, sex, session
                FROM school.students WHERE school_id = $1`
	args := []any{schoolID}
	if classID != "" {
		base += ` AND class_id = $2`
		args = append(args, classID)
	}
	base += ` ORDER BY full_name`
	rows, err := s.Pool.Query(ctx, base, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SchoolStudent
	for rows.Next() {
		var st SchoolStudent
		if err := rows.Scan(&st.ID, &st.SchoolID, &st.ClassID, &st.FullName, &st.AdmissionNo, &st.Sex, &st.Session); err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	return out, rows.Err()
}

// ------------------------------------------------------------ syllabus

// EnsureSyllabus returns the syllabus row for class+subject+term,
// creating it (with an empty topic list) when missing.
func (s *Store) EnsureSyllabus(ctx context.Context, schoolID, classID, subjectID string, term int, session string) (*SchoolSyllabus, error) {
	sy := &SchoolSyllabus{SchoolID: schoolID, ClassID: classID, SubjectID: subjectID, Term: term, Session: session}
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.syllabuses (school_id, class_id, subject_id, term, session)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (class_id, subject_id, term, session) DO UPDATE SET session = EXCLUDED.session
                RETURNING id, scheme_of_work`, schoolID, classID, subjectID, term, session,
	).Scan(&sy.ID, &sy.SchemeOfWork)
	if err != nil {
		return nil, fmt.Errorf("store: ensure syllabus: %w", err)
	}
	return sy, nil
}

// SyllabusTree returns all three terms for a class+subject with topics.
func (s *Store) SyllabusTree(ctx context.Context, schoolID, classID, subjectID string) ([]SchoolSyllabus, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, class_id, subject_id, term, session, scheme_of_work
                FROM school.syllabuses
                WHERE school_id = $1 AND class_id = $2 AND subject_id = $3
                ORDER BY term`, schoolID, classID, subjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SchoolSyllabus
	for rows.Next() {
		var sy SchoolSyllabus
		if err := rows.Scan(&sy.ID, &sy.ClassID, &sy.SubjectID, &sy.Term, &sy.Session, &sy.SchemeOfWork); err != nil {
			return nil, err
		}
		out = append(out, sy)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for i := range out {
		topics, err := s.topicsFor(ctx, out[i].ID)
		if err != nil {
			return nil, err
		}
		out[i].Topics = topics
	}
	return out, nil
}

func (s *Store) topicsFor(ctx context.Context, syllabusID string) ([]SchoolTopic, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, syllabus_id, title, seq, week, content, source, updated_at
                FROM school.topics WHERE syllabus_id = $1 ORDER BY seq, week`, syllabusID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SchoolTopic
	for rows.Next() {
		var t SchoolTopic
		if err := rows.Scan(&t.ID, &t.Syllabus, &t.Title, &t.Seq, &t.Week, &t.Content, &t.Source, &t.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// UpdateTopic edits a topic's title/content/week and bumps updated_at.
func (s *Store) UpdateTopic(ctx context.Context, topicID, title, content string, week int) error {
	ct, err := s.Pool.Exec(ctx, `
                UPDATE school.topics
                SET title = $2, content = $3, week = $4, updated_at = now()
                WHERE id = $1`, topicID, title, content, week)
	if err != nil {
		return fmt.Errorf("store: update topic: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// UpdateSchemeOfWork replaces a syllabus's weekly plan.
func (s *Store) UpdateSchemeOfWork(ctx context.Context, syllabusID string, scheme json.RawMessage, updatedBy string) error {
	_, err := s.Pool.Exec(ctx, `
                UPDATE school.syllabuses SET scheme_of_work = $2, updated_by = $3, updated_at = now()
                WHERE id = $1`, syllabusID, scheme, updatedBy)
	return err
}

// TeacherOwnsSyllabus reports whether the member holds an assignment on
// the syllabus's class+subject (management routes never call this).
func (s *Store) TeacherOwnsSyllabus(ctx context.Context, memberID, syllabusID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx, `
                SELECT EXISTS (
                        SELECT 1 FROM school.syllabuses sy
                        JOIN school.assignments a
                                ON a.class_id = sy.class_id AND a.subject_id = sy.subject_id
                        WHERE sy.id = $1 AND a.member_id = $2)`,
		syllabusID, memberID).Scan(&ok)
	return ok, err
}

// TeacherOwnsTopic is TeacherOwnsSyllabus one hop down the tree.
func (s *Store) TeacherOwnsTopic(ctx context.Context, memberID, topicID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx, `
                SELECT EXISTS (
                        SELECT 1 FROM school.topics t
                        JOIN school.syllabuses sy ON sy.id = t.syllabus_id
                        JOIN school.assignments a
                                ON a.class_id = sy.class_id AND a.subject_id = sy.subject_id
                        WHERE t.id = $1 AND a.member_id = $2)`,
		topicID, memberID).Scan(&ok)
	return ok, err
}

// ResultFinalized reports whether a student's result for the term is
// already sealed (finalized results reject further score edits).
func (s *Store) ResultFinalized(ctx context.Context, studentID string, term int, session string) (bool, error) {
	var status string
	err := s.Pool.QueryRow(ctx, `
                SELECT status FROM school.results
                WHERE student_id = $1 AND term = $2 AND session = $3`,
		studentID, term, session).Scan(&status)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return status == "finalized", nil
}

// ------------------------------------------------------------ results

// SaveResultItem upserts the student's result for the term (draft) and
// the subject row, recomputing total + grade + remark from CA1/CA2/exam.
func (s *Store) SaveResultItem(ctx context.Context, schoolID, studentID, classID, subjectID string, term int, session string, ca1, ca2, exam float64, enteredBy string) (*SchoolResultItem, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var resultID string
	err = tx.QueryRow(ctx, `
                INSERT INTO school.results (student_id, class_id, term, session)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (student_id, term, session) DO UPDATE SET term = EXCLUDED.term
                RETURNING id`, studentID, classID, term, session,
	).Scan(&resultID)
	if err != nil {
		return nil, fmt.Errorf("store: ensure result: %w", err)
	}

	total := ca1 + ca2 + exam
	g := school.GradeFor(total)
	item := &SchoolResultItem{
		SubjectID: subjectID, EnteredBy: enteredBy,
		CA1: ca1, CA2: ca2, Exam: exam, Total: total,
		Grade: g.Letter, Remark: g.Remark,
	}
	err = tx.QueryRow(ctx, `
                INSERT INTO school.result_items (result_id, subject_id, entered_by, ca1, ca2, exam, total, grade, remark)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                ON CONFLICT (result_id, subject_id) DO UPDATE SET
                        entered_by = EXCLUDED.entered_by, ca1 = EXCLUDED.ca1, ca2 = EXCLUDED.ca2,
                        exam = EXCLUDED.exam, total = EXCLUDED.total, grade = EXCLUDED.grade,
                        remark = EXCLUDED.remark, updated_at = now()
                RETURNING id`, resultID, subjectID, enteredBy, ca1, ca2, exam, total, g.Letter, g.Remark,
	).Scan(new(string))
	if err != nil {
		return nil, fmt.Errorf("store: save result item: %w", err)
	}
	if err = tx.Commit(ctx); err != nil {
		return nil, err
	}
	return item, nil
}

// ResultsGrid returns every student in a class with their result items
// for the term (subjects that have scores), for the class results view.
func (s *Store) ResultsGrid(ctx context.Context, schoolID, classID string, term int, session string) ([]SchoolResult, error) {
	students, err := s.ListStudents(ctx, schoolID, classID)
	if err != nil {
		return nil, err
	}
	subjects, err := s.ListSubjects(ctx, schoolID)
	if err != nil {
		return nil, err
	}
	subjectName := map[string]string{}
	for _, sub := range subjects {
		subjectName[sub.ID] = sub.Name
	}

	var className string
	err = s.Pool.QueryRow(ctx, `SELECT name FROM school.classes WHERE id = $1`, classID).Scan(&className)
	if err != nil {
		return nil, fmt.Errorf("store: class name: %w", err)
	}

	out := make([]SchoolResult, 0, len(students))
	for _, st := range students {
		res := SchoolResult{
			StudentID: st.ID, StudentName: st.FullName, AdmissionNo: st.AdmissionNo,
			ClassID: classID, ClassName: className, Term: term, Session: session,
		}
		var id, status, pin string
		var teacherReport, principalReport string
		err := s.Pool.QueryRow(ctx, `
                        SELECT id, status, pin, teacher_report, principal_report
                        FROM school.results WHERE student_id = $1 AND term = $2 AND session = $3`,
			st.ID, term, session,
		).Scan(&id, &status, &pin, &teacherReport, &principalReport)
		switch {
		case errors.Is(err, pgx.ErrNoRows):
			// no result yet — still list the student so the grid is complete
		case err != nil:
			return nil, err
		default:
			res.ID, res.Status, res.Pin = id, status, pin
			res.TeacherReport, res.PrincipalReport = teacherReport, principalReport
			items, err := s.resultItems(ctx, id, subjectName)
			if err != nil {
				return nil, err
			}
			res.Items = items
		}
		out = append(out, res)
	}
	return out, nil
}

func (s *Store) resultItems(ctx context.Context, resultID string, subjectName map[string]string) ([]SchoolResultItem, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT subject_id, COALESCE(entered_by::text, ''), ca1, ca2, exam, total, grade, remark,
                       COALESCE(position, 0), COALESCE(class_average, 0)
                FROM school.result_items WHERE result_id = $1 ORDER BY updated_at`, resultID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SchoolResultItem
	for rows.Next() {
		var it SchoolResultItem
		if err := rows.Scan(&it.SubjectID, &it.EnteredBy, &it.CA1, &it.CA2, &it.Exam, &it.Total,
			&it.Grade, &it.Remark, &it.Position, &it.ClassAverage); err != nil {
			return nil, err
		}
		it.SubjectName = subjectName[it.SubjectID]
		out = append(out, it)
	}
	return out, rows.Err()
}

// FinalizeResults computes positions + class averages per subject across
// the class, issues a unique 6-digit PIN per result and flips status.
func (s *Store) FinalizeResults(ctx context.Context, schoolID, classID string, term int, session string) (int, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	// Per-subject: collect (result_item_id, total) across the class.
	rows, err := tx.Query(ctx, `
                SELECT ri.id, ri.subject_id, ri.total
                FROM school.result_items ri
                JOIN school.results r ON r.id = ri.result_id
                WHERE r.class_id = $1 AND r.term = $2 AND r.session = $3`,
		classID, term, session)
	if err != nil {
		return 0, err
	}
	type cell struct {
		id    string
		total float64
	}
	perSubject := map[string][]cell{}
	for rows.Next() {
		var c cell
		var subjectID string
		if err := rows.Scan(&c.id, &subjectID, &c.total); err != nil {
			rows.Close()
			return 0, err
		}
		perSubject[subjectID] = append(perSubject[subjectID], c)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}

	for _, cells := range perSubject {
		var sum float64
		for _, c := range cells {
			sum += c.total
		}
		avg := 0.0
		if len(cells) > 0 {
			avg = round2(sum / float64(len(cells)))
		}
		// Sort desc; ties share the same position (ggportal rule).
		for i := 0; i < len(cells); i++ {
			for j := i + 1; j < len(cells); j++ {
				if cells[j].total > cells[i].total {
					cells[i], cells[j] = cells[j], cells[i]
				}
			}
		}
		position := make([]int, len(cells))
		rank := 0
		for i := range cells {
			if i == 0 || cells[i].total != cells[i-1].total {
				rank = i + 1
			}
			position[i] = rank
		}
		for i, c := range cells {
			if _, err := tx.Exec(ctx, `
                                UPDATE school.result_items SET position = $2, class_average = $3
                                WHERE id = $1`, c.id, position[i], avg); err != nil {
				return 0, err
			}
		}
	}

	// Finalize every draft result in the class for the term, minting PINs.
	rows, err = tx.Query(ctx, `
                SELECT id FROM school.results
                WHERE class_id = $1 AND term = $2 AND session = $3 AND status = 'draft'`,
		classID, term, session)
	if err != nil {
		return 0, err
	}
	var resultIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return 0, err
		}
		resultIDs = append(resultIDs, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}

	for _, id := range resultIDs {
		pin, err := newPIN(ctx, tx, id)
		if err != nil {
			return 0, err
		}
		if _, err := tx.Exec(ctx, `
                        UPDATE school.results SET status = 'finalized', pin = $2, finalized_at = now()
                        WHERE id = $1`, id, pin); err != nil {
			return 0, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return len(resultIDs), nil
}

func round2(v float64) float64 {
	return float64(int(v*100+0.5)) / 100
}

// newPIN mints a unique 6-digit result-check PIN.
func newPIN(ctx context.Context, tx pgx.Tx, resultID string) (string, error) {
	for attempt := 0; attempt < 10; attempt++ {
		n, err := rand.Int(rand.Reader, big.NewInt(1000000))
		if err != nil {
			return "", err
		}
		pin := fmt.Sprintf("%06d", n.Int64())
		var exists bool
		if err := tx.QueryRow(ctx,
			`SELECT EXISTS (SELECT 1 FROM school.results WHERE pin = $1 AND id <> $2)`,
			pin, resultID).Scan(&exists); err != nil {
			return "", err
		}
		if !exists {
			return pin, nil
		}
	}
	return "", errors.New("store: could not mint unique pin")
}

// ResultSheet returns one student's full report card for a term.
func (s *Store) ResultSheet(ctx context.Context, schoolID, studentID string, term int, session string) (*SchoolResult, error) {
	var classID, fullName, admissionNo, className string
	err := s.Pool.QueryRow(ctx, `
                SELECT st.class_id, st.full_name, st.admission_no, COALESCE(c.name, '')
                FROM school.students st
                LEFT JOIN school.classes c ON c.id = st.class_id
                WHERE st.id = $1 AND st.school_id = $2`, studentID, schoolID,
	).Scan(&classID, &fullName, &admissionNo, &className)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	subjects, err := s.ListSubjects(ctx, schoolID)
	if err != nil {
		return nil, err
	}
	subjectName := map[string]string{}
	for _, sub := range subjects {
		subjectName[sub.ID] = sub.Name
	}

	res := &SchoolResult{
		StudentID: studentID, StudentName: fullName, AdmissionNo: admissionNo,
		ClassID: classID, ClassName: className, Term: term, Session: session,
	}
	var id, status, pin, teacherReport, principalReport string
	err = s.Pool.QueryRow(ctx, `
                SELECT id, status, pin, teacher_report, principal_report
                FROM school.results WHERE student_id = $1 AND term = $2 AND session = $3`,
		studentID, term, session,
	).Scan(&id, &status, &pin, &teacherReport, &principalReport)
	if errors.Is(err, pgx.ErrNoRows) {
		return res, nil
	}
	if err != nil {
		return nil, err
	}
	res.ID, res.Status, res.Pin = id, status, pin
	res.TeacherReport, res.PrincipalReport = teacherReport, principalReport
	res.Items, err = s.resultItems(ctx, id, subjectName)
	return res, err
}

// CheckResultByPIN is the public result check (like ggportal's student
// check): PIN + term + session -> the finalized report card.
func (s *Store) CheckResultByPIN(ctx context.Context, pin string, term int, session string) (*SchoolResult, error) {
	var resultID, studentID, schoolID string
	err := s.Pool.QueryRow(ctx, `
                SELECT id, student_id, school_id FROM school.results
                WHERE pin = $1 AND term = $2 AND session = $3 AND status = 'finalized'`,
		pin, term, session,
	).Scan(&resultID, &studentID, &schoolID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return s.ResultSheet(ctx, schoolID, studentID, term, session)
}

// ------------------------------------------------------------ offline pack

// SchoolPack is the offline bundle the mobile app downloads for a school
// (syllabus + scheme of work + notes, read-only). Version is a coarse
// stamp the app can compare to detect updates.
type SchoolPack struct {
	School    School          `json:"school"`
	Version   string          `json:"version"`
	Classes   []SchoolClass   `json:"classes"`
	Subjects  []SchoolSubject `json:"subjects"`
	Syllabus  []PackSyllabus  `json:"syllabus"`
	FetchedAt string          `json:"fetchedAt"`
}

// PackSyllabus is one class+subject entry of the offline pack.
type PackSyllabus struct {
	ClassID   string           `json:"classId"`
	ClassName string           `json:"className"`
	SubjectID string           `json:"subjectId"`
	Subject   string           `json:"subject"`
	Terms     []SchoolSyllabus `json:"terms"`
}

// BuildSchoolPack assembles the whole read-only pack for a school.
func (s *Store) BuildSchoolPack(ctx context.Context, schoolID string) (*SchoolPack, error) {
	sc, err := s.SchoolByID(ctx, schoolID)
	if err != nil || sc == nil {
		return nil, err
	}
	classes, err := s.ListClasses(ctx, schoolID)
	if err != nil {
		return nil, err
	}
	subjects, err := s.ListSubjects(ctx, schoolID)
	if err != nil {
		return nil, err
	}
	classSubjects, err := s.ClassSubjects(ctx, schoolID)
	if err != nil {
		return nil, err
	}
	className := map[string]string{}
	for _, c := range classes {
		className[c.ID] = c.Name
	}
	subjectName := map[string]string{}
	for _, sub := range subjects {
		subjectName[sub.ID] = sub.Name
	}

	pack := &SchoolPack{School: *sc, Classes: classes, Subjects: subjects}

	var maxUpdated time.Time
	var topicCount int
	pairs := map[string]*PackSyllabus{}
	for _, cs := range classSubjects {
		tree, err := s.SyllabusTree(ctx, schoolID, cs["classId"].(string), cs["subjectId"].(string))
		if err != nil {
			return nil, err
		}
		if len(tree) == 0 {
			continue
		}
		pairs[cs["classId"].(string)+"|"+cs["subjectId"].(string)] = &PackSyllabus{
			ClassID:   cs["classId"].(string),
			ClassName: cs["className"].(string),
			SubjectID: cs["subjectId"].(string),
			Subject:   cs["subjectName"].(string),
			Terms:     tree,
		}
		for _, sy := range tree {
			for _, t := range sy.Topics {
				topicCount++
				if t.UpdatedAt.After(maxUpdated) {
					maxUpdated = t.UpdatedAt
				}
			}
		}
	}
	for _, ps := range pairs {
		pack.Syllabus = append(pack.Syllabus, *ps)
	}
	pack.Version = fmt.Sprintf("%d-%s", topicCount, maxUpdated.UTC().Format("20060102150405"))
	pack.FetchedAt = time.Now().UTC().Format(time.RFC3339)
	return pack, nil
}
