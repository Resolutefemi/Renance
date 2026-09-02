// Package config loads service configuration from the environment.
//
// ERA-2 law (ADR-0004): the service is DATABASE_URL-agnostic — point it at
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
	DataDir        string // dir containing manifest.json + questions/ + answer-keys/
	WebOrigin      string // comma-separated CORS allowlist ("*" keeps dev open)
	GoogleClientID string // Google OAuth audience(s), comma-separated (web + Android); "" disables Google sign-in
	GradeWorkers   int
	GradeQueue     int
}

func Load() (*Config, error) {
	c := &Config{
		Port:           envInt("PORT", 3990),
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		JWTSecret:      os.Getenv("JWT_SECRET"),
		DataDir:        os.Getenv("DATA_DIR"),
		WebOrigin:      envStr("WEB_ORIGIN", "*"),
		GoogleClientID: strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_ID")),
		GradeWorkers:   envInt("GRADE_WORKERS", 8),
		GradeQueue:     envInt("GRADE_QUEUE", 1024),
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
