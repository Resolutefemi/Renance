// Config tests: the AI provider wiring. Founder directive: Z.ai and
// Groq ONLY - Gemini is gone. The default brain is Z.ai's free
// GLM-4.5-Flash, GROQ_API_KEY resolves the backup brain, explicit
// AI_BASE_URL / AI_MODEL still win over the preset, and AI_PROVIDER
// only flips who answers first.
package config

import (
        "testing"
)

func loadFor(t *testing.T, env map[string]string) *Config {
        t.Helper()
        t.Setenv("DATABASE_URL", "postgres://test")
        t.Setenv("JWT_SECRET", "test-secret-at-least-16-chars")
        for k, v := range env {
                t.Setenv(k, v)
        }
        c, err := Load()
        if err != nil {
                t.Fatalf("Load: %v", err)
        }
        return c
}

func TestAIDefaultsToZai(t *testing.T) {
        c := loadFor(t, nil)
        if c.AIProvider != "zai" {
                t.Errorf("provider = %q, want zai", c.AIProvider)
        }
        if c.AIBaseURL != "https://api.z.ai/api/paas/v4" {
                t.Errorf("base = %q", c.AIBaseURL)
        }
        if c.AIModel != "glm-4.5-flash" {
                t.Errorf("model = %q", c.AIModel)
        }
        if c.AIThinking != "disabled" {
                t.Errorf("thinking = %q, want disabled", c.AIThinking)
        }
}

func TestAIPresetZAlias(t *testing.T) {
        // The founder literally asked "can't I use z?" - accept it.
        for _, name := range []string{"z", "z-ai", "ZAI"} {
                c := loadFor(t, map[string]string{"AI_PROVIDER": name})
                if c.AIProvider != "zai" || c.AIModel != "glm-4.5-flash" {
                        t.Errorf("alias %q = %q / %q", name, c.AIProvider, c.AIModel)
                }
        }
}

func TestAIPresetGroq(t *testing.T) {
        c := loadFor(t, map[string]string{"AI_PROVIDER": "groq"})
        if c.AIBaseURL != "https://api.groq.com/openai/v1" {
                t.Errorf("groq base = %q", c.AIBaseURL)
        }
        if c.AIModel != "llama-3.3-70b-versatile" {
                t.Errorf("groq model = %q", c.AIModel)
        }
}

func TestAIPresetExplicitWin(t *testing.T) {
        c := loadFor(t, map[string]string{
                "AI_BASE_URL": "https://my-proxy.example.com/v1",
                "AI_MODEL":    "my-model",
        })
        if c.AIBaseURL != "https://my-proxy.example.com/v1" || c.AIModel != "my-model" {
                t.Errorf("explicit env must beat preset, got %q / %q", c.AIBaseURL, c.AIModel)
        }
}

func TestGroqBackupResolved(t *testing.T) {
        c := loadFor(t, map[string]string{"GROQ_API_KEY": "gsk_test"})
        if c.GroqAPIKey != "gsk_test" {
                t.Errorf("groq key = %q", c.GroqAPIKey)
        }
        if c.GroqBaseURL != "https://api.groq.com/openai/v1" {
                t.Errorf("groq base = %q", c.GroqBaseURL)
        }
        if c.GroqModel != "llama-3.3-70b-versatile" {
                t.Errorf("groq model = %q", c.GroqModel)
        }
}

func TestGeminiIsGone(t *testing.T) {
        // The GEMINI_API_KEY alias must be dead: setting it must NOT
        // configure the primary brain.
        c := loadFor(t, map[string]string{"GEMINI_API_KEY": "stale-key"})
        if c.AIAPIKey != "" {
                t.Errorf("GEMINI_API_KEY alias must not resurrect, got %q", c.AIAPIKey)
        }
}
