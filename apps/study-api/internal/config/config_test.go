// Config tests: the AI provider preset table. The founder asked for Z,
// so "zai" must resolve to Z.ai's free GLM-4.5-Flash, explicit
// AI_BASE_URL / AI_MODEL must beat any preset, and the unset default
// must stay Gemini's free tier exactly as before the presets existed.
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

func TestAIPresetZai(t *testing.T) {
	c := loadFor(t, map[string]string{"AI_PROVIDER": "zai", "AI_API_KEY": "k"})
	if c.AIBaseURL != "https://api.z.ai/api/paas/v4" {
		t.Errorf("zai base = %q", c.AIBaseURL)
	}
	if c.AIModel != "glm-4.5-flash" {
		t.Errorf("zai model = %q", c.AIModel)
	}
	if c.AIProvider != "zai" {
		t.Errorf("provider = %q", c.AIProvider)
	}
}

func TestAIPresetZAlias(t *testing.T) {
	// The founder literally asked "can't I use z?" - accept it.
	c := loadFor(t, map[string]string{"AI_PROVIDER": "z"})
	if c.AIBaseURL != "https://api.z.ai/api/paas/v4" || c.AIModel != "glm-4.5-flash" {
		t.Errorf("z alias = %q / %q", c.AIBaseURL, c.AIModel)
	}
}

func TestAIPresetExplicitWin(t *testing.T) {
	c := loadFor(t, map[string]string{
		"AI_PROVIDER": "zai",
		"AI_BASE_URL": "https://my-proxy.example.com/v1",
		"AI_MODEL":    "my-model",
	})
	if c.AIBaseURL != "https://my-proxy.example.com/v1" || c.AIModel != "my-model" {
		t.Errorf("explicit env must beat preset, got %q / %q", c.AIBaseURL, c.AIModel)
	}
}

func TestAIPresetUnsetStaysGemini(t *testing.T) {
	c := loadFor(t, nil)
	if c.AIBaseURL != "https://generativelanguage.googleapis.com/v1beta/openai" {
		t.Errorf("default base = %q", c.AIBaseURL)
	}
	if c.AIModel != "gemini-3.6-flash" {
		t.Errorf("default model = %q", c.AIModel)
	}
}

func TestAIPresetGroqAndOpenRouter(t *testing.T) {
	c := loadFor(t, map[string]string{"AI_PROVIDER": "groq"})
	if c.AIModel != "llama-3.3-70b-versatile" {
		t.Errorf("groq model = %q", c.AIModel)
	}
	c = loadFor(t, map[string]string{"AI_PROVIDER": "openrouter"})
	if c.AIBaseURL != "https://openrouter.ai/api/v1" {
		t.Errorf("openrouter base = %q", c.AIBaseURL)
	}
}
