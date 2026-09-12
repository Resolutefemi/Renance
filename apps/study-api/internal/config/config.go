// Package config loads service configuration from the environment.
//
// ERA-2 law (ADR-0004): the service is DATABASE_URL-agnostic, point it at
// Neon in production, userspace Postgres in the paired sandbox.
package config

import (
        "errors"
        "fmt"
        "os"
        "strconv"
        "strings"
)

type Config struct {
        Port           int
        DatabaseURL    string
        JWTSecret      string
        DataDir        string // dir containing manifest.json + questions/ (answers live inside the banks)
        WebOrigin      string // comma-separated CORS allowlist ("*" keeps dev open)
        GoogleClientID string // Google OAuth audience(s), comma-separated (web + Android); "" disables Google sign-in
        AdminToken     string // guards GET /internal/review/tick; "" keeps the route disabled (404)
        GradeWorkers   int
        GradeQueue     int

        // ROADMAP #9 Socratic tutor + AI generator: the provider is
        // Gemini's OpenAI-compatible surface. An empty AIAPIKey keeps
        // hint-only mode for the tutor and the honest "AI is off" state
        // for the generator — set AI_API_KEY (or GEMINI_API_KEY) in the
        // deployment env to switch both to AI mode. GitHub push
        // protection (rightly) refuses the key inside this repo, so it
        // can only ever arrive through the environment.
        AIAPIKey    string
        AIBaseURL   string
        AIModel     string
        AIMaxTokens int

        // Abuse walls (security hardening).
        AuthPerMin       int
        AuthGlobalPerMin int
        TutorPerMin      int

        // ROADMAP #14 multiplayer arena (in-process hub slice).
        ArenaQuestions          int
        ArenaSecondsPerQuestion int
        ArenaIntroSeconds       int
        ArenaBotWaitSeconds     int
        ArenaBotSkill           float64
        ArenaRoomTTLSeconds     int
}

func Load() (*Config, error) {
        c := &Config{
                Port:           envInt("PORT", 3990),
                DatabaseURL:    os.Getenv("DATABASE_URL"),
                JWTSecret:      os.Getenv("JWT_SECRET"),
                DataDir:        os.Getenv("DATA_DIR"),
                WebOrigin:      envStr("WEB_ORIGIN", "*"),
                GoogleClientID: strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_ID")),
                AdminToken:     strings.TrimSpace(os.Getenv("ADMIN_TOKEN")),
                GradeWorkers:   envInt("GRADE_WORKERS", 8),
                GradeQueue:     envInt("GRADE_QUEUE", 1024),

                AIAPIKey:    strings.TrimSpace(os.Getenv("AI_API_KEY")),
                AIBaseURL:   envStr("AI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai"),
                AIModel:     envStr("AI_MODEL", "gemini-3.6-flash"),
                AIMaxTokens: envInt("AI_MAX_TOKENS", 320),

                AuthPerMin:       envInt("AUTH_PER_MIN", 20),
                AuthGlobalPerMin: envInt("AUTH_GLOBAL_PER_MIN", 300),
                TutorPerMin:      envInt("TUTOR_PER_MIN", 12),

                ArenaQuestions:          envInt("ARENA_QUESTIONS", 5),
                ArenaSecondsPerQuestion: envInt("ARENA_SECONDS_PER_QUESTION", 15),
                ArenaIntroSeconds:       envInt("ARENA_INTRO_SECONDS", 3),
                ArenaBotWaitSeconds:     envInt("ARENA_BOT_WAIT_SECONDS", 20),
                ArenaBotSkill:           envFloat("ARENA_BOT_SKILL", 0.6),
                ArenaRoomTTLSeconds:     envInt("ARENA_ROOM_TTL_SECONDS", 900),
        }
        if c.DatabaseURL == "" {
                return nil, errors.New("config: DATABASE_URL is required (Neon console → connection string, or a local Postgres)")
        }
        if c.JWTSecret == "" {
                return nil, errors.New("config: JWT_SECRET is required (dev: scripts/study-api-dev.sh injects one)")
        }
        if len(c.JWTSecret) < 16 {
                return nil, fmt.Errorf("config: JWT_SECRET must be at least 16 characters")
        }
        // GEMINI_API_KEY is an alias for AI_API_KEY (founder habit).
        if c.AIAPIKey == "" {
                c.AIAPIKey = strings.TrimSpace(os.Getenv("GEMINI_API_KEY"))
        }
        return c, nil
}

func envStr(key, def string) string {
        if v := os.Getenv(key); v != "" {
                return v
        }
        return def
}

func envInt(key string, def int) int {
        if v := os.Getenv(key); v != "" {
                if n, err := strconv.Atoi(v); err == nil && n > 0 {
                        return n
                }
        }
        return def
}

func envFloat(key string, def float64) float64 {
        if v := os.Getenv(key); v != "" {
                if f, err := strconv.ParseFloat(v, 64); err == nil && f >= 0 {
                        return f
                }
        }
        return def
}
