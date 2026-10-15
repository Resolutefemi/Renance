// dbapply - applies the study-api's embedded SQL migrations to ONE
// chosen database (founder directive 2026-10-15: prepare the Supabase
// and InsForge fallback databases ahead of time).
//
// The migrations are the same ordered, journaled set the API applies
// at boot (internal/store/migrations/*.sql, embedded); this tool just
// runs them manually against a DSN so the fallback is warm BEFORE the
// first failover boot ever needs it.
//
// NEON GUARD (structural): dbapply REFUSES any DSN whose host carries
// neon.tech unless -force-neon is passed explicitly. The founder's
// compute budget (19% CU, 2026-10-15) must never be spent by accident
// from a tool run.
//
// Usage:
//
//	go run ./cmd/dbapply -dsn "$SUPABASE_DATABASE_URL"
//	go run ./cmd/dbapply -dsn "$INSFORGE_DATABASE_URL"
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"strings"
	"time"

	"renance.dev/study-api/internal/store"
)

func main() {
	dsn := flag.String("dsn", "", "the database to migrate (required)")
	forceNeon := flag.Bool("force-neon", false, "allow a neon.tech DSN despite the compute budget")
	flag.Parse()

	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	if strings.TrimSpace(*dsn) == "" {
		fmt.Fprintln(os.Stderr, "usage: go run ./cmd/dbapply -dsn postgres://... (see -help)")
		os.Exit(2)
	}
	if !*forceNeon && hostIsNeon(*dsn) {
		fmt.Fprintln(os.Stderr, "dbapply: refusing a neon.tech DSN - the Neon compute budget must not be spent by accident. Pass -force-neon to override.")
		os.Exit(2)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	st, err := store.Connect(ctx, *dsn)
	if err != nil {
		log.Error("dbapply: connect", "err", err)
		os.Exit(1)
	}
	defer st.Close()
	if err := st.Migrate(ctx); err != nil {
		log.Error("dbapply: migrate", "err", err)
		os.Exit(1)
	}
	log.Info("dbapply: schema current", "dsn", redact(*dsn))
}

func hostIsNeon(dsn string) bool {
	u, err := url.Parse(strings.TrimSpace(dsn))
	if err != nil {
		return false // let Connect produce the real error
	}
	host := strings.ToLower(u.Hostname())
	return strings.Contains(host, "neon.tech")
}

func redact(dsn string) string {
	u, err := url.Parse(strings.TrimSpace(dsn))
	if err != nil || u.Scheme == "" {
		return "postgres://***"
	}
	if u.User != nil {
		if _, ok := u.User.Password(); ok {
			u.User = url.UserPassword(u.User.Username(), "***")
		}
	}
	return u.String()
}
