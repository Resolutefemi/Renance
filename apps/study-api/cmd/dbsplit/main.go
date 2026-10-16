// dbsplit - the operator tool for the split-horizon databases
// (founder directive 2026-10-16: users + progress on Neon and
// InsForge, the catalog on Supabase, the lesson cache on InsForge).
//
// Subcommands:
//
//	status                per-database sizes + row counts per domain
//	copy-users            one-time user-domain copy: content -> user (overwrite)
//	copy-lessons          lesson cache merge: content -> cache (DO NOTHING)
//	reap-supabase-lessons DROP learn.lessons on the content database
//	                      (safe: the cache lives on InsForge; misses
//	                      synthesize from the embedded engine)
//	reap-supabase-users   DROP every user-domain table on the content
//	                      database (run AFTER copy-users + one clean boot)
//	reap-insforge-catalog DROP the curriculum catalog tables on the cache
//	                      database (frees ~275 MB for the lesson cache;
//	                      run AFTER the split code is deployed - the old
//	                      mirror sync would copy it all back)
//
// Destructive subcommands need --yes. All DSNs come from the same
// environment the API boots with: USER_DATABASE_URL /
// DATABASE_URL, CONTENT_DATABASE_URL, CACHE_DATABASE_URL /
// INSFORGE_DATABASE_URL.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"renance.dev/study-api/internal/store"
)

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "dbsplit: "+format+"\n", args...)
	os.Exit(1)
}

func connectEnv(key string) *store.Store {
	dsn := strings.TrimSpace(os.Getenv(key))
	if dsn == "" {
		fatalf("%s is not set", key)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	st, err := store.Connect(ctx, dsn)
	if err != nil {
		fatalf("%s connect: %v", key, err)
	}
	return st
}

func userStore() *store.Store {
	if strings.TrimSpace(os.Getenv("USER_DATABASE_URL")) != "" {
		return connectEnv("USER_DATABASE_URL")
	}
	return connectEnv("DATABASE_URL")
}

func contentStore() *store.Store {
	return connectEnv("CONTENT_DATABASE_URL")
}

func cacheStore() *store.Store {
	if strings.TrimSpace(os.Getenv("CACHE_DATABASE_URL")) != "" {
		return connectEnv("CACHE_DATABASE_URL")
	}
	return connectEnv("INSFORGE_DATABASE_URL")
}

var sizeQuery = `
        SELECT pg_size_pretty(pg_database_size(current_database())) AS size,
               pg_database_size(current_database())/1048576 AS mb`

func report(ctx context.Context, st *store.Store, label string) {
	var size string
	var mb int64
	if err := st.Pool.QueryRow(ctx, sizeQuery).Scan(&size, &mb); err != nil {
		fmt.Printf("%-10s unreachable: %v\n", label, err)
		return
	}
	fmt.Printf("%-10s %s (%d MB)\n", label, size, mb)
	counts := []struct{ name, sql string }{
		{"departments", `SELECT COUNT(*) FROM learn.departments`},
		{"courses", `SELECT COUNT(*) FROM learn.courses`},
		{"course_units", `SELECT COUNT(*) FROM learn.course_units`},
		{"topics", `SELECT COUNT(*) FROM learn.topics`},
		{"lessons", `SELECT COUNT(*) FROM learn.lessons`},
		{"study.users", `SELECT COUNT(*) FROM study.users`},
		{"learners", `SELECT COUNT(*) FROM learn.learners`},
		{"progress", `SELECT COUNT(*) FROM learn.progress`},
		{"user_courses", `SELECT COUNT(*) FROM learn.user_courses`},
		{"social.posts", `SELECT COUNT(*) FROM social.posts`},
	}
	for _, c := range counts {
		var n int64
		if err := st.Pool.QueryRow(ctx, c.sql).Scan(&n); err == nil && n > 0 {
			fmt.Printf("           %-14s %d\n", c.name, n)
		}
	}
}

func main() {
	log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelWarn}))
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, `dbsplit - the split-horizon operator tool

usage: dbsplit <command> [--yes]

commands:
  status                per-database sizes + row counts per domain
  copy-users            one-time user copy: content -> user (overwrite)
  copy-lessons          lesson cache merge: content -> cache
  reap-supabase-lessons drop learn.lessons on the content database
  reap-supabase-users   drop every user-domain table on the content database
  reap-insforge-catalog drop the catalog tables on the cache database

environment: USER_DATABASE_URL (or DATABASE_URL), CONTENT_DATABASE_URL,
CACHE_DATABASE_URL (or INSFORGE_DATABASE_URL).
`)
		os.Exit(2)
	}
	cmd := os.Args[1]
	yes := false
	for _, a := range os.Args[2:] {
		if a == "--yes" {
			yes = true
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	switch cmd {
	case "status":
		report(ctx, userStore(), "user")
		report(ctx, contentStore(), "content")
		report(ctx, cacheStore(), "cache")

	case "copy-users":
		u, c := userStore(), contentStore()
		stats, err := store.SyncMirrorDataFiltered(ctx, c.Pool, u.Pool, log, "content-legacy", "user-primary", store.SyncOptions{
			SkipTables:  store.DomainSkipTablesExported(),
			Overwrite:   true,
			Directional: true,
		})
		if err != nil {
			fatalf("copy-users: %v", err)
		}
		fmt.Printf("user copy complete: tables checked %d, synced %d, rows %d\n",
			stats.TablesChecked, stats.TablesSynced, stats.RowsCopied)

	case "copy-lessons":
		c, k := contentStore(), cacheStore()
		stats, err := store.SyncMirrorDataFiltered(ctx, c.Pool, k.Pool, log, "content-legacy", "lesson-cache", store.SyncOptions{
			OnlyTables:  map[string]bool{"learn.lessons": true},
			Directional: true,
		})
		if err != nil {
			fatalf("copy-lessons: %v", err)
		}
		fmt.Printf("lesson merge complete: rows copied %d\n", stats.RowsCopied)

	case "reap-supabase-lessons":
		if !yes {
			fatalf("reap-supabase-lessons drops data - pass --yes when sure")
		}
		c := contentStore()
		if _, err := c.Pool.Exec(ctx, `DROP TABLE IF EXISTS learn.lessons`); err != nil {
			fatalf("drop learn.lessons: %v", err)
		}
		fmt.Println("learn.lessons dropped on the content database")

	case "reap-supabase-users":
		if !yes {
			fatalf("reap-supabase-users drops data - pass --yes when sure")
		}
		c := contentStore()
		tables, err := store.UserDomainTables(ctx, c.Pool)
		if err != nil {
			fatalf("list user tables: %v", err)
		}
		if len(tables) == 0 {
			fmt.Println("no user-domain tables left on the content database")
			return
		}
		fmt.Printf("dropping %d user-domain tables off the content database...\n", len(tables))
		for _, t := range tables {
			if _, err := c.Pool.Exec(ctx, fmt.Sprintf(`DROP TABLE IF EXISTS %s CASCADE`, t)); err != nil {
				fmt.Fprintf(os.Stderr, "  %s: %v\n", t, err)
				continue
			}
			fmt.Println("  dropped " + t)
		}

	case "reap-insforge-catalog":
		if !yes {
			fatalf("reap-insforge-catalog drops data - pass --yes when sure")
		}
		k := cacheStore()
		tables, err := store.CatalogTables(ctx, k.Pool)
		if err != nil {
			fatalf("list catalog tables: %v", err)
		}
		if len(tables) == 0 {
			fmt.Println("no catalog tables left on the cache database")
			return
		}
		fmt.Printf("dropping %d catalog tables off the cache database...\n", len(tables))
		for _, t := range tables {
			if _, err := k.Pool.Exec(ctx, fmt.Sprintf(`DROP TABLE IF EXISTS %s CASCADE`, t)); err != nil {
				fmt.Fprintf(os.Stderr, "  %s: %v\n", t, err)
				continue
			}
			fmt.Println("  dropped " + t)
		}

	default:
		fatalf("unknown command %q", cmd)
	}
}
