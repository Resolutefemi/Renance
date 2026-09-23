package httpapi

import (
        "context"
        "errors"
        "net/http"
        "strings"

        "renance.dev/study-api/internal/store"
)

type profileRequest struct {
        Username    string   `json:"username"`
        FullName    string   `json:"fullName"`
        Institution string   `json:"institution"`
        GradeLevel  string   `json:"gradeLevel"`
        Exams       []string `json:"exams"`
        Subjects    []string `json:"subjects,omitempty"`
        TargetYear  *int     `json:"targetYear"`
}

// resolveSubjects keeps the daily subject combination honest across
// full-profile saves: the profile modal never edits the combination, so
// a payload that omits it carries the stored one forward instead of
// wiping it. Clients that DO send subjects (combo editors) win.
func (s *Server) resolveSubjects(ctx context.Context, uid string, incoming []string) []string {
        if incoming != nil {
                return dailySubjects(incoming)
        }
        existing, err := s.store.ProfileByUser(ctx, uid)
        if err != nil || existing == nil {
                return nil
        }
        return existing.Subjects
}

// handleUpdateProfile is the contextual profile modal target: full name,
// target institution, grade level, active examinations. Completion kicks
// the silent background asset sync.
func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        var req profileRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        req.Username = strings.ToLower(strings.TrimSpace(req.Username))
        req.FullName = strings.TrimSpace(req.FullName)
        req.Institution = strings.TrimSpace(req.Institution)
        req.GradeLevel = strings.TrimSpace(req.GradeLevel)

        // The web account-setup modal asks for the handle right here (email
        // registers a provisional seed). Empty username = legacy clients that
        // never send it - leave the existing handle untouched.
        if req.Username != "" {
                if !usernameRE.MatchString(req.Username) {
                        fail(w, http.StatusBadRequest, "invalid_username",
                                "username must be 3-24 chars: lowercase letters, digits, underscores")
                        return
                }
                if err := s.store.UpdateUsername(r.Context(), uid, req.Username); err != nil {
                        if errors.Is(err, store.ErrUniqueUsername) {
                                fail(w, http.StatusConflict, "username_taken", "that username is already taken")
                                return
                        }
                        s.log.Error("username update failed", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not save profile")
                        return
                }
        }

        if len(req.FullName) < 2 || len(req.FullName) > 120 {
                fail(w, http.StatusBadRequest, "invalid_fullName", "full name must be 2-120 characters")
                return
        }
        // The school no longer sits in the signup questions (founder rule:
        // it is picked once on the School Desk home, then only editable in
        // the profile), so the field is optional now.
        if len(req.Institution) > 160 {
                fail(w, http.StatusBadRequest, "invalid_institution", "institution must be at most 160 characters")
                return
        }
        if len(req.GradeLevel) > 60 {
                fail(w, http.StatusBadRequest, "invalid_gradeLevel", "grade level must be at most 60 characters")
                return
        }
        if len(req.Exams) == 0 || len(req.Exams) > 4 {
                fail(w, http.StatusBadRequest, "invalid_exams", "select between 1 and 4 active examinations")
                return
        }
        if req.TargetYear != nil && (*req.TargetYear < 2000 || *req.TargetYear > 2100) {
                fail(w, http.StatusBadRequest, "invalid_targetYear", "target year must be between 2000 and 2100")
                return
        }
        seen := map[string]struct{}{}
        for _, e := range req.Exams {
                if _, dup := seen[e]; dup {
                        fail(w, http.StatusBadRequest, "invalid_exams", "duplicate examination: "+e)
                        return
                }
                seen[e] = struct{}{}
                if _, ok := s.allowed[e]; !ok {
                        fail(w, http.StatusBadRequest, "invalid_exams",
                                "examinations must be chosen from: JAMB, WAEC, NECO, POST-UTME, University Modules")
                        return
                }
        }

        profile, err := s.store.UpsertProfile(r.Context(), uid, &store.Profile{
                FullName:    req.FullName,
                Institution: req.Institution,
                GradeLevel:  req.GradeLevel,
                Exams:       req.Exams,
                Subjects:    s.resolveSubjects(r.Context(), uid, req.Subjects),
                TargetYear:  req.TargetYear,
                Completed:   true,
        })
        if err != nil {
                s.log.Error("profile upsert failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not save profile")
                return
        }

        // Silent background asset sync starts the moment preferences land.
        s.syncer.Kick(uid)

        resp := map[string]any{
                "profile": profile,
                "sync":    "kicked",
        }
        // Echo the (possibly renamed) identity back so clients refresh the
        // stored session user without a second round-trip.
        if req.Username != "" {
                resp["user"] = userPayload{ID: uid, Username: req.Username, ProfileCompleted: true}
        }
        writeJSON(w, http.StatusOK, resp)
}

// dailySubjectsRequest is the daily CBT combination picker's payload.
type dailySubjectsRequest struct {
        Subjects []string `json:"subjects"`
}

// handleSetDailySubjects stores the caller's daily subject combination
// (the first daily tap asks for it; every daily sprint afterwards draws
// only these subjects). A light endpoint on purpose: the daily picker
// can run before the full profile modal ever opens, so it must not be
// forced to echo the whole profile back.
func (s *Server) handleSetDailySubjects(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        var req dailySubjectsRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        subjects := dailySubjects(req.Subjects)
        if len(subjects) == 0 {
                fail(w, http.StatusBadRequest, "invalid_subjects",
                        "pick at least one subject (slug shapes: letters, digits, dashes)")
                return
        }
        if err := s.store.SetDailySubjects(r.Context(), uid, subjects); err != nil {
                s.log.Error("daily subjects save failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not save the subject combination")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{"subjects": subjects})
}
