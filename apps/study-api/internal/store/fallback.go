// fallback.go - the multi-database fallback layer (founder directive
// 2026-10-15: "can the project share two databases, or use another
// database as a backup when the first one's free trial ends?").
//
// Order: DATABASE_URL (Neon, the primary) first, then every DSN in
// FALLBACK_DATABASE_URLS. When that list is empty the two named
// fallbacks are collected instead: SUPABASE_DATABASE_URL first, then
// INSFORGE_DATABASE_URL - the founder's Supabase and InsForge
// databases.
//
// Boot: the first DSN that connects AND answers the ping wins. The
// schema migrations then run on the winner, and the normal boot path
// (curriculum seed, premium backfill) provisions a fresh fallback
// database automatically - a failover boot leaves nothing missing.
//
// Runtime detection lives in internal/httpapi/dbwatch.go: it never
// pings on a schedule (a scheduled ping is what keeps a serverless
// Neon compute awake and burns the 100 CU-hour budget), it only probes
// after real request failures, and when the database is truly down it
// exits the process so the platform restart re-runs this boot
// fallback onto a live DSN.
package store

import (
	"context"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"strings"
)

// FallbackDSNs returns the ordered fallback DSN list from the
// environment: FALLBACK_DATABASE_URLS when set (comma, space or
// newline separated, order preserved), else SUPABASE_DATABASE_URL
// followed by INSFORGE_DATABASE_URL.
func FallbackDSNs() []string {
	parse := func(raw string) []string {
		var out []string
		for _, dsn := range strings.FieldsFunc(raw, func(r rune) bool {
			return r == ',' || r == '\n' || r == '\r' || r == '\t' || r == ' '
		}) {
			if dsn = strings.TrimSpace(dsn); dsn != "" {
				out = append(out, dsn)
			}
		}
		return out
	}
	if raw := strings.TrimSpace(os.Getenv("FALLBACK_DATABASE_URLS")); raw != "" {
		return parse(raw)
	}
	var out []string
	for _, key := range []string{"SUPABASE_DATABASE_URL", "INSFORGE_DATABASE_URL"} {
		if v := strings.TrimSpace(os.Getenv(key)); v != "" {
			out = append(out, v)
		}
	}
	return out
}

// redactDSN masks the password of a DSN for logging. Anything it
// cannot parse collapses to a bare scheme marker - a credential must
// never reach a log line.
func redactDSN(dsn string) string {
	trimmed := strings.TrimSpace(dsn)
	u, err := url.Parse(trimmed)
	if err != nil || u.Scheme == "" {
		return "postgres://***"
	}
	if u.User != nil {
		if _, hasPassword := u.User.Password(); hasPassword {
			u.User = url.UserPassword(u.User.Username(), "***")
		}
	}
	return u.String()
}

// ConnectWithFallback walks the primary DSN followed by every fallback
// and returns a Store bound to the first that parses, connects and
// pings. Every hop is logged with the DSN redacted; when everything
// fails the returned error names every candidate (redacted) so the
// operator knows exactly what was tried.
func ConnectWithFallback(ctx context.Context, dsn string, fallbacks []string, log *slog.Logger) (*Store, error) {
	candidates := make([]string, 0, 1+len(fallbacks))
	if strings.TrimSpace(dsn) != "" {
		candidates = append(candidates, dsn)
	}
	candidates = append(candidates, fallbacks...)
	if len(candidates) == 0 {
		return nil, fmt.Errorf("store: no database configured - set DATABASE_URL (primary) and optionally FALLBACK_DATABASE_URLS")
	}
	var lastErr error
	for i, candidate := range candidates {
		if strings.TrimSpace(candidate) == "" {
			continue
		}
		role := "primary"
		if i > 0 {
			role = fmt.Sprintf("fallback %d", i)
		}
		st, err := Connect(ctx, candidate)
		if err == nil {
			if log != nil {
				log.Info("database connected",
					"dsn", redactDSN(candidate),
					"role", role,
				)
			}
			return st, nil
		}
		lastErr = err
		if log != nil {
			log.Warn("database unreachable, walking to the next candidate",
				"dsn", redactDSN(candidate),
				"role", role,
				"err", err.Error(),
			)
		}
	}
	names := make([]string, 0, len(candidates))
	for _, c := range candidates {
		if strings.TrimSpace(c) != "" {
			names = append(names, redactDSN(c))
		}
	}
	return nil, fmt.Errorf("store: every database is unreachable (tried: %s) - last error: %w",
		strings.Join(names, " -> "), lastErr)
}
