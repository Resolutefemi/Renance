// Package config loads service configuration from the environment.
//
// ERA-2 law (ADR-0004): the service is DATABASE_URL-agnostic, point it at
// Neon in production, userspace Postgres in the paired sandbox.
package config

import (
        "encoding/hex"
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

        // DeviceLock is the one-device-one-account switch (founder
        // directive 2026-10-02): an account signed up on a device can
        // only be used on that device; anyone - even the account owner -
        // signing in from another phone is refused with device_locked and
        // the WhatsApp management rescue. The feature is BUILT but
        // LOCKED: DEVICE_LOCK defaults to false, so the lock stays
        // dormant (no binding, no rejection) until the founder flips it
        // to true on Render - which lights it up for every installed app
        // instantly, no app update needed. The rescue (management DM +
        // POST /internal/device/unbind) exists ONLY for the lost/replaced
        // phone case.
        DeviceLock bool
        GradeWorkers   int
        GradeQueue     int

        // ROADMAP #9 Socratic tutor + AI generator: the provider is ANY
        // OpenAI-compatible chat endpoint. Founder directive: Z.ai ONLY
        // (Groq's key was revoked and Groq is removed; Gemini is gone).
        // AI_API_KEY is the Z.ai key and powers the free GLM-4.5-Flash
        // brain. No key at all keeps hint-only mode for the tutor and
        // the honest "AI is off" state for the generator. The key lives
        // on the server (render.yaml / Render env) and never reaches a
        // client bundle.
        AIAPIKey    string
        AIBaseURL   string
        AIModel     string
        AIProvider  string // "zai"; shown by /tutor/status
        AIMaxTokens int
        // AI_THINKING: "disabled" (default) makes Z.ai's GLM-4.5 answer
        // directly instead of reasoning first - verified far faster and
        // the reply always fits the token budget. "enabled" restores
        // deep reasoning at the cost of speed.
        AIThinking string

        // Billing (Paystack). An empty key keeps the paywall on its
        // fallback surfaces (REN coins + the WhatsApp line) and the
        // webhook route disabled; the key can only arrive via the env.
        PaystackSecretKey string

        // Abuse walls (security hardening).
        AuthPerMin       int
        AuthGlobalPerMin int
        TutorPerMin      int

        // Bundle shield (founder directive 2026-10-11: "ultimate
        // security - no agentic AI may scrape the 200,000+ past
        // questions"). BUNDLE_MASTER_KEY is 32 bytes hex shared by this
        // API and the web bake (Vercel + GitHub Pages build secrets);
        // "" disables /bundles/key so the encrypted static shelf falls
        // back to API-only serving. BUNDLE_KEY_ID labels the rotation
        // (kid). BUNDLE_ANON_KEY=false removes the anonymous
        // proof-of-work path so bank keys require a signed-in account.
        BundleMasterKey []byte
        BundleKeyID     string
        BundleAnonKey   bool
        // Anonymous key fetches per IP per hour (proof-of-work path).
        BundleIPPerHour int
        // Proof-of-work difficulty in bits for the anonymous key path
        // (18 ≈ 262k hashes, ~0.3s in a browser, per key request).
        BundlePowBits int

        // Reset-mail quota armor (founder directive 2026-10-05, trimming
        // the 2026-10-04 armor: "remove the 100 email/day budget... put
        // the 300/day"). RESET_MAIL_DAILY_CAP is the total number of
        // reset mails the API will send per UTC day, across every
        // account - set to the Brevo free plan itself (300/day, shared
        // with confirmation mails); 0 disables the global budget. The
        // per-account 3-mails/24h ceiling is GONE: the only per-account
        // wall left is the request-driven 10-minute duplicate guard.
        ResetMailDailyCap int

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
                DeviceLock:     envBool("DEVICE_LOCK", false),
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

                BundleMasterKey:     envHex("BUNDLE_MASTER_KEY"),
                BundleKeyID:         envStr("BUNDLE_KEY_ID", "k1"),
                BundleAnonKey:       envBool("BUNDLE_ANON_KEY", true),
                BundleIPPerHour:      envInt("BUNDLE_IP_PER_HOUR", 12),
                BundlePowBits:       envInt("BUNDLE_POW_BITS", 18),
                ResetMailDailyCap: envInt("RESET_MAIL_DAILY_CAP", 300),

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
        // Founder directive: Z.ai ONLY. Groq's key was revoked (live
        // probes answered 403 Forbidden twice) and the provider is
        // removed - no Gemini alias, no other providers. Retired or
        // unknown AI_PROVIDER values ("groq" included) fall back to
        // Z.ai, and explicit AI_BASE_URL / AI_MODEL always win.
        c.AIProvider = strings.ToLower(strings.TrimSpace(os.Getenv("AI_PROVIDER")))
        switch c.AIProvider {
        case "", "z", "z-ai", "groq": // "" + aliases, plus the retired Groq
                c.AIProvider = "zai"
        }
        base, model := aiPreset(c.AIProvider)
        if c.AIBaseURL == "" {
                c.AIBaseURL = base
        }
        if c.AIModel == "" {
                c.AIModel = model
        }
        return c, nil
}

// aiPreset maps a provider name to its OpenAI-compatible base URL and
// a sensible default model. Unknown names fall back to Z.ai, the
// founder's one and only brain.
func aiPreset(provider string) (base, model string) {
        switch provider {
        default: // "zai", anything unknown ("groq" is retired)
                return "https://api.z.ai/api/paas/v4", "glm-4.5-flash" // free model
        }
}

// envHex reads a hex-encoded secret (BUNDLE_MASTER_KEY) and returns
// the decoded bytes; empty/invalid yields nil, which cleanly disables
// the feature that depends on it.
func envHex(key string) []byte {
        v := strings.TrimSpace(os.Getenv(key))
        if v == "" {
                return nil
        }
        b, err := hex.DecodeString(v)
        if err != nil || len(b) != 32 {
                return nil
        }
        return b
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

// envFloat parses a float knob; anything odd keeps the default.
func envFloat(key string, def float64) float64 {
        if v := os.Getenv(key); v != "" {
                if f, err := strconv.ParseFloat(v, 64); err == nil && f >= 0 {
                        return f
                }
        }
        return def
}

// envBool parses a boolean switch: true/1/t/yes/on (any case) flips it
// on, 0/f/false/no/off flips it off, anything else keeps the default.
// Powers DEVICE_LOCK, the one-device-one-account feature switch that
// ships LOCKED (false) and goes live the moment the founder sets
// DEVICE_LOCK=true on Render.
func envBool(key string, def bool) bool {
        v := strings.ToLower(strings.TrimSpace(os.Getenv(key)))
        if v == "" {
                return def
        }
        switch v {
        case "1", "t", "true", "yes", "on":
                return true
        case "0", "f", "false", "no", "off":
                return false
        default:
                return def
        }
}
