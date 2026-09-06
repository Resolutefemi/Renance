// Package daily is the deterministic heart of the daily challenge
// (ROADMAP #20): one 10-question sprint per exam body per UTC day.
//
// The whole selection is a PURE function of (day, body, library) — no
// state, no scheduler, no locks. Every student on earth gets the same
// pack and the same play order for a given day, which is what makes the
// per-day leaderboard a fair race. The splitmix64 generator is seeded
// from SHA-256 of the inputs so the sequence is stable across process
// restarts, hosts and Go releases (stdlib rand makes no such promise).
package daily

import (
	"crypto/sha256"
	"encoding/binary"
	"sort"

	"renance.dev/study-api/internal/cbtdata"
)

// Size is the number of questions in one day's challenge. Packs with
// fewer questions are served whole.
const Size = 10

// IDs flattens a bundle's question ids in pack order — the natural
// order every deterministic shuffle below starts from.
func IDs(b *cbtdata.Bundle) []string {
	ids := make([]string, len(b.Questions))
	for i, q := range b.Questions {
		ids[i] = q.ID
	}
	return ids
}

// PickCode returns the pack that carries the body's challenge on the
// given day: the body's bundle codes sorted lexicographically, indexed
// by a seeded draw. cbtdata hands codes over pre-sorted; sort again
// here so the contract holds regardless of the caller.
func PickCode(day, body string, codes []string) string {
	if len(codes) == 0 {
		return ""
	}
	sorted := append([]string(nil), codes...)
	sort.Strings(sorted)
	r := newRNG("pack", day, body)
	return sorted[r.intn(len(sorted))]
}

// QuestionIDs returns the day's challenge: a seeded shuffle of the
// pack's question ids capped at Size, in play order. Same day + body +
// ids always yields the same sequence.
func QuestionIDs(day, body string, ids []string) []string {
	if len(ids) == 0 {
		return nil
	}
	pool := append([]string(nil), ids...)
	r := newRNG("questions", day, body)
	// Fisher-Yates from a deterministic generator: every prefix of the
	// shuffled pool is an unbiased sample, so the Size cut is fair.
	for i := len(pool) - 1; i > 0; i-- {
		j := r.intn(i + 1)
		pool[i], pool[j] = pool[j], pool[i]
	}
	if len(pool) > Size {
		pool = pool[:Size]
	}
	return pool
}

// newRNG derives a splitmix64 stream from SHA-256(domain|day|body), so
// the "pack" and "questions" draws are independent even for the same
// day+body pair.
func newRNG(domain, day, body string) *rng {
	sum := sha256.Sum256([]byte(domain + "|" + day + "|" + body))
	return &rng{s: binary.BigEndian.Uint64(sum[:8])}
}

// rng is splitmix64 — 15 lines, fully deterministic, no reliance on
// stdlib rand sequences staying put across Go releases.
type rng struct{ s uint64 }

func (r *rng) next() uint64 {
	r.s += 0x9e3779b97f4a7c15
	z := r.s
	z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9
	z = (z ^ (z >> 27)) * 0x94d049bb133111eb
	return z ^ (z >> 31)
}

// intn maps one draw into [0, n) via multiply-high — modulo bias stays
// below 2^-48, irrelevant for quiz selection.
func (r *rng) intn(n int) int {
	if n <= 1 {
		return 0
	}
	return int((r.next() >> 16) * uint64(n) >> 48)
}
