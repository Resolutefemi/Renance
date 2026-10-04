// Package httpapi wires the study API's HTTP surface.
//
// Routes (all JSON):
//
//      GET    /healthz
//      POST   /auth/register          {email, password} (web) or {username, password} (legacy mobile)
//      POST   /auth/login             {email, password} or {username, password}
//      GET    /me
//      GET    /me/attempts           -> paper history (newest first)
//      GET    /me/gamification     -> streaks, XP, badges (zero state on first launch)
//      GET    /me/review            -> spaced-repetition queue (due today + upcoming)
//      GET    /me/fatigue           -> current take-a-break advisory (ROADMAP #6)
//      POST   /me/sessions          -> log one sitting's telemetry, signal out
//      GET    /me/cards/progress    -> flashcard Leitner state
//      POST   /me/cards/progress    -> batch-grade flashcards
//      GET    /flashcards           -> deck list
//      GET    /flashcards/{code}    -> one deck with cards
//      GET    /lessons              -> lesson list (ROADMAP #8)
//      GET    /lessons/{slug}       -> one lesson with sections
//      GET    /career               -> curated scholarships + course paths (ROADMAP #18)
//      GET    /arena/ws             -> live 1v1 quiz socket (?token=, ROADMAP #14); "host"/"join" open private room-code lobbies
//      GET    /arena/status         -> lobby state (waiting buckets, live matches)
//      GET    /arena/history        -> the caller's recent matches
//      GET    /tutor/status         -> {aiEnabled} (ROADMAP #9)
//      POST   /attempts/{id}/tutor  -> Socratic chat on a graded attempt
//      GET    /daily/{body}        -> today's deterministic challenge (ROADMAP #20)
//      GET    /daily/{body}/leaderboard?day= -> one day's board + caller's rank
//      PUT    /me/profile             {fullName, institution, gradeLevel, exams[], targetYear?}
//      GET    /manifest
//      GET    /bundles/{code}
//      POST   /attempts               {code}
//      POST   /attempts/{id}/submit   {answers:[{questionId, selected}], durationMs?}
//      GET    /attempts/{id}
//      GET    /attempts/{id}/review -> per-question review (graded attempts only)
//      GET    /sync/status
package httpapi

import (
        "bytes"
        "context"
        "encoding/json"
        "errors"
        "io"
        "log/slog"
        "net/http"
        "strings"
        "sync"
        "time"

        "renance.dev/study-api/internal/arena"
        "renance.dev/study-api/internal/cbtdata"
        "renance.dev/study-api/internal/config"
        "renance.dev/study-api/internal/googleid"
        "renance.dev/study-api/internal/grading"
        "renance.dev/study-api/internal/jwtx"
        "renance.dev/study-api/internal/schoolcorpus"
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

        // keys resolves sealed answer keys; mock papers also grow it at
        // runtime via the Put hook (see paper.go).
        keys grading.KeySource
        // mockMu serializes composite mock-paper composition.
        mockMu sync.Mutex

        // ROADMAP #14: the in-process arena hub. nil keeps every /arena
        // route on a clean 503 (e.g. unit tests that skip it).
        arena     *arena.Hub
        arenaSock *arena.SocketHandler

        tutor      *tutor.Tutor
        limiter    *rateLimiter
        authIP     *rateLimiter
        authGlobal *rateLimiter
        // resetBudget caps the total reset mails per UTC day (the
        // founder's Brevo free-tier quota armor).
        resetBudget *dailyMailBudget

        // National curriculum corpus (schemes + notes) read straight
        // from the data folder; nil keeps the routes returning clean
        // empty lists (unit tests without a data dir).
        corpus *schoolcorpus.Corpus
}

// syncerKicker is the narrow interface the handlers need from the syncer.
type syncerKicker interface {
        Kick(userID string)
}

func NewServer(cfg *config.Config, log *slog.Logger, st *store.Store, lib *cbtdata.Library, eng *grading.Engine, sync syncerKicker, keys grading.KeySource) *Server {
        s := &Server{
                cfg: cfg, log: log, store: st, lib: lib, engine: eng, syncer: sync, keys: keys,
                allowed: map[string]struct{}{
                        "JAMB": {}, "WAEC": {}, "NECO": {}, "POST-UTME": {}, "University Modules": {},
                },
        }
        // Google sign-in is OPTIONAL per deployment: unset GOOGLE_CLIENT_ID
        // keeps POST /auth/google cleanly disabled (503) with zero partial UI.
        // The value may be a comma-separated list, the web OAuth client AND
        // the Android client, and tokens minted for either are accepted.
        if cfg.GoogleClientID != "" {
                s.google = googleid.New(strings.Split(cfg.GoogleClientID, ",")...)
        }
        // The tutor ALWAYS exists; with no key configured at all its
        // provider stays nil, which switches Reply() into deterministic
        // hint mode. Founder setup: Z.ai ONLY (AI_API_KEY) - Groq's key
        // was revoked and the provider removed, Gemini is gone.
        s.tutor = &tutor.Tutor{MaxTokens: cfg.AIMaxTokens, Log: log}
        if cfg.AIAPIKey != "" {
                s.tutor.Provider = &tutor.OpenAICompat{
                        BaseURL: cfg.AIBaseURL, APIKey: cfg.AIAPIKey, Model: cfg.AIModel, Thinking: cfg.AIThinking,
                        // The provider's own wall must clear the studio's async
                        // budget: generation runs off-request with a 90s context,
                        // and big documents (notebooks) legitimately take 30-60s
                        // on the free GLM tier. The default 30s client was cutting
                        // every notebook attempt in half.
                        HTTP: &http.Client{Timeout: 85 * time.Second},
                }
        }
        s.limiter = newRateLimiter(cfg.TutorPerMin, cfg.TutorPerMin)
        s.authIP = newRateLimiter(cfg.AuthPerMin, cfg.AuthPerMin*2)
        s.authGlobal = newRateLimiter(cfg.AuthGlobalPerMin, cfg.AuthGlobalPerMin)
        s.resetBudget = newDailyMailBudget(cfg.ResetMailDailyCap)
        if cfg.DataDir != "" {
                s.corpus = schoolcorpus.Load(cfg.DataDir)
        }
        // The arena boots whenever an answer-key source exists; without one
        // no pack can be scored and every route stays a clean 503.
        if keys != nil {
                s.arena = arena.NewHub(arenaConfig(cfg), newPackSource(lib, keys), arenaSink(st), log)
                s.arenaSock = &arena.SocketHandler{Hub: s.arena, Log: log}
        }
        return s
}

// Hub exposes the arena hub so main can stop it on shutdown. Nil when
// the arena never booted.
func (s *Server) Hub() *arena.Hub { return s.arena }

func arenaConfig(cfg *config.Config) arena.Config {
        return arena.Config{
                Questions:          cfg.ArenaQuestions,
                SecondsPerQuestion: cfg.ArenaSecondsPerQuestion,
                IntroCountdown:     time.Duration(cfg.ArenaIntroSeconds) * time.Second,
                BotWait:            time.Duration(cfg.ArenaBotWaitSeconds) * time.Second,
                BotSkill:           cfg.ArenaBotSkill,
                RoomTTL:            time.Duration(cfg.ArenaRoomTTLSeconds) * time.Second,
        }
}

func (s *Server) Handler() http.Handler {
        mux := http.NewServeMux()

        mux.HandleFunc("GET /healthz", s.handleHealth)
        // The mobile update gate's version check (founder directive
        // 2026-10-04): public, unauthenticated - the app reads it before
        // any sign-in through https://renance.app/api/app-version.
        mux.HandleFunc("GET /app-version", s.handleAppVersion)
        mux.HandleFunc("POST /auth/register", s.authLimit(s.handleRegister))
        mux.HandleFunc("POST /auth/login", s.authLimit(s.handleLogin))
        mux.HandleFunc("POST /auth/google", s.authLimit(s.handleGoogleAuth))
        // Forgot password (founder directive 2026-10-02): request a
        // single-use reset link by email or username, then consume it.
        mux.HandleFunc("POST /auth/forgot-password", s.authLimit(s.handleForgotPassword))
        mux.HandleFunc("POST /auth/reset-password", s.authLimit(s.handleResetPassword))

        mux.HandleFunc("GET /me", s.auth(s.handleMe))
        // Account self-deletion (founder directive 2026-10-05): DELETE
        // /me purges the account and every row tied to it, activities
        // included - study.purge_user() in one transaction.
        mux.HandleFunc("DELETE /me", s.auth(s.handleDeleteAccount))
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
        mux.HandleFunc("GET /arena/ws", s.handleArenaWS)
        mux.HandleFunc("GET /arena/status", s.auth(s.handleArenaStatus))
        mux.HandleFunc("GET /arena/players", s.auth(s.handleArenaPlayers))
        mux.HandleFunc("GET /arena/history", s.auth(s.handleArenaHistory))
        mux.HandleFunc("GET /leaderboard/arena", s.auth(s.handleArenaLeaderboard))
        mux.HandleFunc("GET /leaderboard/focus", s.auth(s.handleFocusLeaderboard))
        mux.HandleFunc("GET /leaderboard/streak", s.auth(s.handleStreakLeaderboard))
        mux.HandleFunc("GET /daily/{body}", s.auth(s.handleDaily))
        mux.HandleFunc("GET /daily/{body}/leaderboard", s.auth(s.handleDailyLeaderboard))
        mux.HandleFunc("GET /tutor/status", s.auth(s.handleTutorStatus))
        mux.HandleFunc("POST /ai/generate", s.auth(s.handleAIGenerate))
        mux.HandleFunc("POST /ai/chat", s.auth(s.userLimit("ai", s.handleAIChat)))
        // Renance AI Studio: the past-question bridge, persistent
        // chats (folders + history + memories) and the document
        // generators (quiz / note / lesson note / notebook) with
        // shareable, exportable artifacts.
        mux.HandleFunc("GET /ai/bridge/stats", s.auth(s.handleBridgeStats))
        mux.HandleFunc("GET /ai/bridge/search", s.auth(s.handleBridgeSearch))
        mux.HandleFunc("GET /ai/chats", s.auth(s.handleListAIChats))
        mux.HandleFunc("POST /ai/chats", s.auth(s.handleCreateAIChat))
        mux.HandleFunc("GET /ai/chats/{id}", s.auth(s.handleGetAIChat))
        mux.HandleFunc("PATCH /ai/chats/{id}", s.auth(s.handleUpdateAIChat))
        mux.HandleFunc("DELETE /ai/chats/{id}", s.auth(s.handleDeleteAIChat))
        mux.HandleFunc("POST /ai/chats/{id}/messages", s.auth(s.userLimit("ai", s.handlePostChatMessage)))
        mux.HandleFunc("GET /ai/folders", s.auth(s.handleAIFolders))
        mux.HandleFunc("GET /ai/memories", s.auth(s.handleListAIMemories))
        mux.HandleFunc("POST /ai/memories", s.auth(s.handleAddAIMemory))
        mux.HandleFunc("DELETE /ai/memories/{id}", s.auth(s.handleDeleteAIMemory))
        mux.HandleFunc("POST /ai/quiz", s.auth(s.userLimit("ai", s.handleAIGenerateQuiz)))
        mux.HandleFunc("POST /ai/notes", s.auth(s.userLimit("ai", s.handleAIGenerateNote)))
        mux.HandleFunc("POST /ai/notes/from-text", s.auth(s.handleAINoteFromText))
        mux.HandleFunc("POST /ai/lesson-note", s.auth(s.userLimit("ai", s.handleAIGenerateLessonNote)))
        mux.HandleFunc("POST /ai/notebook", s.auth(s.userLimit("ai", s.handleAIGenerateNotebook)))
        mux.HandleFunc("GET /ai/artifacts", s.auth(s.handleListArtifacts))
        mux.HandleFunc("GET /ai/artifacts/{id}", s.auth(s.handleGetArtifact))
        mux.HandleFunc("DELETE /ai/artifacts/{id}", s.auth(s.handleDeleteArtifact))
        mux.HandleFunc("POST /ai/artifacts/{id}/share", s.auth(s.handleShareArtifact))
        mux.HandleFunc("GET /quiz/shared/{slug}", s.handleSharedQuiz)
        mux.HandleFunc("GET /internal/review/tick", s.handleReviewTick)
        // Management rescue for the device lock (lost/replaced phone):
        // clears a user's device binding after the student DMs management.
        mux.HandleFunc("POST /internal/device/unbind", s.handleDeviceUnbind)
        mux.HandleFunc("PUT /me/profile", s.auth(s.handleUpdateProfile))
        mux.HandleFunc("PUT /me/daily-subjects", s.auth(s.handleSetDailySubjects))
        mux.HandleFunc("GET /manifest", s.auth(s.handleManifest))
        mux.HandleFunc("GET /bundles/{code}", s.auth(s.handleBundle))
        mux.HandleFunc("GET /billing/plans", s.handleBillingPlans)
        mux.HandleFunc("POST /billing/paystack/initialize", s.auth(s.handleBillingInitialize))
        mux.HandleFunc("POST /billing/paystack/webhook", s.handlePaystackWebhook)
        mux.HandleFunc("POST /billing/redeem", s.auth(s.handleBillingRedeem))
        mux.HandleFunc("POST /auth/verify-email", s.handleVerifyEmail)
        mux.HandleFunc("POST /auth/resend-verification", s.auth(s.handleResendVerification))
        mux.HandleFunc("POST /auth/refresh", s.auth(s.handleRefreshSession))
        mux.HandleFunc("POST /me/change-email", s.auth(s.handleChangeEmail))
        mux.HandleFunc("GET /qimages/{name}", s.handleQImage)

        mux.HandleFunc("POST /attempts", s.auth(s.handleCreateAttempt))
        mux.HandleFunc("POST /attempts/{id}/submit", s.auth(s.handleSubmitAttempt))
        mux.HandleFunc("POST /attempts/{id}/tutor", s.auth(s.handleAttemptTutor))
        mux.HandleFunc("GET /attempts/{id}", s.auth(s.handleGetAttempt))
        mux.HandleFunc("GET /attempts/{id}/review", s.auth(s.handleAttemptReview))
        mux.HandleFunc("GET /sync/status", s.auth(s.handleSyncStatus))

        // school platform ---------------------------------------------------
        // School workspace DB separation (founder directive 2026-10-05,
        // "the school workspace db must not mix with student login details"):
        // every workspace route below runs through schoolAuth, which re-checks
        // the ACCOUNT KIND from the database (study.users.account_kind) before
        // the handler - a student token can never read or write school data,
        // even when the request skips the login audience field (legacy
        // clients). The national corpus routes stay on plain s.auth on
        // purpose: students study from the same corpus.
        mux.HandleFunc("POST /school/auth/register", s.authLimit(s.handleSchoolRegister))
        mux.HandleFunc("GET /school/check-result", s.handleSchoolCheckResult)
        mux.HandleFunc("GET /school/curriculum", s.handleSchoolCurriculum)
        mux.HandleFunc("GET /school/corpus/classes", s.auth(s.handleCorpusClasses))
        mux.HandleFunc("GET /school/corpus/schemes/{class}/{subject}", s.auth(s.handleCorpusSchemes))
        mux.HandleFunc("GET /school/corpus/notes/{class}/{subject}", s.auth(s.handleCorpusNotes))
        mux.HandleFunc("GET /school/me", s.schoolAuth(s.handleSchoolMe))
        mux.HandleFunc("GET /school/plan", s.schoolAuth(s.handleSchoolPlan))
        mux.HandleFunc("GET /school/pack/{schoolId}", s.schoolAuth(s.handleSchoolPack))
        mux.HandleFunc("GET /school/classes", s.schoolAuth(s.handleSchoolClasses))
        mux.HandleFunc("GET /school/subjects", s.schoolAuth(s.handleSchoolSubjects))
        mux.HandleFunc("GET /school/class-subjects", s.schoolAuth(s.handleSchoolClassSubjects))
        mux.HandleFunc("GET /school/members", s.schoolAuth(s.handleSchoolMembers))
        mux.HandleFunc("GET /school/assignments", s.schoolAuth(s.handleSchoolAssignments))
        mux.HandleFunc("GET /school/students", s.schoolAuth(s.handleSchoolStudents))
        mux.HandleFunc("GET /school/syllabus", s.schoolAuth(s.handleSchoolSyllabus))
        mux.HandleFunc("GET /school/results", s.schoolAuth(s.handleSchoolResults))
        mux.HandleFunc("GET /school/result-sheet", s.schoolAuth(s.handleSchoolResultSheet))
        mux.HandleFunc("POST /school/seed-curriculum", s.schoolAuth(s.handleSchoolSeed))
        mux.HandleFunc("POST /school/teachers", s.schoolAuth(s.handleSchoolCreateTeacher))
        mux.HandleFunc("POST /school/assignments", s.schoolAuth(s.handleSchoolAssignment))
        mux.HandleFunc("POST /school/students", s.schoolAuth(s.handleSchoolCreateStudent))
        mux.HandleFunc("PUT /school/topic", s.schoolAuth(s.handleSchoolUpdateTopic))
        mux.HandleFunc("PUT /school/scheme", s.schoolAuth(s.handleSchoolUpdateScheme))
        mux.HandleFunc("PUT /school/result-item", s.schoolAuth(s.handleSchoolSaveResultItem))
        // GGSA report-card extras (founder directive 2026-10-04): traits,
        // attendance counts, teacher/principal reports, next-term-begins.
        mux.HandleFunc("PUT /school/result-detail", s.schoolAuth(s.handleSchoolSaveResultDetail))
        mux.HandleFunc("POST /school/finalize", s.schoolAuth(s.handleSchoolFinalize))
        mux.HandleFunc("PUT /school/profile", s.schoolAuth(s.handleSchoolProfile))
        mux.HandleFunc("GET /school/profile", s.schoolAuth(s.handleSchoolGetProfile))
        mux.HandleFunc("POST /school/subject", s.schoolAuth(s.handleSchoolCreateSubject))
        mux.HandleFunc("PUT /school/subject", s.schoolAuth(s.handleSchoolUpdateSubject))
        mux.HandleFunc("POST /school/class-subject", s.schoolAuth(s.handleSchoolClassSubject))
        mux.HandleFunc("GET /school/student-detail", s.schoolAuth(s.handleSchoolStudentDetail))
        mux.HandleFunc("PUT /school/student", s.schoolAuth(s.handleSchoolUpdateStudent))
        mux.HandleFunc("GET /school/student-subjects", s.schoolAuth(s.handleSchoolStudentSubjects))
        mux.HandleFunc("PUT /school/student-subjects", s.schoolAuth(s.handleSchoolSetStudentSubjects))
        mux.HandleFunc("GET /school/attendance", s.schoolAuth(s.handleSchoolAttendanceDay))
        mux.HandleFunc("POST /school/attendance", s.schoolAuth(s.handleSchoolAttendanceSave))
        mux.HandleFunc("GET /school/attendance-summary", s.schoolAuth(s.handleSchoolAttendanceSummary))
        mux.HandleFunc("POST /school/bulk-notes", s.schoolAuth(s.handleSchoolBulkNotes))
        mux.HandleFunc("POST /school/bulk-schemes", s.schoolAuth(s.handleSchoolBulkSchemes))
        mux.HandleFunc("POST /school/bulk-exam-questions", s.schoolAuth(s.handleSchoolBulkExamQuestions))

        // school ops: fees, ID cards, timetable, exam bank --------------------
        mux.HandleFunc("GET /school/fees", s.schoolAuth(s.handleSchoolFees))
        mux.HandleFunc("PUT /school/fee", s.schoolAuth(s.handleSchoolSaveFee))
        mux.HandleFunc("DELETE /school/fee", s.schoolAuth(s.handleSchoolDeleteFee))
        mux.HandleFunc("POST /school/fee-payment", s.schoolAuth(s.handleSchoolRecordPayment))
        mux.HandleFunc("GET /school/fee-payments", s.schoolAuth(s.handleSchoolPayments))
        mux.HandleFunc("GET /school/fee-balances", s.schoolAuth(s.handleSchoolFeeBalances))
        mux.HandleFunc("GET /school/id-cards", s.schoolAuth(s.handleSchoolIDCards))
        mux.HandleFunc("POST /school/id-card", s.schoolAuth(s.handleSchoolIssueCard))
        mux.HandleFunc("POST /school/id-cards", s.schoolAuth(s.handleSchoolIssueCardsBatch))
        mux.HandleFunc("PUT /school/id-card", s.schoolAuth(s.handleSchoolCardStatus))
        mux.HandleFunc("GET /school/timetable", s.schoolAuth(s.handleSchoolTimetable))
        mux.HandleFunc("POST /school/timetable", s.schoolAuth(s.handleSchoolSaveTimetable))
        mux.HandleFunc("GET /school/exam-questions", s.schoolAuth(s.handleSchoolExamQuestions))
        mux.HandleFunc("POST /school/exam-question", s.schoolAuth(s.handleSchoolAddExamQuestion))
        mux.HandleFunc("DELETE /school/exam-question", s.schoolAuth(s.handleSchoolDeleteExamQuestion))
        mux.HandleFunc("GET /school/exams", s.schoolAuth(s.handleSchoolExams))
        mux.HandleFunc("POST /school/exam", s.schoolAuth(s.handleSchoolPublishExam))
        mux.HandleFunc("POST /school/seed-exam-bank", s.schoolAuth(s.handleSchoolSeedExamBank))
        mux.HandleFunc("POST /school/seed-schemes", s.schoolAuth(s.handleSchoolSeedSchemes))
        mux.HandleFunc("GET /school/exam-paper", s.schoolAuth(s.handleSchoolExamPaper))

        // school platform: the old corpus route block (GET /school/corpus/*)
        // moved UP into the workspace block above, where it stays on plain
        // s.auth - students read the national corpus too.

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
                // Email-confirmation gate: a session minted before the
                // signup email was confirmed only opens the confirmation
                // surface (state polling, resend, wrong-email rescue,
                // session refresh). Everything else stays a clean 403 so
                // the account is useless until the mailed link is
                // consumed - reloading the tab or reopening the app never
                // loses the unverified state, it lives in the database.
                if claims.Unverified {
                        if _, ok := verifyAllowlist[r.URL.Path]; !ok {
                                fail(w, http.StatusForbidden, "email_unverified",
                                        "confirm your email to continue - sign in again to resend the confirmation mail.")
                                return
                        }
                }
                ctx := r.Context()
                ctx = contextWith(ctx, ctxUserID, claims.UserID)
                ctx = contextWith(ctx, ctxUsername, claims.Username)
                next(w, r.WithContext(ctx))
        }
}

// schoolAuth is auth plus the school-workspace DB gate (founder
// directive 2026-10-05: "the school workspace db must not mix with
// student login details - any student can sign in with his account to
// the school workspace"). After the token verifies, the account kind is
// re-read from study.users.account_kind and anything that is not a
// school account is refused 403 before the handler runs - so a student
// session can never read or write school data, whichever client it
// came from and whatever audience the login carried. The kind check is
// a DB point-read per request (one indexed PK lookup) and doubles as
// the immediate kill-switch: stamping a user 'student' ejects them
// from the workspace on their very next request.
func (s *Server) schoolAuth(next http.HandlerFunc) http.HandlerFunc {
        return s.auth(func(w http.ResponseWriter, r *http.Request) {
                uid, err := userIDFrom(r)
                if err != nil {
                        fail(w, http.StatusUnauthorized, "unauthorized", "missing user")
                        return
                }
                kind, err := s.store.AccountKindOf(r.Context(), uid)
                if err != nil {
                        s.log.Error("school workspace kind lookup failed", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not verify the account")
                        return
                }
                if kind != store.AccountKindSchool {
                        fail(w, http.StatusForbidden, "not_school_account",
                                "this is a student account. Student details cannot open the school workplace - sign in under For Students.")
                        return
                }
                next(w, r)
        })
}

// verifyAllowlist keeps the confirmation surface reachable for
// students whose session was issued before their signup email was
// confirmed: the account screen (state + email polling), the resend,
// the wrong-email rescue and the session refresh that swaps the
// restricted token for a seated one once the mailed link lands.
var verifyAllowlist = map[string]struct{}{
        "/me":                       {},
        "/auth/resend-verification": {},
        "/auth/refresh":            {},
        "/me/change-email":         {},
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
                w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
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

// decodeSchoolScope strictly parses a school write request and returns the
// school scope the client attached. The web app carries schoolId in the JSON
// body while scripts and older links pass it in the query string; both stay
// valid and the body wins when both are present. The scope key is lifted out
// of the payload before the strict pass so handlers that do not model it in
// their request struct still decode cleanly.
func decodeSchoolScope(w http.ResponseWriter, r *http.Request, dst any) (string, bool) {
        body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
        if err != nil {
                fail(w, http.StatusBadRequest, "invalid_body", truncateErr(err))
                return "", false
        }
        var probe map[string]json.RawMessage
        if json.Unmarshal(body, &probe) != nil {
                // not a JSON object: nothing to lift, decode the body as-is
                return r.URL.Query().Get("schoolId"), decodeFrom(w, body, dst)
        }
        scope := r.URL.Query().Get("schoolId")
        if raw, ok := probe["schoolId"]; ok {
                if v := strings.TrimSpace(string(raw)); v != "" && v != `""` && v != "null" {
                        _ = json.Unmarshal(raw, &scope)
                }
                delete(probe, "schoolId")
                if body, err = json.Marshal(probe); err != nil {
                        fail(w, http.StatusBadRequest, "invalid_body", truncateErr(err))
                        return "", false
                }
        }
        return scope, decodeFrom(w, body, dst)
}

// decodeFrom is decodeJSON over an in-memory body (unknown fields rejected).
func decodeFrom(w http.ResponseWriter, body []byte, dst any) bool {
        dec := json.NewDecoder(bytes.NewReader(body))
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
