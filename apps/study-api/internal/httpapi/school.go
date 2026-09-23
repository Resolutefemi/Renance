// School-platform HTTP surface. Sign-up ("For Schools"), the management
// + teacher workspace, syllabus/topics/notes, results (ggportal-style
// CA + exam, positions on finalize, per-result PIN check) and the
// read-only offline pack the mobile app downloads.
package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"renance.dev/study-api/internal/jwtx"
	"renance.dev/study-api/internal/school"
	"renance.dev/study-api/internal/store"
)

// ---------------------------------------------------------------- helpers

func (s *Server) memberAndSchool(w http.ResponseWriter, r *http.Request, schoolID string) (*store.SchoolMember, *store.School, bool) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing user")
		return nil, nil, false
	}
	if schoolID == "" {
		fail(w, http.StatusBadRequest, "missing_school", "schoolId is required")
		return nil, nil, false
	}
	m, err := s.store.MemberFor(r.Context(), uid, schoolID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "membership lookup failed")
		return nil, nil, false
	}
	if m == nil || m.Status != "active" {
		fail(w, http.StatusForbidden, "not_a_member", "you are not an active member of this school")
		return nil, nil, false
	}
	sc, err := s.store.SchoolByID(r.Context(), schoolID)
	if err != nil || sc == nil {
		fail(w, http.StatusNotFound, "school_not_found", "school does not exist")
		return nil, nil, false
	}
	return m, sc, true
}

func (s *Server) requireManagement(w http.ResponseWriter, m *store.SchoolMember) bool {
	if m.Role != "management" {
		fail(w, http.StatusForbidden, "management_only", "only school management can do that")
		return false
	}
	return true
}

func queryInt(r *http.Request, key string) (int, bool) {
	v := strings.TrimSpace(r.URL.Query().Get(key))
	if v == "" {
		return 0, false
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return 0, false
	}
	return n, true
}

// ---------------------------------------------------------------- register

type schoolRegisterReq struct {
	SchoolName string `json:"schoolName"`
	SchoolType string `json:"schoolType"`
	FullName   string `json:"fullName"`
	Email      string `json:"email"`
	Password   string `json:"password"`
}

// POST /school/auth/register - school sign-up: creates the account, the
// school and the management membership, then seeds the Nigerian
// curriculum so the portal is never a blank screen.
func (s *Server) handleSchoolRegister(w http.ResponseWriter, r *http.Request) {
	var req schoolRegisterReq
	if !decodeJSON(w, r, &req) {
		return
	}
	req.SchoolName = strings.TrimSpace(req.SchoolName)
	req.FullName = strings.TrimSpace(req.FullName)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.SchoolType = strings.TrimSpace(req.SchoolType)

	if req.SchoolName == "" || req.FullName == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "schoolName and fullName are required")
		return
	}
	if req.SchoolType != "primary" && req.SchoolType != "secondary" && req.SchoolType != "both" {
		fail(w, http.StatusBadRequest, "invalid_school_type", "schoolType must be primary, secondary or both")
		return
	}
	if len(req.Password) < 8 || len(req.Password) > 72 {
		fail(w, http.StatusBadRequest, "invalid_password", "password must be 8-72 characters")
		return
	}
	if req.Email == "" || !strings.Contains(req.Email, "@") {
		fail(w, http.StatusBadRequest, "invalid_email", "a valid school email is required")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not hash password")
		return
	}

	// Reuse the email-first creation rules (claims Google-only rows,
	// maps unique violations to clean errors).
	u, err := s.store.CreateUserEmail(r.Context(), req.Email, string(hash))
	if err != nil {
		switch {
		case errors.Is(err, store.ErrUniqueEmail):
			fail(w, http.StatusConflict, "email_taken", "that email already has a Renance account")
		case errors.Is(err, store.ErrUniqueUsername):
			fail(w, http.StatusConflict, "username_taken", "could not derive a free handle, try again")
		default:
			s.log.Error("school register: create user", "err", err)
			fail(w, http.StatusInternalServerError, "internal", "could not create the account")
		}
		return
	}

	sc, m, err := s.store.CreateSchool(r.Context(), req.SchoolName, req.SchoolType, u.ID, req.FullName)
	if err != nil {
		s.log.Error("school register: create school", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not create the school")
		return
	}

	// Best-effort curriculum seed; management can re-run it from the
	// portal if this ever fails.
	classes, subjects, seedErr := s.store.SeedCurriculum(r.Context(), sc.ID)
	if seedErr != nil {
		s.log.Warn("school register: curriculum seed failed", "school", sc.ID, "err", seedErr)
	}

	token, err := jwtx.Issue(u.ID, u.Username, s.cfg.JWTSecret)
	if err != nil {
		s.log.Error("school register: token issue", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not log in")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"token": token,
		"user":  userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: true},
		"school": map[string]any{
			"id": sc.ID, "name": sc.Name, "schoolType": sc.SchoolType,
			"memberId": m.ID, "role": m.Role,
		},
		"seededClasses": classes, "seededSubjects": subjects, "seedError": errString(seedErr),
	})
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

// ---------------------------------------------------------------- read side

// GET /school/me - the caller's school memberships (management/teacher).
func (s *Server) handleSchoolMe(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing user")
		return
	}
	ctxs, err := s.store.SchoolsForUser(r.Context(), uid)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load school memberships")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"schools": ctxs})
}

// GET /school/pack/{schoolId} - the read-only offline pack (app).
func (s *Server) handleSchoolPack(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.PathValue("schoolId"))
	if !ok {
		return
	}
	pack, err := s.store.BuildSchoolPack(r.Context(), m.SchoolID)
	if err != nil {
		s.log.Error("school pack build", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not build the school pack")
		return
	}
	writeJSON(w, http.StatusOK, pack)
}

// GET /school/classes?schoolId=
func (s *Server) handleSchoolClasses(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	classes, err := s.store.ListClasses(r.Context(), m.SchoolID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load classes")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"classes": classes})
}

// GET /school/subjects?schoolId=
func (s *Server) handleSchoolSubjects(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	subjects, err := s.store.ListSubjects(r.Context(), m.SchoolID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load subjects")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"subjects": subjects})
}

// GET /school/class-subjects?schoolId=
func (s *Server) handleSchoolClassSubjects(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	pairs, err := s.store.ClassSubjects(r.Context(), m.SchoolID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load class subjects")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"pairs": pairs})
}

// GET /school/members?schoolId= (management only)
func (s *Server) handleSchoolMembers(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	members, err := s.store.ListMembers(r.Context(), m.SchoolID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load members")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"members": members})
}

// GET /school/assignments?schoolId=&memberId=
func (s *Server) handleSchoolAssignments(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	memberID := r.URL.Query().Get("memberId")
	if m.Role != "management" && memberID != m.ID {
		fail(w, http.StatusForbidden, "forbidden", "teachers may only view their own assignments")
		return
	}
	assignments, err := s.store.ListAssignments(r.Context(), m.SchoolID, memberID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load assignments")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"assignments": assignments})
}

// GET /school/students?schoolId=&classId=
func (s *Server) handleSchoolStudents(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	students, err := s.store.ListStudents(r.Context(), m.SchoolID, r.URL.Query().Get("classId"))
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load students")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"students": students})
}

// GET /school/syllabus?schoolId=&classId=&subjectId= - all terms+topics.
func (s *Server) handleSchoolSyllabus(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	q := r.URL.Query()
	classID, subjectID := q.Get("classId"), q.Get("subjectId")
	if classID == "" || subjectID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "classId and subjectId are required")
		return
	}
	tree, err := s.store.SyllabusTree(r.Context(), m.SchoolID, classID, subjectID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load the syllabus")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"terms": tree})
}

// ---------------------------------------------------------------- writes

type seedReq struct {
	SchoolID string `json:"schoolId"`
}

// POST /school/seed-curriculum - (re)install the Nigerian curriculum.
func (s *Server) handleSchoolSeed(w http.ResponseWriter, r *http.Request) {
	var req seedReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	classes, subjects, err := s.store.SeedCurriculum(r.Context(), m.SchoolID)
	if err != nil {
		s.log.Error("seed curriculum", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not seed the curriculum")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"seededClasses": classes, "seededSubjects": subjects})
}

type teacherReq struct {
	SchoolID  string `json:"schoolId"`
	FullName  string `json:"fullName"`
	Email     string `json:"email"`
	Password  string `json:"password"`
	StaffCode string `json:"staffCode"`
}

// POST /school/teachers - management creates a teacher account. The
// teacher then signs in with the email + password through the normal
// "For Schools" login and lands in teacher mode.
func (s *Server) handleSchoolCreateTeacher(w http.ResponseWriter, r *http.Request) {
	var req teacherReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.FullName = strings.TrimSpace(req.FullName)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	if req.FullName == "" || !strings.Contains(req.Email, "@") {
		fail(w, http.StatusBadRequest, "invalid_body", "fullName and a valid email are required")
		return
	}
	if len(req.Password) < 8 || len(req.Password) > 72 {
		fail(w, http.StatusBadRequest, "invalid_password", "password must be 8-72 characters")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not hash password")
		return
	}
	u, err := s.store.CreateUserEmail(r.Context(), req.Email, string(hash))
	if err != nil {
		if errors.Is(err, store.ErrUniqueEmail) {
			fail(w, http.StatusConflict, "email_taken", "that email already has a Renance account")
			return
		}
		s.log.Error("create teacher user", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not create the teacher account")
		return
	}
	member, err := s.store.CreateTeacherMember(r.Context(), m.SchoolID, u.ID, req.FullName, strings.TrimSpace(req.StaffCode))
	if err != nil {
		s.log.Error("create teacher member", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not add the teacher to the school")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"member": member, "username": u.Username,
	})
}

type assignmentReq struct {
	SchoolID  string `json:"schoolId"`
	MemberID  string `json:"memberId"`
	ClassID   string `json:"classId"`
	SubjectID string `json:"subjectId"`
	Remove    bool   `json:"remove"`
}

// POST /school/assignments - grant (or revoke) a teacher's right to fill
// results for one class+subject.
func (s *Server) handleSchoolAssignment(w http.ResponseWriter, r *http.Request) {
	var req assignmentReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	if req.MemberID == "" || req.ClassID == "" || req.SubjectID == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "memberId, classId and subjectId are required")
		return
	}
	if req.Remove {
		if err := s.store.RemoveAssignment(r.Context(), req.MemberID, req.ClassID, req.SubjectID); err != nil {
			fail(w, http.StatusInternalServerError, "internal", "could not revoke the assignment")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
		return
	}
	if err := s.store.AddAssignment(r.Context(), m.SchoolID, req.MemberID, req.ClassID, req.SubjectID); err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not grant the assignment")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

type studentReq struct {
	SchoolID    string `json:"schoolId"`
	ClassID     string `json:"classId"`
	FullName    string `json:"fullName"`
	AdmissionNo string `json:"admissionNo"`
	Sex         string `json:"sex"`
	Session     string `json:"session"`
}

// POST /school/students - enroll a student.
func (s *Server) handleSchoolCreateStudent(w http.ResponseWriter, r *http.Request) {
	var req studentReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.FullName = strings.TrimSpace(req.FullName)
	if req.FullName == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "fullName is required")
		return
	}
	if req.Sex != "" && req.Sex != "M" && req.Sex != "F" {
		fail(w, http.StatusBadRequest, "invalid_body", "sex must be M, F or empty")
		return
	}
	st, err := s.store.CreateStudent(r.Context(), m.SchoolID, req.ClassID, req.FullName,
		strings.TrimSpace(req.AdmissionNo), req.Sex, strings.TrimSpace(req.Session))
	if err != nil {
		s.log.Error("create student", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not enroll the student")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"student": st})
}

type topicReq struct {
	SchoolID string `json:"schoolId"`
	TopicID  string `json:"topicId"`
	Title    string `json:"title"`
	Content  string `json:"content"`
	Week     int    `json:"week"`
}

// PUT /school/topic - edit a topic's title + note body. Management may
// edit everything; a teacher may edit notes of classes/subjects they are
// assigned to (their result-filling assignment doubles as content duty).
func (s *Server) handleSchoolUpdateTopic(w http.ResponseWriter, r *http.Request) {
	var req topicReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	req.Content = normalizeHyphens(req.Content)
	if req.TopicID == "" || req.Title == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "topicId and title are required")
		return
	}
	if m.Role != "management" {
		allowed, err := s.store.TeacherOwnsTopic(r.Context(), m.ID, req.TopicID)
		if err != nil || !allowed {
			fail(w, http.StatusForbidden, "forbidden", "you are not assigned to this class+subject")
			return
		}
	}
	if err := s.store.UpdateTopic(r.Context(), req.TopicID, req.Title, req.Content, req.Week); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			fail(w, http.StatusNotFound, "topic_not_found", "topic does not exist")
			return
		}
		fail(w, http.StatusInternalServerError, "internal", "could not save the topic")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

type schemeReq struct {
	SchoolID   string          `json:"schoolId"`
	SyllabusID string          `json:"syllabusId"`
	Scheme     json.RawMessage `json:"scheme"`
}

// PUT /school/scheme - replace a syllabus's weekly plan.
func (s *Server) handleSchoolUpdateScheme(w http.ResponseWriter, r *http.Request) {
	var req schemeReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if req.SyllabusID == "" || len(req.Scheme) == 0 {
		fail(w, http.StatusBadRequest, "invalid_body", "syllabusId and scheme are required")
		return
	}
	if m.Role != "management" {
		allowed, err := s.store.TeacherOwnsSyllabus(r.Context(), m.ID, req.SyllabusID)
		if err != nil || !allowed {
			fail(w, http.StatusForbidden, "forbidden", "you are not assigned to this class+subject")
			return
		}
	}
	uid, _ := userIDFrom(r)
	req.Scheme = json.RawMessage(normalizeHyphensInScheme(req.Scheme))
	if err := s.store.UpdateSchemeOfWork(r.Context(), req.SyllabusID, req.Scheme, uid); err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not save the scheme of work")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// normalizeHyphensInScheme enforces the no-long-hyphen rule on every
// text field of the weekly plan (topic, objectives, activities).
func normalizeHyphensInScheme(raw json.RawMessage) []byte {
	var rows []map[string]any
	if err := json.Unmarshal(raw, &rows); err != nil {
		return raw
	}
	for _, row := range rows {
		for k, v := range row {
			if s, ok := v.(string); ok {
				row[k] = normalizeHyphens(s)
			}
		}
	}
	out, err := json.Marshal(rows)
	if err != nil {
		return raw
	}
	return out
}

type resultItemReq struct {
	SchoolID  string  `json:"schoolId"`
	StudentID string  `json:"studentId"`
	ClassID   string  `json:"classId"`
	SubjectID string  `json:"subjectId"`
	Term      int     `json:"term"`
	Session   string  `json:"session"`
	CA1       float64 `json:"ca1"`
	CA2       float64 `json:"ca2"`
	Exam      float64 `json:"exam"`
}

// PUT /school/result-item - a teacher (assigned) or management fills one
// subject's scores for one student. CA1/CA2 max 20, exam max 60.
func (s *Server) handleSchoolSaveResultItem(w http.ResponseWriter, r *http.Request) {
	var req resultItemReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if req.StudentID == "" || req.ClassID == "" || req.SubjectID == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "studentId, classId and subjectId are required")
		return
	}
	if req.Term < 1 || req.Term > 3 {
		fail(w, http.StatusBadRequest, "invalid_term", "term must be 1, 2 or 3")
		return
	}
	if req.CA1 < 0 || req.CA1 > 20 || req.CA2 < 0 || req.CA2 > 20 || req.Exam < 0 || req.Exam > 60 {
		fail(w, http.StatusBadRequest, "invalid_scores", "CA1 and CA2 max 20 each, exam max 60")
		return
	}
	if m.Role != "management" {
		allowed, err := s.store.HasAssignment(r.Context(), m.ID, req.ClassID, req.SubjectID)
		if err != nil || !allowed {
			fail(w, http.StatusForbidden, "forbidden", "you are not assigned to this class+subject")
			return
		}
	}
	// A finalized result is sealed; unfinalize from the portal first.
	finalized, err := s.store.ResultFinalized(r.Context(), req.StudentID, req.Term, req.Session)
	if err == nil && finalized {
		fail(w, http.StatusConflict, "result_finalized", "this result is finalized; unfinalize it first")
		return
	}
	item, err := s.store.SaveResultItem(r.Context(), m.SchoolID, req.StudentID, req.ClassID,
		req.SubjectID, req.Term, req.Session, req.CA1, req.CA2, req.Exam, m.UserID)
	if err != nil {
		s.log.Error("save result item", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save the scores")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"item": item})
}

type finalizeReq struct {
	SchoolID string `json:"schoolId"`
	ClassID  string `json:"classId"`
	Term     int    `json:"term"`
	Session  string `json:"session"`
}

// POST /school/finalize - compute positions + averages, seal results and
// mint the per-student result-check PINs.
func (s *Server) handleSchoolFinalize(w http.ResponseWriter, r *http.Request) {
	var req finalizeReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, req.SchoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	if req.ClassID == "" || req.Term < 1 || req.Term > 3 {
		fail(w, http.StatusBadRequest, "invalid_body", "classId and term (1-3) are required")
		return
	}
	n, err := s.store.FinalizeResults(r.Context(), m.SchoolID, req.ClassID, req.Term, req.Session)
	if err != nil {
		s.log.Error("finalize results", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not finalize the results")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"finalized": n})
}

// GET /school/results?schoolId=&classId=&term=&session= - class grid.
func (s *Server) handleSchoolResults(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	q := r.URL.Query()
	classID := q.Get("classId")
	term, _ := queryInt(r, "term")
	session := q.Get("session")
	if classID == "" || term == 0 {
		fail(w, http.StatusBadRequest, "missing_params", "classId and term are required")
		return
	}
	grid, err := s.store.ResultsGrid(r.Context(), m.SchoolID, classID, term, session)
	if err != nil {
		s.log.Error("results grid", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the results")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"results": grid})
}

// GET /school/result-sheet?schoolId=&studentId=&term=&session=
func (s *Server) handleSchoolResultSheet(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	q := r.URL.Query()
	studentID := q.Get("studentId")
	term, _ := queryInt(r, "term")
	session := q.Get("session")
	if studentID == "" || term == 0 {
		fail(w, http.StatusBadRequest, "missing_params", "studentId and term are required")
		return
	}
	sheet, err := s.store.ResultSheet(r.Context(), m.SchoolID, studentID, term, session)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not load the result sheet")
		return
	}
	if sheet == nil {
		fail(w, http.StatusNotFound, "not_found", "student not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"result": sheet})
}

// GET /school/check-result?pin=&term=&session= - PUBLIC result check
// (the ggportal pattern: the 6-digit PIN is the student's credential).
func (s *Server) handleSchoolCheckResult(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	pin := strings.TrimSpace(q.Get("pin"))
	term, hasTerm := queryInt(r, "term")
	session := strings.TrimSpace(q.Get("session"))
	if pin == "" || !hasTerm || term < 1 || term > 3 || session == "" {
		fail(w, http.StatusBadRequest, "missing_params", "pin, term (1-3) and session are required")
		return
	}
	res, err := s.store.CheckResultByPIN(r.Context(), pin, term, session)
	if err != nil {
		s.log.Error("check result", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not check the result")
		return
	}
	if res == nil {
		fail(w, http.StatusNotFound, "no_result", "no finalized result matches that PIN, term and session")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"result": res})
}

// GET /school/curriculum - the raw seed catalog (for portal pickers).
func (s *Server) handleSchoolCurriculum(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"classes":  school.Classes,
		"subjects": school.Subjects,
	})
}
