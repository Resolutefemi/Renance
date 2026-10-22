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
        "renance.dev/study-api/internal/learn"
        "renance.dev/study-api/internal/r2store"
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
        // verifyIP gates the 6-digit code entry (POST /auth/verify-email)
        // per client IP - a tight bucket that blocks code guessing.
        verifyIP *rateLimiter
        // resetBudget caps the total reset mails per UTC day (the
        // founder's Brevo free-tier quota armor).
        resetBudget *dailyMailBudget

        // Bundle shield state (botshield.go, founder directive 2026-10-11:
        // "ultimate security - no agentic AI may scrape the 200,000+ past
        // questions"). ledger = per-account distinct-bank counts + honeypot
        // strikes; pows = proof-of-work challenge nonces; bundleKeyIP =
        // anonymous key-fetch cap per IP per hour; bundleBurstIP = bundle
        // route burst rate; bundleAnonGlobal = global anonymous budget.
        ledger           *userLedger
        pows             *powLedger
        bundleKeyIP      *rateLimiter
        bundleBurstIP    *rateLimiter
        bundleAnonGlobal *rateLimiter
        // Static shield (founder directive 2026-10-12: the /pdfs shelf +
        // school-corpus must never ship plain on the CDN again):
        // staticFiles = paths the key route will serve keys for (from
        // data/static_registry.json, written by scripts/encrypt_pdfs.mjs);
        // staticHoneypots = registry decoys that strike the account;
        // bundleKeyUser = per-account key SPEED cap (no daily cap - that
        // was removed 2026-10-11 and stays removed); staticKeyIPCorpus =
        // the gentler anonymous cap for school-corpus keys.
        staticFiles       map[string]struct{}
        staticHoneypots   map[string]struct{}
        bundleKeyUser     *rateLimiter
        staticKeyIPCorpus *rateLimiter

        // National curriculum corpus (schemes + notes) read straight
        // from the data folder; nil keeps the routes returning clean
        // empty lists (unit tests without a data dir).
        corpus *schoolcorpus.Corpus

        // The Supreme learn module merged into Renance (founder
        // directive 2026-10-14): gamified course paths, quests, shop,
        // league - all keyed to the real account. nil in tests keeps
        // every /learn route on a clean 503.
        learn *learn.Service

        // photos is the profile-picture folder on the SAME R2 bucket as
        // the lessons (founder 2026-10-22). nil keeps the photo upload
        // route on a clean 503 and the serve route on "not configured".
        photos *r2store.Client
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
        var aiProvider tutor.Provider
        if cfg.AIAPIKey != "" {
                s.tutor.Provider = &tutor.OpenAICompat{
                        BaseURL: cfg.AIBaseURL, APIKey: cfg.AIAPIKey, Model: cfg.AIModel, Thinking: cfg.AIThinking,
                        // The provider's own wall must clear the studio's async
                        // budget: generation runs off-request with a 90s context,
                        // and big documents (notebooks) legitimately take 30-60s
                        // on the free GLM tier. The default 30s client was cutting
                        // every notebook attempt in half.
                        // The deep lesson (notes top-up rounds + 20-question quiz) can
                        // legitimately run long on the free GLM tier; the shared client
                        // timeout is only a ceiling - the per-call context budgets
                        // (chat 27s, /ai/generate 60s) still govern everything else.
                        HTTP: &http.Client{Timeout: 150 * time.Second},
                }
                aiProvider = s.tutor.Provider
        }
        // The learn module shares the tutor's OpenAI-compatible provider
        // for JIT lesson generation; unlimited hearts is the launch
        // posture (founder 2026-10-14: everyone unlimited for now, gems
        // and hearts still accrue as rewards). The pool may be nil in
        // unit tests that never touch learn routes - constructing with a
        // nil pool is fine, dereferencing st was not.
        var learnPool store.Pool
        var learnCachePool store.Pool
        if st != nil {
                learnPool = st.Pool
                learnCachePool = st.Cache()
        }
        s.learn = &learn.Service{
                Pool:            learnPool,
                CachePool:       learnCachePool,
                Log:             log,
                Engine:          learn.NewEngine(aiProvider, lib),
                UnlimitedHearts: cfg.LearnUnlimitedHearts,
        }
        // Lesson blobs (founder 2026-10-17, "how do we move to cloudflare
        // r2"): with the R2_* environment set, Cloudflare R2 becomes the
        // durable home of every lesson document - R2-first reads, dual
        // writes (bucket + cache database). Unset keeps the single-home
        // posture; nothing else changes.
        if blobs := r2store.FromEnv(log); blobs != nil {
                s.learn.Blobs = blobs
                log.Info("lesson blobs: cloudflare r2 attached - the bucket is the durable lesson home",
                        "bucket", blobs.Bucket(), "prefix", blobs.Prefix())
        } else {
                log.Info("lesson blobs: r2 not configured - the cache database stays the only lesson home")
        }
        // Profile photos (founder 2026-10-22): the profile-picture/ folder
        // on the same bucket. Same credentials, zero extra configuration.
        if photos := r2store.FromEnvPrefix(log, "profile-picture/"); photos != nil {
                s.photos = photos
                log.Info("profile photos: cloudflare r2 attached",
                        "bucket", photos.Bucket(), "prefix", photos.Prefix())
        } else {
                log.Info("profile photos: r2 not configured - photo uploads stay off")
        }
        s.learn.WireExpGuard()
        s.limiter = newRateLimiter(cfg.TutorPerMin, cfg.TutorPerMin)
        s.authIP = newRateLimiter(cfg.AuthPerMin, cfg.AuthPerMin*2)
        s.authGlobal = newRateLimiter(cfg.AuthGlobalPerMin, cfg.AuthGlobalPerMin)
        // 6 tries a minute per IP: a student typing (or mistyping) their
        // code never feels it; a brute-force walk of the 900k code space
        // would take months. Hardcoded - the code entry is not tunable
        // churn, it is a floor.
        s.verifyIP = newRateLimiter(6, 6)
        s.resetBudget = newDailyMailBudget(cfg.ResetMailDailyCap)

        // Bundle shield: in-memory ledgers + rate walls. The per-IP key cap
        // is hourly (anonymous proof-of-work path only); the burst wall
        // covers the bundle route for everyone; the anonymous global budget
        // catches IP rotation. All three are env-tunable. Configs built
        // directly (tests) get the Load() defaults for unset knobs.
        // (The per-account daily bank quota is gone - founder directive
        // 2026-10-11: signed-in students are never capped.)
        if cfg.BundleIPPerHour <= 0 {
                cfg.BundleIPPerHour = 12
        }
        if cfg.BundlePowBits <= 0 {
                cfg.BundlePowBits = 18
        }
        s.ledger = &userLedger{}
        s.pows = &powLedger{}
        s.bundleKeyIP = newRateLimiter(cfg.BundleIPPerHour, cfg.BundleIPPerHour)
        s.bundleBurstIP = newRateLimiter(30, 30)
        s.bundleAnonGlobal = newRateLimiter(600, 600)
        // Static shield: the PDF vault rides the strict bundleKeyIP cap,
        // the school-corpus rides a gentler one (public curriculum
        // browsing), and every signed-in key fetch is speed-capped per
        // account (90/min, burst 120 - 10x any real study burst, while an
        // enumerator walking all 3,000+ static codes + 1,000 banks needs
        // half an hour minimum, through the watermark ledger).
        if cfg.BundleKeyUserPerMin <= 0 {
                cfg.BundleKeyUserPerMin = 90
        }
        if cfg.BundleCorpusIPPerHour <= 0 {
                cfg.BundleCorpusIPPerHour = 120
        }
        if cfg.BundleCorpusPowBits <= 0 {
                cfg.BundleCorpusPowBits = 14
        }
        s.bundleKeyUser = newRateLimiter(cfg.BundleKeyUserPerMin, cfg.BundleKeyUserPerMin)
        s.staticKeyIPCorpus = newRateLimiter(cfg.BundleCorpusIPPerHour, cfg.BundleCorpusIPPerHour)
        s.loadStaticRegistry(cfg.DataDir)
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

// Learn exposes the learn service so main can wire the grading engine's
// quiz-streak bridge (founder directive 2026-10-17: a graded quiz/mock
// attempt advances the Supreme streak exactly like a finished lesson).
func (s *Server) Learn() *learn.Service { return s.learn }

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
        // The REAL Postgres probe (Neon compute budget, 2026-10-14): /healthz
        // is DB-free so keep-warm pingers can never wake the database; any
        // human or CI check that must prove the Neon connection lives points
        // here instead. Deliberately NOT in the bot shield's tool whitelist.
        mux.HandleFunc("GET /readyz", s.handleReady)
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

        // ── The learn module (Supreme merged into Renance, 2026-10-14).
        // Every route rides the standard JWT auth: the gamified course
        // paths, quests, shop and league all live on the Renance account.
        mux.HandleFunc("GET /learn/profile", s.auth(s.handleLearnProfile))
        mux.HandleFunc("PATCH /learn/profile", s.auth(s.handleLearnPatchProfile))
        mux.HandleFunc("DELETE /learn/profile", s.auth(s.handleLearnReset))
        mux.HandleFunc("GET /learn/catalog", s.auth(s.handleLearnCatalog))
        mux.HandleFunc("GET /learn/faculties", s.auth(s.handleLearnFaculties))
        mux.HandleFunc("GET /learn/departments", s.auth(s.handleLearnDepartments))
        mux.HandleFunc("GET /learn/course-desk", s.auth(s.handleLearnCourseDesk))
        mux.HandleFunc("GET /learn/course-desk/others", s.auth(s.handleLearnCourseDeskOthers))
        mux.HandleFunc("GET /learn/search", s.auth(s.handleLearnSearch))
        mux.HandleFunc("POST /learn/ai-match", s.auth(s.handleLearnAIMatch))
        mux.HandleFunc("GET /learn/my-courses", s.auth(s.handleLearnMyCourses))
        mux.HandleFunc("POST /learn/my-courses", s.auth(s.handleLearnSetMyCourses))
        mux.HandleFunc("POST /learn/active-course", s.auth(s.handleLearnActiveCourse))
        mux.HandleFunc("GET /learn/courses/{id}", s.auth(s.handleLearnCoursePath))
        mux.HandleFunc("GET /learn/topics/{id}/content", s.auth(s.handleLearnLesson))
        mux.HandleFunc("POST /learn/progress", s.auth(s.handleLearnProgress))
        mux.HandleFunc("GET /learn/quests", s.auth(s.handleLearnQuests))
        mux.HandleFunc("POST /learn/quests", s.auth(s.handleLearnQuests))
        mux.HandleFunc("GET /learn/shop", s.auth(s.handleLearnShop))
        mux.HandleFunc("POST /learn/shop", s.auth(s.handleLearnShop))
        mux.HandleFunc("GET /learn/leaderboard", s.auth(s.handleLearnLeague))
        mux.HandleFunc("POST /learn/heartbeat", s.auth(s.handleLearnHeartbeat))
        mux.HandleFunc("POST /learn/flags", s.auth(s.handleLearnFlags))
        mux.HandleFunc("POST /learn/course-requests", s.auth(s.handleLearnCourseRequests))
        mux.HandleFunc("POST /learn/chests", s.auth(s.handleLearnChest))
        mux.HandleFunc("GET /learn/practice", s.auth(s.handleLearnPractice))
        mux.HandleFunc("POST /learn/practice", s.auth(s.handleLearnPractice))
        mux.HandleFunc("GET /learn/review", s.auth(s.handleLearnReview))
        mux.HandleFunc("GET /learn/revision", s.auth(s.handleLearnRevision))

        // ── The Renance social layer (feed + follows, 2026-10-14): the
        // Duolingo-style feed of MILESTONE stories, likes, comments,
        // the follow graph and the public profiles every board opens.
        mux.HandleFunc("GET /social/feed", s.auth(s.handleSocialFeed))
        mux.HandleFunc("POST /social/feed", s.auth(s.handleSocialPostCreate))
        mux.HandleFunc("GET /social/search", s.auth(s.handleSocialSearch))
        mux.HandleFunc("GET /social/suggestions", s.auth(s.handleSocialSuggestions))
        mux.HandleFunc("POST /social/announcements", s.auth(s.handleSocialAnnouncementCreate))
        // Founder directive 2026-10-22: user posts are enabled again -
        // the feed automation needs the student's achievement shares
        // riding post meta ({score, exam, course...}). The 2026-10-14
        // "platform voice only" retirement is lifted for freeform
        // posts; milestone stories remain platform-written with their
        // (user_id, milestone) dedup unchanged.
        mux.HandleFunc("DELETE /social/posts/{id}", s.auth(s.handleSocialPostDelete))
        mux.HandleFunc("POST /social/posts/{id}/like", s.auth(s.handleSocialLike))
        mux.HandleFunc("POST /social/posts/{id}/react", s.auth(s.handleSocialReact))
        mux.HandleFunc("GET /social/posts/{id}/comments", s.auth(s.handleSocialCommentsGet))
        mux.HandleFunc("POST /social/posts/{id}/comments", s.auth(s.handleSocialCommentAdd))
        mux.HandleFunc("POST /social/users/{username}/follow", s.auth(s.handleSocialFollow))
        mux.HandleFunc("GET /social/users/{username}", s.auth(s.handleSocialPublicProfile))
        mux.HandleFunc("GET /social/connections", s.auth(s.handleSocialConnections))
        mux.HandleFunc("POST /me/avatar/photo", s.auth(s.handleAvatarPhotoUpload))
        mux.HandleFunc("DELETE /me/avatar/photo", s.auth(s.handleAvatarPhotoDelete))
        // The public photo reader - no auth, immutable cache (the key
        // embeds the upload timestamp; profile photos are not secrets).
        mux.HandleFunc("GET /media/profile-picture/{key}", s.handleProfilePhotoServe)
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
        mux.HandleFunc("GET /leaderboard/gems", s.auth(s.handleGemsLeaderboard))
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
        mux.HandleFunc("GET /robots.txt", s.handleRobotsTxt)
        mux.HandleFunc("GET /manifest", s.auth(s.handleManifest))
        // The shield wall (botshield.go): account quotas, IP burst rate,
        // honeypot decoys, poisoned canary banks, per-user watermarks.
        mux.HandleFunc("GET /bundles/{code}", s.auth(s.shieldBundle(s.handleBundle)))
        // Per-bank AES key for the web's encrypted static shelf: signed-in
        // (JWT + daily quota) or anonymous (proof-of-work + IP caps).
        mux.HandleFunc("GET /bundles/key", s.authOptional(s.handleBundleKey))
        mux.HandleFunc("GET /billing/plans", s.handleBillingPlans)
        mux.HandleFunc("POST /billing/paystack/initialize", s.auth(s.handleBillingInitialize))
        mux.HandleFunc("POST /billing/paystack/webhook", s.handlePaystackWebhook)
        mux.HandleFunc("POST /billing/redeem", s.auth(s.handleBillingRedeem))
        mux.HandleFunc("POST /auth/verify-email", s.verifyLimit(s.handleVerifyEmail))
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

        // dbWatch (dbwatch.go, founder directive 2026-10-15): the CU-aware
        // database-down detector - counts 5xx responses, probes the pool
        // only after a real failure burst, and exits so the platform
        // restart re-runs the boot fallback onto a live DSN. Innermost on
        // purpose: it counts handler 500s (the DB failure surface), while
        // the CORS and security wrappers still decorate every response.
        //
        // panicGuard is the OUTERMOST ring (2026-10-20): a handler panic
        // used to tear the connection down with no response - the client
        // saw Cloudflare's bare 502 and every route read as dead (the
        // "find my courses with ai is not working" probe hit exactly
        // this: empty reply, ~30s, no log the client could show). The
        // guard converts the panic into the standard error envelope and
        // leaves a full stack in the Render log, so a crash is now ONE
        // greppable event instead of a mystery 502.
        return s.panicGuard(s.botShield(s.securityHeaders(s.cors(s.dbWatch(mux)))))
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

// authOptional verifies the bearer token when one is present and
// enriches the context with the user, but lets anonymous callers
// through untouched (the /bundles/key route: signed-in accounts ride
// the quota path, anonymous ones the proof-of-work path). An invalid
// or unverified token degrades to anonymous rather than failing.
func (s *Server) authOptional(next http.HandlerFunc) http.HandlerFunc {
        return func(w http.ResponseWriter, r *http.Request) {
                header := r.Header.Get("Authorization")
                if strings.HasPrefix(header, "Bearer ") {
                        if claims, err := jwtx.Verify(strings.TrimPrefix(header, "Bearer "), s.cfg.JWTSecret); err == nil && !claims.Unverified {
                                ctx := contextWith(r.Context(), ctxUserID, claims.UserID)
                                ctx = contextWith(ctx, ctxUsername, claims.Username)
                                r = r.WithContext(ctx)
                        }
                }
                next(w, r)
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
        "/auth/refresh":             {},
        "/me/change-email":          {},
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
                // PATCH rides the list since the course-desk save shipped
                // (fc28ff22, method:'PATCH'): without it the browser refuses
                // every preflighted PATCH before it ever leaves the tab, the
                // fetch throws TypeError, and the student reads "The study
                // service did not answer in time" on every desk save - the
                // exact founder bug report of 2026-10-15 ("can't leave step2").
                // curl and the e2e scripts never saw it: CORS is a browser rule.
                w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
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
