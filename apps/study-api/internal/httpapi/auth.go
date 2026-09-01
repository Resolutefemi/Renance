package httpapi

import (
	"errors"
	"net/http"
	"regexp"
	"strings"

	"golang.org/x/crypto/bcrypt"

	"renance.dev/study-api/internal/jwtx"
	"renance.dev/study-api/internal/store"
)

// Minimal credential flow (founder spec): registration captures STRICTLY
// username + password. Scholar attributes arrive later via the profile modal.
var usernameRE = regexp.MustCompile(`^[a-z0-9_]{3,24}$`)

type credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type userPayload struct {
	ID               string `json:"id"`
	Username         string `json:"username"`
	ProfileCompleted bool   `json:"profileCompleted"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req credentials
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Username = strings.ToLower(strings.TrimSpace(req.Username))
	if !usernameRE.MatchString(req.Username) {
		fail(w, http.StatusBadRequest, "invalid_username",
			"username must be 3-24 chars: lowercase letters, digits, underscores")
		return
	}
	if len(req.Password) < 8 || len(req.Password) > 72 {
		fail(w, http.StatusBadRequest, "invalid_password", "password must be 8-72 characters")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		s.log.Error("bcrypt hash failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not register")
		return
	}

	u, err := s.store.CreateUser(r.Context(), req.Username, string(hash))
	if errors.Is(err, store.ErrUniqueUsername) {
		fail(w, http.StatusConflict, "username_taken", "that username is already taken")
		return
	}
	if err != nil {
		s.log.Error("create user failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not register")
		return
	}
	s.finishAuth(w, http.StatusCreated, u, false)
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req credentials
	if !decodeJSON(w, r, &req) {
		return
	}
	u, err := s.store.UserByUsername(r.Context(), strings.TrimSpace(req.Username))
	if err != nil {
		s.log.Error("login lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not log in")
		return
	}
	// Generic error whether the user is missing or the password is wrong.
	if u == nil || bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
		fail(w, http.StatusUnauthorized, "invalid_credentials", "invalid username or password")
		return
	}

	profile, err := s.store.ProfileByUser(r.Context(), u.ID)
	if err != nil {
		s.log.Error("profile lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not log in")
		return
	}
	s.finishAuth(w, http.StatusOK, u, profile != nil && profile.Completed)
}

func (s *Server) finishAuth(w http.ResponseWriter, status int, u *store.User, profileCompleted bool) {
	token, err := jwtx.Issue(u.ID, u.Username, s.cfg.JWTSecret)
	if err != nil {
		s.log.Error("token issue failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not log in")
		return
	}
	writeJSON(w, status, map[string]any{
		"token": token,
		"user":  userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profileCompleted},
	})
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	u, err := s.store.UserByID(r.Context(), uid)
	if err != nil || u == nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "unknown user")
		return
	}
	profile, err := s.store.ProfileByUser(r.Context(), uid)
	if err != nil {
		s.log.Error("profile lookup failed", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load profile")
		return
	}
	resp := map[string]any{
		"user": userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profile != nil && profile.Completed},
	}
	if profile != nil {
		resp["profile"] = profile
	} else {
		resp["profile"] = nil
	}
	writeJSON(w, http.StatusOK, resp)
}
