package store

import (
        "strings"
        "testing"
        "time"
)

// TestPinReturningValuesShapes covers the exact INSERT..RETURNING
// shapes the codebase rides through QueryRow (verified by scan). The
// mirror must replay them with the PRIMARY's generated values pinned
// into the column list, so FK children replicate cleanly.
func TestPinReturningValuesShapes(t *testing.T) {
        sqlUsers := `
                INSERT INTO study.users (username, password_hash)
                VALUES ($1, $2)
                RETURNING id, created_at`
        newSQL, args, pinned := pinReturningValues(sqlUsers, []any{"alice", "hash"}, []any{ptr("11111111-1111-1111-1111-111111111111"), ptr(time.Unix(1700000000, 0))})
        if !pinned {
                t.Fatal("expected the users insert to be pinned")
        }
        want := "INSERT INTO study.users (username, password_hash, id, created_at) VALUES ($1, $2, $3, $4)"
        if newSQL != want {
                t.Fatalf("got:  %s\nwant: %s", newSQL, want)
        }
        if len(args) != 4 || args[2] != "11111111-1111-1111-1111-111111111111" {
                t.Fatalf("args: %v", args)
        }

        // ON CONFLICT variant keeps its suffix.
        sqlClasses := `INSERT INTO school.classes (school_id, name, level, seq) VALUES ($1, $2, $3, $4)
                ON CONFLICT (school_id, name) DO UPDATE SET seq = EXCLUDED.seq RETURNING id`
        newSQL, args, pinned = pinReturningValues(sqlClasses, []any{"s1", "JSS 1A", "junior", int64(1)}, []any{ptr(int64(42))})
        if !pinned {
                t.Fatal("expected the on-conflict insert to be pinned")
        }
        if !strings.Contains(newSQL, "ON CONFLICT (school_id, name) DO UPDATE SET seq = EXCLUDED.seq") {
                t.Fatalf("suffix lost: %s", newSQL)
        }
        if !strings.Contains(newSQL, "level, seq, id) VALUES ($1, $2, $3, $4, $5)") {
                t.Fatalf("cols/placeholders wrong: %s", newSQL)
        }
        if len(args) != 5 || args[4] != int64(42) {
                t.Fatalf("args: %v", args)
        }

        // Literal-heavy VALUES (interval arithmetic) survives tuple scanning.
        sqlSchool := `INSERT INTO school.schools (name, school_type, owner_user_id, plan, trial_ends_at)
                VALUES ($1, $2, $3, 'trial', now() + interval '30 days') RETURNING id`
        newSQL, _, pinned = pinReturningValues(sqlSchool, []any{"n", "secondary", "u1"}, []any{ptr("abc")})
        if !pinned {
                t.Fatal("expected literal-heavy insert to be pinned")
        }
        if !strings.Contains(newSQL, "VALUES ($1, $2, $3, 'trial', now() + interval '30 days', $4)") {
                t.Fatalf("values mangled: %s", newSQL)
        }

        // UPDATE..RETURNING replays verbatim (no ids to pin).
        sqlUpd := `UPDATE study.users SET password_hash = $2 WHERE id = $1 RETURNING id, username`
        newSQL, args, pinned = pinReturningValues(sqlUpd, []any{"u", "h"}, []any{ptr("u"), ptr("alice")})
        if pinned {
                t.Fatal("update must replay verbatim")
        }
        if newSQL != strings.TrimSpace(sqlUpd) || len(args) != 2 {
                t.Fatalf("update changed: %s %v", newSQL, args)
        }

        // Returning a column that is already inserted explicitly is not
        // duplicated.
        sqlNoDup := `INSERT INTO study.ai_chats (user_id, folder, title) VALUES ($1, $2, $3) RETURNING id, folder, title, updated_at`
        newSQL, _, pinned = pinReturningValues(sqlNoDup, []any{"u", "f", "t"}, []any{ptr("id1"), ptr("f2"), ptr("t2"), ptr(time.Unix(1, 0))})
        if !pinned {
                t.Fatal("expected pin")
        }
        if strings.Count(newSQL, "folder") != 1 { // folder is inserted explicitly, so it is not re-added
                t.Fatalf("folder duplicated: %s", newSQL)
        }
        if !strings.Contains(newSQL, "user_id, folder, title, id, updated_at) VALUES ($1, $2, $3, $4, $5)") {
                t.Fatalf("cols wrong: %s", newSQL)
        }

        // jsonb-ish scanned bytes replay as strings.
        sqlPayments := `INSERT INTO study.payments (user_id, provider, plan, amount_kobo, reference, meta)
                VALUES ($1, $2, $3, $4, $5, $6::jsonb) RETURNING id, user_id, provider`
        _, args, pinned = pinReturningValues(sqlPayments,
                []any{"u", "p", "plan", int64(100), "ref", map[string]any{"a": 1}},
                []any{ptr(int64(9)), ptr("u"), ptr("p")})
        // user_id and provider are already inserted explicitly, so only
        // the generated id is pinned.
        if !pinned || len(args) != 7 || args[6] != int64(9) {
                t.Fatalf("payments: pinned=%v args=%v", pinned, args)
        }
}

// TestPinReturningCastColumns covers the school module's house pattern
// - RETURNING lists that cast columns to text ("RETURNING id,
// school_id::text"). The CI bug 2026-10-16: the rewrite copied the cast
// INTO the INSERT column list ("..., school_id::text)"), which is a
// syntax error, so every school write to the mirror died. A cast must
// pin its BASE column; expressions (COALESCE) must be skipped.
func TestPinReturningCastColumns(t *testing.T) {
        // school.fee_payments shape (the exact CI failure).
        sqlFees := `INSERT INTO school.fee_payments (school_id, fee_id, student_id, amount_kobo, method, reference, paid_on)
                VALUES ($1, $2, $3, $4, $5, $6, COALESCE(NULLIF($7,'')::date, current_date))
                RETURNING id, paid_on::text`
        newSQL, args, pinned := pinReturningValues(sqlFees,
                []any{"s1", "f1", "st1", int64(2500), "transfer", "E2E-1", ""},
                []any{ptr("5d2bcd8d-f4fb-4890-bd69-d04e1c7339e1"), ptr("2026-10-16")})
        if !pinned {
                t.Fatal("expected the fee insert to be pinned")
        }
        if strings.Contains(newSQL, "::text)") || strings.Contains(newSQL, "::text,") {
                t.Fatalf("a cast leaked into the column list: %s", newSQL)
        }
        // paid_on is inserted explicitly already (same arg value the
        // primary returned), so only the generated id is appended.
        if !strings.Contains(newSQL, "reference, paid_on, id) VALUES") {
                t.Fatalf("cast column not pinned as its base: %s", newSQL)
        }
        if len(args) != 8 || args[7] != "5d2bcd8d-f4fb-4890-bd69-d04e1c7339e1" {
                t.Fatalf("args: %v", args)
        }

        // school.exams shape: cast column + plain id, ON CONFLICT suffix.
        sqlExams := `INSERT INTO school.exams (school_id, class_id, subject_id, term, session, title, duration_minutes, question_count, status, created_by)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                ON CONFLICT (class_id, subject_id, term, session) DO UPDATE SET title = EXCLUDED.title
                RETURNING id, school_id::text`
        newSQL, _, pinned = pinReturningValues(sqlExams,
                []any{"s1", "c1", "sub1", "1", "2025/2026", "E2E paper", "45", "4", "published", "u1"},
                []any{ptr("b08f2e49"), ptr("s1")})
        if !pinned {
                t.Fatal("expected the exam insert to be pinned")
        }
        if strings.Contains(newSQL, "school_id::text") {
                t.Fatalf("cast leaked into the column list: %s", newSQL)
        }
        if !strings.Contains(newSQL, "created_by, id) VALUES") {
                t.Fatalf("cast base column missing: %s", newSQL)
        }
        // school_id is already inserted explicitly - only id is appended.
        if strings.Count(newSQL, "school_id") != 1 {
                t.Fatalf("school_id duplicated: %s", newSQL)
        }

        // COALESCE expressions are skipped, plain columns still pin.
        sqlCards := `INSERT INTO school.id_cards (school_id, student_id, serial, session)
                VALUES ($1, $2, $3, $4)
                RETURNING id, school_id::text, student_id::text, serial, session, COALESCE(issued_by::text, ''), issued_at`
        var issuedBy *string
        newSQL, args, pinned = pinReturningValues(sqlCards,
                []any{"s1", "st1", "SER-1", "2025/2026"},
                []any{ptr("id1"), ptr("s1"), ptr("st1"), ptr("SER-1"), ptr("2025/2026"), ptr(issuedBy), ptr("2026-10-16")})
        if !pinned {
                t.Fatal("expected the idcard insert to be pinned")
        }
        if strings.Contains(newSQL, "COALESCE") && strings.Contains(newSQL, "RETURNING") {
                t.Fatalf("RETURNING clause survived: %s", newSQL)
        }
        if strings.Contains(newSQL, "issued_by") {
                t.Fatalf("COALESCE expression was not skipped: %s", newSQL)
        }
        if !strings.Contains(newSQL, "serial, session, id, issued_at) VALUES") {
                t.Fatalf("skip/pin mix wrong: %s", newSQL)
        }
        // 4 original args + 2 pinned values (id, issued_at): the cast
        // columns school_id/student_id were inserted explicitly already,
        // so their bases dedupe out and the COALESCE is skipped.
        if len(args) != 6 || args[4] != "id1" || args[5] != "2026-10-16" {
                t.Fatalf("args: %v", args)
        }
}

// TestDerefScanDestBytes verifies []byte scanned values replay as
// strings (jsonb/text round-trip; the schema has no bytea columns).
func TestDerefScanDestBytes(t *testing.T) {
        b := []byte(`{"a":1}`)
        if got := derefScanDest(&b); got != `{"a":1}` {
                t.Fatalf("bytes: %v", got)
        }
        var nilStr *string
        if got := derefScanDest(nilStr); got != nil {
                t.Fatalf("typed nil: %v", got)
        }
        s := "x"
        if got := derefScanDest(&s); got != "x" {
                t.Fatalf("string: %v", got)
        }
}

func ptr[T any](v T) *T { return &v }
