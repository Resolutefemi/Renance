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
//      r2-status             the Cloudflare R2 lesson-blob ledger: rows in
//                            learn.lessons vs objects in the bucket, with
//                            bytes
//      r2-push               one-time backfill: every learn.lessons row on
//                            the cache database uploads to R2 as
//                            lessons/<topic_id>.json (resumable - objects
//                            already in the bucket skip unless --force)
//      r2-restore            the disaster-rebuild path: every bucket object
//                            upserts back into learn.lessons on the cache
//                            database (hit_count resets; the bucket was
//                            always the durable home)
//
// Destructive subcommands need --yes. All DSNs come from the same
// environment the API boots with: USER_DATABASE_URL /
// DATABASE_URL, CONTENT_DATABASE_URL, CACHE_DATABASE_URL /
// INSFORGE_DATABASE_URL. The R2 commands additionally need
// R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
// (optional R2_PREFIX) - the same variables the API boots with.
package main

import (
        "context"
        "encoding/json"
        "fmt"
        "log/slog"
        "os"
        "strings"
        "time"

        "renance.dev/study-api/internal/learn"
        "renance.dev/study-api/internal/r2store"
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
  r2-status             lesson rows in the cache database vs objects in the R2 bucket
  r2-push               backfill every cache lesson row into R2 (resumable, --force rewrites)
  r2-restore            rebuild learn.lessons from the R2 bucket (--yes required)

environment: USER_DATABASE_URL (or DATABASE_URL), CONTENT_DATABASE_URL,
CACHE_DATABASE_URL (or INSFORGE_DATABASE_URL); the r2-* commands also
need R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY.
`)
                os.Exit(2)
        }
        cmd := os.Args[1]
        yes := false
        force := false
        for _, a := range os.Args[2:] {
                switch a {
                case "--yes":
                        yes = true
                case "--force":
                        force = true
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

        case "r2-status":
                // The migration ledger: rows on the cache database vs
                // objects in the bucket. When the two counts agree (or
                // the bucket is ahead - freshly generated lessons dual-
                // write), the backfill is complete.
                k := cacheStore()
                blobs := r2store.FromEnv(log)
                if blobs == nil {
                        fatalf("r2-status: set R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY (optional R2_PREFIX) first")
                }
                var rows int64
                if err := k.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM learn.lessons`).Scan(&rows); err != nil {
                        fatalf("r2-status: count learn.lessons: %v", err)
                }
                objects, err := blobs.ListLessons(ctx)
                if err != nil {
                        fatalf("r2-status: list bucket: %v", err)
                }
                var bytes int64
                for _, sz := range objects {
                        bytes += sz
                }
                fmt.Printf("cache database rows  : %d\n", rows)
                fmt.Printf("bucket objects       : %d (prefix %s)\n", len(objects), blobs.Prefix())
                fmt.Printf("bucket lesson bytes  : %.1f MB\n", float64(bytes)/1048576)
                if int(rows) > len(objects) {
                        fmt.Printf("backfill pending     : %d rows not yet in the bucket (run r2-push)\n", int(rows)-len(objects))
                } else {
                        fmt.Printf("backfill complete    : the bucket covers every database row\n")
                }
                fmt.Printf("bucket is the durable home; database is the index\n")

        case "r2-push":
                // The one-time backfill (runbook: docs/cloudflare-r2.md).
                // Streams every learn.lessons row off the cache database
                // and PUTs it as lessons/<topic_id>.json. Resumable: the
                // bucket's existing keys skip unless --force, so a half-
                // finished run continues where it stopped. 36k rows of
                // ~40 KB is ~1.5 GB - inside the 10 GB free tier.
                k := cacheStore()
                blobs := r2store.FromEnv(log)
                if blobs == nil {
                        fatalf("r2-push: set R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY (optional R2_PREFIX) first")
                }
                existing, err := blobs.ListLessons(ctx)
                if err != nil {
                        fatalf("r2-push: list bucket: %v", err)
                }
                fmt.Printf("r2-push: %d objects already in the bucket (skip unless --force)\n", len(existing))
                rows, err := k.Pool.Query(ctx, `
                        SELECT topic_id, title, summary, notes, key_points, quiz, drawings, source,
                               COALESCE(generated_at::text, '')
                        FROM learn.lessons ORDER BY topic_id`)
                if err != nil {
                        fatalf("r2-push: read learn.lessons: %v", err)
                }
                defer rows.Close()
                pushed, skipped, failed, total := 0, 0, 0, 0
                for rows.Next() {
                        var blob learn.LessonBlob
                        var notes, kp, quiz, draw []byte
                        if err := rows.Scan(&blob.TopicID, &blob.Title, &blob.Summary,
                                &notes, &kp, &quiz, &draw, &blob.Source, &blob.GeneratedAt); err != nil {
                                fatalf("r2-push: scan: %v", err)
                        }
                        blob.Notes, blob.KeyPoints, blob.Quiz, blob.Drawings = notes, kp, quiz, draw
                        total++
                        if _, done := existing[blob.TopicID]; done && !force {
                                skipped++
                                continue
                        }
                        payload, err := json.Marshal(blob)
                        if err != nil {
                                fmt.Fprintf(os.Stderr, "  marshal %s: %v\n", blob.TopicID, err)
                                failed++
                                continue
                        }
                        if err := blobs.Put(ctx, blob.TopicID, payload); err != nil {
                                fmt.Fprintf(os.Stderr, "  put %s: %v\n", blob.TopicID, err)
                                failed++
                                continue
                        }
                        pushed++
                        if pushed%500 == 0 {
                                fmt.Printf("  ... %d pushed, %d skipped, %d failed (scanned %d)\n", pushed, skipped, failed, total)
                        }
                }
                if err := rows.Err(); err != nil {
                        fatalf("r2-push: rows: %v", err)
                }
                fmt.Printf("r2-push complete: pushed %d, skipped %d, failed %d (scanned %d rows)\n", pushed, skipped, failed, total)
                if failed > 0 {
                        os.Exit(1)
                }

        case "r2-restore":
                // The disaster-rebuild path: the cache database was lost
                // or wiped, the bucket holds everything. Every object
                // upserts back into learn.lessons (hit_count restarts at
                // zero - it is a serving statistic, not content).
                if !yes {
                        fatalf("r2-restore overwrites cache rows - pass --yes when sure")
                }
                k := cacheStore()
                blobs := r2store.FromEnv(log)
                if blobs == nil {
                        fatalf("r2-restore: set R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY (optional R2_PREFIX) first")
                }
                objects, err := blobs.ListLessons(ctx)
                if err != nil {
                        fatalf("r2-restore: list bucket: %v", err)
                }
                fmt.Printf("r2-restore: %d objects in the bucket\n", len(objects))
                restored, failed := 0, 0
                for topicID := range objects {
                        payload, ok, err := blobs.Get(ctx, topicID)
                        if err != nil || !ok {
                                fmt.Fprintf(os.Stderr, "  get %s: ok=%v err=%v\n", topicID, ok, err)
                                failed++
                                continue
                        }
                        var blob learn.LessonBlob
                        if err := json.Unmarshal(payload, &blob); err != nil {
                                fmt.Fprintf(os.Stderr, "  decode %s: %v\n", topicID, err)
                                failed++
                                continue
                        }
                        if _, err := k.Pool.Exec(ctx, `
                                INSERT INTO learn.lessons (topic_id, title, summary, notes, key_points, quiz, drawings, source, generated_at)
                                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,COALESCE(NULLIF($9,'')::timestamptz, now()))
                                ON CONFLICT (topic_id) DO UPDATE SET title=$2, summary=$3, notes=$4, key_points=$5,
                                  quiz=$6, drawings=$7, source=$8, generated_at=COALESCE(NULLIF($9,'')::timestamptz, learn.lessons.generated_at)`,
                                blob.TopicID, blob.Title, blob.Summary, string(blob.Notes), string(blob.KeyPoints),
                                string(blob.Quiz), string(blob.Drawings), blob.Source, blob.GeneratedAt); err != nil {
                                fmt.Fprintf(os.Stderr, "  upsert %s: %v\n", topicID, err)
                                failed++
                                continue
                        }
                        restored++
                        if restored%500 == 0 {
                                fmt.Printf("  ... %d restored, %d failed\n", restored, failed)
                        }
                }
                fmt.Printf("r2-restore complete: restored %d, failed %d\n", restored, failed)
                if failed > 0 {
                        os.Exit(1)
                }

        default:
                fatalf("unknown command %q", cmd)
        }
}
