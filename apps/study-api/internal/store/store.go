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
	TargetYear  *int      `json:"targetYear,omitempty"`
	Completed   bool      `json:"completed"`
	UpdatedAt   time.Time `json:"-"`
}

func (s *Store) UpsertProfile(ctx context.Context, userID string, p *Profile) (*Profile, error) {
	examsJSON, err := json.Marshal(p.Exams)
	if err != nil {
		return nil, fmt.Errorf("store: marshal exams: %w", err)
	}
	out := &Profile{}
	err = s.Pool.QueryRow(ctx, `
                INSERT INTO study.profiles (user_id, full_name, institution, grade_level, exams, target_year, completed, updated_at)
                VALUES ($1, $2, $3, $4, $5::jsonb, $6, true, now())
                ON CONFLICT (user_id) DO UPDATE
                SET full_name   = EXCLUDED.full_name,
                    institution = EXCLUDED.institution,
                    grade_level = EXCLUDED.grade_level,
                    exams       = EXCLUDED.exams,
                    target_year = EXCLUDED.target_year,
                    completed   = true,
                    updated_at  = now()
                RETURNING full_name, institution, grade_level, exams, target_year, completed, updated_at`,
		userID, p.FullName, p.Institution, p.GradeLevel, string(examsJSON), p.TargetYear,
	).Scan(&out.FullName, &out.Institution, &out.GradeLevel, &examsJSON, &out.TargetYear, &out.Completed, &out.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("store: upsert profile: %w", err)
	}
	if err := json.Unmarshal(examsJSON, &out.Exams); err != nil {
		return nil, fmt.Errorf("store: unmarshal exams: %w", err)
	}
	return out, nil
}

func (s *Store) ProfileByUser(ctx context.Context, userID string) (*Profile, error) {
	var examsJSON []byte
	p := &Profile{}
	err := s.Pool.QueryRow(ctx, `
                SELECT full_name, institution, grade_level, exams, target_year, completed, updated_at
                FROM study.profiles WHERE user_id = $1`, userID,
	).Scan(&p.FullName, &p.Institution, &p.GradeLevel, &examsJSON, &p.TargetYear, &p.Completed, &p.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("store: profile by user: %w", err)
	}
	if err := json.Unmarshal(examsJSON, &p.Exams); err != nil {
		return nil, fmt.Errorf("store: unmarshal exams: %w", err)
	}
	return p, nil
}

// ---------------------------------------------------------- answer keys

type KeyEntry struct {
	Letter      string
	Explanation string
}

// AllKeys loads every key row, grouped by bank code. Grading cache boot.
func (s *Store) AllKeys(ctx context.Context) (map[string]map[string]KeyEntry, error) {
	rows, err := s.Pool.Query(ctx, `SELECT code, question_id, letter FROM study.answer_keys`)
	if err != nil {
		return nil, fmt.Errorf("store: all keys: %w", err)
	}
	defer rows.Close()
	out := map[string]map[string]KeyEntry{}
	for rows.Next() {
		var code, qid, letter string
		if err := rows.Scan(&code, &qid, &letter); err != nil {
			return nil, fmt.Errorf("store: scan key: %w", err)
		}
		if out[code] == nil {
			out[code] = map[string]KeyEntry{}
		}
		out[code][qid] = KeyEntry{Letter: letter}
	}
	return out, rows.Err()
}

// SeedKeys upserts a full key set for one bank (content pipeline bootstrapping).
func (s *Store) SeedKeys(ctx context.Context, code string, keys map[string]KeyEntry) (int, error) {
	b := &pgx.Batch{}
	for qid, k := range keys {
		b.Queue(`
                        INSERT INTO study.answer_keys (code, question_id, letter, explanation)
                        VALUES ($1, $2, $3, $4)
                        ON CONFLICT (code, question_id) DO UPDATE
                        SET letter = EXCLUDED.letter, explanation = EXCLUDED.explanation`,
			code, qid, k.Letter, k.Explanation)
	}
	br := s.Pool.SendBatch(ctx, b)
	defer br.Close()
	for range keys {
		if _, err := br.Exec(); err != nil {
			return 0, fmt.Errorf("store: seed key: %w", err)
		}
	}
	return len(keys), nil
}

// -------------------------------------------------------------- attempts

type Attempt struct {
	ID          string     `json:"id"`
	UserID      string     `json:"-"`
	Code        string     `json:"code"`
	Status      string     `json:"status"`
	StartedAt   time.Time  `json:"startedAt"`
	SubmittedAt *time.Time `json:"submittedAt,omitempty"`
	DurationMs  *int       `json:"-"`
}

type Picked struct {
	QuestionID string
	Selected   string
}

// CreateAttempt opens an attempt. order (possibly nil) is the
// adaptive weak-topic-first question sequence for this paper; adaptive
// records whether the student asked for it, for history and telemetry.
func (s *Store) CreateAttempt(ctx context.Context, userID, code string, order []string, adaptive bool) (*Attempt, error) {
	a := &Attempt{UserID: userID, Code: code, Status: "in_progress"}
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.attempts (user_id, code, question_order, adaptive)
                VALUES ($1, $2, $3, $4)
                RETURNING id, status, started_at`, userID, code, order, adaptive,
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
	err := s.Pool.QueryRow(ctx, `
                SELECT id, user_id, code, status, started_at, submitted_at, duration_ms
                FROM study.attempts WHERE id = $1 AND user_id = $2`, attemptID, userID,
	).Scan(&a.ID, &a.UserID, &a.Code, &a.Status, &a.StartedAt, &submitted, &duration)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("store: attempt by id: %w", err)
	}
	a.SubmittedAt, a.DurationMs = submitted, duration
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

// KeysForBank loads the sealed key rows of one pack. Used by the answer
// review route: keys stay server-side; only post-grade explanations leave.
func (s *Store) KeysForBank(ctx context.Context, code string) (map[string]KeyEntry, error) {
	rows, err := s.Pool.Query(ctx, `
		SELECT question_id, letter, explanation
		FROM study.answer_keys WHERE code = $1`, code)
	if err != nil {
		return nil, fmt.Errorf("store: keys for bank: %w", err)
	}
	defer rows.Close()
	out := map[string]KeyEntry{}
	for rows.Next() {
		var qid, letter, explanation string
		if err := rows.Scan(&qid, &letter, &explanation); err != nil {
			return nil, fmt.Errorf("store: scan key: %w", err)
		}
		out[qid] = KeyEntry{Letter: letter, Explanation: explanation}
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
