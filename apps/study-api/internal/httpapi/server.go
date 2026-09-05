// Package httpapi wires the study API's HTTP surface.
//
// Routes (all JSON):
//
//	GET    /healthz
//	POST   /auth/register          {username, password}   ← THE ONLY FIELDS
//	POST   /auth/login             {username, password}
//	GET    /me
//	GET    /me/attempts           -> paper history (newest first)
//	GET    /me/gamification     -> streaks, XP, badges (zero state on first launch)
//	GET    /me/review            -> spaced-repetition queue (due today + upcoming)
//	GET    /me/fatigue           -> current take-a-break advisory (ROADMAP #6)
//	POST   /me/sessions          -> log one sitting's telemetry, signal out
//	GET    /me/cards/progress    -> flashcard Leitner state
//	POST   /me/cards/progress    -> batch-grade flashcards
//	GET    /flashcards           -> deck list
//	GET    /flashcards/{code}    -> one deck with cards
//	GET    /lessons              -> lesson list (ROADMAP #8)
//	GET    /lessons/{slug}       -> one lesson with sections
//	GET    /career               -> curated scholarships + course paths (ROADMAP #18)
//	GET    /tutor/status         -> {aiEnabled} (ROADMAP #9)
//	POST   /attempts/{id}/tutor  -> Socratic chat on a graded attempt
//	PUT    /me/profile             {fullName, institution, gradeLevel, exams[], targetYear?}
//	GET    /manifest
//	GET    /bundles/{code}
//	POST   /attempts               {code}
//	POST   /attempts/{id}/submit   {answers:[{questionId, selected}], durationMs?}
//	GET    /attempts/{id}
//	GET    /attempts/{id}/review -> per-question review (graded attempts only)
//	GET    /sync/status
package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/config"
	"renance.dev/study-api/internal/googleid"
	"renance.dev/study-api/internal/grading"
	"renance.dev/study-api/internal/jwtx"
	"renance.dev/study-api/internal/store"
	"renance.dev/study-api/internal/tutor"
)

type Server struct {
	cfg     *config.Config
	log     *slog.Logger
	store   *store.Store
	lib     *cbtdata.Library
	engine  *grading.Engine
	syncer  syncerKicker
	google  *googleid.Verifier
	allowed map[string]struct{}

	tutor      *tutor.Tutor
	limiter    *rateLimiter
	authIP     *rateLimiter
	authGlobal *rateLimiter
}

// syncerKicker is the narrow interface the handlers need from the syncer.
type syncerKicker interface {
	Kick(userID string)
}

func NewServer(cfg *config.Config, log *slog.Logger, st *store.Store, lib *cbtdata.Library, eng *grading.Engine, sync syncerKicker) *Server {
	s := &Server{
		cfg: cfg, log: log, store: st, lib: lib, engine: eng, syncer: sync,
		allowed: map[string]struct{}{
			"JAMB": {}, "WAEC": {}, "NECO": {}, "University Modules": {},
		},
	}
	// Google sign-in is OPTIONAL per deployment: unset GOOGLE_CLIENT_ID
	// keeps POST /auth/google cleanly disabled (503) with zero partial UI.
	// The value may be a comma-separated list, the web OAuth client AND
	// the Android client, and tokens minted for either are accepted.
	if cfg.GoogleClientID != "" {
		s.google = googleid.New(strings.Split(cfg.GoogleClientID, ",")...)
	}
	// The tutor ALWAYS exists; an empty AI_API_KEY just leaves its
	// provider nil, which switches Reply() into deterministic hint mode.
	s.tutor = &tutor.Tutor{MaxTokens: cfg.AIMaxTokens, Log: log}
	if cfg.AIAPIKey != "" {
		s.tutor.Provider = &tutor.OpenAICompat{BaseURL: cfg.AIBaseURL, APIKey: cfg.AIAPIKey, Model: cfg.AIModel}
	}
	s.limiter = newRateLimiter(cfg.TutorPerMin, cfg.TutorPerMin)
	s.authIP = newRateLimiter(cfg.AuthPerMin, cfg.AuthPerMin*2)
	s.authGlobal = newRateLimiter(cfg.AuthGlobalPerMin, cfg.AuthGlobalPerMin)
	return s
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.HandleFunc("POST /auth/register", s.authLimit(s.handleRegister))
	mux.HandleFunc("POST /auth/login", s.authLimit(s.handleLogin))
	mux.HandleFunc("POST /auth/google", s.authLimit(s.handleGoogleAuth))

	mux.HandleFunc("GET /me", s.auth(s.handleMe))
	mux.HandleFunc("GET /me/attempts", s.auth(s.handleListAttempts))
	mux.HandleFunc("GET /me/gamification", s.auth(s.handleGamification))
	mux.HandleFunc("GET /me/review", s.auth(s.handleReviewQueue))
	mux.HandleFunc("GET /me/fatigue", s.auth(s.handleFatigue))
	mux.HandleFunc("POST /me/sessions", s.auth(s.handleLogSession))
	mux.HandleFunc("GET /me/cards/progress", s.auth(s.handleCardProgress))
	mux.HandleFunc("POST /me/cards/progress", s.auth(s.handleGradeCards))
	mux.HandleFunc("GET /syllabus/{body}", s.auth(s.handleSyllabus))
	mux.HandleFunc("GET /flashcards", s.auth(s.handleFlashcardDecks))
	mux.HandleFunc("GET /flashcards/{code}", s.auth(s.handleFlashcardDeck))
	mux.HandleFunc("GET /lessons", s.auth(s.handleLessons))
	mux.HandleFunc("GET /lessons/{slug}", s.auth(s.handleLesson))
	mux.HandleFunc("GET /career", s.auth(s.handleCareer))
	mux.HandleFunc("GET /tutor/status", s.auth(s.handleTutorStatus))
	mux.HandleFunc("GET /internal/review/tick", s.handleReviewTick)
	mux.HandleFunc("PUT /me/profile", s.auth(s.handleUpdateProfile))
	mux.HandleFunc("GET /manifest", s.auth(s.handleManifest))
	mux.HandleFunc("GET /bundles/{code}", s.auth(s.handleBundle))

	mux.HandleFunc("POST /attempts", s.auth(s.handleCreateAttempt))
	mux.HandleFunc("POST /attempts/{id}/submit", s.auth(s.handleSubmitAttempt))
	mux.HandleFunc("POST /attempts/{id}/tutor", s.auth(s.handleAttemptTutor))
	mux.HandleFunc("GET /attempts/{id}", s.auth(s.handleGetAttempt))
	mux.HandleFunc("GET /attempts/{id}/review", s.auth(s.handleAttemptReview))
	mux.HandleFunc("GET /sync/status", s.auth(s.handleSyncStatus))

	return s.securityHeaders(s.cors(mux))
}

// ------------------------------------------------------------------ glue

type ctxKey int

const (
	ctxUserID ctxKey = iota
	ctxUsername
)

func (s *Server) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			fail(w, http.StatusUnauthorized, "unauthorized", "missing bearer token")
			return
		}
		claims, err := jwtx.Verify(strings.TrimPrefix(header, "Bearer "), s.cfg.JWTSecret)
		if err != nil {
			fail(w, http.StatusUnauthorized, "unauthorized", "invalid or expired token")
			return
		}
		ctx := r.Context()
		ctx = contextWith(ctx, ctxUserID, claims.UserID)
		ctx = contextWith(ctx, ctxUsername, claims.Username)
		next(w, r.WithContext(ctx))
	}
}

// cors resolves Access-Control-Allow-Origin from WEB_ORIGIN, a
// comma-separated allowlist (e.g. "https://resolutefemi.github.io,
// http://localhost:3000"). "*" keeps the wide-open dev default. Native
// Flutter clients need no CORS at all; unmatched origins simply get no ACAO
// header (curl and the mobile apps are unaffected).
func (s *Server) cors(next http.Handler) http.Handler {
	wildcard := false
	allowed := map[string]struct{}{}
	for _, o := range strings.Split(s.cfg.WebOrigin, ",") {
		if o = strings.TrimSpace(o); o != "" {
			if o == "*" {
				wildcard = true
			}
			allowed[o] = struct{}{}
		}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		switch {
		case wildcard:
			w.Header().Set("Access-Control-Allow-Origin", "*")
		case origin != "":
			if _, ok := allowed[origin]; ok {
				w.Header().Set("Access-Control-Allow-Origin", origin)
			}
		}
		w.Header().Set("Vary", "Origin")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "86400")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ------------------------------------------------------------- responses

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

type errBody struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func fail(w http.ResponseWriter, status int, code, msg string) {
	var b errBody
	b.Error.Code, b.Error.Message = code, msg
	writeJSON(w, status, b)
}

// decodeJSON strictly parses a request body into dst (unknown fields rejected).
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		fail(w, http.StatusBadRequest, "invalid_body", truncateErr(err))
		return false
	}
	return true
}

func truncateErr(err error) string {
	msg := err.Error()
	if len(msg) > 200 {
		msg = msg[:200]
	}
	return msg
}

var errNoUser = errors.New("no user in context")

func contextWith[V any](ctx context.Context, k ctxKey, v V) context.Context {
	return context.WithValue(ctx, k, v)
}

func userIDFrom(r *http.Request) (string, error) {
	v, ok := r.Context().Value(ctxUserID).(string)
	if !ok || v == "" {
		return "", errNoUser
	}
	return v, nil
}
