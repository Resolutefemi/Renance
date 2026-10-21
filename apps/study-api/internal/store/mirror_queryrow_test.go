package store

import (
	"testing"

	"github.com/jackc/pgx/v5"
)

// fakeRow lets us drive mirrorRow.Scan without a database.
type fakeRow struct{ called int }

func (f *fakeRow) Scan(dest ...any) error { f.called++; return nil }

func TestIsWriteSQLExactShapes(t *testing.T) {
	cases := map[string]bool{
		"\n\t\tINSERT INTO study.users (username, password_hash)\n\t\tVALUES ($1, $2)\n\t\tRETURNING id, created_at": true,
		"INSERT INTO learn.learners (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING":                          true,
		"UPDATE learn.learners SET institution_type=$2, department=$3 WHERE user_id=$1":                              true,
		"SELECT COUNT(*) FROM learn.departments WHERE dept_id=$1":                                                    false,
		"WITH ranked AS (SELECT user_id FROM learn.x) SELECT * FROM ranked":                                          false,
		"\n  \tSELECT id, username FROM study.users WHERE google_sub = $1":                                           false,
		"SELECT study.purge_user($1)":        true,
		"SELECT study.purge_deleted_users()": true,
	}
	for sql, want := range cases {
		if got := isWriteSQL(sql); got != want {
			t.Errorf("isWriteSQL(%q) = %v, want %v", sql, got, want)
		}
	}
}

// TestMirrorRowDispatchesOnScan proves a write-with-RETURNING riding
// QueryRow fans out after a successful scan.
func TestMirrorRowDispatchesOnScan(t *testing.T) {
	m := &Mirror{enabled: true}
	w := &mirrorWorker{
		name: "test",
		pool: nil, // never touched: we only check the channel
		ch:   make(chan mirrorOp, 4),
		m:    m,
		done: make(chan struct{}),
	}
	m.workers = []*mirrorWorker{w}

	inner := &fakeRow{}
	row := &mirrorRow{Row: inner, m: m, sql: "INSERT INTO study.users (username) VALUES ($1) RETURNING id", args: []any{"alice"}}
	var id string
	if err := row.Scan(&id); err != nil {
		t.Fatal(err)
	}
	if inner.called != 1 {
		t.Fatalf("inner scan not called")
	}
	select {
	case op := <-w.ch:
		if op.sql == "" || op.txStmts != nil || op.batch != nil {
			t.Fatalf("unexpected op shape: %+v", op)
		}
	default:
		t.Fatal("mirrorRow.Scan did not dispatch the write to the mirror worker")
	}
	// A second Scan must not dispatch twice.
	_ = row.Scan(&id)
	select {
	case <-w.ch:
		t.Fatal("double dispatch")
	default:
	}
}

var _ pgx.Row = (*mirrorRow)(nil)
var _ pgx.Row = (*fakeRow)(nil)
