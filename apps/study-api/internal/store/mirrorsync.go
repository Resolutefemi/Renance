// mirrorsync.go - the self-healing row sync between the primary and
// a mirror (founder directive 2026-10-15: "make sure you copy all the
// user details, all the dB, to Supabase too").
//
// WHAT IT DOES: a bidirectional MISSING-ROW merge over every app
// table (study, learn, social, arena, school schemas):
//
//   primary ahead  -> rows the mirror lacks are copied to the mirror
//                     (the normal case: Neon collected user rows the
//                     fallbacks never had)
//   mirror ahead   -> rows the primary lacks are copied BACK to the
//                     primary (the comeback case: the service ran on
//                     Supabase for a while and Neon came back) - safe
//                     because every key is a UUID or an explicit id
//                     and only one side is ever primary at a time.
//
// Rows flow as whole JSON rows: `SELECT to_jsonb(t) FROM tbl t` on
// the source, then
// `INSERT INTO tbl SELECT * FROM jsonb_populate_recordset(NULL::tbl,
// $1::jsonb) ON CONFLICT DO NOTHING` on the destination - one
// round-trip per 250 rows, no column lists to maintain, every type
// (uuid, timestamptz, jsonb, arrays, numeric) round-trips through
// JSON, and conflicts (same row on both sides, or a username unique
// index) skip silently. Table order follows the foreign-key graph
// (Kahn), so parents land before children.
//
// Sequences are re-based afterwards (setval to each side's own MAX)
// so a failover boot that starts generating bigserial ids on the
// mirror can never collide with ids copied across.
//
// VISIBILITY: every run appends a row to public.mirror_sync on BOTH
// sides - open the Supabase Table Editor (public schema) and the run
// history is right there next to db_keepalive.
//
// Runs at boot in the background (main.go), bounded by a 15-minute
// context, and is idempotent: in-sync tables cost one COUNT each.
// MIRROR_SYNC=0 disables it.
package store

import (
        "context"
        "fmt"
        "log/slog"
        "os"
        "strconv"
        "strings"
        "time"
)

// appSchemas are the schemas the app owns; provider schemas (auth,
// storage, realtime, vault, cron, monitoring, ...) are NEVER touched.
var appSchemas = []string{"study", "learn", "social", "arena", "school"}

// syncChunkRows is the row count per INSERT round-trip.
const syncChunkRows = 250

// SyncStats reports one merge pass.
type SyncStats struct {
        TablesChecked int
        TablesSynced  int
        RowsCopied    int64
}

// MirrorSyncEnabled reads MIRROR_SYNC (default true).
func MirrorSyncEnabled() bool {
        v := strings.TrimSpace(os.Getenv("MIRROR_SYNC"))
        if v == "" {
                return true
        }
        if n, err := strconv.Atoi(v); err == nil {
                return n != 0
        }
        switch strings.ToLower(v) {
        case "0", "f", "false", "no", "off":
                return false
        }
        return true
}

type syncTable struct {
        schema string
        name   string
        qname  string // "study"."users" quoted
}

// SyncMirrorData merges missing rows between a and b (either side may
// be ahead) and re-bases sequences. It never deletes and never
// overwrites an existing row (ON CONFLICT DO NOTHING).
func SyncMirrorData(ctx context.Context, a, b Pool, log *slog.Logger, aLabel, bLabel string) (*SyncStats, error) {
        stats := &SyncStats{}
        started := time.Now()

        aTables, err := listAppTables(ctx, a)
        if err != nil {
                return nil, fmt.Errorf("sync: list %s: %w", aLabel, err)
        }
        bTables, err := listAppTables(ctx, b)
        if err != nil {
                return nil, fmt.Errorf("sync: list %s: %w", bLabel, err)
        }
        bSet := map[string]bool{}
        for _, t := range bTables {
                bSet[t.schema+"."+t.name] = true
        }
        shared := make([]syncTable, 0, len(aTables))
        for _, t := range aTables {
                if bSet[t.schema+"."+t.name] {
                        shared = append(shared, t)
                } else if log != nil {
                        log.Warn("sync: table exists on one side only - run migrations on both databases",
                                "table", t.schema+"."+t.name, "a", aLabel, "b", bLabel)
                }
        }
        if len(shared) == 0 {
                return stats, nil
        }

        // Foreign-key ordering (Kahn) so parents copy before children.
        order, cyclic := topologicalTables(ctx, a, shared)
        if len(cyclic) > 0 && log != nil {
                log.Warn("sync: foreign-key cycle or self-reference detected - those tables sync last, best-effort",
                        "tables", cyclic)
        }

        // One count query per side over every shared table.
        countsA, err := countTables(ctx, a, order)
        if err != nil {
                return nil, fmt.Errorf("sync: count %s: %w", aLabel, err)
        }
        countsB, err := countTables(ctx, b, order)
        if err != nil {
                return nil, fmt.Errorf("sync: count %s: %w", bLabel, err)
        }

        for _, t := range order {
                stats.TablesChecked++
                ca, cb := countsA[t.qname], countsB[t.qname]
                if ca == cb {
                        continue
                }
                if cb < ca {
                        copied, err := copyRows(ctx, a, b, t)
                        if err != nil {
                                if log != nil {
                                        log.Error("sync: copy failed - the table stays behind, retried next boot",
                                                "table", t.schema+"."+t.name, "direction", aLabel+" -> "+bLabel, "err", err.Error())
                                }
                                continue
                        }
                        stats.TablesSynced++
                        stats.RowsCopied += copied
                        if log != nil {
                                log.Info("sync: rows copied",
                                        "table", t.schema+"."+t.name,
                                        "direction", aLabel+" -> "+bLabel,
                                        "rows", copied,
                                        "was", cb, "now", ca)
                        }
                } else {
                        // The mirror is ahead (the comeback case): copy
                        // back to the primary.
                        copied, err := copyRows(ctx, b, a, t)
                        if err != nil {
                                if log != nil {
                                        log.Error("sync: back-copy failed - the table stays behind, retried next boot",
                                                "table", t.schema+"."+t.name, "direction", bLabel+" -> "+aLabel, "err", err.Error())
                                }
                                continue
                        }
                        stats.TablesSynced++
                        stats.RowsCopied += copied
                        if log != nil {
                                log.Info("sync: rows copied back to the primary",
                                        "table", t.schema+"."+t.name,
                                        "direction", bLabel+" -> "+aLabel,
                                        "rows", copied,
                                        "was", ca, "now", cb)
                        }
                }
        }

        // Sequences: re-base both sides on their own post-copy MAX so
        // failover-generated bigserial ids can never collide.
        for _, pool := range []Pool{a, b} {
            if err := rebaseSequences(ctx, pool); err != nil {
                if log != nil {
                        log.Warn("sync: sequence re-base failed (non-fatal)", "err", err.Error())
                }
            }
        }

        // Visible run journal on BOTH sides (public.mirror_sync).
        noteSyncRun(ctx, a, bLabel, stats)
        noteSyncRun(ctx, b, aLabel, stats)

        if log != nil {
                log.Info("sync: merge pass complete",
                        "a", aLabel, "b", bLabel,
                        "tablesChecked", stats.TablesChecked,
                        "tablesSynced", stats.TablesSynced,
                        "rowsCopied", stats.RowsCopied,
                        "took", time.Since(started).Round(time.Millisecond).String())
        }
        return stats, nil
}

// listAppTables returns the app-schema tables that exist on pool.
func listAppTables(ctx context.Context, pool Pool) ([]syncTable, error) {
        rows, err := pool.Query(ctx, `
                SELECT n.nspname, c.relname
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind = 'r' AND n.nspname = ANY($1)
                ORDER BY n.nspname, c.relname`, appSchemas)
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        var out []syncTable
        for rows.Next() {
                var t syncTable
                if err := rows.Scan(&t.schema, &t.name); err != nil {
                        return nil, err
                }
                t.qname = quoteQualified(t.schema, t.name)
                out = append(out, t)
        }
        return out, rows.Err()
}

// topologicalTables orders tables so FK parents come first. Tables in
// cycles (or self-referencing) are appended at the end and returned
// separately.
func topologicalTables(ctx context.Context, pool Pool, tables []syncTable) (order []syncTable, cyclic []string) {
        // Edges: child -> parent, restricted to the tables we have.
        have := map[string]int{}
        for i, t := range tables {
                have[t.schema+"."+t.name] = i
        }
        deps := make([][]int, len(tables)) // deps[i] = indexes this table depends on
        rows, err := pool.Query(ctx, `
                SELECT ns.nspname || '.' || cs.relname AS child,
                       np.nspname || '.' || cp.relname AS parent
                FROM pg_constraint k
                JOIN pg_class cs ON cs.oid = k.conrelid
                JOIN pg_namespace ns ON ns.oid = cs.relnamespace
                JOIN pg_class cp ON cp.oid = k.confrelid
                JOIN pg_namespace np ON np.oid = cp.relnamespace
                WHERE k.contype = 'f' AND ns.nspname = ANY($1)`, appSchemas)
        if err != nil {
                return tables, nil // unreadable graph: keep catalog order
        }
        defer rows.Close()
        for rows.Next() {
                var child, parent string
                if err := rows.Scan(&child, &parent); err != nil {
                        return tables, nil
                }
                ci, okC := have[child]
                pi, okP := have[parent]
                if okC && okP {
                        deps[ci] = append(deps[ci], pi)
                }
        }

        // Kahn over the subgraph.
        resolved := make([]bool, len(tables))
        progress := true
        for progress {
                progress = false
                for i := range tables {
                        if resolved[i] {
                                continue
                        }
                        ready := true
                        for _, d := range deps[i] {
                                if !resolved[d] {
                                        ready = false
                                        break
                                }
                        }
                        if ready {
                                resolved[i] = true
                                order = append(order, tables[i])
                                progress = true
                        }
                }
        }
        for i, ok := range resolved {
                if !ok {
                        cyclic = append(cyclic, tables[i].schema+"."+tables[i].name)
                        order = append(order, tables[i])
                }
        }
        return order, cyclic
}

// countTables counts every table in ONE round-trip per pool; each
// row carries its own table name so nothing depends on result order.
func countTables(ctx context.Context, pool Pool, tables []syncTable) (map[string]int64, error) {
        var b strings.Builder
        for i, t := range tables {
                if i > 0 {
                        b.WriteString(" UNION ALL ")
                }
                fmt.Fprintf(&b, "SELECT %s AS t, count(*)::bigint AS n FROM %s",
                        quoteLiteral(t.qname), t.qname)
        }
        rows, err := pool.Query(ctx, b.String())
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        out := make(map[string]int64, len(tables))
        for rows.Next() {
                var name string
                var n int64
                if err := rows.Scan(&name, &n); err != nil {
                        return nil, err
                }
                out[name] = n
        }
        return out, rows.Err()
}

// quoteLiteral renders a SQL string literal.
func quoteLiteral(s string) string {
        return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

// copyRows streams source rows as JSON and upserts them into dst in
// chunks, skipping rows that already exist.
func copyRows(ctx context.Context, src, dst Pool, t syncTable) (int64, error) {
        rows, err := src.Query(ctx, fmt.Sprintf("SELECT to_jsonb(u) FROM %s u", t.qname))
        if err != nil {
                return 0, fmt.Errorf("read: %w", err)
        }
        defer rows.Close()
        var total int64
        chunk := make([]string, 0, syncChunkRows)
        flush := func() error {
                if len(chunk) == 0 {
                        return nil
                }
                payload := "[" + strings.Join(chunk, ",") + "]"
                if _, err := dst.Exec(ctx, fmt.Sprintf(
                        "INSERT INTO %s SELECT * FROM jsonb_populate_recordset(NULL::%s, $1::jsonb) ON CONFLICT DO NOTHING",
                        t.qname, t.qname), payload); err != nil {
                        return fmt.Errorf("write: %w", err)
                }
                total += int64(len(chunk))
                chunk = chunk[:0]
                return nil
        }
        for rows.Next() {
                var j string
                if err := rows.Scan(&j); err != nil {
                        return total, fmt.Errorf("scan: %w", err)
                }
                chunk = append(chunk, j)
                if len(chunk) >= syncChunkRows {
                        if err := flush(); err != nil {
                                return total, err
                        }
                }
        }
        if err := rows.Err(); err != nil {
                return total, fmt.Errorf("read: %w", err)
        }
        if err := flush(); err != nil {
                return total, err
        }
        return total, nil
}

// rebaseSequences moves every column-owned sequence to that
// database's own MAX of its column.
func rebaseSequences(ctx context.Context, pool Pool) error {
        rows, err := pool.Query(ctx, `
                SELECT quote_literal(ns.nspname || '.' || s.relname),
                       quote_ident(tn.nspname) || '.' || quote_ident(t.relname),
                       quote_ident(a.attname)
                FROM pg_class s
                JOIN pg_namespace ns ON ns.oid = s.relnamespace
                JOIN pg_depend d ON d.objid = s.oid AND d.deptype = 'a'
                JOIN pg_class t ON t.oid = d.refobjid
                JOIN pg_namespace tn ON tn.oid = t.relnamespace
                JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
                WHERE s.relkind = 'S' AND ns.nspname = ANY($1)`, appSchemas)
        if err != nil {
                return err
        }
        type seqJob struct{ setval, tbl, col string }
        var jobs []seqJob
        for rows.Next() {
                var j seqJob
                if err := rows.Scan(&j.setval, &j.tbl, &j.col); err != nil {
                        rows.Close()
                        return err
                }
                jobs = append(jobs, j)
        }
        rows.Close()
        if err := rows.Err(); err != nil {
                return err
        }
        for _, j := range jobs {
                stmt := fmt.Sprintf("SELECT setval(%s, GREATEST(COALESCE((SELECT MAX(%s) FROM %s), 1), 1))",
                        j.setval, j.col, j.tbl)
                if _, err := pool.Exec(ctx, stmt); err != nil {
                        return fmt.Errorf("%s: %w", j.setval, err)
                }
        }
        return nil
}

// noteSyncRun appends the run history where the founder can SEE it:
// public.mirror_sync on the given side.
func noteSyncRun(ctx context.Context, pool Pool, partner string, stats *SyncStats) {
        if _, err := pool.Exec(ctx, `
                CREATE TABLE IF NOT EXISTS public.mirror_sync (
                        id        bigserial   PRIMARY KEY,
                        partner   text        NOT NULL,
                        tables    integer     NOT NULL,
                        rows      bigint      NOT NULL,
                        ran_at    timestamptz NOT NULL DEFAULT now()
                )`); err != nil {
                return
        }
        _, _ = pool.Exec(ctx,
                `INSERT INTO public.mirror_sync (partner, tables, rows) VALUES ($1, $2, $3)`,
                partner, stats.TablesSynced, stats.RowsCopied)
}

// quoteQualified renders schema.table with both parts quoted.
func quoteQualified(schema, table string) string {
        return fmt.Sprintf("%q.%q", schema, table)
}
