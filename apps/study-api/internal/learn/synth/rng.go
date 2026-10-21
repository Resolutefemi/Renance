// Package synth is Renance's deterministic deep content engine: given
// a course and a topic it produces the full lesson (10+ long note
// sections, 20 quiz items: 10 easy + 10 hard) with ZERO AI calls.
//
// Why: the founder's directive 2026-10-16 - the AI API does not have
// the capacity to generate notes and quizzes for 10,000+ tertiary
// courses x 15 units x 10 topics, so the agent builds the content
// engine itself. Every output is a pure function of the topic id:
// the same topic always synthesizes byte identical content, so the
// API, the bulk pre generator and a rebuild all agree.
package synth

import (
	"fmt"
	"hash/fnv"
	"math/rand"
	"strings"
)

// RNG is a small deterministic PRNG seeded from a string. It wraps
// math/rand with a fixed seed so every synthesis run for the same
// topic walks the same path (the founder: content must be stable -
// a student who reopens a topic sees the same lesson).
type RNG struct{ r *rand.Rand }

// NewRNG seeds a PRNG from a string key (fnv1a 32 bit).
func NewRNG(key string) *RNG {
	h := fnv.New32a()
	_, _ = h.Write([]byte(key))
	return &RNG{r: rand.New(rand.NewSource(int64(h.Sum32())))}
}

// Intn returns a non negative pseudo random in [0,n). n<=0 yields 0.
func (g *RNG) Intn(n int) int {
	if n <= 0 {
		return 0
	}
	return g.r.Intn(n)
}

// Pick returns one element of pool (empty string when pool is empty).
func (g *RNG) Pick(pool []string) string {
	if len(pool) == 0 {
		return ""
	}
	return pool[g.r.Intn(len(pool))]
}

// PickN draws k distinct elements from pool (fewer when the pool is
// smaller). Order is randomized. Used for distractor harvesting.
func (g *RNG) PickN(pool []string, k int) []string {
	if k >= len(pool) {
		out := append([]string(nil), pool...)
		g.r.Shuffle(len(out), func(i, j int) { out[i], out[j] = out[j], out[i] })
		return out
	}
	idx := g.r.Perm(len(pool))[:k]
	out := make([]string, 0, k)
	for _, i := range idx {
		out = append(out, pool[i])
	}
	return out
}

// Shuffle returns a shuffled copy of pool.
func (g *RNG) Shuffle(pool []string) []string {
	out := append([]string(nil), pool...)
	g.r.Shuffle(len(out), func(i, j int) { out[i], out[j] = out[j], out[i] })
	return out
}

// Int returns a pseudo random int in [lo,hi] (inclusive).
func (g *RNG) Int(lo, hi int) int {
	if hi <= lo {
		return lo
	}
	return lo + g.r.Intn(hi-lo+1)
}

// F32 returns a pseudo random float32 in [lo,hi).
func (g *RNG) F32(lo, hi float32) float32 {
	return lo + g.r.Float32()*(hi-lo)
}

// Fill replaces every {slot} in the template with values[slot]; a slot
// with no value stays out (the surrounding spaces are squeezed).
func Fill(tpl string, values map[string]string) string {
	out := tpl
	for k, v := range values {
		out = strings.ReplaceAll(out, "{"+k+"}", v)
	}
	// drop unfilled slots and squeeze doubled spaces
	out = strings.ReplaceAll(out, "{}", "")
	for strings.Contains(out, "  ") {
		out = strings.ReplaceAll(out, "  ", " ")
	}
	out = strings.TrimSpace(out)
	out = strings.Trim(out, " ,.")
	if out != "" {
		out += ""
	}
	return out
}

// Cap upper cases the first rune (sentence start).
func Cap(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	if r[0] >= 'a' && r[0] <= 'z' {
		r[0] = r[0] - 32
	}
	return string(r)
}

// Sentence joins fragments into one sentence and capitalizes it.
func Sentence(parts ...string) string {
	s := strings.TrimSpace(strings.Join(parts, " "))
	return Cap(s)
}

// ID returns a stable, readable id for a synthesized question.
func QID(topicID, band string, n int) string {
	return fmt.Sprintf("%s-%s%02d", topicID, band, n)
}
