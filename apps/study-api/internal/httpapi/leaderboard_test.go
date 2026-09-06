package httpapi

import "testing"

// The period parser is the only decision the leaderboard handlers make
// on their own — the SQL itself is verified by the Postgres E2E in CI
// (scripts/api-e2e.sh asserts both boards against a real database).
// These tests pin the contract: empty/default = week, "all" = all, and
// anything unknown is rejected so client bugs cannot silently read the
// wrong board.
func TestBoardPeriod(t *testing.T) {
	cases := []struct {
		raw  string
		want string
		ok   bool
	}{
		{raw: "", want: "week", ok: true},
		{raw: "week", want: "week", ok: true},
		{raw: "all", want: "all", ok: true},
		{raw: "ALL", want: "", ok: false},   // case-sensitive on purpose
		{raw: "month", want: "", ok: false}, // not a board until designed
		{raw: "week ", want: "", ok: false}, // no silent trimming
	}
	for _, tc := range cases {
		got, ok := boardPeriod(tc.raw)
		if ok != tc.ok || (ok && got != tc.want) {
			t.Errorf("boardPeriod(%q) = (%q, %v), want (%q, %v)", tc.raw, got, ok, tc.want, tc.ok)
		}
	}
}
