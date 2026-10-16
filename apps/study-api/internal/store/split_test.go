// split_test.go - the routing + purity guards for the split-horizon
// store (founder directive 2026-10-16). Two jobs:
//
//  1. classifySQL table-driven cases (routing correctness).
//  2. A source-tree sweep: every backtick SQL literal in the API
//     must be single-domain (or domain-free). A statement naming
//     tables from two domains cannot run across the split - the
//     founder's users-on-Neon+InsForge / catalog-on-Supabase /
//     cache-on-InsForge layout depends on the rewrite backlog
//     staying at ZERO, so any new cross-domain join fails CI here
//     before it can fail a student request.
package store

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestClassifySQL(t *testing.T) {
	cases := []struct {
		sql  string
		want int
	}{
		{`SELECT * FROM study.users WHERE id = $1`, domainUser},
		{`INSERT INTO learn.progress (user_id, topic_id) VALUES ($1, $2)`, domainUser},
		{`SELECT COUNT(*) FROM social.posts`, domainUser},
		{`UPDATE school.students SET name = $1`, domainUser},
		{`SELECT 1`, domainUser}, // no tables -> user pool
		{`SELECT name FROM learn.departments WHERE dept_id = $1`, domainContent},
		{`SELECT c.title FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id`, domainContent},
		{`SELECT COUNT(*) FROM learn.topics WHERE course_id = $1`, domainContent},
		{`SELECT notes, quiz FROM learn.lessons WHERE topic_id = $1`, domainCache},
		{`INSERT INTO learn.lessons (topic_id, title) VALUES ($1, $2) ON CONFLICT (topic_id) DO NOTHING`, domainCache},
	}
	for _, c := range cases {
		got, mixed := classifySQL(c.sql)
		if mixed {
			t.Errorf("classifySQL(%q) reported MIXED - unexpected for the curated set", c.sql)
		}
		if got != c.want {
			t.Errorf("classifySQL(%q) = %d, want %d", c.sql, got, c.want)
		}
	}
}

func TestClassifySQLMixed(t *testing.T) {
	cases := []struct {
		sql       string
		wantMixed bool
	}{
		{`SELECT t.topic_id FROM learn.topics t JOIN learn.progress pr ON pr.topic_id = t.topic_id`, true},
		{`SELECT c.title FROM learn.courses c WHERE EXISTS (SELECT 1 FROM learn.user_courses uc WHERE uc.course_id = c.course_id)`, true},
		{`SELECT l.quiz FROM learn.lessons l JOIN learn.topics t ON t.topic_id = l.topic_id`, true},
		{`SELECT topic_id, quiz FROM learn.lessons WHERE topic_id = ANY($1)`, false},
	}
	for _, c := range cases {
		_, mixed := classifySQL(c.sql)
		if mixed != c.wantMixed {
			t.Errorf("classifySQL(%q) mixed = %v, want %v", c.sql, mixed, c.wantMixed)
		}
	}
}

// TestNoCrossDomainStatements sweeps every non-test .go file under
// the module and fails on any backtick SQL literal that names tables
// from more than one domain. Mirrors the one-time audit script; runs
// in CI so the backlog can never quietly regrow.
func TestNoCrossDomainStatements(t *testing.T) {
	root := "../.."
	fset := token.NewFileSet()
	bad := 0
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			name := info.Name()
			if name == "node_modules" || name == ".git" || name == "testdata" {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		// Only sweep packages that speak SQL. cmd/synthgen is the
		// offline batch generator: it always runs against ONE database
		// (no router), so its joins are legitimate single-pool SQL.
		if !strings.Contains(path, "/internal/") && !strings.Contains(filepath.ToSlash(path), "/cmd/dbsplit/") {
			return nil
		}
		if strings.Contains(filepath.ToSlash(path), "/cmd/synthgen/") {
			return nil
		}
		f, perr := parser.ParseFile(fset, path, nil, 0)
		if perr != nil {
			return nil // syntax problems are the compiler's job
		}
		ast.Inspect(f, func(n ast.Node) bool {
			bl, ok := n.(*ast.BasicLit)
			if !ok || bl.Kind != token.STRING || !strings.HasPrefix(bl.Value, "`") {
				return true
			}
			sql := strings.Trim(bl.Value, "`")
			if !strings.Contains(sql, "\n") && !sqlLooksLikeSQL(sql) {
				return true
			}
			if !sqlLooksLikeSQL(sql) {
				return true
			}
			_, mixed := classifySQL(sql)
			if mixed {
				bad++
				t.Errorf("%s: cross-domain SQL statement (rewrite as a two-step pool-safe query):\n%.160s",
					fset.Position(bl.Pos()), sql)
			}
			return true
		})
		return nil
	})
	if err != nil {
		t.Fatalf("walk: %v", err)
	}
	if bad > 0 {
		t.Fatalf("%d cross-domain statements found - the split router cannot run them", bad)
	}
}

func sqlLooksLikeSQL(s string) bool {
	up := strings.ToUpper(s)
	for _, kw := range []string{"SELECT ", "INSERT ", "UPDATE ", "DELETE ", "WITH "} {
		if strings.Contains(up, kw) {
			return true
		}
	}
	return false
}
