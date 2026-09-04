package fatigue

import (
	"reflect"
	"testing"
)

func TestMedian(t *testing.T) {
	cases := []struct {
		name string
		in   []int64
		want int64
	}{
		{"empty", nil, 0},
		{"single", []int64{7}, 7},
		{"odd", []int64{5, 1, 3}, 3},
		{"even", []int64{4, 2}, 3},
		{"even wide", []int64{1, 2, 100, 200}, 51},
		{"unsorted", []int64{900, 100, 500, 300, 700}, 500},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := Median(tc.in); got != tc.want {
				t.Fatalf("Median(%v) = %d, want %d", tc.in, got, tc.want)
			}
		})
	}
}

// Median must never mutate its input — callers log the raw recording.
func TestMedianDoesNotMutate(t *testing.T) {
	in := []int64{9, 1, 5}
	_ = Median(in)
	if !reflect.DeepEqual(in, []int64{9, 1, 5}) {
		t.Fatalf("Median mutated input: %v", in)
	}
}

func steady(n int, ms int64) []int64 {
	out := make([]int64, n)
	for i := range out {
		out[i] = ms
	}
	return out
}

func TestAssessTooFewAnswers(t *testing.T) {
	// A short sitting with no length signal: even wild numbers say nothing.
	got := Assess([]int64{1000, 90000, 500}, 5)
	if got.Level != "none" || got.SuggestBreak {
		t.Fatalf("short sitting with <8 answers should be none, got %+v", got)
	}
}

func TestAssessDriftMild(t *testing.T) {
	lat := append(steady(5, 8000), steady(5, 20000)...) // 2.5x slow-down
	got := Assess(lat, 20)
	if got.Level != "mild" || !got.SuggestBreak {
		t.Fatalf("drift alone under 30min should be mild, got %+v", got)
	}
	if got.DriftRatio < 1.8 {
		t.Fatalf("drift ratio should capture the slow-down: %+v", got)
	}
	if got.MedianFirst5 != 8000 || got.MedianLast5 != 20000 {
		t.Fatalf("medians wrong: %+v", got)
	}
}

func TestAssessDriftHighOnLongSitting(t *testing.T) {
	lat := append(steady(5, 5000), steady(5, 25000)...) // 5x
	got := Assess(lat, 42)
	if got.Level != "high" {
		t.Fatalf("5x drift over 42min should be high, got %+v", got)
	}
}

func TestAssessDriftNeedsLengthFloor(t *testing.T) {
	// Heavy drift inside a SHORT sitting stays mild — a fast dash is not fatigue.
	lat := append(steady(5, 5000), steady(5, 25000)...)
	got := Assess(lat, 10)
	if got.Level != "mild" {
		t.Fatalf("heavy drift under 30min should stay mild, got %+v", got)
	}
}

func TestAssessMildDriftPlusLongSittingEscalates(t *testing.T) {
	lat := append(steady(5, 10000), steady(5, 20000)...) // 2x → mild
	got := Assess(lat, 55)                               // also >= MildMinutes
	if got.Level != "high" {
		t.Fatalf("mild drift + long sitting should escalate to high, got %+v", got)
	}
}

func TestAssessLengthOnly(t *testing.T) {
	mild := Assess(steady(12, 9000), 55)
	if mild.Level != "mild" || len(mild.Reasons) != 1 {
		t.Fatalf("55min steady pace should be mild length-only, got %+v", mild)
	}
	high := Assess(steady(12, 9000), 80)
	if high.Level != "high" {
		t.Fatalf("80min steady pace should be high, got %+v", high)
	}
	edge := Assess(steady(12, 9000), 49.9)
	if edge.Level != "none" {
		t.Fatalf("49.9min steady pace is still none, got %+v", edge)
	}
}

func TestAssessSteadyLongPractice(t *testing.T) {
	got := Assess(steady(40, 12000), 25)
	if got.Level != "none" || got.SuggestBreak {
		t.Fatalf("steady pace, short sitting: no break, got %+v", got)
	}
}

func TestAssessEmpty(t *testing.T) {
	got := Assess(nil, 0)
	if got.Level != "none" || got.Reasons == nil {
		t.Fatalf("empty sitting should give a zero signal with empty reasons, got %+v", got)
	}
}

func TestMaxLevel(t *testing.T) {
	for _, tc := range []struct{ a, b, want string }{
		{"none", "mild", "mild"},
		{"mild", "none", "mild"},
		{"high", "mild", "high"},
		{"none", "none", "none"},
	} {
		if got := MaxLevel(tc.a, tc.b); got != tc.want {
			t.Fatalf("MaxLevel(%s,%s) = %s, want %s", tc.a, tc.b, got, tc.want)
		}
	}
}
