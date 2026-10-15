// mirror.go - the dual-write mirror (founder directive 2026-10-15:
// "make sure you copy all the user details, all the DB, to Supabase
// too, and everything should save simultaneously on both Neon and
// Supabase at once").
//
// DESIGN, in one breath:
//
//   - The PRIMARY (Neon while it lives, then the fallback chain in
//     order) answers every read and is the only database whose errors
//     reach the student. Writes that the primary ACCEPTS are replayed
//     to every MIRROR (Supabase, then InsForge) asynchronously - a
//     student never waits on a mirror, and a failed primary write is
//     never replicated (a rejected INSERT must not half-land on a
//     mirror).
//
//   - ORDERING: each mirror owns ONE dispatch channel + ONE worker
//     goroutine, so the mirror applies writes in exactly the order
//     the primary accepted them. Transactions are special: a mirror
//     transaction is NOT opened at Begin() time (an open mirror tx
//     would hold row locks while later-queued plain writes pile up
//     behind it). Instead DualTx buffers its statements and dispatches
//     the WHOLE transaction as one composite op at COMMIT time, so
//     the mirror sees the transaction land atomically at the same
//     position the primary's commit took. Rollbacks discard the
//     buffer - the mirror never sees the transaction at all.
//
//   - RESILIENCE: a mirror that is slow, down or paused never slows
//     or fails a student request. Mirror write errors are logged
//     (throttled), consecutive failures are counted, and drops
//     (channel full) are counted too. The gaps self-heal: the boot
//     sync (mirrorsync.go) copies any rows a mirror missed, and
//     ON CONFLICT-style idempotent SQL keeps the replay safe.
//
//   - KILL SWITCHES: MIRROR_WRITES=0 boots the classic single-pool
//     behaviour (zero fan-out); MIRROR_SYNC=0 skips the boot sync.
//     Both default ON.
//
// Reads NEVER bounce to a mirror for their RESULTS (the primary is
// authoritative and a mirror can legally lag a write behind) - but a
// write riding QueryRow (INSERT ... RETURNING, the house pattern)
// still replicates AFTER the primary row scanned cleanly.
package store

import (
        "context"
        "fmt"
        "log/slog"
        "os"
        "reflect"
        "regexp"
        "strconv"
        "strings"
        "sync"
        "sync/atomic"
        "time"

        "github.com/jackc/pgx/v5"
        "github.com/jackc/pgx/v5/pgconn"
)

// mirrorWriteTimeout bounds one mirrored statement on a worker.
const mirrorWriteTimeout = 10 * time.Second

// mirrorQueueDepth is the per-mirror op backlog. Past it ops are
// dropped (counted, logged throttled) - a wedged mirror must never
// grow the process memory; the boot sync heals the gap.
const mirrorQueueDepth = 1024

// Mirror is the Pool the whole app talks to: primary + mirrors.
type Mirror struct {
        primary Pool
        workers []*mirrorWorker
        log     *slog.Logger
        enabled bool

        // failStreak counts consecutive mirror-side failures across
        // all workers (writes, batches, tx bursts, drops). The first
        // 10 failures each log a warning; after that only every
        // 100th, so a dead mirror cannot drown the log. The first
        // success after failures logs the recovery once.
        failStreak atomic.Int64
}

// mirrorWorker is one mirror database: a pool, a FIFO of ops, one
// goroutine executing them strictly in dispatch order.
type mirrorWorker struct {
        name string // short label for logs ("supabase", "insforge")
        pool Pool
        ch   chan mirrorOp
        m    *Mirror
        done chan struct{}
}

// mirrorStmt is one buffered statement of a transaction.
type mirrorStmt struct {
        sql   string
        args  []any
        batch []batchStmt // set instead of sql/args
}

// batchStmt is one query of a snapshotted batch. A *pgx.Batch may
// only be sent once, so the mirror rebuilds a fresh Batch from this
// snapshot instead of re-sending the caller's.
type batchStmt struct {
        sql  string
        args []any
}

// mirrorOp is one unit of work on a worker. Exactly one field group
// is used: a single statement, a pool-level batch snapshot, or a
// whole transaction burst.
type mirrorOp struct {
        sql   string
        args  []any

        batch []batchStmt

        txStmts []mirrorStmt
        txName  string
}

// NewMirror wraps the primary with the given mirrors (each already
// migrated). A nil/empty mirror list returns a passthrough wrapper.
func NewMirror(primary Pool, mirrors []Pool, names []string, log *slog.Logger) *Mirror {
        m := &Mirror{
                primary: primary,
                log:     log,
                enabled: mirrorWritesEnabled(),
        }
        for i, mp := range mirrors {
                if mp == nil {
                        continue
                }
                name := fmt.Sprintf("mirror-%d", i+1)
                if i < len(names) && names[i] != "" {
                        name = names[i]
                }
                w := &mirrorWorker{
                        name: name,
                        pool: mp,
                        ch:   make(chan mirrorOp, mirrorQueueDepth),
                        m:    m,
                        done: make(chan struct{}),
                }
                m.workers = append(m.workers, w)
                go w.run()
        }
        if log != nil {
                if !m.enabled {
                        log.Info("dual-write mirror DISABLED (MIRROR_WRITES=0) - single-pool behaviour")
                } else if len(m.workers) == 0 {
                        log.Info("dual-write mirror armed with no mirrors - passthrough")
                } else {
                        labels := make([]string, 0, len(m.workers))
                        for _, w := range m.workers {
                                labels = append(labels, w.name)
                        }
                        log.Info("dual-write mirror armed - every accepted write replays to the mirrors",
                                "mirrors", strings.Join(labels, ", "))
                }
        }
        return m
}

// mirrorWritesEnabled reads MIRROR_WRITES (default true).
func mirrorWritesEnabled() bool {
        v := strings.TrimSpace(os.Getenv("MIRROR_WRITES"))
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

// ─── Pool interface (primary authoritative) ───────────────────────────────

// Exec runs the write on the primary; when the primary ACCEPTS it the
// statement is queued on every mirror. A primary error returns
// unchanged and nothing is replicated.
func (m *Mirror) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
        tag, err := m.primary.Exec(ctx, sql, args...)
        if err != nil {
                return tag, err
        }
        if m.enabled && isWriteSQL(sql) {
                m.dispatch(mirrorOp{sql: sql, args: args})
        }
        return tag, nil
}

// Query reads the primary only.
func (m *Mirror) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
        return m.primary.Query(ctx, sql, args...)
}

// Query reads the primary only - UNLESS the SQL is a write riding
// QueryRow (the house pattern: INSERT/UPDATE ... RETURNING ...).
// The result row always comes from the primary; after a SUCCESSFUL
// scan the statement replays to the mirrors. A write that the
// primary rejects (unique violation, no rows) never replicates.
func (m *Mirror) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
        row := m.primary.QueryRow(ctx, sql, args...)
        if m.enabled && isWriteSQL(sql) {
                return &mirrorRow{Row: row, m: m, sql: sql, args: args}
        }
        return row
}

// mirrorRow is a pgx.Row that fans a write-with-RETURNING out to
// the mirrors once the primary row scanned cleanly (pgx.Row is
// lazy: the statement only runs at Scan time, so this is the one
// place success is knowable).
type mirrorRow struct {
        pgx.Row
        m    *Mirror
        sql  string
        args []any
        once bool
}

func (r *mirrorRow) Scan(dest ...any) error {
        err := r.Row.Scan(dest...)
        if err == nil && !r.once {
                r.once = true
                replaySQL, replayArgs, pinned := pinReturningValues(r.sql, r.args, dest)
                if os.Getenv("MIRROR_DEBUG") != "" {
                        fmt.Fprintf(os.Stderr, "MIRROR_DEBUG: queryrow write dispatching to %d mirror(s) (pinned=%v): %.80s\n",
                                len(r.m.workers), pinned, compactSQL(replaySQL))
                }
                r.m.dispatch(mirrorOp{sql: replaySQL, args: replayArgs})
        }
        return err
}

// SendBatch runs the batch on the primary (the caller drains the
// primary results as before) and queues a SNAPSHOT of the same
// queries for every mirror, where the worker replays them through a
// fresh Batch and drains it fully. A *pgx.Batch may only be sent
// once, hence the snapshot; the caller may free its batch
// afterwards.
func (m *Mirror) SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults {
        br := m.primary.SendBatch(ctx, b)
        if m.enabled {
                m.dispatch(mirrorOp{batch: snapshotBatch(b)})
        }
        return br
}

// Begin opens the primary transaction and returns a DualTx: writes
// buffer, the whole transaction replays to the mirrors atomically at
// Commit time (see the header for why not at Begin time).
func (m *Mirror) Begin(ctx context.Context) (pgx.Tx, error) {
        pt, err := m.primary.Begin(ctx)
        if err != nil {
                return nil, err
        }
        return &DualTx{pt: pt, m: m}, nil
}

// Ping probes the primary only - the dbwatch exit doctrine keys on
// the authoritative database, and a paused mirror must never restart
// the service.
func (m *Mirror) Ping(ctx context.Context) error {
        return m.primary.Ping(ctx)
}

// Close stops the workers and closes the primary plus every mirror.
func (m *Mirror) Close() {
        for _, w := range m.workers {
                w.stop()
        }
        m.primary.Close()
}

// MirrorNames labels the attached mirrors (for logs and the sync).
func (m *Mirror) MirrorNames() []string {
        out := make([]string, 0, len(m.workers))
        for _, w := range m.workers {
                out = append(out, w.name)
        }
        return out
}

// MirrorPools exposes the raw mirror pools (the boot sync reads and
// writes them directly).
func (m *Mirror) MirrorPools() []Pool {
        out := make([]Pool, 0, len(m.workers))
        for _, w := range m.workers {
                out = append(out, w.pool)
        }
        return out
}

// ─── dispatch + worker ────────────────────────────────────────────────────

// dispatch queues op on every mirror. Non-blocking: a full queue
// drops the op (counted, logged throttled) instead of ever stalling
// a student response; the boot sync heals dropped writes.
func (m *Mirror) dispatch(op mirrorOp) {
        for _, w := range m.workers {
                select {
                case w.ch <- op:
                default:
                        m.noteFailure(fmt.Sprintf("%s: mirror queue full - write dropped, the boot sync will heal it", w.name))
                }
        }
}

// noteFailure records a mirror-side failure with throttled logging.
func (m *Mirror) noteFailure(msg string) {
        streak := m.failStreak.Add(1)
        if m.log != nil && (streak <= 10 || streak%100 == 0) {
                m.log.Warn("mirror: "+msg, "consecutiveFailures", streak)
        }
}

// noteSuccess clears the failure streak, logging recovery once.
func (m *Mirror) noteSuccess(where string) {
        if streak := m.failStreak.Swap(0); streak > 0 && m.log != nil {
                m.log.Info("mirror: recovered - mirror writes are landing again",
                        "was", where, "consecutiveFailuresBefore", streak)
        }
}

// run is the worker loop: one goroutine, ops strictly in order.
func (w *mirrorWorker) run() {
        defer close(w.done)
        for op := range w.ch {
                ctx, cancel := context.WithTimeout(context.Background(), mirrorWriteTimeout)
                switch {
                case op.txStmts != nil:
                        w.runTxBurst(ctx, op)
                case op.batch != nil:
                        w.runBatch(ctx, op.batch)
                default:
                        w.runExec(ctx, op.sql, op.args)
                }
                cancel()
        }
}

// stop drains and closes the worker's pool.
func (w *mirrorWorker) stop() {
        close(w.ch)
        <-w.done
        w.pool.Close()
}

func (w *mirrorWorker) runExec(ctx context.Context, sql string, args []any) {
        tag, err := w.pool.Exec(ctx, sql, args...)
        if os.Getenv("MIRROR_DEBUG") != "" {
                fmt.Fprintf(os.Stderr, "MIRROR_DEBUG: worker %s exec: err=%v rows=%d sql=%.80s args=%v\n", w.name, err, tag.RowsAffected(), compactSQL(sql), args)
        }
        if err != nil {
                w.m.noteFailure(fmt.Sprintf("%s: %v - sql %.90s", w.name, err, compactSQL(sql)))
                return
        }
        w.m.noteSuccess(w.name)
}

// runBatch replays a pool-level batch snapshot fully (drain +
// close) on the mirror. The caller already drained the primary's
// results; the mirror side executes every queued query through a
// fresh Batch.
func (w *mirrorWorker) runBatch(ctx context.Context, snap []batchStmt) {
        nb := &pgx.Batch{}
        for _, s := range snap {
                nb.Queue(s.sql, s.args...)
        }
        br := w.pool.SendBatch(ctx, nb)
        for range snap {
                if _, err := br.Exec(); err != nil {
                        w.m.noteFailure(fmt.Sprintf("%s: batch: %v", w.name, err))
                        br.Close()
                        return
                }
        }
        if err := br.Close(); err != nil {
                w.m.noteFailure(fmt.Sprintf("%s: batch close: %v", w.name, err))
                return
        }
        w.m.noteSuccess(w.name)
}

// snapshotBatch copies a batch's queries so the mirror can replay
// them in a fresh *pgx.Batch (a Batch may only be sent once).
func snapshotBatch(b *pgx.Batch) []batchStmt {
        if b == nil {
                return nil
        }
        snap := make([]batchStmt, 0, len(b.QueuedQueries))
        for _, q := range b.QueuedQueries {
                snap = append(snap, batchStmt{sql: q.SQL, args: q.Arguments})
        }
        return snap
}

// runTxBurst replays a whole transaction on the mirror: begin, every
// buffered statement (or batch), commit. Any error aborts with a
// rollback and is counted - the boot sync heals the gap.
func (w *mirrorWorker) runTxBurst(ctx context.Context, op mirrorOp) {
        tx, err := w.pool.Begin(ctx)
        if err != nil {
                w.m.noteFailure(fmt.Sprintf("%s: tx begin: %v", w.name, err))
                return
        }
        for _, st := range op.txStmts {
                if st.batch != nil {
                        nb := &pgx.Batch{}
                        for _, s := range st.batch {
                                nb.Queue(s.sql, s.args...)
                        }
                        br := tx.SendBatch(ctx, nb)
                        for range st.batch {
                                if _, err := br.Exec(); err != nil {
                                        w.m.noteFailure(fmt.Sprintf("%s: tx batch: %v", w.name, err))
                                        _ = br.Close()
                                        _ = tx.Rollback(ctx)
                                        return
                                }
                        }
                        if err := br.Close(); err != nil {
                                w.m.noteFailure(fmt.Sprintf("%s: tx batch close: %v", w.name, err))
                                _ = tx.Rollback(ctx)
                                return
                        }
                        continue
                }
                if _, err := tx.Exec(ctx, st.sql, st.args...); err != nil {
                        w.m.noteFailure(fmt.Sprintf("%s: tx stmt: %v - sql %.90s", w.name, err, compactSQL(st.sql)))
                        _ = tx.Rollback(ctx)
                        return
                }
        }
        if err := tx.Commit(ctx); err != nil {
                w.m.noteFailure(fmt.Sprintf("%s: tx commit: %v", w.name, err))
                return
        }
        w.m.noteSuccess(w.name)
}

// compactSQL flattens a statement for log lines.
func compactSQL(sql string) string {
        return strings.Join(strings.Fields(sql), " ")
}

// isWriteSQL screens statements so the fan-out only ever ships
// writes to the mirrors. INSERT/UPDATE/DELETE heads are writes;
// WITH heads (CTEs) are writes only when the CTE chain ends in a
// data-changing statement (the codebase's WITH+SELECT reads must
// never pay a mirror round-trip). Query(...) stays read-only by
// doctrine - writes ride Exec, QueryRow (RETURNING) or SendBatch.
func isWriteSQL(sql string) bool {
        s := strings.TrimSpace(sql)
        if s == "" {
                return false
        }
        head := strings.ToLower(s[:min(len(s), 12)])
        for _, kw := range []string{"insert", "update", "delete"} {
                if strings.HasPrefix(head, kw) {
                        return true
                }
        }
        if strings.HasPrefix(head, "with") {
                return cteChangesData(s)
        }
        if strings.HasPrefix(head, "select") {
                return callsMutatingFunction(s)
        }
        return false
}

// mutatingFunctions are the schema functions that CHANGE data but
// ride SELECT heads (account purge, 0027). The mirror must replay
// them - a delete that only lands on the primary resurrects at the
// next boot sync (the mirror is ahead, the back-copy re-inserts the
// purged account). Grow this list when a new mutating function ships.
var mutatingFunctions = []string{
        "study.purge_user",
        "study.purge_deleted_users",
}

func callsMutatingFunction(s string) bool {
        for _, fn := range mutatingFunctions {
                if strings.Contains(s, fn+"(") {
                        return true
                }
        }
        return false
}

// cteChangesData reports whether a WITH... statement ends in
// INSERT/UPDATE/DELETE (a bare WITH...SELECT is a read).
func cteChangesData(sql string) bool {
        return writeTail.FindString(strings.ToLower(sql)) != ""
}

var writeTail = regexp.MustCompile(`\)\s*(insert|update|delete)\b`)

func min(a, b int) int {
        if a < b {
                return a
        }
        return b
}

// pinReturningValues rewrites an INSERT ... RETURNING so the mirror
// stores the PRIMARY's generated values instead of generating its
// own. Without this, `INSERT INTO study.users (username, password_hash)
// VALUES ($1,$2) RETURNING id, created_at` lands on the mirror with a
// FRESH random uuid - and every child row dispatched next (learners,
// sessions, profiles - all FK-keyed to the primary's uuid) fails with
// a foreign-key violation on the mirror.
//
// The rewrite (shape verified against every INSERT..RETURNING in this
// codebase; unmatched shapes replay verbatim and let the boot sync
// heal):
//
//   INSERT INTO t (a, b) VALUES ($1, $2) [ON CONFLICT ...] RETURNING x, y
//   ->
//   INSERT INTO t (a, b, x, y) VALUES ($1, $2, $3, $4) [ON CONFLICT ...]
//
// where $3/$4 carry the values the primary RETURNED (the dest slice
// after a successful Scan). UPDATE/DELETE never generate ids - they
// replay verbatim.
func pinReturningValues(sql string, args []any, dest []any) (string, []any, bool) {
        s := strings.TrimSpace(sql)
        up := strings.ToUpper(s)
        if !strings.HasPrefix(up, "INSERT") {
                return s, args, false // UPDATE/DELETE: replay as-is
        }
        retIdx := lastKeyword(s, "RETURNING")
        if retIdx < 0 {
                return s, args, false // no generated values to pin
        }
        base := strings.TrimRight(s[:retIdx], " \t\n\r")
        retCols := splitIdentList(s[retIdx+len("RETURNING"):])
        if len(retCols) == 0 || len(retCols) != len(dest) {
                // The caller scans fewer dests than RETURNING columns
                // (pgx allows that) - pinning is unsafe, replay as-is.
                return s, args, false
        }

        m := insertHeadRe.FindStringSubmatchIndex(base)
        if m == nil {
                return s, args, false
        }
        table := base[m[2]:m[3]]
        colOpen := m[1] // the full match ends just past '('
        colClose := strings.IndexByte(base[colOpen:], ')')
        if colClose < 0 {
                return s, args, false
        }
        colClose += colOpen
        cols := splitIdentList(base[colOpen:colClose])

        valIdx := keywordAt(base, colClose, "VALUES")
        if valIdx < 0 {
                return s, args, false
        }
        rest := base[valIdx+len("VALUES"):]
        tOpen := strings.IndexByte(rest, '(')
        if tOpen < 0 {
                return s, args, false
        }
        tClose := scanTupleEnd(rest, tOpen)
        if tClose < 0 {
                return s, args, false
        }
        inner := rest[tOpen+1 : tClose]
        suffix := strings.TrimSpace(rest[tClose+1:]) // ON CONFLICT ... DO ...

        // Only pin returning columns not already inserted explicitly.
        have := make(map[string]bool, len(cols))
        for _, c := range cols {
                have[strings.ToLower(c)] = true
        }
        var addCols []string
        var addVals []any
        for i, rc := range retCols {
                if have[strings.ToLower(rc)] {
                        continue
                }
                addCols = append(addCols, rc)
                addVals = append(addVals, derefScanDest(dest[i]))
        }
        if len(addCols) == 0 {
                return s, args, false
        }
        k := len(args)
        var ph []string
        for range addCols {
                k++
                ph = append(ph, "$"+strconv.Itoa(k))
        }
        var b strings.Builder
        b.WriteString("INSERT INTO ")
        b.WriteString(table)
        b.WriteString(" (")
        b.WriteString(strings.Join(cols, ", "))
        b.WriteString(", ")
        b.WriteString(strings.Join(addCols, ", "))
        b.WriteString(") VALUES (")
        b.WriteString(inner)
        b.WriteString(", ")
        b.WriteString(strings.Join(ph, ", "))
        b.WriteString(")")
        if suffix != "" {
                b.WriteString(" ")
                b.WriteString(suffix)
        }
        out := append(append([]any{}, args...), addVals...)
        return b.String(), out, true
}

// insertHeadRe captures "INSERT INTO <table> (" (case-insensitive).
var insertHeadRe = regexp.MustCompile(`(?i)^INSERT\s+INTO\s+([\w."]+)\s*\(`)

// lastKeyword finds the last whole-word, case-insensitive occurrence
// of kw outside of string literals.
func lastKeyword(s, kw string) int {
        idx := -1
        lower := strings.ToLower(s)
        needle := strings.ToLower(kw)
        for i := 0; i+len(needle) <= len(lower); {
                j := strings.Index(lower[i:], needle)
                if j < 0 {
                        break
                }
                pos := i + j
                before := pos == 0 || !isWordByte(lower[pos-1])
                after := pos+len(needle) == len(lower) || !isWordByte(lower[pos+len(needle)])
                if before && after {
                        idx = pos
                }
                i = pos + len(needle)
        }
        return idx
}

// keywordAt finds kw at or after from, before the end of the statement.
func keywordAt(s string, from int, kw string) int {
        if from >= len(s) {
                return -1
        }
        sub := s[from:]
        i := keywordIndexFold(sub, kw)
        if i < 0 {
                return -1
        }
        return from + i
}

func keywordIndexFold(s, kw string) int {
        lower := strings.ToLower(s)
        needle := strings.ToLower(kw)
        for i := 0; i+len(needle) <= len(lower); {
                j := strings.Index(lower[i:], needle)
                if j < 0 {
                        return -1
                }
                pos := i + j
                before := pos == 0 || !isWordByte(lower[pos-1])
                after := pos+len(needle) == len(lower) || !isWordByte(lower[pos+len(needle)])
                if before && after {
                        return pos
                }
                i = pos + len(needle)
        }
        return -1
}

func isWordByte(b byte) bool {
        return b == '_' || (b >= '0' && b <= '9') || (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z')
}

// splitIdentList splits a comma-separated identifier list, trimming
// spaces; empty items drop out.
func splitIdentList(s string) []string {
        var out []string
        for _, part := range strings.Split(s, ",") {
                if part = strings.TrimSpace(part); part != "" {
                        out = append(out, part)
                }
        }
        return out
}

// scanTupleEnd walks a VALUES tuple from its opening '(' to the
// matching ')', skipping single-quoted string literals.
func scanTupleEnd(s string, open int) int {
        depth := 0
        inStr := false
        for i := open; i < len(s); i++ {
                c := s[i]
                switch {
                case inStr:
                        if c == '\'' {
                                if i+1 < len(s) && s[i+1] == '\'' {
                                        i++ // escaped quote
                                } else {
                                        inStr = false
                                }
                        }
                case c == '\'':
                        inStr = true
                case c == '(':
                        depth++
                case c == ')':
                        depth--
                        if depth == 0 {
                                return i
                        }
                }
        }
        return -1
}

// derefScanDest lifts the scanned value out of a Scan destination
// pointer. []byte becomes string (jsonb/text columns replay as text;
// the schema has no bytea). A typed nil stays nil.
func derefScanDest(d any) any {
        v := reflect.Indirect(reflect.ValueOf(d))
        if !v.IsValid() {
                return nil
        }
        switch v.Kind() {
        case reflect.Invalid, reflect.Ptr, reflect.Interface, reflect.Slice, reflect.Map:
                if v.Kind() == reflect.Slice && v.Type().Elem().Kind() == reflect.Uint8 && v.Len() >= 0 {
                        return string(v.Bytes())
                }
                return nil
        }
        val := v.Interface()
        if b, ok := val.([]byte); ok {
                return string(b)
        }
        return val
}

// ─── DualTx: the transaction half ─────────────────────────────────────────

// DualTx wraps the primary transaction and buffers every accepted
// statement. Commit dispatches the whole burst to the mirrors;
// Rollback (or a failed commit) discards the buffer.
type DualTx struct {
        pt    pgx.Tx
        m     *Mirror
        mu    sync.Mutex
        stmts []mirrorStmt
}

func (t *DualTx) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
        tag, err := t.pt.Exec(ctx, sql, args...)
        if err != nil {
                return tag, err
        }
        if t.m.enabled && isWriteSQL(sql) {
                t.mu.Lock()
                t.stmts = append(t.stmts, mirrorStmt{sql: sql, args: args})
                t.mu.Unlock()
        }
        return tag, nil
}

func (t *DualTx) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
        return t.pt.Query(ctx, sql, args...)
}

func (t *DualTx) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
        row := t.pt.QueryRow(ctx, sql, args...)
        if t.m.enabled && isWriteSQL(sql) {
                return &dualTxRow{Row: row, t: t, sql: sql, args: args}
        }
        return row
}

// dualTxRow buffers a write-with-RETURNING into the transaction's
// mirror burst after the primary row scanned cleanly.
type dualTxRow struct {
        pgx.Row
        t    *DualTx
        sql  string
        args []any
        once bool
}

func (r *dualTxRow) Scan(dest ...any) error {
        err := r.Row.Scan(dest...)
        if err == nil && !r.once {
                r.once = true
                replaySQL, replayArgs, _ := pinReturningValues(r.sql, r.args, dest)
                r.t.mu.Lock()
                r.t.stmts = append(r.t.stmts, mirrorStmt{sql: replaySQL, args: replayArgs})
                r.t.mu.Unlock()
        }
        return err
}

// SendBatch runs the batch on the primary tx (caller drains) and
// buffers a snapshot for the mirror burst.
func (t *DualTx) SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults {
        br := t.pt.SendBatch(ctx, b)
        if t.m.enabled {
                t.mu.Lock()
                t.stmts = append(t.stmts, mirrorStmt{batch: snapshotBatch(b)})
                t.mu.Unlock()
        }
        return br
}

// Commit commits the primary transaction; when the primary accepts
// the whole burst replays to every mirror.
func (t *DualTx) Commit(ctx context.Context) error {
        err := t.pt.Commit(ctx)
        if err != nil {
                return err
        }
        if t.m.enabled && len(t.stmts) > 0 {
                t.mu.Lock()
                stmts := t.stmts
                t.stmts = nil
                t.mu.Unlock()
                t.m.dispatch(mirrorOp{txStmts: stmts, txName: "commit"})
        }
        return nil
}

// Rollback rolls the primary back; the buffered statements are
// discarded - the mirrors never learn about the transaction.
func (t *DualTx) Rollback(ctx context.Context) error {
        t.mu.Lock()
        t.stmts = nil
        t.mu.Unlock()
        return t.pt.Rollback(ctx)
}

// The remaining pgx.Tx surface is unused by this codebase; honest
// errors keep a future caller from silently single-DB-ing.

func (t *DualTx) Prepare(ctx context.Context, name, sql string) (*pgconn.StatementDescription, error) {
        return t.pt.Prepare(ctx, name, sql)
}

func (t *DualTx) CopyFrom(ctx context.Context, tableName pgx.Identifier, columnNames []string, rowSrc pgx.CopyFromSource) (int64, error) {
        return t.pt.CopyFrom(ctx, tableName, columnNames, rowSrc)
}

func (t *DualTx) LargeObjects() pgx.LargeObjects {
        return t.pt.LargeObjects()
}

func (t *DualTx) Conn() *pgx.Conn {
        return t.pt.Conn()
}

// Begin (nested savepoint) is not mirrored: nothing in this codebase
// nests transactions, and silently running a nested tx primary-only
// would desync the mirrors. Fail loudly instead.
func (t *DualTx) Begin(ctx context.Context) (pgx.Tx, error) {
        return nil, fmt.Errorf("store: nested transactions are not supported on a DualTx")
}
