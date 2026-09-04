// e2eclean deletes the throwaway users created by scripts/api-e2e.sh ,
// used after running the E2E against a REAL database (Neon) so test
// scholars never linger. CASCADE drops their profiles/attempts/results.
//
// Usage: DATABASE_URL=postgres://… go run ./cmd/e2eclean -prefix e2e
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

func main() {
	prefix := flag.String("prefix", "e2e", "username prefix to purge (case-insensitive)")
	flag.Parse()

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		fmt.Fprintln(os.Stderr, "e2eclean: DATABASE_URL is required")
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		fmt.Fprintln(os.Stderr, "e2eclean: connect:", err)
		os.Exit(1)
	}
	defer conn.Close(ctx)

	tag, err := conn.Exec(ctx,
		`DELETE FROM study.users WHERE lower(username) LIKE lower($1) || '%'`, *prefix)
	if err != nil {
		fmt.Fprintln(os.Stderr, "e2eclean: delete:", err)
		os.Exit(1)
	}
	fmt.Printf("e2eclean: removed %d user(s) with prefix %q\n", tag.RowsAffected(), *prefix)
}
