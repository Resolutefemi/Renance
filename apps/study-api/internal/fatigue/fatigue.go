// Package fatigue (ROADMAP #6), the pure, unit-testable fatigue signal.
//
// The client tracks per-answer latencies and the session wall clock; the
// server re-computes THE SAME signal from the raw numbers it receives, so
// app, web and API always agree on what "your pace is dipping" means.
// No PII exists anywhere in the pipeline, only timing.
//
// The rule set is deliberately small and explainable:
//
//	drift  , the median of the last five answers vs the first five.
//	          A 1.8x slowdown is "mild"; 2.6x is "high" once the sitting
//	          is long enough (>= 30 min) to be a real fatigue curve.
//	length , 50 minutes of sitting is "mild", 75 is "high".
//	samples, fewer than MinAnswers answers says nothing about drift.
package fatigue

import "sort"

const (
	// MinAnswers is the smallest sample that makes drift meaningful.
	MinAnswers = 8
	// DriftMild is the mild slowdown ratio (last5 vs first5 median).
	DriftMild = 1.8
	// DriftHigh is the heavy slowdown ratio, combined with a long sitting.
	DriftHigh = 2.6
	// DriftFloorMinutes: drift only implies fatigue on sittings this long.
	DriftFloorMinutes = 30.0
	// MildMinutes / HighMinutes are the sitting-length thresholds.
	MildMinutes = 50.0
	HighMinutes = 75.0
	// ComboMinutes: mild drift escalates to high at this sitting length.
	ComboMinutes = 40.0
)

// Signal is the fatigue assessment of one sitting. Level is
// "none" | "mild" | "high"; SuggestBreak is true whenever Level is not
// "none", the cue both clients render as the gentle "Take 5" card.
type Signal struct {
	Level        string   `json:"level"`
	SuggestBreak bool     `json:"suggestBreak"`
	Reasons      []string `json:"reasons"`
	DriftRatio   float64  `json:"driftRatio"`
	MedianFirst5 int64    `json:"medianFirst5Ms"`
	MedianLast5  int64    `json:"medianLast5Ms"`
}

// Median returns the median of a copied slice (ms). Empty input → 0.
func Median(ms []int64) int64 {
	if len(ms) == 0 {
		return 0
	}
	s := make([]int64, len(ms))
	copy(s, ms)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	mid := len(s) / 2
	if len(s)%2 == 1 {
		return s[mid]
	}
	return (s[mid-1] + s[mid]) / 2
}

// window returns up to n samples from the head and the tail of the
// recording, in the order answers were given.
func window(ms []int64, n int) ([]int64, []int64) {
	first := ms
	if len(first) > n {
		first = first[:n]
	}
	last := ms
	if len(last) > n {
		last = last[len(last)-n:]
	}
	return first, last
}

// Assess computes the signal for one sitting. latenciesMs must be in the
// order the answers were given; sessionMinutes is the wall-clock length.
// The function is total: any input yields a usable Signal, never an error.
func Assess(latenciesMs []int64, sessionMinutes float64) Signal {
	sig := Signal{Level: "none", SuggestBreak: false, Reasons: []string{}}

	first, last := window(latenciesMs, 5)
	mFirst := Median(first)
	mLast := Median(last)
	sig.MedianFirst5 = mFirst
	sig.MedianLast5 = mLast
	if mFirst > 0 {
		sig.DriftRatio = float64(mLast) / float64(mFirst)
	}

	driftMild := len(latenciesMs) >= MinAnswers && sig.DriftRatio >= DriftMild
	driftHigh := len(latenciesMs) >= MinAnswers && sig.DriftRatio >= DriftHigh &&
		sessionMinutes >= DriftFloorMinutes

	switch {
	case driftHigh:
		sig.Level = "high"
		sig.Reasons = append(sig.Reasons,
			"Answers are taking much longer than they did at the start")
	case driftMild && sessionMinutes >= ComboMinutes:
		sig.Level = "high"
		sig.Reasons = append(sig.Reasons,
			"Your pace is dipping and this has been a long sitting")
	case driftMild:
		sig.Level = "mild"
		sig.Reasons = append(sig.Reasons, "Your pace is dipping")
	}

	if sessionMinutes >= HighMinutes {
		sig.Level = "high"
		sig.Reasons = append(sig.Reasons, "This has been a long session")
	} else if sessionMinutes >= MildMinutes && sig.Level == "none" {
		sig.Level = "mild"
		sig.Reasons = append(sig.Reasons, "This has been a long session")
	}

	sig.SuggestBreak = sig.Level != "none"
	return sig
}

// MaxLevel returns the heavier of two levels ("none" < "mild" < "high").
func MaxLevel(a, b string) string {
	rank := map[string]int{"none": 0, "mild": 1, "high": 2}
	if rank[b] > rank[a] {
		return b
	}
	return a
}
