// Package store owns every byte of SQL the study API executes.
//
// Doctrine: structure changes ONLY via ordered migrations in
// migrations/*.sql (embedded, applied at boot). No hand-ALTERs, ever.
// pgx runs in simple-protocol mode so the pooled Neon endpoint stays safe.
package store

import (
        "context"
        "embed"
        "encoding/json"
        "errors"
        "fmt"
        "net/url"
        "sort"
        "strings"
        "time"

        "github.com/jackc/pgx/v5"
        "github.com/jackc/pgx/v5/pgconn"
        "github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// ErrUniqueUsername is returned when a username collides (case-insensitive).
var ErrUniqueUsername = errors.New("store: username already taken")

// ErrUniqueEmail is returned when an email collides (case-insensitive).
var ErrUniqueEmail = errors.New("store: email already registered")

const uniqueViolation = "23505"

type Store struct {
        Pool *pgxpool.Pool
}

func Connect(ctx context.Context, dsn string) (*Store, error) {
        cfg, err := pgxpool.ParseConfig(normalizeDSN(dsn))
        if err != nil {
                return nil, fmt.Errorf("store: parse dsn: %w", err)
        }
        // Transaction-mode poolers (Neon) break prepared-statement caching.
        cfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
        cfg.MaxConns = 8
        pool, err := pgxpool.NewWithConfig(ctx, cfg)
        if err != nil {
                return nil, fmt.Errorf("store: connect: %w", err)
        }
        pingCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
        defer cancel()
        if err := pool.Ping(pingCtx); err != nil {
                pool.Close()
                return nil, fmt.Errorf("store: ping: %w", err)
        }
        return &Store{Pool: pool}, nil
}

func (s *Store) Close() { s.Pool.Close() }

// normalizeDSN strips libpq parameters pgx has no support for. Neon's
// console hands out URIs ending in channel_binding=require; without this
// scrub pgxpool.ParseConfig would reject the whole URI.
func normalizeDSN(dsn string) string {
        u, err := url.Parse(strings.TrimSpace(dsn))
        if err != nil {
                return dsn // let ParseConfig produce the real error
        }
        q := u.Query()
        if q.Get("channel_binding") != "" {
                q.Del("channel_binding")
                u.RawQuery = q.Encode()
        }
        return u.String()
}

// Migrate applies every not-yet-applied migration in filename order.
func (s *Store) Migrate(ctx context.Context) error {
        if _, err := s.Pool.Exec(ctx, `
                CREATE SCHEMA IF NOT EXISTS study;
                CREATE TABLE IF NOT EXISTS study.schema_migrations (
                        version    text        PRIMARY KEY,
                        applied_at timestamptz NOT NULL DEFAULT now()
                )`); err != nil {
                return fmt.Errorf("store: ensure schema_migrations: %w", err)
        }
        entries, err := migrationsFS.ReadDir("migrations")
        if err != nil {
                return fmt.Errorf("store: read migrations: %w", err)
        }
        names := make([]string, 0, len(entries))
        for _, e := range entries {
                if !e.IsDir() {
                        names = append(names, e.Name())
                }
        }
        sort.Strings(names)

        for _, name := range names {
                var exists bool
                if err := s.Pool.QueryRow(ctx,
                        `SELECT EXISTS (SELECT 1 FROM study.schema_migrations WHERE version = $1)`, name,
                ).Scan(&exists); err != nil {
                        return fmt.Errorf("store: check %s: %w", name, err)
                }
                if exists {
                        continue
                }
                sqlBytes, err := migrationsFS.ReadFile("migrations/" + name)
                if err != nil {
                        return fmt.Errorf("store: read %s: %w", name, err)
                }
                tx, err := s.Pool.Begin(ctx)
                if err != nil {
                        return fmt.Errorf("store: begin %s: %w", name, err)
                }
                if _, err := tx.Exec(ctx, string(sqlBytes)); err != nil {
                        _ = tx.Rollback(ctx)
                        return fmt.Errorf("store: apply %s: %w", name, err)
                }
                if _, err := tx.Exec(ctx,
                        `INSERT INTO study.schema_migrations (version) VALUES ($1)`, name); err != nil {
                        _ = tx.Rollback(ctx)
                        return fmt.Errorf("store: journal %s: %w", name, err)
                }
                if err := tx.Commit(ctx); err != nil {
                        return fmt.Errorf("store: commit %s: %w", name, err)
                }
        }
        return nil
}

// ---------------------------------------------------------------- users

type User struct {
        ID           string    `json:"id"`
        Username     string    `json:"username"`
        CreatedAt    time.Time `json:"-"`
        PasswordHash string    `json:"-"`
        GoogleSub    *string   `json:"-"`
        Email        *string   `json:"-"`
}

func (s *Store) CreateUser(ctx context.Context, username, passwordHash string) (*User, error) {
        u := &User{Username: username}
        err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.users (username, password_hash)
                VALUES ($1, $2)
                RETURNING id, created_at`, username, passwordHash,
        ).Scan(&u.ID, &u.CreatedAt)
        if err != nil {
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
                        return nil, ErrUniqueUsername
                }
                return nil, fmt.Errorf("store: create user: %w", err)
        }
        return u, nil
}

// UpsertGoogleUser returns the scholar linked to a Google account, creating
// one on first sign-in. The seed username is derived from the Google email
// and numbered (alice_2, alice_3, …) on collision. Google-only rows keep an
// empty password_hash, which can never satisfy a bcrypt comparison.
//
// Same-email parity (founder rule): a scholar who registered with email +
// password and later signs in with Google using the SAME address lands in
// that same account, the Google identity is linked onto it. The reverse
// direction lives in CreateUserEmail (password claims a Google-only row).
func (s *Store) UpsertGoogleUser(ctx context.Context, googleSub, email, seed string) (*User, error) {
        u := &User{}
        err := s.Pool.QueryRow(ctx, `
                SELECT id, username, password_hash, created_at, google_sub, email
                FROM study.users WHERE google_sub = $1`, googleSub,
        ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
        if err == nil {
                return u, nil
        }
        if !errors.Is(err, pgx.ErrNoRows) {
                return nil, fmt.Errorf("store: google lookup: %w", err)
        }

        // No Google-linked row yet: an email-registered account with the
        // same address must adopt this Google identity instead of
        // colliding with the email unique index.
        if email != "" {
                existing, lookErr := s.UserByEmail(ctx, email)
                if lookErr != nil {
                        return nil, fmt.Errorf("store: google email lookup: %w", lookErr)
                }
                if existing != nil {
                        return s.linkGoogleSub(ctx, existing.ID, googleSub, email)
                }
        }

        for attempt := 0; attempt < 8; attempt++ {
                candidate := seed
                if attempt > 0 {
                        candidate = fmt.Sprintf("%s_%d", seed, attempt+1)
                }
                u = &User{Username: candidate}
                err = s.Pool.QueryRow(ctx, `
                        INSERT INTO study.users (username, password_hash, google_sub, email)
                        VALUES ($1, '', $2, NULLIF($3, ''))
                        RETURNING id, username, password_hash, created_at, google_sub, email`,
                        candidate, googleSub, email,
                ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
                if err == nil {
                        return u, nil
                }
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
                        // Could be the username index OR a concurrent login with
                        // the same google_sub winning the insert, re-check.
                        if linked := s.googleBySub(ctx, googleSub); linked != nil {
                                return linked, nil
                        }
                        continue
                }
                return nil, fmt.Errorf("store: create google user: %w", err)
        }
        return nil, fmt.Errorf("store: create google user: could not derive a free username from %q", seed)
}

func (s *Store) googleBySub(ctx context.Context, googleSub string) *User {
        u := &User{}
        err := s.Pool.QueryRow(ctx, `
                SELECT id, username, password_hash, created_at, google_sub, email
                FROM study.users WHERE google_sub = $1`, googleSub,
        ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
        if err != nil {
                return nil
        }
        return u
}

// linkGoogleSub attaches a Google identity to an existing (email +
// password) account, backfilling the email column when the row predates
// email-first auth. Idempotent: a re-link of the same sub is a no-op.
func (s *Store) linkGoogleSub(ctx context.Context, userID, googleSub, email string) (*User, error) {
        u := &User{}
        err := s.Pool.QueryRow(ctx, `
                UPDATE study.users
                SET google_sub = $2,
                    email = CASE WHEN email IS NULL OR email = '' THEN $3 ELSE email END
                WHERE id = $1
                RETURNING id, username, password_hash, created_at, google_sub, email`,
                userID, googleSub, strings.ToLower(strings.TrimSpace(email)),
        ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
        if err != nil {
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
                        // Another row already carries this google_sub (a
                        // concurrent Google sign-in won): return that one.
                        if linked := s.googleBySub(ctx, googleSub); linked != nil {
                                return linked, nil
                        }
                }
                return nil, fmt.Errorf("store: link google identity: %w", err)
        }
        return u, nil
}

func (s *Store) UserByUsername(ctx context.Context, username string) (*User, error) {
        u := &User{Username: username}
        err := s.Pool.QueryRow(ctx, `
                SELECT id, lower(username), password_hash, created_at, google_sub, email
                FROM study.users WHERE lower(username) = lower($1)`, username,
        ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: user by username: %w", err)
        }
        return u, nil
}

func (s *Store) UserByEmail(ctx context.Context, email string) (*User, error) {
        u := &User{}
        err := s.Pool.QueryRow(ctx, `
                SELECT id, username, password_hash, created_at, google_sub, email
                FROM study.users WHERE lower(email) = lower($1)`, email,
        ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: user by email: %w", err)
        }
        return u, nil
}

// seedUsernameFromEmail derives a provisional username from the email local
// part (resolute.femi@x.com -> resolute_femi), numbered on collision like the
// Google flow. The scholar replaces it with a real handle in the account
// setup modal; the seed only guarantees a non-empty, valid, unique value.
func (s *Store) seedUsernameFromEmail(ctx context.Context, email string) (string, error) {
        seed := strings.ToLower(strings.SplitN(email, "@", 2)[0])
        seed = strings.Map(func(r rune) rune {
                if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' {
                        return r
                }
                return '_'
        }, seed)
        seed = strings.Trim(seed, "_")
        if len(seed) < 3 {
                seed = "student"
        }
        if len(seed) > 24 {
                seed = seed[:24]
        }
        for attempt := 0; attempt < 8; attempt++ {
                candidate := seed
                if attempt > 0 {
                        candidate = fmt.Sprintf("%s_%d", seed, attempt+1)
                        if len(candidate) > 24 {
                                candidate = candidate[:21] + fmt.Sprintf("_%d", attempt+1)
                        }
                }
                var taken bool
                if err := s.Pool.QueryRow(ctx,
                        `SELECT EXISTS (SELECT 1 FROM study.users WHERE lower(username) = lower($1))`,
                        candidate,
                ).Scan(&taken); err != nil {
                        return "", fmt.Errorf("store: seed username check: %w", err)
                }
                if !taken {
                        return candidate, nil
                }
        }
        return "", fmt.Errorf("store: could not derive a free username from %q", email)
}

// CreateUserEmail registers an email + password scholar. The username starts
// as an email-derived seed and is renamed in the account-setup modal.
//
// Same-email parity (founder rule): when the address already belongs to a
// Google-only account (empty password_hash, nothing to lose), the signup
// claims that row by setting the password instead of failing with
// ErrUniqueEmail, so both sign-in paths share one account.
func (s *Store) CreateUserEmail(ctx context.Context, email, passwordHash string) (*User, error) {
        normalized := strings.ToLower(strings.TrimSpace(email))
        if existing, err := s.UserByEmail(ctx, normalized); err == nil && existing != nil && existing.PasswordHash == "" {
                u := &User{}
                err := s.Pool.QueryRow(ctx, `
                        UPDATE study.users SET password_hash = $2 WHERE id = $1
                        RETURNING id, username, password_hash, created_at, google_sub, email`,
                        existing.ID, passwordHash,
                ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
                if err != nil {
                        return nil, fmt.Errorf("store: claim google-only account: %w", err)
                }
                return u, nil
        }
        seed, err := s.seedUsernameFromEmail(ctx, email)
        if err != nil {
                return nil, err
        }
        u := &User{Username: seed}
        err = s.Pool.QueryRow(ctx, `
                INSERT INTO study.users (username, password_hash, email)
                VALUES ($1, $2, $3)
                RETURNING id, created_at`,
                seed, passwordHash, strings.ToLower(strings.TrimSpace(email)),
        ).Scan(&u.ID, &u.CreatedAt)
        if err != nil {
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
                        // Disambiguate which unique index fired: the email
                        // partial index means the address is registered; a
                        // username race losing the seed pre-check is a rarer,
                        // retryable conflict surfaced as ErrUniqueUsername.
                        if pgErr.ConstraintName == "users_email_lower_idx" {
                                return nil, ErrUniqueEmail
                        }
                        return nil, ErrUniqueUsername
                }
                return nil, fmt.Errorf("store: create email user: %w", err)
        }
        return u, nil
}

// UpdateUsername renames the scholar once they pick a handle in account
// setup. Case-insensitive uniqueness is enforced by users_username_lower_idx.
func (s *Store) UpdateUsername(ctx context.Context, userID, username string) error {
        _, err := s.Pool.Exec(ctx,
                `UPDATE study.users SET username = $2 WHERE id = $1`, userID, username)
        if err != nil {
                var pgErr *pgconn.PgError
                if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
                        return ErrUniqueUsername
                }
                return fmt.Errorf("store: update username: %w", err)
        }
        return nil
}

func (s *Store) UserByID(ctx context.Context, id string) (*User, error) {
        u := &User{}
        err := s.Pool.QueryRow(ctx, `
                SELECT id, username, password_hash, created_at, google_sub, email
                FROM study.users WHERE id = $1`, id,
        ).Scan(&u.ID, &u.Username, &u.PasswordHash, &u.CreatedAt, &u.GoogleSub, &u.Email)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: user by id: %w", err)
        }
        return u, nil
}

// -------------------------------------------------------------- profile

type Profile struct {
        FullName    string    `json:"fullName"`
        Institution string    `json:"institution"`
        GradeLevel  string    `json:"gradeLevel"`
        Exams       []string  `json:"exams"`
        Subjects    []string  `json:"subjects"`
        TargetYear  *int      `json:"targetYear,omitempty"`
        Completed   bool      `json:"completed"`
        UpdatedAt   time.Time `json:"-"`
}

func (s *Store) UpsertProfile(ctx context.Context, userID string, p *Profile) (*Profile, error) {
        examsJSON, err := json.Marshal(p.Exams)
        if err != nil {
                return nil, fmt.Errorf("store: marshal exams: %w", err)
        }
        subjectsJSON, err := json.Marshal(p.Subjects)
        if err != nil {
                return nil, fmt.Errorf("store: marshal subjects: %w", err)
        }
        out := &Profile{}
        err = s.Pool.QueryRow(ctx, `
                INSERT INTO study.profiles (user_id, full_name, institution, grade_level, exams, subjects, target_year, completed, updated_at)
                VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7, true, now())
                ON CONFLICT (user_id) DO UPDATE
                SET full_name   = EXCLUDED.full_name,
                    institution = EXCLUDED.institution,
                    grade_level = EXCLUDED.grade_level,
                    exams       = EXCLUDED.exams,
                    subjects    = EXCLUDED.subjects,
                    target_year = EXCLUDED.target_year,
                    completed   = true,
                    updated_at  = now()
                RETURNING full_name, institution, grade_level, exams, subjects, target_year, completed, updated_at`,
                userID, p.FullName, p.Institution, p.GradeLevel, string(examsJSON), string(subjectsJSON), p.TargetYear,
        ).Scan(&out.FullName, &out.Institution, &out.GradeLevel, &examsJSON, &subjectsJSON, &out.TargetYear, &out.Completed, &out.UpdatedAt)
        if err != nil {
                return nil, fmt.Errorf("store: upsert profile: %w", err)
        }
        if err := json.Unmarshal(examsJSON, &out.Exams); err != nil {
                return nil, fmt.Errorf("store: unmarshal exams: %w", err)
        }
        if err := json.Unmarshal(subjectsJSON, &out.Subjects); err != nil {
                return nil, fmt.Errorf("store: unmarshal subjects: %w", err)
        }
        return out, nil
}

func (s *Store) ProfileByUser(ctx context.Context, userID string) (*Profile, error) {
        var examsJSON, subjectsJSON []byte
        p := &Profile{}
        err := s.Pool.QueryRow(ctx, `
                SELECT full_name, institution, grade_level, exams, subjects, target_year, completed, updated_at
                FROM study.profiles WHERE user_id = $1`, userID,
        ).Scan(&p.FullName, &p.Institution, &p.GradeLevel, &examsJSON, &subjectsJSON, &p.TargetYear, &p.Completed, &p.UpdatedAt)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: profile by user: %w", err)
        }
        if err := json.Unmarshal(examsJSON, &p.Exams); err != nil {
                return nil, fmt.Errorf("store: unmarshal exams: %w", err)
        }
        if err := json.Unmarshal(subjectsJSON, &p.Subjects); err != nil {
                return nil, fmt.Errorf("store: unmarshal subjects: %w", err)
        }
        return p, nil
}

// SetDailySubjects stores ONLY the daily subject combination, leaving
// the rest of the profile row untouched. A missing profile row seeds a
// minimal one (the daily picker can run before account setup finishes;
// the profile modal later fills the rest through UpsertProfile).
func (s *Store) SetDailySubjects(ctx context.Context, userID string, subjects []string) error {
        subjectsJSON, err := json.Marshal(subjects)
        if err != nil {
                return fmt.Errorf("store: marshal subjects: %w", err)
        }
        tag, err := s.Pool.Exec(ctx, `
                UPDATE study.profiles SET subjects = $2::jsonb, updated_at = now() WHERE user_id = $1`,
                userID, string(subjectsJSON))
        if err != nil {
                return fmt.Errorf("store: set daily subjects: %w", err)
        }
        if tag.RowsAffected() == 1 {
                return nil
        }
        _, err = s.Pool.Exec(ctx, `
                INSERT INTO study.profiles (user_id, full_name, institution, grade_level, exams, subjects, completed, updated_at)
                VALUES ($1, '', '', '', '[]'::jsonb, $2::jsonb, false, now())`,
                userID, string(subjectsJSON))
        if err != nil {
                return fmt.Errorf("store: seed profile subjects: %w", err)
        }
        return nil
}

// ---------------------------------------------------------- answer keys

type KeyEntry struct {
        Letter      string
        Explanation string
        // AnswerImage is an optional worked-solution diagram for the review
        // screen (server-only, served after grading).
        AnswerImage string
        // Video is an optional walkthrough link carried with the key.
        Video string
}

// Sealed answer keys are served from the in-memory grading cache
// (built from the content library at boot). The database no longer
// stores key rows — this closes the repeated-reseed bloat path that
// once pushed study.answer_keys past 100 MB.

// -------------------------------------------------------------- attempts

type Attempt struct {
        ID          string     `json:"id"`
        UserID      string     `json:"-"`
        Code        string     `json:"code"`
        Status      string     `json:"status"`
        StartedAt   time.Time  `json:"startedAt"`
        SubmittedAt *time.Time `json:"submittedAt,omitempty"`
        DurationMs  *int       `json:"-"`
        // DailyDay is set when the attempt is the ROADMAP #20 daily
        // challenge for that UTC day (NULL for ordinary papers). It
        // rides the JSON so clients can reopen the sprint under the
        // "Daily Quiz" head instead of the composed paper's label.
        DailyDay *time.Time `json:"dailyDay,omitempty"`
}

type Picked struct {
        QuestionID string
        Selected   string
}

// CreateAttempt opens an attempt. order (possibly nil) is the
// question sequence for this paper — the adaptive weak-topic-first walk
// (ROADMAP #5) or the daily challenge's seeded selection (ROADMAP #20);
// adaptive records whether the student asked for it, for history and
// telemetry. dailyDay (possibly nil) marks the attempt as that day's
// challenge.
func (s *Store) CreateAttempt(ctx context.Context, userID, code string, order []string, adaptive bool, dailyDay *time.Time) (*Attempt, error) {
        a := &Attempt{UserID: userID, Code: code, Status: "in_progress"}
        err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.attempts (user_id, code, question_order, adaptive, daily_day)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING id, status, started_at`, userID, code, order, adaptive, dailyDay,
        ).Scan(&a.ID, &a.Status, &a.StartedAt)
        if err != nil {
                return nil, fmt.Errorf("store: create attempt: %w", err)
        }
        return a, nil
}

// SubmitAttempt flips an in_progress attempt to grading and persists the
// picked answers in one transaction. Returns false if the attempt was not
// owned by the user or was not in_progress (idempotent-submission guard).
func (s *Store) SubmitAttempt(ctx context.Context, attemptID, userID string, answers []Picked, durationMs *int) (bool, error) {
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return false, fmt.Errorf("store: submit begin: %w", err)
        }
        defer tx.Rollback(ctx)

        tag, err := tx.Exec(ctx, `
                UPDATE study.attempts
                SET status = 'grading', submitted_at = now(), duration_ms = COALESCE($3, duration_ms)
                WHERE id = $1 AND user_id = $2 AND status = 'in_progress'`,
                attemptID, userID, durationMs)
        if err != nil {
                return false, fmt.Errorf("store: submit update: %w", err)
        }
        if tag.RowsAffected() == 0 {
                return false, nil
        }
        b := &pgx.Batch{}
        for _, a := range answers {
                b.Queue(`
                        INSERT INTO study.attempt_answers (attempt_id, question_id, selected)
                        VALUES ($1, $2, $3)
                        ON CONFLICT (attempt_id, question_id) DO UPDATE SET selected = EXCLUDED.selected`,
                        attemptID, a.QuestionID, a.Selected)
        }
        br := tx.SendBatch(ctx, b)
        for range answers {
                if _, err := br.Exec(); err != nil {
                        br.Close()
                        return false, fmt.Errorf("store: submit answer: %w", err)
                }
        }
        if err := br.Close(); err != nil {
                return false, fmt.Errorf("store: submit answers flush: %w", err)
        }
        if err := tx.Commit(ctx); err != nil {
                return false, fmt.Errorf("store: submit commit: %w", err)
        }
        return true, nil
}

func (s *Store) AttemptByID(ctx context.Context, attemptID, userID string) (*Attempt, error) {
        a := &Attempt{}
        var submitted *time.Time
        var duration *int
        var dailyDay *time.Time
        err := s.Pool.QueryRow(ctx, `
                SELECT id, user_id, code, status, started_at, submitted_at, duration_ms, daily_day
                FROM study.attempts WHERE id = $1 AND user_id = $2`, attemptID, userID,
        ).Scan(&a.ID, &a.UserID, &a.Code, &a.Status, &a.StartedAt, &submitted, &duration, &dailyDay)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: attempt by id: %w", err)
        }
        a.SubmittedAt, a.DurationMs, a.DailyDay = submitted, duration, dailyDay
        return a, nil
}

// AnswersForAttempt loads a student's picked answers for grading.
func (s *Store) AnswersForAttempt(ctx context.Context, attemptID string) ([]Picked, error) {
        rows, err := s.Pool.Query(ctx, `
                SELECT question_id, selected FROM study.attempt_answers WHERE attempt_id = $1`, attemptID)
        if err != nil {
                return nil, fmt.Errorf("store: answers for attempt: %w", err)
        }
        defer rows.Close()
        var out []Picked
        for rows.Next() {
                var p Picked
                if err := rows.Scan(&p.QuestionID, &p.Selected); err != nil {
                        return nil, fmt.Errorf("store: scan answer: %w", err)
                }
                out = append(out, p)
        }
        return out, rows.Err()
}

func (s *Store) SetAttemptStatus(ctx context.Context, attemptID, status string) error {
        _, err := s.Pool.Exec(ctx, `UPDATE study.attempts SET status = $2 WHERE id = $1`, attemptID, status)
        if err != nil {
                return fmt.Errorf("store: set attempt status: %w", err)
        }
        return nil
}

// --------------------------------------------------------------- results

type TopicRow struct {
        Topic   string `json:"topic"`
        Correct int    `json:"correct"`
        Total   int    `json:"total"`
}

type Result struct {
        Score     int        `json:"score"`
        Total     int        `json:"total"`
        Breakdown []TopicRow `json:"breakdown"`
        GradedAt  time.Time  `json:"-"`
}

func (s *Store) WriteResult(ctx context.Context, attemptID string, r *Result) error {
        breakdown, err := json.Marshal(r.Breakdown)
        if err != nil {
                return fmt.Errorf("store: marshal breakdown: %w", err)
        }
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return fmt.Errorf("store: result begin: %w", err)
        }
        defer tx.Rollback(ctx)
        if _, err := tx.Exec(ctx, `
                INSERT INTO study.results (attempt_id, score, total, breakdown, graded_at)
                VALUES ($1, $2, $3, $4::jsonb, now())
                ON CONFLICT (attempt_id) DO UPDATE
                SET score = EXCLUDED.score, total = EXCLUDED.total,
                    breakdown = EXCLUDED.breakdown, graded_at = now()`,
                attemptID, r.Score, r.Total, string(breakdown)); err != nil {
                return fmt.Errorf("store: insert result: %w", err)
        }
        if _, err := tx.Exec(ctx,
                `UPDATE study.attempts SET status = 'graded' WHERE id = $1`, attemptID); err != nil {
                return fmt.Errorf("store: mark graded: %w", err)
        }
        if err := tx.Commit(ctx); err != nil {
                return fmt.Errorf("store: result commit: %w", err)
        }
        return nil
}

func (s *Store) ResultByAttempt(ctx context.Context, attemptID string) (*Result, error) {
        var breakdown []byte
        r := &Result{}
        err := s.Pool.QueryRow(ctx, `
                SELECT score, total, breakdown, graded_at
                FROM study.results WHERE attempt_id = $1`, attemptID,
        ).Scan(&r.Score, &r.Total, &breakdown, &r.GradedAt)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: result by attempt: %w", err)
        }
        if err := json.Unmarshal(breakdown, &r.Breakdown); err != nil {
                return nil, fmt.Errorf("store: unmarshal breakdown: %w", err)
        }
        return r, nil
}

// ----------------------------------------------------- attempt history

// AttemptRow is one line of a student's paper history: the attempt joined
// with its graded result (score/total stay null until the engine marks it).
type AttemptRow struct {
        ID          string     `json:"attemptId"`
        Code        string     `json:"code"`
        Status      string     `json:"status"`
        StartedAt   time.Time  `json:"startedAt"`
        SubmittedAt *time.Time `json:"submittedAt,omitempty"`
        DurationMs  *int       `json:"durationMs,omitempty"`
        Score       *int       `json:"score,omitempty"`
        Total       *int       `json:"total,omitempty"`
}

// AttemptsByUser lists a scholar's papers, newest first, capped at limit.
// Feeds the launcher's recent-activity feed and the review tab.
func (s *Store) AttemptsByUser(ctx context.Context, userID string, limit int) ([]*AttemptRow, error) {
        if limit <= 0 || limit > 200 {
                limit = 50
        }
        rows, err := s.Pool.Query(ctx, `
                SELECT a.id, a.code, a.status, a.started_at, a.submitted_at, a.duration_ms,
                       r.score, r.total
                FROM study.attempts a
                LEFT JOIN study.results r ON r.attempt_id = a.id
                WHERE a.user_id = $1
                ORDER BY a.started_at DESC
                LIMIT $2`, userID, limit)
        if err != nil {
                return nil, fmt.Errorf("store: attempts by user: %w", err)
        }
        defer rows.Close()
        out := []*AttemptRow{}
        for rows.Next() {
                r := &AttemptRow{}
                if err := rows.Scan(&r.ID, &r.Code, &r.Status, &r.StartedAt, &r.SubmittedAt,
                        &r.DurationMs, &r.Score, &r.Total); err != nil {
                        return nil, fmt.Errorf("store: scan attempt row: %w", err)
                }
                out = append(out, r)
        }
        return out, rows.Err()
}

// ------------------------------------------------------------ sync jobs

type SyncJob struct {
        ID        string          `json:"id"`
        Status    string          `json:"status"`
        Progress  int             `json:"progress"`
        Detail    json.RawMessage `json:"detail,omitempty"`
        CreatedAt time.Time       `json:"-"`
        UpdatedAt time.Time       `json:"-"`
}

func (s *Store) CreateSyncJob(ctx context.Context, userID string, total int) (string, error) {
        var id string
        detail, _ := json.Marshal(map[string]int{"total": total})
        err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.sync_jobs (user_id, status, progress, detail)
                VALUES ($1, 'running', 0, $2::jsonb)
                RETURNING id`, userID, string(detail)).Scan(&id)
        if err != nil {
                return "", fmt.Errorf("store: create sync job: %w", err)
        }
        return id, nil
}

func (s *Store) UpdateSyncJobProgress(ctx context.Context, jobID string, progress int, detail map[string]any) error {
        raw, _ := json.Marshal(detail)
        _, err := s.Pool.Exec(ctx, `
                UPDATE study.sync_jobs
                SET progress = $2, detail = $3::jsonb, updated_at = now()
                WHERE id = $1`, jobID, progress, string(raw))
        if err != nil {
                return fmt.Errorf("store: update sync job: %w", err)
        }
        return nil
}

func (s *Store) FinishSyncJob(ctx context.Context, jobID string, detail map[string]any) error {
        raw, _ := json.Marshal(detail)
        _, err := s.Pool.Exec(ctx, `
                UPDATE study.sync_jobs
                SET status = 'done', progress = 100, detail = $2::jsonb, updated_at = now()
                WHERE id = $1`, jobID, string(raw))
        if err != nil {
                return fmt.Errorf("store: finish sync job: %w", err)
        }
        return nil
}

func (s *Store) LatestSyncJob(ctx context.Context, userID string) (*SyncJob, error) {
        j := &SyncJob{}
        err := s.Pool.QueryRow(ctx, `
                SELECT id, status, progress, detail, created_at, updated_at
                FROM study.sync_jobs WHERE user_id = $1
                ORDER BY created_at DESC LIMIT 1`, userID,
        ).Scan(&j.ID, &j.Status, &j.Progress, &j.Detail, &j.CreatedAt, &j.UpdatedAt)
        if errors.Is(err, pgx.ErrNoRows) {
                return nil, nil
        }
        if err != nil {
                return nil, fmt.Errorf("store: latest sync job: %w", err)
        }
        return j, nil
}
