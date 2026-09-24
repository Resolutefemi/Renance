// School-setup HTTP surface: school profile + logo, subject departments
// and class-subject wiring, full student detail forms with per-student
// subject offerings, attendance (roster + kiosk + summary) and the bulk
// topic import the legal content scraper pours through.
package httpapi

import (
	"net/http"
	"regexp"
	"strings"

	"renance.dev/study-api/internal/store"
)

// ---------------------------------------------------------------- school

// GET /school/profile - the school identity row (name, type, address,
// logo) for the portal chrome and the setup page.
func (s *Server) handleSchoolGetProfile(w http.ResponseWriter, r *http.Request) {
	m, sc, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	_ = m
	writeJSON(w, http.StatusOK, map[string]any{"school": sc})
}

// PUT /school/profile - management edits the school identity: name,
// address and logo (a data URL stamped on report cards + the portal).
func (s *Server) handleSchoolProfile(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name      string `json:"name"`
		Address   string `json:"address"`
		LogoURL   string `json:"logoUrl"`
		ClearLogo bool   `json:"clearLogo"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.LogoURL = strings.TrimSpace(req.LogoURL)
	if req.Name != "" && len(req.Name) > 160 {
		fail(w, http.StatusBadRequest, "invalid_name", "school name is too long")
		return
	}
	if req.LogoURL != "" && !validLogo(req.LogoURL) {
		fail(w, http.StatusBadRequest, "invalid_logo",
			"logo must be a small PNG/JPEG image (up to about 500 KB) or an https URL")
		return
	}
	if req.ClearLogo {
		if err := s.store.ClearSchoolLogo(r.Context(), m.SchoolID); err != nil {
			s.log.Error("clear school logo", "err", err)
			fail(w, http.StatusInternalServerError, "internal", "could not clear the logo")
			return
		}
	}
	if err := s.store.UpdateSchoolProfile(r.Context(), m.SchoolID, req.Name, req.Address, req.LogoURL); err != nil {
		s.log.Error("school profile update", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save the school profile")
		return
	}
	sc, err := s.store.SchoolByID(r.Context(), m.SchoolID)
	if err != nil || sc == nil {
		fail(w, http.StatusInternalServerError, "internal", "could not reload the school")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"school": sc})
}

// validLogo accepts inline data URLs (resized client-side) and https URLs.
var dataURLRe = regexp.MustCompile(`^data:image/(png|jpeg|jpg|webp);base64,[A-Za-z0-9+/=\s]+$`)

func validLogo(u string) bool {
	if strings.HasPrefix(u, "https://") && len(u) <= 2048 {
		return true
	}
	return len(u) <= 700_000 && dataURLRe.MatchString(u)
}

// -------------------------------------------------------------- subjects

// POST /school/subject - management adds a school subject (NERDC name
// or custom), optionally tagged with its senior department.
func (s *Server) handleSchoolCreateSubject(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name       string `json:"name"`
		Code       string `json:"code"`
		Level      string `json:"level"`
		Department string `json:"department"`
		IsCore     bool   `json:"isCore"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Code = strings.ToUpper(strings.TrimSpace(req.Code))
	req.Level = strings.TrimSpace(req.Level)
	req.Department = strings.TrimSpace(req.Department)
	if req.Name == "" || len(req.Name) > 120 {
		fail(w, http.StatusBadRequest, "invalid_name", "subject name is required")
		return
	}
	if req.Level != "primary" && req.Level != "junior" && req.Level != "senior" && req.Level != "both" {
		fail(w, http.StatusBadRequest, "invalid_level", "level must be primary, junior, senior or both")
		return
	}
	if !validDepartment(req.Department) {
		fail(w, http.StatusBadRequest, "invalid_department", "department must be art, science or commercial")
		return
	}
	sub, err := s.store.CreateSubject(r.Context(), m.SchoolID, req.Name, req.Code, req.Level, req.Department, req.IsCore)
	if err != nil {
		s.log.Error("create subject", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not create the subject")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"subject": sub})
}

// PUT /school/subject - management edits a subject (department, core
// flag, name or code).
func (s *Server) handleSchoolUpdateSubject(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID         string `json:"id"`
		Name       string `json:"name"`
		Code       string `json:"code"`
		Department string `json:"department"`
		IsCore     *bool  `json:"isCore"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Department = strings.TrimSpace(req.Department)
	if req.ID == "" {
		fail(w, http.StatusBadRequest, "missing_id", "subject id is required")
		return
	}
	if !validDepartment(req.Department) {
		fail(w, http.StatusBadRequest, "invalid_department", "department must be art, science or commercial")
		return
	}
	if err := s.store.UpdateSubject(r.Context(), req.ID, req.Name, strings.ToUpper(strings.TrimSpace(req.Code)), req.Department, req.IsCore); err != nil {
		s.log.Error("update subject", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not update the subject")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// POST /school/class-subject - management wires or unwires a subject
// into a class. SSS classes usually take core + their chosen tracks.
func (s *Server) handleSchoolClassSubject(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClassID   string `json:"classId"`
		SubjectID string `json:"subjectId"`
		Remove    bool   `json:"remove"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	if req.ClassID == "" || req.SubjectID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "classId and subjectId are required")
		return
	}
	var err error
	if req.Remove {
		err = s.store.RemoveClassSubject(r.Context(), m.SchoolID, req.ClassID, req.SubjectID)
	} else {
		err = s.store.AddClassSubject(r.Context(), m.SchoolID, req.ClassID, req.SubjectID)
	}
	if err != nil {
		fail(w, http.StatusBadRequest, "invalid_pair", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func validDepartment(d string) bool {
	switch d {
	case "", "art", "science", "commercial":
		return true
	}
	return false
}

// -------------------------------------------------------------- students

// GET /school/student-detail?studentId= - the full enrollment record.
func (s *Server) handleSchoolStudentDetail(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	studentID := r.URL.Query().Get("studentId")
	if studentID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "studentId is required")
		return
	}
	d, err := s.store.StudentByID(r.Context(), m.SchoolID, studentID)
	if err != nil {
		fail(w, http.StatusNotFound, "not_found", "student not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"student": d})
}

// PUT /school/student - management edits the enrollment record.
func (s *Server) handleSchoolUpdateStudent(w http.ResponseWriter, r *http.Request) {
	var req store.StudentDetail
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.FullName = strings.TrimSpace(req.FullName)
	if req.ID == "" || req.FullName == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "student id and full name are required")
		return
	}
	req.Sex = strings.TrimSpace(req.Sex)
	if req.Sex != "" && req.Sex != "M" && req.Sex != "F" {
		fail(w, http.StatusBadRequest, "invalid_sex", "sex must be M or F")
		return
	}
	if err := s.store.UpdateStudent(r.Context(), m.SchoolID, req.ID, req); err != nil {
		fail(w, http.StatusBadRequest, "could_not_save", err.Error())
		return
	}
	d, err := s.store.StudentByID(r.Context(), m.SchoolID, req.ID)
	if err != nil {
		fail(w, http.StatusInternalServerError, "internal", "could not reload the student")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"student": d})
}

// GET /school/student-subjects?studentId= - the explicit offering.
func (s *Server) handleSchoolStudentSubjects(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	studentID := r.URL.Query().Get("studentId")
	if studentID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "studentId is required")
		return
	}
	d, err := s.store.StudentByID(r.Context(), m.SchoolID, studentID)
	if err != nil {
		fail(w, http.StatusNotFound, "not_found", "student not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"subjectIds": d.Subjects})
}

// PUT /school/student-subjects - management sets the offering. An empty
// list clears back to "everything the class does".
func (s *Server) handleSchoolSetStudentSubjects(w http.ResponseWriter, r *http.Request) {
	var req struct {
		StudentID  string   `json:"studentId"`
		SubjectIDs []string `json:"subjectIds"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	if req.StudentID == "" {
		fail(w, http.StatusBadRequest, "missing_params", "studentId is required")
		return
	}
	if err := s.store.SetStudentSubjects(r.Context(), m.SchoolID, req.StudentID, req.SubjectIDs); err != nil {
		fail(w, http.StatusBadRequest, "could_not_save", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ------------------------------------------------------------ attendance

// GET /school/attendance?schoolId=&classId=&day=YYYY-MM-DD
func (s *Server) handleSchoolAttendanceDay(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	q := r.URL.Query()
	classID, day := q.Get("classId"), q.Get("day")
	if classID == "" || !validDay(day) {
		fail(w, http.StatusBadRequest, "missing_params", "classId and day (YYYY-MM-DD) are required")
		return
	}
	entries, err := s.store.AttendanceDay(r.Context(), m.SchoolID, classID, day)
	if err != nil {
		s.log.Error("attendance day", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load attendance")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": entries})
}

// POST /school/attendance - management, or a teacher assigned to the
// class, saves a day's marks (the roster) or a single kiosk tap.
func (s *Server) handleSchoolAttendanceSave(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClassID string                  `json:"classId"`
		Day     string                  `json:"day"`
		Entries []store.AttendanceEntry `json:"entries"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	req.Day = strings.TrimSpace(req.Day)
	if req.ClassID == "" || !validDay(req.Day) || len(req.Entries) == 0 {
		fail(w, http.StatusBadRequest, "invalid_body", "classId, day (YYYY-MM-DD) and entries are required")
		return
	}
	if m.Role != "management" {
		assigned, err := s.store.TeacherAssignedClass(r.Context(), m.ID, req.ClassID)
		if err != nil {
			fail(w, http.StatusInternalServerError, "internal", "could not check your assignments")
			return
		}
		if !assigned {
			fail(w, http.StatusForbidden, "forbidden", "you are not assigned to this class")
			return
		}
	}
	if len(req.Entries) > 500 {
		fail(w, http.StatusBadRequest, "too_many", "split the save into smaller batches")
		return
	}
	n, err := s.store.SaveAttendance(r.Context(), m.SchoolID, req.ClassID, req.Day, userID(m), req.Entries)
	if err != nil {
		s.log.Error("attendance save", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save attendance")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"saved": n})
}

// GET /school/attendance-summary?schoolId=&classId=&from=&to=
func (s *Server) handleSchoolAttendanceSummary(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	q := r.URL.Query()
	classID, from, to := q.Get("classId"), q.Get("from"), q.Get("to")
	if classID == "" || !validDay(from) || !validDay(to) {
		fail(w, http.StatusBadRequest, "missing_params", "classId, from and to (YYYY-MM-DD) are required")
		return
	}
	rows, err := s.store.AttendanceSummary(r.Context(), m.SchoolID, classID, from, to)
	if err != nil {
		s.log.Error("attendance summary", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the summary")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"summary": rows})
}

func validDay(day string) bool {
	if len(day) != 10 || day[4] != '-' || day[7] != '-' {
		return false
	}
	for i, ch := range day {
		if i == 4 || i == 7 {
			continue
		}
		if ch < '0' || ch > '9' {
			return false
		}
	}
	return true
}

// ----------------------------------------------------------- bulk import

// POST /school/bulk-notes - management pours a scraped topic corpus into
// one class+subject+term syllabus. Topics upsert by title; overwrite
// =false only fills topics whose content is still empty, so re-pouring a
// growing corpus never clobbers teacher edits.
func (s *Server) handleSchoolBulkNotes(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClassID   string            `json:"classId"`
		SubjectID string            `json:"subjectId"`
		Term      int               `json:"term"`
		Session   string            `json:"session"`
		Overwrite bool              `json:"overwrite"`
		Topics    []store.BulkTopic `json:"topics"`
	}
	schoolID, ok := decodeSchoolScope(w, r, &req)
	if !ok {
		return
	}
	m, _, ok := s.memberAndSchool(w, r, schoolID)
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	req.Session = strings.TrimSpace(req.Session)
	if req.ClassID == "" || req.SubjectID == "" || req.Term < 1 || req.Term > 3 {
		fail(w, http.StatusBadRequest, "invalid_body", "classId, subjectId and term (1-3) are required")
		return
	}
	if len(req.Topics) == 0 {
		fail(w, http.StatusBadRequest, "invalid_body", "topics list is empty")
		return
	}
	if len(req.Topics) > 500 {
		fail(w, http.StatusBadRequest, "too_many", "import at most 500 topics per call")
		return
	}
	for i := range req.Topics {
		req.Topics[i].Title = strings.TrimSpace(req.Topics[i].Title)
		req.Topics[i].Content = strings.TrimSpace(req.Topics[i].Content)
		req.Topics[i].Source = strings.TrimSpace(req.Topics[i].Source)
		if len(req.Topics[i].Content) > 80_000 {
			req.Topics[i].Content = req.Topics[i].Content[:80_000]
		}
		// Founder content rule: the long hyphen never ships.
		req.Topics[i].Title = normalizeHyphens(req.Topics[i].Title)
		req.Topics[i].Content = normalizeHyphens(req.Topics[i].Content)
	}
	n, err := s.store.BulkUpsertTopics(r.Context(), m.SchoolID, req.ClassID, req.SubjectID, req.Term, req.Session, req.Overwrite, req.Topics)
	if err != nil {
		s.log.Error("bulk notes import", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not import the topics")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"written": n, "received": len(req.Topics)})
}

// normalizeHyphens enforces the "never use the long hyphen" rule on
// imported content: em dashes, en dashes and double hyphens become a
// single plain hyphen.
var hyphenRun = regexp.MustCompile(`\s*[-\x{2010}-\x{2015}]{2,}\s*`)

func normalizeHyphens(s string) string {
	return hyphenRun.ReplaceAllString(s, " - ")
}

// -------------------------------------------------------------- helpers

func userID(m *store.SchoolMember) string { return m.UserID }
