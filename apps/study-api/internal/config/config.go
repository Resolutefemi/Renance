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

        // ROADMAP #9 Socratic tutor + AI generator: the provider is ANY
        // OpenAI-compatible chat endpoint. Founder directive: Z.ai and
        // Groq ONLY - Gemini is gone. AI_API_KEY is the Z.ai key (the
        // default brain, free GLM-4.5-Flash) and GROQ_API_KEY is the
        // backup (free Llama 3.3 70B): with both set the tutor tries Z
        // first and falls back to Groq on any error, so a provider
        // outage never blanks the AI. AI_PROVIDER only flips the order
        // ("groq" makes Groq primary). No key at all keeps hint-only
        // mode for the tutor and the honest "AI is off" state for the
        // generator. GitHub push protection (rightly) refuses keys
        // inside this repo, so they can only ever arrive through the
        // environment - the keys live on the server, never in a client
        // bundle.
        AIAPIKey    string
        AIBaseURL   string
        AIModel     string
        AIProvider  string // "zai" (default) or "groq"; shown by /tutor/status
        AIMaxTokens int
        // AI_THINKING: "disabled" (default) makes Z.ai's GLM-4.5 answer
        // directly instead of reasoning first - verified far faster and
        // the reply always fits the token budget. "enabled" restores
        // deep reasoning at the cost of speed.
        AIThinking string

        // The Groq backup brain, resolved from GROQ_API_KEY.
        GroqAPIKey  string
        GroqBaseURL string
        GroqModel   string

        // Billing (Paystack). An empty key keeps the paywall on its
        // fallback surfaces (REN coins + the WhatsApp line) and the
        // webhook route disabled; the key can only arrive via the env.
        PaystackSecretKey string

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
                AIBaseURL:   strings.TrimSpace(os.Getenv("AI_BASE_URL")),
                AIModel:     strings.TrimSpace(os.Getenv("AI_MODEL")),
                AIMaxTokens: envInt("AI_MAX_TOKENS", 320),
                AIThinking:  envStr("AI_THINKING", "disabled"),

                PaystackSecretKey: strings.TrimSpace(os.Getenv("PAYSTACK_SECRET_KEY")),

                AuthPerMin:       envInt("AUTH_PER_MIN", 20),
                AuthGlobalPerMin: envInt("AUTH_GLOBAL_PER_MIN", 300),
                TutorPerMin:      envInt("TUTOR_PER_MIN", 12),

                ArenaQuestions:          envInt("ARENA_QUESTIONS", 15),            // founder rule: 15-question duels
                ArenaSecondsPerQuestion: envInt("ARENA_SECONDS_PER_QUESTION", 20), // 15 x 20s = five minutes
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
        // Founder directive: Z.ai and Groq ONLY. The Z.ai key is the
        // primary brain; the Groq key is the backup. No Gemini alias,
        // no other providers. Unknown AI_PROVIDER values fall back to
        // Z.ai, and explicit AI_BASE_URL / AI_MODEL always win.
        c.AIProvider = strings.ToLower(strings.TrimSpace(os.Getenv("AI_PROVIDER")))
        if c.AIProvider == "" || c.AIProvider == "z" || c.AIProvider == "z-ai" {
                c.AIProvider = "zai"
        }
        base, model := aiPreset(c.AIProvider)
        if c.AIBaseURL == "" {
                c.AIBaseURL = base
        }
        if c.AIModel == "" {
                c.AIModel = model
        }
        c.GroqAPIKey = strings.TrimSpace(os.Getenv("GROQ_API_KEY"))
        c.GroqBaseURL, c.GroqModel = aiPreset("groq")
        return c, nil
}

// aiPreset maps a provider name to its OpenAI-compatible base URL and
// a sensible default model. Unknown names fall back to Z.ai, the
// founder's default brain.
func aiPreset(provider string) (base, model string) {
        switch provider {
        case "groq":
                return "https://api.groq.com/openai/v1", "llama-3.3-70b-versatile"
        default: // "", "zai", anything unknown
                return "https://api.z.ai/api/paas/v4", "glm-4.5-flash" // free model
        }
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
