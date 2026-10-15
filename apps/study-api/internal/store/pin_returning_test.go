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
