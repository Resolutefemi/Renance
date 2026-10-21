// split.go - the split-horizon database router (founder directive
// 2026-10-16: "make sure users details and progress are stored in
// Neon and InsForge alone, Supabase should only hold the courses,
// topics and units").
//
// THREE DATABASES, THREE ROLES:
//
//      USER pool (Neon, mirror InsForge): every user-owned table -
//      study.*, arena.*, school.*, social.* and the learn user tables
//      (learners, progress, user_courses, active_course, mistakes,
//      daily_stats, xp_events, chest_opens, topic_chests,
//      quest_claims, league_members). Writes fan out to the InsForge
//      mirror through the existing dual-write Mirror.
//
//      CONTENT pool (Supabase): the shared curriculum catalog ONLY -
//      learn.departments, learn.courses, learn.course_units,
//      learn.topics. No user rows, no lesson cache.
//
//      CACHE pool (InsForge by default): learn.lessons, the speed
//      cache the deterministic engine fills as students read. The
//      Supabase free tier was 20 MB from the wall; the cache now grows
//      on InsForge instead, under its own storage cap.
//
// ROUTING: every statement that crosses the Pool interface is
// classified by the tables it names and sent to the pool that owns
// them. Statements naming no known table (health probes, migration
// journal) default to the USER pool. A statement that MIXES domains
// is a bug - the 12 join-across-databases statements were rewritten
// as two-step pool-safe queries - so a mixed statement degrades onto
// the pool hosting its first table (so the missing-relation error
// surfaces) and logs a throttled error with the SQL head.
//
// DEGRADATION: each domain DSN falls back to the user primary when
// unset or unreachable, so a single-database boot behaves exactly
// like the pre-split app (content and cache statements ride the one
// pool). Transactions always open on the USER pool: every tx in the
// codebase is user-domain (the catalog seed passes the content pool
// explicitly).
package store

import (
        "context"
        "crypto/sha256"
        "encoding/hex"
        "errors"
        "fmt"
        "log/slog"
        "os"
        "strings"
        "sync"
        "time"

        "github.com/jackc/pgx/v5"
        "github.com/jackc/pgx/v5/pgconn"
)

// domain tags for the classifier.
const (
        domainUser = iota
        domainContent
        domainCache
)

// contentTables are the catalog tables that live on the CONTENT pool
// (Supabase) - founder directive: Supabase holds the courses, topics
// and units with departments, and nothing else.
var contentTables = []string{
        "learn.departments",
        "learn.courses",
        "learn.course_units",
        "learn.topics",
}

// cacheTables live on the CACHE pool (InsForge).
var cacheTables = []string{
        "learn.lessons",
}

// userPrefixes: any statement naming a schema-qualified table under
// these schemas is user-domain.
var userPrefixes = []string{
        "study.", "arena.", "school.", "social.", "public.",
}

// userLearnTables are the learn-schema tables that describe student
// state, not curriculum.
var userLearnTables = []string{
        "learn.learners",
        "learn.progress",
        "learn.user_courses",
        "learn.active_course",
        "learn.mistakes",
        "learn.daily_stats",
        "learn.xp_events",
        "learn.chest_opens",
        "learn.topic_chests",
        "learn.quest_claims",
        "learn.league_members",
}

// classifySQL reports which pool owns the statement plus whether it
// MIXES domains (a rewrite regression - see warnMixed). Statements
// that name no known table default to the user pool.
func classifySQL(sql string) (domain int, mixed bool) {
        hasContent, hasCache, hasUser := false, false, false
        for _, t := range contentTables {
                if strings.Contains(sql, t) {
                        hasContent = true
                        break
                }
        }
        for _, t := range cacheTables {
                if strings.Contains(sql, t) {
                        hasCache = true
                        break
                }
        }
        if !hasUser {
                for _, p := range userPrefixes {
                        if strings.Contains(sql, p) {
                                hasUser = true
                                break
                        }
                }
        }
        if !hasUser {
                for _, t := range userLearnTables {
                        if strings.Contains(sql, t) {
                                hasUser = true
                                break
                        }
                }
        }
        switch {
        case hasUser:
                if hasContent || hasCache {
                        return domainUser, true
                }
                return domainUser, false
        case hasCache:
                if hasContent {
                        return domainCache, true
                }
                return domainCache, false
        case hasContent:
                return domainContent, false
        default:
                return domainUser, false
        }
}

// Split is the Pool the whole app talks to after the split boot: it
// implements store.Pool by routing every statement to the pool that
// owns its tables.
type Split struct {
        User    Pool // user domain, already Mirror-wrapped (InsForge mirror)
        Content Pool // catalog domain
        Cache   Pool // lesson cache domain

        sameContent bool // Content == User (single-db degradation)
        sameCache   bool // Cache == User

        log     *slog.Logger
        mixedMu sync.Mutex
        mixed   map[string]bool // throttled mixed-domain warnings by SQL hash

        // Content self-heal (the courses-are-down repair, 2026-10-17).
        // When the content chain was unreachable (or its migration
        // failed) at boot, the catalog degrades onto the user pool -
        // every catalog query then answers 42P01 forever, because
        // nothing re-probes. The healer re-runs the content chain
        // (connect + content-role migrate) after a content-routed
        // statement misses a relation there, at most once per cooldown,
        // single-flight. nil on single-pool boots.
        healMu      sync.Mutex
        healing     bool
        lastHeal    time.Time
        lastHealErr error
        healer      func() (Pool, error)

        // Content recycle (the wedged-pool repair, 2026-10-20). A
        // content pool that connects at boot and wedges at runtime
        // (Render egress rot, Supavisor session rot, stale pooler DNS)
        // used to hang every catalog request for the full 20s bound
        // FOREVER - noteContentFailure only healed the degraded-at-boot
        // shape. The recycle re-runs the content chain on a transport
        // failure; when the chain is dead it degrades the catalog onto
        // the user pool so requests fail FAST and the 42P01 heal loop
        // takes over. Same machinery for the cache pool.
        lastRecycle time.Time

        cacheHealer      func() (Pool, error)
        healingCache     bool
        lastCacheHeal    time.Time
        lastCacheRecycle time.Time
}

// healCooldown keeps a dead Supabase from being re-probed on every
// failing request: one attempt per cooldown, and the request that
// found the failure still answers its error - the next catalog read
// rides the healed pool.
const healCooldown = 10 * time.Minute

// recycleCooldown is the tighter cadence of the transport-failure
// recycle: a wedged pool usually clears with ONE fresh dial, so the
// first recycle fires within two minutes of the wedge instead of
// making students wait out the full heal cooldown.
const recycleCooldown = 2 * time.Minute

// SetContentHealer wires the boot's content chain re-connect closure.
func (s *Split) SetContentHealer(fn func() (Pool, error)) {
        s.healMu.Lock()
        s.healer = fn
        s.healMu.Unlock()
}

// SetCacheHealer wires the boot's cache chain re-connect closure
// (same contract as the content healer, one domain down).
func (s *Split) SetCacheHealer(fn func() (Pool, error)) {
        s.healMu.Lock()
        s.cacheHealer = fn
        s.healMu.Unlock()
}

// noteContentFailure inspects a failed content-routed statement: while
// the catalog is degraded onto the user pool, a missing-relation error
// on a content table is the "catalog is down" signature, and it never
// fixes itself on its own - try the healer. While the content pool is
// LIVE, a transport-level failure (the wedged pool of 2026-10-20:
// every catalog read hung its full 20s bound with "context deadline
// exceeded" while Supabase itself answered other clients in half a
// second) means the pool's sockets rotted underneath it - recycle.
func (s *Split) noteContentFailure(sql string, err error) {
        if err == nil {
                return
        }
        d, _ := classifySQL(sql)
        if d != domainContent {
                return
        }
        if s.sameContent {
                // Healthy split: a 42P01 on the content pool is a real
                // schema bug, not a degradation - do not churn heals.
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && (pgErr.Code == "42P01" || pgErr.Code == "42703") {
                        s.maybeHeal()
                }
                return
        }
        if isTransportFailure(err) {
                s.recycleContent()
        }
}

// noteCacheFailure is noteContentFailure for the lesson-cache domain:
// while the cache rides another pool, a missing learn.lessons is the
// degrade signature (no healer for that shape - the boot already chose
// the best available home); while the cache pool is live, transport
// failures recycle it.
func (s *Split) noteCacheFailure(err error) {
        if err == nil {
                return
        }
        s.healMu.Lock()
        sameCache := s.sameCache
        s.healMu.Unlock()
        if sameCache {
                return
        }
        if isTransportFailure(err) {
                s.recycleCache()
        }
}

// isTransportFailure reports whether a statement error smells like a
// dead/wedged NETWORK PATH rather than a server-side SQL error: the
// bounded context's deadline (every wedged-pool read answers exactly
// this), pgx connect errors, TCP resets, TLS breakage, and the usual
// socket corpses. A *pgconn.PgError is a Postgres answer - the wire
// works, the pool is alive, never recycle on it. context.Canceled is
// a client walking away, not a wedge - excluded.
func isTransportFailure(err error) bool {
        if err == nil {
                return false
        }
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) {
                return false
        }
        if errors.Is(err, context.DeadlineExceeded) {
                return true
        }
        if errors.Is(err, context.Canceled) {
                return false
        }
        var connErr *pgconn.ConnectError
        if errors.As(err, &connErr) {
                return true
        }
        msg := strings.ToLower(err.Error())
        for _, marker := range []string{
                "context deadline exceeded", "context timeout",
                "connection reset", "broken pipe", "unexpected eof",
                "connection refused", "dial tcp", "i/o timeout", "io timeout",
                "tls handshake", "ssl connection", "server closed the connection",
                "connection idle", "conn busy", "no route to host",
                "host unreachable", "network is unreachable",
        } {
                if strings.Contains(msg, marker) {
                        return true
                }
        }
        return false
}

// recycleContent re-walks the content chain on a transport failure
// (single-flight, recycleCooldown): a fresh dial clears the usual
// wedge, a dead chain degrades the catalog onto the user pool so
// requests fail FAST and the 42P01 heal loop keeps retrying the chain
// every healCooldown until the path comes back.
func (s *Split) recycleContent() {
        s.healMu.Lock()
        if s.healing || s.healer == nil || time.Since(s.lastRecycle) < recycleCooldown {
                s.healMu.Unlock()
                return
        }
        s.healing = true
        s.lastRecycle = time.Now()
        heal := s.healer
        s.healMu.Unlock()

        go func() {
                defer func() {
                        if r := recover(); r != nil {
                                if s.log != nil {
                                        s.log.Error("store: content recycle panicked", "err", r)
                                }
                        }
                        s.healMu.Lock()
                        s.healing = false
                        s.healMu.Unlock()
                }()
                pool, err := heal()
                s.healMu.Lock()
                s.lastHeal = time.Now()
                s.lastHealErr = err
                if err != nil {
                        if !s.sameContent {
                                old := s.Content
                                s.Content = s.User
                                s.sameContent = true
                                s.healMu.Unlock()
                                if s.log != nil {
                                        s.log.Warn("store: content recycle failed - catalog degrades onto the user pool until the next heal",
                                                "err", err.Error())
                                }
                                if closer, ok := old.(interface{ Close() }); ok && old != s.User {
                                        closer.Close()
                                }
                                return
                        }
                        s.healMu.Unlock()
                        if s.log != nil {
                                s.log.Warn("store: content recycle failed - catalog stays on the user pool until the next attempt",
                                        "err", err.Error())
                        }
                        return
                }
                old := s.Content
                s.Content = pool
                s.sameContent = false
                s.healMu.Unlock()
                if s.log != nil {
                        s.log.Info("store: content pool recycled - the catalog is live again")
                }
                if closer, ok := old.(interface{ Close() }); ok && old != s.User {
                        closer.Close()
                }
        }()
}

// recycleCache is recycleContent for the lesson-cache pool: fresh dial
// on wedge, degrade onto the content pool (the boot doctrine) - or the
// user pool when the content pool is degraded itself - on a dead chain.
func (s *Split) recycleCache() {
        s.healMu.Lock()
        if s.healingCache || s.cacheHealer == nil || time.Since(s.lastCacheRecycle) < recycleCooldown {
                s.healMu.Unlock()
                return
        }
        s.healingCache = true
        s.lastCacheRecycle = time.Now()
        heal := s.cacheHealer
        s.healMu.Unlock()

        go func() {
                defer func() {
                        if r := recover(); r != nil {
                                if s.log != nil {
                                        s.log.Error("store: cache recycle panicked", "err", r)
                                }
                        }
                        s.healMu.Lock()
                        s.healingCache = false
                        s.healMu.Unlock()
                }()
                pool, err := heal()
                s.healMu.Lock()
                s.lastCacheHeal = time.Now()
                if err != nil {
                        if !s.sameCache {
                                old := s.Cache
                                if s.sameContent {
                                        s.Cache = s.User
                                } else {
                                        s.Cache = s.Content
                                }
                                s.sameCache = true
                                s.healMu.Unlock()
                                if s.log != nil {
                                        s.log.Warn("store: cache recycle failed - lesson cache degrades until the next heal",
                                                "err", err.Error())
                                }
                                if closer, ok := old.(interface{ Close() }); ok && old != s.Cache {
                                        closer.Close()
                                }
                                return
                        }
                        s.healMu.Unlock()
                        if s.log != nil {
                                s.log.Warn("store: cache recycle failed - lesson cache stays degraded until the next attempt",
                                        "err", err.Error())
                        }
                        return
                }
                old := s.Cache
                s.Cache = pool
                s.sameCache = false
                s.healMu.Unlock()
                if s.log != nil {
                        s.log.Info("store: cache pool recycled - the lesson cache is live again")
                }
                if closer, ok := old.(interface{ Close() }); ok && old != s.User {
                        closer.Close()
                }
        }()
}

func (s *Split) maybeHeal() {
        s.healMu.Lock()
        if s.healing || s.healer == nil || time.Since(s.lastHeal) < healCooldown {
                s.healMu.Unlock()
                return
        }
        s.healing = true
        s.lastHeal = time.Now()
        heal := s.healer
        s.healMu.Unlock()

        go func() {
                defer func() {
                        if r := recover(); r != nil {
                                if s.log != nil {
                                        s.log.Error("store: content heal panicked", "err", r)
                                }
                        }
                        s.healMu.Lock()
                        s.healing = false
                        s.healMu.Unlock()
                }()
                pool, err := heal()
                s.healMu.Lock()
                s.lastHealErr = err
                s.healMu.Unlock()
                if err != nil {
                        if s.log != nil {
                                s.log.Warn("store: content heal failed - catalog stays on the user pool until the next attempt", "err", err.Error())
                        }
                        return
                }
                s.healMu.Lock()
                old := s.Content
                s.Content = pool
                s.sameContent = false
                s.healMu.Unlock()
                if s.log != nil {
                        s.log.Info("store: content pool healed - the catalog is live again")
                }
                if closer, ok := old.(interface{ Close() }); ok && old != s.User {
                        closer.Close()
                }
        }()
}

// NewSplit wires the three domain pools. A nil domain pool (or one
// that IS the user pool) degrades that domain onto the user pool.
func NewSplit(user, content, cache Pool, log *slog.Logger) *Split {
        s := &Split{User: user, log: log, mixed: map[string]bool{}}
        s.sameContent = content == nil || content == user
        s.sameCache = cache == nil || cache == user
        s.Content, s.Cache = user, user
        if !s.sameContent {
                s.Content = content
        }
        if !s.sameCache {
                s.Cache = cache
        }
        return s
}

func (s *Split) route(sql string) Pool {
        d, _ := classifySQL(sql)
        switch d {
        case domainContent:
                return s.Content
        case domainCache:
                return s.Cache
        default:
                return s.User
        }
}

// warnMixed logs a mixed-domain statement once per shape: across two
// databases the join cannot run, so the two-step rewrite backlog
// must stay at zero - this keeps any regression loud.
func (s *Split) warnMixed(sql string) {
        if s.log == nil {
                return
        }
        sum := sha256.Sum256([]byte(sql))
        key := hex.EncodeToString(sum[:8])
        s.mixedMu.Lock()
        defer s.mixedMu.Unlock()
        if s.mixed[key] {
                return
        }
        s.mixed[key] = true
        fields := strings.Fields(sql)
        head := sql
        if len(fields) > 14 {
                head = strings.Join(fields[:14], " ")
        }
        s.log.Error("store: MIXED-DOMAIN statement - rewrite as a two-step pool-safe query",
                "sql_head", head)
}

// guard runs when the split is LIVE (content is a distinct database):
// a mixed-domain statement degrades onto the pool hosting its first
// table so the failure is visible, never silent.
func (s *Split) guard(sql string) (Pool, bool) {
        _, mixed := classifySQL(sql)
        if !mixed || s.sameContent {
                return nil, false
        }
        s.warnMixed(sql)
        switch mixedVerdict(sql) {
        case domainContent:
                return s.Content, true
        case domainCache:
                return s.Cache, true
        default:
                return s.User, true
        }
}

// mixedVerdict picks the degrade pool for a mixed statement: lessons
// mixes land on the cache pool, catalog mixes on the content pool,
// everything else on the user pool.
func mixedVerdict(sql string) int {
        for _, t := range cacheTables {
                if strings.Contains(sql, t) {
                        return domainCache
                }
        }
        for _, t := range contentTables {
                if strings.Contains(sql, t) {
                        return domainContent
                }
        }
        return domainUser
}

// contentQueryTimeout bounds every statement the split routes to the
// content or cache pool. The catalog and lesson-cache pools idle
// between student traffic - when their network path rots (the
// zombie-connection outage of 2026-10-17), the bounded deadline turns
// what used to be a ~15-minute TCP retransmit hang into a clean
// failure; pgxpool discards the poisoned connection and the next
// request dials fresh. The user pool is deliberately NOT bounded:
// auth traffic keeps it warm and its queries own no such corpse risk.
const contentQueryTimeout = 20 * time.Second

// routeCtx bounds ctx for content/cache-routed statements. The
// returned cancel is always non-nil when ok is true; callers MUST
// run it (the deadline itself is the backstop).
func (s *Split) routeCtx(ctx context.Context, sql string) (context.Context, context.CancelFunc, bool) {
        if s.sameContent && s.sameCache {
                return ctx, nil, false
        }
        d, _ := classifySQL(sql)
        if d != domainContent && d != domainCache {
                return ctx, nil, false
        }
        if d == domainContent && s.sameContent {
                return ctx, nil, false
        }
        if d == domainCache && s.sameCache {
                return ctx, nil, false
        }
        c, cancel := context.WithTimeout(ctx, contentQueryTimeout)
        return c, cancel, true
}

// cancelRow releases the bounded context once the caller actually
// scans the row (pgx Row is lazy - the query runs on Scan).
type cancelRow struct {
        pgx.Row
        cancel context.CancelFunc
        once   sync.Once
}

func (r *cancelRow) Scan(dest ...any) error {
        defer r.once.Do(r.cancel)
        return r.Row.Scan(dest...)
}

// cancelRows releases the bounded context when the caller closes the
// result set; an abandoned Rows dies at the deadline instead.
type cancelRows struct {
        pgx.Rows
        cancel context.CancelFunc
        once   sync.Once
}

func (r *cancelRows) Close() {
        r.once.Do(r.cancel)
        r.Rows.Close()
}

// noteFailure dispatches a failed statement to its domain's failure
// handler: content failures drive the catalog heal/recycle loop, cache
// failures the lesson-cache recycle.
func (s *Split) noteFailure(sql string, err error) {
        if err == nil {
                return
        }
        d, _ := classifySQL(sql)
        switch d {
        case domainContent:
                s.noteContentFailure(sql, err)
        case domainCache:
                s.noteCacheFailure(err)
        }
}

func (s *Split) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
        qctx, cancel, bounded := s.routeCtx(ctx, sql)
        if bounded {
                defer cancel()
        }
        if p, degraded := s.guard(sql); degraded {
                tag, err := p.Exec(qctx, sql, args...)
                s.noteFailure(sql, err)
                return tag, err
        }
        tag, err := s.route(sql).Exec(qctx, sql, args...)
        s.noteFailure(sql, err)
        return tag, err
}

func (s *Split) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
        qctx, cancel, bounded := s.routeCtx(ctx, sql)
        if p, degraded := s.guard(sql); degraded {
                rows, err := p.Query(qctx, sql, args...)
                if bounded {
                        if err != nil {
                                cancel()
                        } else {
                                rows = &cancelRows{Rows: rows, cancel: cancel}
                        }
                }
                s.noteFailure(sql, err)
                return rows, err
        }
        rows, err := s.route(sql).Query(qctx, sql, args...)
        if bounded {
                if err != nil {
                        cancel()
                } else {
                        rows = &cancelRows{Rows: rows, cancel: cancel}
                }
        }
        s.noteFailure(sql, err)
        return rows, err
}

func (s *Split) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
        qctx, cancel, bounded := s.routeCtx(ctx, sql)
        var row pgx.Row
        if p, degraded := s.guard(sql); degraded {
                row = p.QueryRow(qctx, sql, args...)
        } else {
                row = s.route(sql).QueryRow(qctx, sql, args...)
        }
        if bounded {
                row = &cancelRow{Row: row, cancel: cancel}
        }
        // pgx Row is lazy - the query runs on Scan, so any error (a
        // content-pool wedge among them) only exists after Scan. The
        // notifyingRow feeds that error back into the same failure
        // loop the eager Exec/Query paths drive.
        return &notifyingRow{Row: row, split: s, sql: sql}
}

// notifyingRow reports a lazily-surfaced statement error to the
// split's failure loop. Scan releases the bounded context first (the
// wrapped cancelRow owns that) so the recycle never stacks on a hung
// deadline.
type notifyingRow struct {
        pgx.Row
        split *Split
        sql   string
}

func (r *notifyingRow) Scan(dest ...any) error {
        err := r.Row.Scan(dest...)
        r.split.noteFailure(r.sql, err)
        return err
}

// SendBatch routes a batch to ONE pool: every queued statement must
// share a domain (both current call sites queue one table's inserts).
// A mixed batch degrades like a mixed statement.
func (s *Split) SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults {
        dom, mixed := -1, false
        for _, q := range b.QueuedQueries {
                d, _ := classifySQL(q.SQL)
                if dom == -1 {
                        dom = d
                } else if dom != d {
                        mixed = true
                        break
                }
        }
        if mixed {
                if p, _ := s.guard(batchHead(b)); p != nil {
                        return p.SendBatch(ctx, b)
                }
        }
        qctx, cancel, bounded := s.routeCtx(ctx, batchHead(b))
        switch dom {
        case domainContent:
                br := s.Content.SendBatch(qctx, b)
                if bounded {
                        br = &cancelBatchResults{BatchResults: br, cancel: cancel}
                }
                return br
        case domainCache:
                br := s.Cache.SendBatch(qctx, b)
                if bounded {
                        br = &cancelBatchResults{BatchResults: br, cancel: cancel}
                }
                return br
        default:
                return s.User.SendBatch(ctx, b)
        }
}

// cancelBatchResults releases the bounded context when the batch is
// closed; a batch abandoned without Close dies at the deadline.
type cancelBatchResults struct {
        pgx.BatchResults
        cancel context.CancelFunc
        once   sync.Once
}

func (r *cancelBatchResults) Close() error {
        defer r.once.Do(r.cancel)
        return r.BatchResults.Close()
}

func batchHead(b *pgx.Batch) string {
        if len(b.QueuedQueries) == 0 {
                return ""
        }
        return b.QueuedQueries[0].SQL
}

// Begin always opens on the USER pool: every transaction in the
// codebase is user-domain (the catalog seed passes the content pool
// explicitly and never calls Begin through the Split).
func (s *Split) Begin(ctx context.Context) (pgx.Tx, error) {
        return s.User.Begin(ctx)
}

// Ping probes the USER pool: the dbwatch exit doctrine keys on the
// authoritative user database.
func (s *Split) Ping(ctx context.Context) error {
        return s.User.Ping(ctx)
}

func (s *Split) Close() {
        s.User.Close()
        if !s.sameContent {
                s.Content.Close()
        }
        if !s.sameCache {
                s.Cache.Close()
        }
}

// SplitActive reports whether the content pool is a DISTINCT database
// from the user pool (the founder's Supabase-and-Neon split is live).
func (s *Split) SplitActive() bool { return !s.sameContent }

// env DSN keys for the split.
const (
        envUserDatabaseURL    = "USER_DATABASE_URL"
        envContentDatabaseURL = "CONTENT_DATABASE_URL"
        envCacheDatabaseURL   = "CACHE_DATABASE_URL"
)

// bakedUserDSN is the USER_DATABASE_URL default (founder directive
// 2026-10-16: "users details and progress are stored in Neon and
// InsForge alone ... do this yourself"). The founder pasted the Neon
// pooled DSN in chat the same day, so the cutover the agent performs
// itself: Neon is THE user primary (accounts, progress, streaks,
// achievements, follows, quiz results). The agent provisioned it
// ahead of this deploy with dbsplit (copy-users + seal-backfill +
// reap-user-stale: 112 accounts carried off Supabase exactly once,
// the pre-split catalog husks dropped), so the first boot here simply
// connects, skips the backfill on the sealed public.split_backfill
// marker and starts serving. A real USER_DATABASE_URL env value
// always wins - this default only fills an EMPTY env. Private repo,
// same practice as the baked DSNs in render.yaml.
const bakedUserDSN = "postgresql://neondb_owner:npg_siaeB4m7IMUZ@ep-snowy-base-axf83q3b-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

// bakedUserFallbackDSN is the user-chain failover - the Neon CU
// callback plan (founder 2026-10-16: Neon had already burned 84% of
// the monthly compute by mid-month, "hope there's a callback plan for
// the user login/signup and the part neon is handling"). The first
// InsForge (dbeqj4dx) is a complete, LIVE user mirror - the dual-write
// Mirror replays every signup, login and progress write to it, so when
// the Neon free tier runs dry and its compute stops responding the
// chain walks one hop and the API keeps serving accounts and progress
// from the mirror with zero data loss. It sits BEFORE the legacy
// primary in the chain on purpose: the old chain would have landed on
// Supabase first (alive, but catalog-only since the user reaps -
// accounts would 404). When Neon resets next cycle it wins the chain
// again automatically (first live DSN boots); run dbsplit adopt-mirror
// once to carry any rows created during the outage back to Neon.
const bakedUserFallbackDSN = "postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require"

// bakedCacheDSN is the CACHE_DATABASE_URL default (founder directive
// 2026-10-16: "don't use insforge #2 for lesson cache only use #1").
// The second InsForge (6zctb6jv) turned out to be the 500 MB free tier
// while the cache had grown to 901 MB ("how did it store 900MB?"), so
// the cache moved onto the FIRST InsForge (dbeqj4dx): scripts/
// move_cache_dblink.js carried the newest ~36k lessons over dblink
// (server to server inside Insforge's own network) and dropped the
// 887 MB table off #2. LESSON_CACHE_CAP_MB drops 900 -> 430 so the
// mirror plus cache (the guard probes the whole DATABASE size)
// stays safely inside the 500 MB tier with write headroom.
// A real CACHE_DATABASE_URL env value always wins - this default only
// fills an EMPTY env.
const bakedCacheDSN = "postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require"

// bakedDSNsDisabled reports whether the baked production DSNs must
// stay out of every chain. CI is the reason this exists: the E2E job
// sets only DATABASE_URL (its own throwaway Postgres), and the baked
// constants used to fill the empty env slots FIRST - so a CI runner
// booted the API with live Neon as the user primary and InsForge as
// the mirror, registered e2e test scholars in PRODUCTION and synced
// production rows into the runner (founder bug 2026-10-16, five CI
// runs affected). GITHUB_ACTIONS=true is GitHub's own marker; the
// DISABLE_BAKED_DSN env is the manual switch for local dev and any
// other sandbox that must never reach production.
func bakedDSNsDisabled() bool {
        if strings.EqualFold(strings.TrimSpace(os.Getenv("GITHUB_ACTIONS")), "true") {
                return true
        }
        v := strings.ToLower(strings.TrimSpace(os.Getenv("DISABLE_BAKED_DSN")))
        switch v {
        case "1", "t", "true", "y", "yes", "on":
                return true
        }
        return false
}

// SplitDSNs resolves the three domain chains from the environment:
//
//      user    = USER_DATABASE_URL -> bakedUserDSN (Neon) ->
//                bakedUserFallbackDSN (InsForge #1, the Neon CU
//                failover) -> (the caller's primary DSN) -> fallbacks
//                (the env always wins; baked defaults only fill gaps)
//      content = CONTENT_DATABASE_URL
//      cache   = CACHE_DATABASE_URL -> bakedCacheDSN (InsForge #1,
//                the mirror database - cache and mirror share it
//                under the 430 MB cap) -> INSFORGE_DATABASE_URL
//
// The baked defaults never fill gaps under CI / DISABLE_BAKED_DSN
// (see bakedDSNsDisabled) - a sandbox boot then rides its own
// DATABASE_URL alone, exactly like production rides its env.
//
// The first live DSN of each chain wins at boot; every hop is logged
// redacted. An empty content chain means "ride the user pool" (the
// pre-split single-database behaviour).
func SplitDSNs(primary string, fallbacks []string) (user, content, cache []string) {
        user = make([]string, 0, 3+len(fallbacks))
        if v := strings.TrimSpace(os.Getenv(envUserDatabaseURL)); v != "" {
                user = append(user, v)
        } else if !bakedDSNsDisabled() && strings.TrimSpace(bakedUserDSN) != "" {
                user = append(user, bakedUserDSN)
        }
        // The Neon CU failover: deduped (a founder env pointing at the
        // mirror itself must not list it twice).
        if fb := strings.TrimSpace(bakedUserFallbackDSN); fb != "" && !bakedDSNsDisabled() {
                dupe := false
                for _, d := range user {
                        if strings.TrimSpace(d) == fb {
                                dupe = true
                                break
                        }
                }
                if !dupe {
                        user = append(user, fb)
                }
        }
        if strings.TrimSpace(primary) != "" {
                user = append(user, strings.TrimSpace(primary))
        }
        user = append(user, fallbacks...)

        if v := strings.TrimSpace(os.Getenv(envContentDatabaseURL)); v != "" {
                content = []string{v}
        }

        if v := strings.TrimSpace(os.Getenv(envCacheDatabaseURL)); v != "" {
                cache = append(cache, v)
        } else if !bakedDSNsDisabled() && strings.TrimSpace(bakedCacheDSN) != "" {
                cache = append(cache, bakedCacheDSN)
        }
        if v := strings.TrimSpace(os.Getenv("INSFORGE_DATABASE_URL")); v != "" {
                cache = append(cache, v)
        }
        return user, content, cache
}

// connectFirst walks a DSN chain and returns the first pool that
// connects and pings, with its DSN. Migrations are the caller's job.
func connectFirst(ctx context.Context, dsns []string, log *slog.Logger, role string) (Pool, string, error) {
        var lastErr error
        tried := 0
        for _, dsn := range dsnList(dsns) {
                tried++
                st, err := Connect(ctx, dsn)
                if err == nil {
                        if log != nil {
                                log.Info("database connected", "dsn", redactDSN(dsn), "role", role)
                        }
                        return st.Pool, strings.TrimSpace(dsn), nil
                }
                lastErr = err
                if log != nil {
                        log.Warn("database unreachable, walking to the next candidate",
                                "dsn", redactDSN(dsn), "role", role, "err", err.Error())
                }
        }
        if tried == 0 {
                return nil, "", fmt.Errorf("store: no %s database configured", role)
        }
        return nil, "", fmt.Errorf("store: %s database unreachable - last error: %w", role, lastErr)
}

func dsnList(dsns []string) []string {
        out := make([]string, 0, len(dsns))
        for _, d := range dsns {
                if d = strings.TrimSpace(d); d != "" {
                        out = append(out, d)
                }
        }
        return out
}

// sameDatabase reports whether two pools point at the same Postgres
// instance (system identifier compare - pooler hosts and ports may
// differ for one database).
func sameDatabase(ctx context.Context, a, b Pool) (bool, error) {
        var sa, sb int64
        if err := a.QueryRow(ctx, `SELECT system_identifier FROM pg_control_system()`).Scan(&sa); err != nil {
                return false, err
        }
        if err := b.QueryRow(ctx, `SELECT system_identifier FROM pg_control_system()`).Scan(&sb); err != nil {
                return false, err
        }
        return sa == sb, nil
}

// systemID returns the Postgres system identifier of a pool (0 on error).
func systemID(ctx context.Context, p Pool) int64 {
        var id int64
        _ = p.QueryRow(ctx, `SELECT system_identifier FROM pg_control_system()`).Scan(&id)
        return id
}

// ─── Boot backfill ────────────────────────────────────────────────────────

// SplitBackfillStats reports one boot backfill pass.
type SplitBackfillStats struct {
        UserRowsCopied   int64
        LessonRowsCopied int64
        UserBackfillRan  bool // the one-time user copy ran this boot
        LessonsCopied    bool
        Skipped          string // why nothing ran (single-db / marker present)
}

// splitBackfillMarker remembers (on the USER database) that the
// one-time user-domain copy off the legacy content database finished.
// Keyed by the content database's system identifier, so re-pointing
// CONTENT_DATABASE_URL at a fresh database triggers exactly one copy.
const splitBackfillMarker = `
        CREATE TABLE IF NOT EXISTS public.split_backfill (
                content_sysid text PRIMARY KEY,
                copied_at     timestamptz NOT NULL DEFAULT now()
        )`

// BackfillSplit copies the user domain off the content database into
// the user database (once, overwrite mode: the content side was the
// live primary while the user side was disconnected, so its rows are
// the freshest) and merges the lesson cache content -> cache (every
// boot, merge mode: a cheap no-op once the counts agree). Safe to
// call on every boot: single-database boots skip, the marker skips
// the user copy after the first success.
func BackfillSplit(ctx context.Context, user, content, cache Pool, log *slog.Logger) (*SplitBackfillStats, error) {
        stats := &SplitBackfillStats{}
        same, err := sameDatabase(ctx, user, content)
        if err != nil {
                return nil, fmt.Errorf("store: split backfill compare: %w", err)
        }
        if same {
                stats.Skipped = "single database - nothing to backfill"
                return stats, nil
        }

        // 1. The one-time user-domain copy (content -> user, overwrite).
        if _, err := user.Exec(ctx, splitBackfillMarker); err != nil {
                return nil, fmt.Errorf("store: split backfill marker: %w", err)
        }
        contentSysID := fmt.Sprintf("%d", systemID(ctx, content))
        var done bool
        if err := user.QueryRow(ctx,
                `SELECT EXISTS (SELECT 1 FROM public.split_backfill WHERE content_sysid=$1)`,
                contentSysID).Scan(&done); err != nil {
                return nil, fmt.Errorf("store: split backfill marker read: %w", err)
        }
        if !done {
                if log != nil {
                        log.Info("split backfill: copying the user domain off the content database (one-time)",
                                "content_sysid", contentSysID)
                }
                ustats, err := SyncMirrorDataFiltered(ctx, content, user, log, "content-legacy", "user-primary", SyncOptions{
                        SkipTables:  domainSkipTables(),
                        Overwrite:   true,
                        Directional: true,
                })
                if err != nil {
                        return nil, fmt.Errorf("store: split backfill user copy: %w", err)
                }
                stats.UserRowsCopied = ustats.RowsCopied
                stats.UserBackfillRan = true
                if _, err := user.Exec(ctx,
                        `INSERT INTO public.split_backfill (content_sysid) VALUES ($1)
                         ON CONFLICT (content_sysid) DO NOTHING`, contentSysID); err != nil {
                        return nil, fmt.Errorf("store: split backfill marker write: %w", err)
                }
                if log != nil {
                        log.Info("split backfill: user domain copied - the marker is set",
                                "rows", stats.UserRowsCopied)
                }
        } else {
                stats.Skipped = "user backfill already done (marker present)"
        }

        // 2. The lesson cache merge (content -> cache, every boot).
        if cache != nil && cache != content {
                csame, err := sameDatabase(ctx, cache, content)
                if err == nil && !csame {
                        lstats, err := SyncMirrorDataFiltered(ctx, content, cache, log, "content-legacy", "lesson-cache", SyncOptions{
                                OnlyTables:  map[string]bool{"learn.lessons": true},
                                Directional: true,
                        })
                        if err != nil {
                                if log != nil {
                                        log.Warn("split backfill: lesson cache merge failed - retried on the next boot", "err", err.Error())
                                }
                        } else {
                                stats.LessonRowsCopied = lstats.RowsCopied
                                stats.LessonsCopied = lstats.RowsCopied > 0
                                if lstats.RowsCopied > 0 && log != nil {
                                        log.Info("split backfill: lesson cache merged off the content database", "rows", lstats.RowsCopied)
                                }
                        }
                }
        }
        return stats, nil
}

// domainSkipTables lists the catalog + cache tables the USER-domain
// copy must never touch (they belong to the content/cache databases).
func domainSkipTables() map[string]bool {
        skip := map[string]bool{}
        for _, t := range contentTables {
                skip[t] = true
        }
        for _, t := range cacheTables {
                skip[t] = true
        }
        return skip
}

// splitBackfillDeadline bounds the synchronous boot backfill.
const splitBackfillDeadline = 15 * time.Minute

// BackfillDeadline exposes the budget main.go wraps the backfill in.
func BackfillDeadline() time.Duration { return splitBackfillDeadline }

// DomainSkipTablesExported exposes the catalog + cache skip list so
// the main.go mirror sync keeps the user-domain replication (primary
// <-> mirrors) away from the catalog and lesson tables.
func DomainSkipTablesExported() map[string]bool { return domainSkipTables() }

// UserDomainTables lists the user-domain app tables present on a
// pool (the reap tool's target list). Content + cache tables and the
// migration journal are excluded.
func UserDomainTables(ctx context.Context, p Pool) ([]string, error) {
        rows, err := p.Query(ctx, `
                SELECT n.nspname || '.' || c.relname
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind = 'r' AND n.nspname = ANY($1)
                ORDER BY 1`, []string{"study", "arena", "school", "social", "learn"})
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        skip := domainSkipTables()
        var out []string
        for rows.Next() {
                var name string
                if err := rows.Scan(&name); err != nil {
                        return nil, err
                }
                if skip[name] || name == "study.schema_migrations" || name == "public.split_backfill" {
                        continue
                }
                out = append(out, name)
        }
        return out, rows.Err()
}

// CatalogTables lists the catalog tables present on a pool (the
// InsForge reclaim list).
func CatalogTables(ctx context.Context, p Pool) ([]string, error) {
        rows, err := p.Query(ctx, `
                SELECT n.nspname || '.' || c.relname
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind = 'r' AND n.nspname = ANY($1)
                ORDER BY 1`, []string{"learn"})
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        keep := map[string]bool{"learn.lessons": true, "learn.learners": true, "learn.progress": true,
                "learn.user_courses": true, "learn.active_course": true, "learn.mistakes": true,
                "learn.daily_stats": true, "learn.xp_events": true, "learn.chest_opens": true,
                "learn.topic_chests": true, "learn.quest_claims": true, "learn.league_members": true}
        var out []string
        for rows.Next() {
                var name string
                if err := rows.Scan(&name); err != nil {
                        return nil, err
                }
                if keep[name] {
                        continue
                }
                out = append(out, name)
        }
        return out, rows.Err()
}
