// pool.go - the database surface every package programs against.
//
// It used to be the concrete *pgxpool.Pool. The dual-write mirror
// (founder directive 2026-10-15: "everything should save
// simultaneously on both Neon and Supabase at once") needs to
// intercept every write and fan it out to the mirror databases, so
// the field is now this interface: *pgxpool.Pool satisfies it
// directly (a no-mirror deploy behaves exactly as before), and
// internal/store/mirror.go wraps a primary pool with best-effort
// mirrors.
//
// Reads (Query, QueryRow) are PRIMARY-ONLY by doctrine: the primary
// is authoritative and the mirrors can lag a write behind, so a read
// that bounced to a mirror could serve stale counters. Writes
// (Exec, SendBatch, Begin -> Tx.Exec, CopyFrom) fan out.
package store

import (
        "context"

        "github.com/jackc/pgx/v5"
        "github.com/jackc/pgx/v5/pgconn"
)

// Pool is the complete database surface the study-api uses. It is
// deliberately minimal: exactly the methods the codebase calls, so a
// mirror wrapper can implement all of it honestly. Anything new that
// needs a pool method grows the interface here first.
type Pool interface {
        // Writes: mirrored when a mirror is attached.
        Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
        SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults
        Begin(ctx context.Context) (pgx.Tx, error)

        // Reads: primary only, always.
        Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
        QueryRow(ctx context.Context, sql string, args ...any) pgx.Row

        // Health + lifecycle. Ping probes the primary only: the
        // dbwatch exit doctrine keys on the authoritative database.
        Ping(ctx context.Context) error
        Close()
}
