// dbsplit - the operator tool for the split-horizon databases
// (founder directive 2026-10-16: users + progress on Neon and
// InsForge, the catalog on Supabase, the lesson cache on InsForge).
//
// Subcommands:
//
//      status                per-database sizes + row counts per domain
//      copy-users            one-time user-domain copy: content -> user (overwrite)
//      adopt-mirror          one-time interim adopt: the user mirror
//                            (INSFORGE_DATABASE_URL) overwrites the user
//                            primary - carries every row written while the
//                            mirror was the live primary onto the new
//                            primary, updates included (merge mode can
//                            never heal a same-PK row)
//      move-lessons          lesson cache move: the OLD cache
//                            (INSFORGE_DATABASE_URL) merges into the NEW
//                            cache (CACHE_DATABASE_URL) - how the 36k
//                            cached lessons moved to the founder's second
//                            InsForge (1 GB) on 2026-10-16
//      seal-backfill         write the one-time split_backfill marker on
//                            the user database for the content database's
//                            system identifier (skips the boot copy when
//                            the agent already ran copy-users by hand)
//      reap-supabase-lessons DROP learn.lessons on the content database
//                            (safe: the cache lives on InsForge; misses
//                            synthesize from the embedded engine)
//      reap-supabase-users   DROP every user-domain table on the content
//                            database (run AFTER copy-users + one clean boot)
//      reap-insforge-catalog DROP the curriculum catalog tables on the cache
//                            database (frees ~275 MB for the lesson cache;
//                            run AFTER the split code is deployed - the old
//                            mirror sync would copy it all back)
//      reap-insforge-lessons DROP learn.lessons on INSFORGE_DATABASE_URL -
//                            after move-lessons + one clean boot the old
//                            cache home is pure user mirror again
//      reap-user-stale       DROP the dead catalog + lesson + legacy tables
//                            off the USER database (Neon still carried the
//                            pre-split era: 925k topics, 8,208 lessons and
//                            the unreferenced public.user_details that the
//                            split router never reads)
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
  adopt-mirror          one-time interim adopt: mirror -> user (overwrite)
  move-lessons          lesson cache move: old cache -> new cache
  seal-backfill         write the split_backfill marker on the user database
  reap-supabase-lessons drop learn.lessons on the content database
  reap-supabase-users   drop every user-domain table on the content database
  reap-insforge-catalog drop the catalog tables on the cache database
  reap-insforge-lessons drop learn.lessons on the old cache (INSFORGE_DATABASE_URL)
  reap-user-stale       drop dead catalog/lesson/legacy tables off the user database

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
        ctx, cancel := context.WithTimeout(context.Background(), 90*time.Minute)
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

        case "adopt-mirror":
                // The interim adopt (Neon cutover, 2026-10-16): the mirror
                // (InsForge) was the live user primary while the real one
                // sat disconnected, so it holds rows and row UPDATES the
                // merge-mode boot sync can never carry across (counts
                // agree, values differ). One overwrite pass mirror ->
                // primary, catalog + cache tables skipped, makes the new
                // primary exactly as fresh as the mirror was.
                u, m := userStore(), connectEnv("INSFORGE_DATABASE_URL")
                stats, err := store.SyncMirrorDataFiltered(ctx, m.Pool, u.Pool, log, "user-mirror", "user-primary", store.SyncOptions{
                        SkipTables:  store.DomainSkipTablesExported(),
                        Overwrite:   true,
                        Directional: true,
                })
                if err != nil {
                        fatalf("adopt-mirror: %v", err)
                }
                fmt.Printf("mirror adopt complete: tables checked %d, synced %d, rows %d\n",
                        stats.TablesChecked, stats.TablesSynced, stats.RowsCopied)

        case "move-lessons":
                // The lesson cache move: old cache home (InsForge #1) ->
                // the new dedicated cache database (InsForge #2). Merge
                // mode: identical deterministic rows skip, only the
                // missing ones copy, safe to re-run after a boot that
                // wrote fresh rows into the old home.
                if strings.TrimSpace(os.Getenv("CACHE_DATABASE_URL")) == "" {
                        fatalf("move-lessons needs CACHE_DATABASE_URL (the new cache home); the old home is INSFORGE_DATABASE_URL")
                }
                k, old := cacheStore(), connectEnv("INSFORGE_DATABASE_URL")
                stats, err := store.SyncMirrorDataFiltered(ctx, old.Pool, k.Pool, log, "lesson-cache-old", "lesson-cache-new", store.SyncOptions{
                        OnlyTables:  map[string]bool{"learn.lessons": true},
                        Directional: true,
                })
                if err != nil {
                        fatalf("move-lessons: %v", err)
                }
                fmt.Printf("lesson cache move complete: rows copied %d\n", stats.RowsCopied)

        case "seal-backfill":
                // Writes the split_backfill marker on the user database
                // for the CONTENT database's system identifier - the same
                // row BackfillSplit writes after its one-time user copy.
                // Run after a hand-run copy-users so the next boot skips
                // the copy instead of overwriting fresher rows with the
                // frozen content-database versions.
                u, c := userStore(), contentStore()
                var sysid int64
                if err := c.Pool.QueryRow(ctx, `SELECT system_identifier FROM pg_control_system()`).Scan(&sysid); err != nil {
                        fatalf("seal-backfill: read content sysid: %v", err)
                }
                if _, err := u.Pool.Exec(ctx, `CREATE TABLE IF NOT EXISTS public.split_backfill (
                        content_sysid text PRIMARY KEY,
                        copied_at     timestamptz NOT NULL DEFAULT now()
                )`); err != nil {
                        fatalf("seal-backfill: marker table: %v", err)
                }
                if _, err := u.Pool.Exec(ctx,
                        `INSERT INTO public.split_backfill (content_sysid) VALUES ($1)
                         ON CONFLICT (content_sysid) DO NOTHING`, fmt.Sprintf("%d", sysid)); err != nil {
                        fatalf("seal-backfill: marker write: %v", err)
                }
                fmt.Printf("split_backfill sealed on the user database for content sysid %d\n", sysid)

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

        case "reap-insforge-lessons":
                if !yes {
                        fatalf("reap-insforge-lessons drops data - pass --yes when sure")
                }
                old := connectEnv("INSFORGE_DATABASE_URL")
                if _, err := old.Pool.Exec(ctx, `DROP TABLE IF EXISTS learn.lessons`); err != nil {
                        fatalf("drop learn.lessons: %v", err)
                }
                fmt.Println("learn.lessons dropped on INSFORGE_DATABASE_URL - the old cache home is a pure user mirror now")

        case "reap-user-stale":
                if !yes {
                        fatalf("reap-user-stale drops data - pass --yes when sure")
                }
                u := userStore()
                // The dead weight the split router can never read again:
                // the catalog (content domain = Supabase), the lesson cache
                // (cache domain = its own database) and the pre-split
                // public.user_details the code does not reference.
                stale := []string{
                        `learn.departments`, `learn.courses`, `learn.course_units`, `learn.topics`,
                        `learn.lessons`, `public.user_details`,
                }
                for _, t := range stale {
                        res, err := u.Pool.Exec(ctx, fmt.Sprintf(`DROP TABLE IF EXISTS %s CASCADE`, t))
                        if err != nil {
                                fmt.Fprintf(os.Stderr, "  %s: %v\n", t, err)
                                continue
                        }
                        _ = res
                        fmt.Println("  dropped " + t)
                }
                fmt.Println("user database stale tables dropped")

        default:
                fatalf("unknown command %q", cmd)
        }
}
