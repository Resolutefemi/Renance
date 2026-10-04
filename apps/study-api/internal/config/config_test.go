// Config tests: the AI provider wiring. Founder directive: Z.ai ONLY -
// Groq (key revoked) and Gemini are gone. The one brain is Z.ai's free
// GLM-4.5-Flash, explicit AI_BASE_URL / AI_MODEL still win over the
// preset, and retired provider names fall back to Z.ai.
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

func TestGroqIsGone(t *testing.T) {
        // Groq's key was revoked and the provider removed: AI_PROVIDER=groq
        // must now resolve to the Z.ai preset, and a stale GROQ_API_KEY in
        // the environment must configure nothing.
        c := loadFor(t, map[string]string{"AI_PROVIDER": "groq", "GROQ_API_KEY": "gsk_stale"})
        if c.AIProvider != "zai" || c.AIBaseURL != "https://api.z.ai/api/paas/v4" || c.AIModel != "glm-4.5-flash" {
                t.Errorf("retired groq must fall back to zai, got %q / %q / %q", c.AIProvider, c.AIBaseURL, c.AIModel)
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

func TestGeminiIsGone(t *testing.T) {
        // The GEMINI_API_KEY alias must be dead: setting it must NOT
        // configure the primary brain.
        c := loadFor(t, map[string]string{"GEMINI_API_KEY": "stale-key"})
        if c.AIAPIKey != "" {
                t.Errorf("GEMINI_API_KEY alias must not resurrect, got %q", c.AIAPIKey)
        }
}

// Device lock switch (founder directive 2026-10-02): the one-device-
// one-account rule ships LOCKED - DEVICE_LOCK defaults to false so no
// account binds and no login is refused until the founder flips it to
// true on Render. Flipping accepts the usual spellings; garbage keeps
// the feature safely off.
func TestDeviceLockShipsLocked(t *testing.T) {
        c := loadFor(t, nil)
        if c.DeviceLock {
                t.Errorf("DEVICE_LOCK must default to false - the feature ships locked")
        }
        c = loadFor(t, map[string]string{"DEVICE_LOCK": ""})
        if c.DeviceLock {
                t.Errorf("empty DEVICE_LOCK must stay false")
        }
        c = loadFor(t, map[string]string{"DEVICE_LOCK": "garbage"})
        if c.DeviceLock {
                t.Errorf("unparseable DEVICE_LOCK must stay false")
        }
}

func TestDeviceLockFlipSpellings(t *testing.T) {
        for _, v := range []string{"true", "TRUE", "1", "t", "yes", "on", "Yes"} {
                c := loadFor(t, map[string]string{"DEVICE_LOCK": v})
                if !c.DeviceLock {
                        t.Errorf("DEVICE_LOCK=%q must flip the switch on", v)
                }
        }
        for _, v := range []string{"false", "0", "no", "off", "False"} {
                c := loadFor(t, map[string]string{"DEVICE_LOCK": v})
                if c.DeviceLock {
                        t.Errorf("DEVICE_LOCK=%q must keep the switch off", v)
                }
        }
}
